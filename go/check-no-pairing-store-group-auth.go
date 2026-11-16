// abstraction-provenance: {"artifact_sha256": "89530c8c9af37ea03d5f069d66ff60f23f21d675446853133fac936cfc61e030", "source_sha256": "a9a15237ac26649d4fe81c84ab0e7be0474d07af42503d8016279ce5a868359c", "target_language": "go"}
// check-no-pairing-store-group-auth.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-pairing-store-group-auth.mjs
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

var (
	storeIdentifierRe = regexp.MustCompile(`^(?:storeAllowFrom|storedAllowFrom|storeAllowList)$`)
	groupNameRe       = regexp.MustCompile(`(?:groupAllowFrom|effectiveGroupAllowFrom|groupAllowed|groupAllow|groupAuth|groupSender)`)
	storeSourceCallNames = map[string]bool{
		"readChannelAllowFromStore":         true,
		"readChannelAllowFromStoreSync":      true,
		"readStoreAllowFromForDmPolicy":      true,
	}
	allowedResolverCallNames = map[string]bool{
		"resolveEffectiveAllowFromLists":     true,
		"resolveDmGroupAccessWithLists":      true,
		"resolveMattermostEffectiveAllowFromLists": true,
		"resolveIrcEffectiveAllowlists":      true,
	}
	allowedFiles = map[string]bool{
		"src/security/dm-policy-shared.ts": true,
		"src/channels/allow-from.ts":        true,
		"src/security/fix.ts":               true,
		"src/security/audit-channel.ts":    true,
	}
)

type violation struct {
	path   string
	line   int
	reason string
}

func getPropertyNameText(expr ast.Expr) string {
	switch e := expr.(type) {
	case *ast.Ident:
		return e.Name
	case *ast.BasicLit:
		if e.Kind == token.STRING {
			return strings.Trim(e.Value, "\"")
		}
	}
	return ""
}

func containsPairingStoreSource(node ast.Node) bool {
	found := false
	ast.Inspect(node, func(n ast.Node) bool {
		if found {
			return false
		}
		switch x := n.(type) {
		case *ast.Ident:
			if storeIdentifierRe.MatchString(x.Name) {
				found = true
				return false
			}
		case *ast.CallExpr:
			if ident, ok := x.Fun.(*ast.Ident); ok {
				if storeSourceCallNames[ident.Name] {
					found = true
					return false
				}
			}
			if sel, ok := x.Fun.(*ast.SelectorExpr); ok {
				if ident, ok := sel.Sel.(*ast.Ident); ok {
					if storeSourceCallNames[ident.Name] {
						found = true
						return false
					}
				}
			}
		}
		return true
	})
	return found
}

func getCallName(node ast.Node) string {
	call, ok := node.(*ast.CallExpr)
	if !ok {
		return ""
	}
	
	switch fun := call.Fun.(type) {
	case *ast.Ident:
		return fun.Name
	case *ast.SelectorExpr:
		return fun.Sel.Name
	}
	return ""
}

func isSuspiciousNormalizeWithStoreCall(node ast.Node) bool {
	call, ok := node.(*ast.CallExpr)
	if !ok {
		return false
	}
	
	funName := getCallName(call)
	if funName != "normalizeAllowFromWithStore" {
		return false
	}
	
	if len(call.Args) == 0 {
		return false
	}
	
	obj, ok := call.Args[0].(*ast.CompositeLit)
	if !ok {
		return false
	}
	
	hasStoreProp := false
	hasGroupAllowProp := false
	
	for _, elt := range obj.Elts {
		if kv, ok := elt.(*ast.KeyValueExpr); ok {
			propName := getPropertyNameText(kv.Key)
			if propName == "storeAllowFrom" && containsPairingStoreSource(kv.Value) {
				hasStoreProp = true
			}
			if propName == "allowFrom" {
				if ident, ok := kv.Value.(*ast.Ident); ok {
					if groupNameRe.MatchString(ident.Name) {
						hasGroupAllowProp = true
					}
				}
			}
		}
	}
	
	return hasStoreProp && hasGroupAllowProp
}

func findViolations(content, filePath string) ([]violation, error) {
	fset := token.NewFileSet()
	file, err := parser.ParseFile(fset, filePath, content, parser.ParseComments)
	if err != nil {
		return nil, err
	}
	
	var violations []violation
	
	ast.Inspect(file, func(node ast.Node) bool {
		switch n := node.(type) {
		case *ast.ValueSpec:
			for i, name := range n.Names {
				if i < len(n.Values) && n.Values[i] != nil {
					if groupNameRe.MatchString(name.Name) && containsPairingStoreSource(n.Values[i]) {
						callName := getCallName(n.Values[i])
						if allowedResolverCallNames[callName] {
							continue
						}
						pos := fset.Position(n.Pos())
						violations = append(violations, violation{
							path:   filePath,
							line:   pos.Line,
							reason: fmt.Sprintf(`group-scoped variable "%s" references pairing-store identifiers`, name.Name),
						})
					}
				}
			}
		case *ast.KeyValueExpr:
			propName := getPropertyNameText(n.Key)
			if propName != "" && groupNameRe.MatchString(propName) && containsPairingStoreSource(n.Value) {
				pos := fset.Position(n.Pos())
				violations = append(violations, violation{
					path:   filePath,
					line:   pos.Line,
					reason: fmt.Sprintf(`group-scoped property "%s" references pairing-store identifiers`, propName),
				})
			}
		}
		
		if isSuspiciousNormalizeWithStoreCall(node) {
			pos := fset.Position(node.Pos())
			violations = append(violations, violation{
				path:   filePath,
				line:   pos.Line,
				reason: "group allowlist uses normalizeAllowFromWithStore(...) with pairing-store entries",
			})
		}
		
		return true
	})
	
	return violations, nil
}

func collectFileViolations(sourceRoots []string, repoRoot string, skipFile func(string) bool) ([]violation, error) {
	var allViolations []violation
	
	for _, root := range sourceRoots {
		err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return err
			}
			
			if info.IsDir() || !strings.HasSuffix(path, ".ts") {
				return nil
			}
			
			if skipFile(path) {
				return nil
			}
			
			content, err := os.ReadFile(path)
			if err != nil {
				return err
			}
			
			violations, err := findViolations(string(content), path)
			if err != nil {
				return err
			}
			
			allViolations = append(allViolations, violations...)
			return nil
		})
		
		if err != nil {
			return nil, err
		}
	}
	
	return allViolations, nil
}

func resolveFromRepo(repoRoot, relPath string) string {
	return filepath.Join(repoRoot, relPath)
}

func createPairingGuardContext(repoRoot string) ([]string, string) {
	sourceRoots := []string{filepath.Join(repoRoot, "src")}
	return sourceRoots, repoRoot
}

func main() {
	repoRoot, _ := os.Getwd()
	sourceRoots, _ := createPairingGuardContext(repoRoot)
	
	skipFile := func(filePath string) bool {
		relPath, err := filepath.Rel(repoRoot, filePath)
		if err != nil {
			return false
		}
		return allowedFiles[relPath]
	}
	
	violations, err := collectFileViolations(sourceRoots, repoRoot, skipFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error collecting violations: %v\n", err)
		os.Exit(1)
	}
	
	if len(violations) == 0 {
		return
	}
	
	fmt.Fprintln(os.Stderr, "Found pairing-store identifiers referenced in group auth composition:")
	for _, violation := range violations {
		fmt.Fprintf(os.Stderr, "- %s:%d (%s)\n", violation.path, violation.line, violation.reason)
	}
	fmt.Fprintln(os.Stderr, "Group auth must be composed via shared resolvers (resolveDmGroupAccessWithLists / resolveEffectiveAllowFromLists).")
	os.Exit(1)
}

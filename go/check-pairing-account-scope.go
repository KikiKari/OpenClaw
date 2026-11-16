// abstraction-provenance: {"artifact_sha256": "fabd9bc7677ab2515f91decab4d414efd105e4040816bf9eb26b711669960921", "source_sha256": "03602fb41765aad7878e52af85d1c4c5a8d1d8a752b53a46602deb38e8783f73", "target_language": "go"}
// check-pairing-account-scope.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-pairing-account-scope.mjs
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"strings"
)

// PairingGuardContext represents the context for pairing guard checks
type PairingGuardContext struct {
	RepoRoot    string
	SourceRoots []string
}

// Violation represents a found violation
type Violation struct {
	Path   string
	Line   int
	Reason string
}

// createPairingGuardContext creates the context for pairing guard checks
func createPairingGuardContext() *PairingGuardContext {
	// This would need to be adapted based on your project structure
	repoRoot := "." // In a real implementation, this would be determined dynamically
	sourceRoots := []string{"."}
	
	return &PairingGuardContext{
		RepoRoot:    repoRoot,
		SourceRoots: sourceRoots,
	}
}

// isUndefinedLikeExpression checks if a node represents undefined or null
func isUndefinedLikeExpression(expr ast.Expr) bool {
	switch e := expr.(type) {
	case *ast.Ident:
		return e.Name == "undefined"
	case *ast.BasicLit:
		return e.Kind == token.NULL
	}
	return false
}

// hasRequiredAccountIdProperty checks if an object literal has a required accountId property
func hasRequiredAccountIdProperty(expr ast.Expr) bool {
	obj, ok := expr.(*ast.CompositeLit)
	if !ok {
		return false
	}

	for _, elt := range obj.Elts {
		switch e := elt.(type) {
		case *ast.KeyValueExpr:
			if ident, ok := e.Key.(*ast.Ident); ok && ident.Name == "accountId" {
				if !isUndefinedLikeExpression(e.Value) {
					return true
				}
				return false
			}
		case *ast.Ident:
			if e.Name == "accountId" {
				return true
			}
		}
	}
	return false
}

// findViolations finds violations in Go source code
func findViolations(content, filePath string) ([]Violation, error) {
	fset := token.NewFileSet()
	file, err := parser.ParseFile(fset, filePath, content, parser.ParseComments)
	if err != nil {
		return nil, err
	}

	var violations []Violation

	ast.Inspect(file, func(n ast.Node) bool {
		call, ok := n.(*ast.CallExpr)
		if !ok {
			return true
		}

		ident, ok := call.Fun.(*ast.Ident)
		if !ok {
			return true
		}

		callName := ident.Name
		pos := fset.Position(n.Pos())
		
		if callName == "readChannelAllowFromStore" {
			if len(call.Args) < 3 || isUndefinedLikeExpression(call.Args[2]) {
				violations = append(violations, Violation{
					Path:   filePath,
					Line:   pos.Line,
					Reason: "readChannelAllowFromStore call must pass explicit accountId as 3rd arg",
				})
			}
		} else if callName == "readLegacyChannelAllowFromStore" || callName == "readLegacyChannelAllowFromStoreSync" {
			violations = append(violations, Violation{
				Path:   filePath,
				Line:   pos.Line,
				Reason: fmt.Sprintf("%s is legacy-only; use account-scoped readChannelAllowFromStore* APIs", callName),
			})
		} else if callName == "upsertChannelPairingRequest" {
			if len(call.Args) == 0 || !hasRequiredAccountIdProperty(call.Args[0]) {
				violations = append(violations, Violation{
					Path:   filePath,
					Line:   pos.Line,
					Reason: "upsertChannelPairingRequest call must include accountId in params",
				})
			}
		}

		return true
	})

	return violations, nil
}

// collectFileViolations collects violations from files in source roots
func collectFileViolations(ctx *PairingGuardContext) ([]Violation, error) {
	var allViolations []Violation

	for _, root := range ctx.SourceRoots {
		err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return err
			}

			if info.IsDir() {
				return nil
			}

			if !strings.HasSuffix(path, ".go") {
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

func main() {
	ctx := createPairingGuardContext()
	violations, err := collectFileViolations(ctx)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error collecting violations: %v\n", err)
		os.Exit(1)
	}

	if len(violations) == 0 {
		return
	}

	fmt.Fprintln(os.Stderr, "Found unscoped pairing-store calls:")
	for _, violation := range violations {
		fmt.Fprintf(os.Stderr, "- %s:%d (%s)\n", violation.Path, violation.Line, violation.Reason)
	}
	os.Exit(1)
}

// abstraction-provenance: {"artifact_sha256": "0f2d70a3cc99f0e74360c369dde9d99de9a4fd81e340d5fe1e89c56a94f664c2", "source_sha256": "a2afe873e78fca9f7a9bf66785f17d7cad24c6285fd2c0dc6c6bb2abf1e375fa", "target_language": "go"}
// check-channel-agnostic-boundaries.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-channel-agnostic-boundaries.mjs
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

var repoRoot string

var acpCoreProtectedSources = []string{
	filepath.Join("src", "acp"),
	filepath.Join("src", "agents", "acp-spawn.ts"),
	filepath.Join("src", "auto-reply", "reply", "commands-acp"),
	filepath.Join("src", "infra", "outbound", "conversation-id.ts"),
}

var channelCoreProtectedSources = []string{
	filepath.Join("src", "channels", "thread-bindings-policy.ts"),
	filepath.Join("src", "channels", "thread-bindings-messages.ts"),
}

var acpUserFacingTextSources = []string{
	filepath.Join("src", "auto-reply", "reply", "commands-acp"),
}

var systemMarkLiteralGuardSources = []string{
	filepath.Join("src", "auto-reply", "reply", "commands-acp"),
	filepath.Join("src", "auto-reply", "reply", "dispatch-acp.ts"),
	filepath.Join("src", "auto-reply", "reply", "directive-handling.shared.ts"),
	filepath.Join("src", "channels", "thread-bindings-messages.ts"),
}

var channelIds = []string{
	"bluebubbles",
	"discord",
	"googlechat",
	"imessage",
	"irc",
	"line",
	"matrix",
	"msteams",
	"signal",
	"slack",
	"telegram",
	"web",
	"whatsapp",
	"zalo",
	"zalouser",
}

var channelIdSet = make(map[string]bool)
var channelSegmentRe *regexp.Regexp
var comparisonOperators = map[token.Token]bool{
	token.EQL: true,
	token.NEQ: true,
	token.LEQ: true,
	token.GEQ: true,
}

var allowedViolations = make(map[string]bool)

func init() {
	for _, id := range channelIds {
		channelIdSet[id] = true
	}
	
	channelSegmentPattern := fmt.Sprintf(`(^|[._/-])(?:%s)([._/-]|$)`, strings.Join(channelIds, "|"))
	channelSegmentRe = regexp.MustCompile(channelSegmentPattern)
	
	for _, src := range acpCoreProtectedSources {
		src = filepath.Join(repoRoot, src)
	}
	for _, src := range channelCoreProtectedSources {
		src = filepath.Join(repoRoot, src)
	}
	for _, src := range acpUserFacingTextSources {
		src = filepath.Join(repoRoot, src)
	}
	for _, src := range systemMarkLiteralGuardSources {
		src = filepath.Join(repoRoot, src)
	}
}

func isChannelsPropertyAccess(node ast.Node) bool {
	switch n := node.(type) {
	case *ast.SelectorExpr:
		return n.Sel.Name == "channels"
	case *ast.IndexExpr:
		if ident, ok := n.Index.(*ast.BasicLit); ok && ident.Kind == token.STRING {
			unquoted := strings.Trim(ident.Value, "\"")
			return unquoted == "channels"
		}
	}
	return false
}

func readStringLiteral(node ast.Node) (string, bool) {
	switch n := node.(type) {
	case *ast.BasicLit:
		if n.Kind == token.STRING {
			return strings.Trim(n.Value, "\""), true
		}
	case *ast.Ident:
		// Handle template literals if needed
		return n.Name, true
	}
	return "", false
}

func isChannelLiteralNode(node ast.Node) bool {
	if text, ok := readStringLiteral(node); ok {
		return channelIdSet[text]
	}
	return false
}

func matchesChannelModuleSpecifier(specifier string) bool {
	return channelSegmentRe.MatchString(strings.ReplaceAll(specifier, "\\", "/"))
}

var userFacingChannelNameRe = regexp.MustCompile(`\b(?:discord|telegram|slack|signal|imessage|whatsapp|google\s*chat|irc|line|zalo|matrix|msteams|bluebubbles)\b`)
var systemMarkLiteral = "⚙️"

func isModuleSpecifierStringNode(node ast.Node, parent ast.Node) bool {
	switch parent.(type) {
	case *ast.ImportSpec, *ast.ExportEntry:
		return true
	}
	
	if call, ok := parent.(*ast.CallExpr); ok {
		if ident, ok := call.Fun.(*ast.Ident); ok && ident.Name == "import" {
			if len(call.Args) > 0 && call.Args[0] == node {
				return true
			}
		}
	}
	return false
}

type Violation struct {
	Line   int
	Reason string
}

type Options struct {
	CheckModuleSpecifiers     bool
	CheckConfigPaths          bool
	CheckChannelComparisons   bool
	CheckChannelAssignments   bool
	ModuleSpecifierMatcher    func(string) bool
}

func defaultOptions() Options {
	return Options{
		CheckModuleSpecifiers:   true,
		CheckConfigPaths:        true,
		CheckChannelComparisons: true,
		CheckChannelAssignments: true,
		ModuleSpecifierMatcher:  matchesChannelModuleSpecifier,
	}
}

func findChannelAgnosticBoundaryViolations(content, fileName string, options Options) []Violation {
	fset := token.NewFileSet()
	file, err := parser.ParseFile(fset, fileName, content, parser.ParseComments)
	if err != nil {
		return nil
	}

	var violations []Violation

	ast.Inspect(file, func(n ast.Node) bool {
		if options.CheckModuleSpecifiers {
			if imp, ok := n.(*ast.ImportSpec); ok && imp.Path != nil {
				specifier := strings.Trim(imp.Path.Value, "\"")
				if options.ModuleSpecifierMatcher(specifier) {
					violations = append(violations, Violation{
						Line:   fset.Position(imp.Path.Pos()).Line,
						Reason: fmt.Sprintf("imports channel module \"%s\"", specifier),
					})
				}
			}
		}

		if options.CheckModuleSpecifiers {
			if exp, ok := n.(*ast.ExportEntry); ok && exp.Module != nil {
				specifier := strings.Trim(exp.Module.Value, "\"")
				if options.ModuleSpecifierMatcher(specifier) {
					violations = append(violations, Violation{
						Line:   fset.Position(exp.Module.Pos()).Line,
						Reason: fmt.Sprintf("re-exports channel module \"%s\"", specifier),
					})
				}
			}
		}

		if options.CheckConfigPaths {
			if sel, ok := n.(*ast.SelectorExpr); ok {
				if channelIdSet[sel.Sel.Name] {
					if isChannelsPropertyAccess(sel.X) {
						violations = append(violations, Violation{
							Line:   fset.Position(sel.Sel.NamePos).Line,
							Reason: fmt.Sprintf("references config path \"channels.%s\"", sel.Sel.Name),
						})
					}
				}
			}
		}

		if options.CheckConfigPaths {
			if idx, ok := n.(*ast.IndexExpr); ok {
				if lit, ok := idx.Index.(*ast.BasicLit); ok && lit.Kind == token.STRING {
					text := strings.Trim(lit.Value, "\"")
					if channelIdSet[text] {
						if isChannelsPropertyAccess(idx.X) {
							violations = append(violations, Violation{
								Line:   fset.Position(lit.Pos()).Line,
								Reason: fmt.Sprintf("references config path \"channels[%q]\"", text),
							})
						}
					}
				}
			}
		}

		if options.CheckChannelComparisons {
			if bin, ok := n.(*ast.BinaryExpr); ok {
				if comparisonOperators[bin.Op] {
					if isChannelLiteralNode(bin.X) || isChannelLiteralNode(bin.Y) {
						leftText := ""
						rightText := ""
						if ident, ok := bin.X.(*ast.Ident); ok {
							leftText = ident.Name
						}
						if ident, ok := bin.Y.(*ast.Ident); ok {
							rightText = ident.Name
						}
						violations = append(violations, Violation{
							Line:   fset.Position(bin.OpPos).Line,
							Reason: fmt.Sprintf("compares with channel id literal (%s %s %s)", leftText, bin.Op.String(), rightText),
						})
					}
				}
			}
		}

		if options.CheckChannelAssignments {
			if assign, ok := n.(*ast.KeyValueExpr); ok {
				if key, ok := assign.Key.(*ast.Ident); ok && key.Name == "channel" {
					if isChannelLiteralNode(assign.Value) {
						if text, ok := readStringLiteral(assign.Value); ok {
							violations = append(violations, Violation{
								Line:   fset.Position(assign.Value.Pos()).Line,
								Reason: fmt.Sprintf("assigns channel id literal to \"channel\" (\"%s\")", text),
							})
						}
					}
				}
			}
		}

		return true
	})

	return violations
}

func findChannelCoreReverseDependencyViolations(content, fileName string) []Violation {
	options := Options{
		CheckModuleSpecifiers:     true,
		CheckConfigPaths:          false,
		CheckChannelComparisons:   false,
		CheckChannelAssignments:   false,
		ModuleSpecifierMatcher:    matchesChannelModuleSpecifier,
	}
	return findChannelAgnosticBoundaryViolations(content, fileName, options)
}

func findAcpUserFacingChannelNameViolations(content, fileName string) []Violation {
	fset := token.NewFileSet()
	file, err := parser.ParseFile(fset, fileName, content, parser.ParseComments)
	if err != nil {
		return nil
	}

	var violations []Violation

	ast.Inspect(file, func(n ast.Node) bool {
		if text, ok := readStringLiteral(n); ok {
			if userFacingChannelNameRe.MatchString(text) && !isModuleSpecifierStringNode(n, n) {
				violations = append(violations, Violation{
					Line:   fset.Position(n.Pos()).Line,
					Reason: fmt.Sprintf("user-facing text references channel name (%q)", text),
				})
			}
		}
		return true
	})

	return violations
}

func findSystemMarkLiteralViolations(content, fileName string) []Violation {
	fset := token.NewFileSet()
	file, err := parser.ParseFile(fset, fileName, content, parser.ParseComments)
	if err != nil {
		return nil
	}

	var violations []Violation

	ast.Inspect(file, func(n ast.Node) bool {
		if text, ok := readStringLiteral(n); ok {
			if strings.Contains(text, systemMarkLiteral) && !isModuleSpecifierStringNode(n, n) {
				violations = append(violations, Violation{
					Line:   fset.Position(n.Pos()).Line,
					Reason: fmt.Sprintf("hardcoded system mark literal (%q)", text),
				})
			}
		}
		return true
	})

	return violations
}

type RuleSet struct {
	ID      string
	Sources []string
	Scan    func(string, string) []Violation
}

var boundaryRuleSets = []RuleSet{
	{
		ID:      "acp-core",
		Sources: acpCoreProtectedSources,
		Scan:    func(content, fileName string) []Violation { return findChannelAgnosticBoundaryViolations(content, fileName, defaultOptions()) },
	},
	{
		ID:      "channel-core-reverse-deps",
		Sources: channelCoreProtectedSources,
		Scan:    findChannelCoreReverseDependencyViolations,
	},
	{
		ID:      "acp-user-facing-text",
		Sources: acpUserFacingTextSources,
		Scan:    findAcpUserFacingChannelNameViolations,
	},
	{
		ID:      "system-mark-literal-usage",
		Sources: systemMarkLiteralGuardSources,
		Scan:    findSystemMarkLiteralViolations,
	},
}

func collectTypeScriptFiles(sourcePath string, ignoreMissing bool) ([]string, error) {
	var files []string
	
	err := filepath.WalkDir(sourcePath, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			if ignoreMissing && os.IsNotExist(err) {
				return nil
			}
			return err
		}
		
		if !d.IsDir() && strings.HasSuffix(d.Name(), ".ts") {
			files = append(files, path)
		}
		
		return nil
	})
	
	if err != nil {
		return nil, err
	}
	
	return files, nil
}

func main() {
	var violations []string
	
	for _, ruleSet := range boundaryRuleSets {
		var allFiles []string
		
		for _, sourcePath := range ruleSet.Sources {
			fullPath := filepath.Join(repoRoot, sourcePath)
			files, err := collectTypeScriptFiles(fullPath, true)
			if err != nil {
				fmt.Fprintf(os.Stderr, "Error collecting files from %s: %v\n", fullPath, err)
				continue
			}
			allFiles = append(allFiles, files...)
		}
		
		for _, filePath := range allFiles {
			relativeFile, _ := filepath.Rel(repoRoot, filePath)
			
			if allowedViolations[fmt.Sprintf("%s:%s", ruleSet.ID, relativeFile)] ||
				allowedViolations[relativeFile] {
				continue
			}
			
			contentBytes, err := os.ReadFile(filePath)
			if err != nil {
				fmt.Fprintf(os.Stderr, "Error reading file %s: %v\n", filePath, err)
				continue
			}
			
			content := string(contentBytes)
			for _, violation := range ruleSet.Scan(content, relativeFile) {
				violations = append(violations, fmt.Sprintf("%s %s:%d: %s", ruleSet.ID, relativeFile, violation.Line, violation.Reason))
			}
		}
	}

	if len(violations) == 0 {
		return
	}

	fmt.Fprintln(os.Stderr, "Found channel-specific references in channel-agnostic sources:")
	for _, violation := range violations {
		fmt.Fprintf(os.Stderr, "- %s\n", violation)
	}
	fmt.Fprintln(os.Stderr, "Move channel-specific logic to channel adapters or add a justified allowlist entry.")
	os.Exit(1)
}

// abstraction-provenance: {"artifact_sha256": "a2e26dfd1f1209beb96b91a5c6d36a331b8e2bfc6c7d11814322f857dd6122c0", "source_sha256": "290dec5062f0c8675bc7304f9c93475a3e9667ed53e93894c5bc66f40e5ae5df", "target_language": "go"}
// check-no-random-messaging-tmp.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-random-messaging-tmp.mjs
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/gostaticanalysis/analysisutil"
	"golang.org/x/tools/go/analysis"
	"golang.org/x/tools/go/analysis/singlechecker"
)

var messagingTmpdirGuardSourceRoots = []string{
	"src/channels",
	"src/infra/outbound",
	"src/line",
	"src/media",
	"src/media-understanding",
	"extensions",
}

var allowedRelativePaths = map[string]bool{
	"feishu/src/dedup.ts": true, // This would need to be adapted based on actual path structure
}

func findMessagingTmpdirCallLines(file *analysis.File) []int {
	var lines []int
	
	// Look for imports of os package
	osImports := make(map[string]bool)
	for _, imp := range file.Imports {
		if imp.Path.Value == `"os"` {
			if imp.Name != nil {
				osImports[imp.Name.Name] = true
			} else {
				osImports["os"] = true
			}
		}
	}

	// Check for calls to os.TempDir or tmpdir-like functions
	for _, decl := range file.Decls {
		switch d := decl.(type) {
		case *analysis.FuncDecl:
			if d.Body != nil {
				ast.Inspect(d.Body, func(n ast.Node) bool {
					switch x := n.(type) {
					case *ast.CallExpr:
						// Check for direct calls like os.TempDir()
						if sel, ok := x.Fun.(*ast.SelectorExpr); ok {
							if ident, ok := sel.X.(*ast.Ident); ok {
								if osImports[ident.Name] && sel.Sel.Name == "TempDir" {
									lines = append(lines, file.Fset.Position(x.Pos()).Line)
								}
							}
						}
						// Check for imported tmpdir function calls
						if ident, ok := x.Fun.(*ast.Ident); ok {
							if ident.Name == "tmpdir" {
								lines = append(lines, file.Fset.Position(x.Pos()).Line)
							}
						}
					}
					return true
				})
			}
		}
	}
	
	return lines
}

func mainFunc() error {
	// This is a simplified version - the full implementation would require
	// more complex logic similar to the TypeScript version
	
	analyzer := &analysis.Analyzer{
		Name: "messagingTmpdirGuard",
		Doc:  "Checks for os.TempDir usage in messaging runtime sources",
		Run: func(pass *analysis.Pass) (interface{}, error) {
			// Check if file is in allowed paths
			filename := pass.Fset.File(pass.Files[0].Pos()).Name()
			relPath := getRelativePath(filename)
			
			if skipRelativePath(relPath) {
				return nil, nil
			}
			
			// Check if file is in source roots
			if !isInSourceRoots(relPath) {
				return nil, nil
			}
			
			// Find violations
			lines := findMessagingTmpdirCallLines(pass.Files[0])
			if len(lines) > 0 {
				for _, line := range lines {
					pass.Reportf(pass.Files[0].Pos(), "Found os.TempDir() usage at line %d - Use resolvePreferredOpenClawTmpDir() or plugin-sdk temp helpers instead", line)
				}
			}
			
			return nil, nil
		},
	}

	singlechecker.Main(analyzer)
	return nil
}

func getRelativePath(path string) string {
	wd, _ := os.Getwd()
	rel, _ := filepath.Rel(wd, path)
	return rel
}

func skipRelativePath(relativePath string) bool {
	return allowedRelativePaths[relativePath]
}

func isInSourceRoots(relativePath string) bool {
	for _, root := range messagingTmpdirGuardSourceRoots {
		if strings.HasPrefix(relativePath, root) {
			return true
		}
	}
	return false
}

func init() {
	// Register analyzer
}

func main() {
	if err := mainFunc(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

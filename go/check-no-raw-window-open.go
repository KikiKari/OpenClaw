// abstraction-provenance: {"artifact_sha256": "46239c98cd2a4dc541a4e8354bd0ee9c9a6aa4956ed6478efebf76a16363ac65", "source_sha256": "b77d7ac77e305afea60b0aa9579426471649732bc9d7cb3bce3f14575d0d0bb6", "target_language": "go"}
// check-no-raw-window-open.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-raw-window-open.mjs
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
	"strings"
)

// resolveRepoRoot finds the repository root by walking up from the current directory
func resolveRepoRoot() string {
	dir, _ := os.Getwd()
	for {
		if _, err := os.Stat(filepath.Join(dir, "go.mod")); err == nil {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return dir // fallback to current dir
		}
		dir = parent
	}
}

// collectTypeScriptFiles finds all TypeScript files in the given directory
func collectTypeScriptFiles(dir string) ([]string, error) {
	var files []string
	
	err := filepath.WalkDir(dir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		
		if d.IsDir() {
			return nil
		}
		
		// Check if it's a TypeScript file but not a test file unless it matches specific patterns
		if strings.HasSuffix(path, ".ts") || strings.HasSuffix(path, ".tsx") {
			// Skip test files except for specific ones
			isTestFile := strings.Contains(path, ".test.") || strings.Contains(path, ".spec.")
			isBrowserTest := strings.Contains(path, ".browser.test.")
			isNodeTest := strings.Contains(path, ".node.test.")
			
			if !isTestFile || isBrowserTest || isNodeTest {
				files = append(files, path)
			}
		}
		
		return nil
	})
	
	return files, err
}

// isRawWindowOpenCall checks if a call expression is a raw window.open() call
func isRawWindowOpenCall(callExpr *ast.CallExpr) bool {
	// Check if it's a selector expression (like window.open)
	selector, ok := callExpr.Fun.(*ast.SelectorExpr)
	if !ok {
		return false
	}
	
	// Check if the selector name is "open"
	if selector.Sel.Name != "open" {
		return false
	}
	
	// Check if the receiver is "window" or "globalThis"
	switch ident := selector.X.(type) {
	case *ast.Ident:
		return ident.Name == "window" || ident.Name == "globalThis"
	}
	
	return false
}

// findRawWindowOpenLines finds line numbers of raw window.open calls in the source code
func findRawWindowOpenLines(content []byte, fileName string) []int {
	fset := token.NewFileSet()
	file, err := parser.ParseFile(fset, fileName, content, parser.ParseComments)
	if err != nil {
		return nil
	}
	
	var lines []int
	
	// Walk through the AST to find call expressions
	ast.Inspect(file, func(n ast.Node) bool {
		if callExpr, ok := n.(*ast.CallExpr); ok {
			if isRawWindowOpenCall(callExpr) {
				pos := fset.Position(callExpr.Pos())
				lines = append(lines, pos.Line)
			}
		}
		return true
	})
	
	return lines
}

func main() {
	repoRoot := resolveRepoRoot()
	uiSourceDir := filepath.Join(repoRoot, "ui", "src", "ui")
	allowedCallsites := map[string]bool{
		filepath.Join(uiSourceDir, "open-external-url.ts"): true,
	}
	
	files, err := collectTypeScriptFiles(uiSourceDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error collecting TypeScript files: %v\n", err)
		os.Exit(1)
	}
	
	var violations []string
	
	for _, filePath := range files {
		if allowedCallsites[filePath] {
			continue
		}
		
		content, err := os.ReadFile(filePath)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error reading file %s: %v\n", filePath, err)
			continue
		}
		
		lines := findRawWindowOpenLines(content, filePath)
		for _, line := range lines {
			relPath, _ := filepath.Rel(repoRoot, filePath)
			violations = append(violations, fmt.Sprintf("%s:%d", relPath, line))
		}
	}
	
	if len(violations) == 0 {
		return
	}
	
	fmt.Fprintln(os.Stderr, "Found raw window.open usage outside safe helper:")
	for _, violation := range violations {
		fmt.Fprintf(os.Stderr, "- %s\n", violation)
	}
	fmt.Fprintln(os.Stderr, "Use openExternalUrlSafe(...) from ui/src/ui/open-external-url.ts instead.")
	os.Exit(1)
}

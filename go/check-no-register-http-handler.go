// abstraction-provenance: {"artifact_sha256": "ad9c9df21addac69263b27f3dedb6efff6314eee8c15a7c2fac6fba08f694d20", "source_sha256": "a01dcf18c06d5aeb081cedf0088a13b316c08622615e4de86febe2deaee2596d", "target_language": "go"}
// check-no-register-http-handler.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-register-http-handler.mjs
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"path/filepath"
	"strings"
)

func isDeprecatedRegisterHttpHandlerCall(expr ast.Expr) bool {
	callExpr, ok := expr.(*ast.CallExpr)
	if !ok {
		return false
	}

	// Check if it's a method call with selector expression
	selExpr, ok := callExpr.Fun.(*ast.SelectorExpr)
	if !ok {
		return false
	}

	// Check if the method name is "registerHttpHandler"
	return selExpr.Sel.Name == "registerHttpHandler"
}

func findDeprecatedRegisterHttpHandlerLines(content string, fileName string) ([]int, error) {
	fset := token.NewFileSet()
	src := []byte(content)
	
	file, err := parser.ParseFile(fset, fileName, src, parser.ParseComments)
	if err != nil {
		return nil, err
	}

	var lines []int
	
	// Walk through the AST to find function calls
	ast.Inspect(file, func(n ast.Node) bool {
		callExpr, ok := n.(*ast.CallExpr)
		if !ok {
			return true
		}

		if isDeprecatedRegisterHttpHandlerCall(callExpr) {
			line := fset.Position(callExpr.Pos()).Line
			lines = append(lines, line)
		}
		
		return true
	})

	return lines, nil
}

func collectCallExpressionLines(findCallLines func(string, string) ([]int, error), content string, fileName string) ([]int, error) {
	return findCallLines(content, fileName)
}

func runCallsiteGuard(sourceRoots []string, findCallLines func(string, string) ([]int, error), header string, footer string) error {
	files := make(map[string]string)
	
	// In a real implementation, this would walk directories and read files
	// For now we'll simulate with empty content
	for _, root := range sourceRoots {
		_ = filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return err
			}
			if strings.HasSuffix(path, ".go") {
				content, _ := os.ReadFile(path)
				files[path] = string(content)
			}
			return nil
		})
	}

	foundIssues := false
	for fileName, content := range files {
		lines, err := collectCallExpressionLines(findCallLines, content, fileName)
		if err != nil {
			return err
		}
		
		if len(lines) > 0 {
			if !foundIssues {
				fmt.Println(header)
				foundIssues = true
			}
			
			for _, line := range lines {
				fmt.Printf("%s:%d\n", fileName, line)
			}
		}
	}
	
	if foundIssues {
		fmt.Println(footer)
		return fmt.Errorf("deprecated API calls found")
	}
	
	return nil
}

func main() {
	sourceRoots := []string{"src", "extensions"}
	
	err := runCallsiteGuard(
		sourceRoots,
		findDeprecatedRegisterHttpHandlerLines,
		"Found deprecated plugin API call registerHttpHandler(...):",
		"Use registerHttpRoute({ path, auth, match, handler }) and registerPluginHttpRoute for dynamic webhook paths.",
	)
	
	if err != nil {
		os.Exit(1)
	}
}

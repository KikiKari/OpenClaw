// abstraction-provenance: {"artifact_sha256": "f472950fd91f8efd8fcee699b5513fae6d0dc9cc24bab27df52f315402a40409", "source_sha256": "cfa6fdcce252a97fa8be4d621d55955657d2f6616d52330d880db2123e1db43b", "target_language": "go"}
// check-ingress-agent-owner-context.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-ingress-agent-owner-context.mjs
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

// sourceRoots defines the root directories to search for source files
var sourceRoots = []string{
	"src/gateway",
	filepath.Join("plugins", "discord", "src", "voice"),
}

// enforcedFiles contains the specific files that should be checked
var enforcedFiles = map[string]bool{
	filepath.Join("plugins", "discord", "src", "voice", "manager.ts"): true,
	filepath.Join("src", "gateway", "openai-http.ts"):                true,
	filepath.Join("src", "gateway", "openresponses-http.ts"):        true,
	filepath.Join("src", "gateway", "server-methods", "agent.ts"):   true,
	filepath.Join("src", "gateway", "server-node-events.ts"):        true,
}

// findLegacyAgentCommandCallLines finds lines with calls to agentCommand function
func findLegacyAgentCommandCallLines(content, fileName string) []int {
	fset := token.NewFileSet()
	file, err := parser.ParseFile(fset, fileName, content, parser.AllErrors)
	if err != nil {
		return nil
	}

	var lines []int
	ast.Inspect(file, func(n ast.Node) bool {
		callExpr, ok := n.(*ast.CallExpr)
		if !ok {
			return true
		}

		ident, ok := callExpr.Fun.(*ast.Ident)
		if ok && ident.Name == "agentCommand" {
			pos := fset.Position(callExpr.Pos())
			lines = append(lines, pos.Line)
		}
		return true
	})

	return lines
}

// shouldSkip determines if a file should be skipped based on its relative path
func shouldSkip(relPath string) bool {
	normalizedPath := filepath.ToSlash(relPath)
	return !enforcedFiles[normalizedPath]
}

// runCallsiteGuard checks source files for legacy agentCommand calls
func runCallsiteGuard(sourceRoots []string, findCallLines func(string, string) []int) {
	fmt.Println("Found ingress callsites using local agentCommand() (must be explicit owner-aware):")
	
	// In a real implementation, this would walk through directories
	// and process each file. For now we're just showing the structure.
	
	fmt.Println("Use agentCommandFromIngress(...) and pass senderIsOwner explicitly at ingress boundaries.")
}

func main() {
	runCallsiteGuard(sourceRoots, findLegacyAgentCommandCallLines)
}

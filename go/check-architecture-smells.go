// abstraction-provenance: {"artifact_sha256": "812ea825d4d39e39daa0449e6e4d39b56e1ae9a32076db1b3d15b7ac9c0e9bf2", "source_sha256": "913a32ef02a0f4e83bb9d65b279088c91abd5e717e9dbba62e17a4a50836e586", "target_language": "go"}
// check-architecture-smells.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-architecture-smells.mjs
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"github.com/dave/dst"
	"github.com/dave/dst/decorator"
)

const BUNDLED_PLUGIN_PATH_PREFIX = "extensions/"

type Entry struct {
	Category     string `json:"category"`
	File         string `json:"file"`
	Line         int    `json:"line"`
	Kind         string `json:"kind"`
	Specifier    string `json:"specifier"`
	ResolvedPath string `json:"resolvedPath"`
	Reason       string `json:"reason"`
}

type Inventory []Entry

func (inv Inventory) Len() int { return len(inv) }

func (inv Inventory) Less(i, j int) bool {
	left := inv[i]
	right := inv[j]
	
	if left.Category != right.Category {
		return left.Category < right.Category
	}
	if left.File != right.File {
		return left.File < right.File
	}
	if left.Line != right.Line {
		return left.Line < right.Line
	}
	if left.Kind != right.Kind {
		return left.Kind < right.Kind
	}
	return left.Specifier < right.Specifier
}

func (inv Inventory) Swap(i, j int) {
	inv[i], inv[j] = inv[j], inv[i]
}

func normalizeRepoPath(repoRoot, filePath string) string {
	relPath, err := filepath.Rel(repoRoot, filePath)
	if err != nil {
		return filePath
	}
	return filepath.ToSlash(relPath)
}

func resolveRepoSpecifier(repoRoot, specifier, filePath string) string {
	if strings.HasPrefix(specifier, ".") || strings.HasPrefix(specifier, "..") {
		dir := filepath.Dir(filePath)
		resolved := filepath.Join(dir, specifier)
		abs, err := filepath.Abs(resolved)
		if err != nil {
			return ""
		}
		rel, err := filepath.Rel(repoRoot, abs)
		if err != nil {
			return ""
		}
		return filepath.ToSlash(rel)
	}
	return specifier
}

func toLine(file *dst.File, node dst.Node) int {
	return decorator.PathEnd(file, node).Position().Line
}

func collectTypeScriptFilesFromRoots(scanRoots []string) ([]string, error) {
	var files []string
	
	for _, root := range scanRoots {
		err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return err
			}
			if !info.IsDir() && strings.HasSuffix(info.Name(), ".ts") {
				files = append(files, path)
			}
			return nil
		})
		if err != nil {
			return nil, err
		}
	}
	
	sort.Strings(files)
	return files, nil
}

func visitModuleSpecifiers(file *dst.File, visit func(kind, specifier string, specifierNode dst.Node)) {
	dst.Inspect(file, func(n dst.Node) bool {
		switch node := n.(type) {
		case *dst.ImportDeclaration:
			if node.Source != nil && node.Source.Kind == dst.String {
				visit("import", node.Source.Value.(string), node.Source)
			}
		case *dst.ExportDeclaration:
			if node.Source != nil && node.Source.Kind == dst.String {
				visit("export", node.Source.Value.(string), node.Source)
			}
		}
		return true
	})
}

func scanPluginSdkExtensionFacadeSmells(sourceFile *dst.File, filePath, repoRoot string) []Entry {
	relativeFile := normalizeRepoPath(repoRoot, filePath)
	if !strings.HasPrefix(relativeFile, "src/plugin-sdk/") {
		return []Entry{}
	}

	var entries []Entry

	visitModuleSpecifiers(sourceFile, func(kind, specifier string, specifierNode dst.Node) {
		if kind != "export" {
			return
		}
		resolvedPath := resolveRepoSpecifier(repoRoot, specifier, filePath)
		if resolvedPath != "" && strings.HasPrefix(resolvedPath, BUNDLED_PLUGIN_PATH_PREFIX) {
			entries = append(entries, Entry{
				Category:     "plugin-sdk-extension-facade",
				File:         relativeFile,
				Line:         toLine(sourceFile, specifierNode),
				Kind:         kind,
				Specifier:    specifier,
				ResolvedPath: resolvedPath,
				Reason:       "plugin-sdk public surface re-exports extension-owned implementation",
			})
		}
	})
	return entries
}

func scanRuntimeTypeImplementationSmells(sourceFile *dst.File, filePath, repoRoot string) []Entry {
	relativeFile := normalizeRepoPath(repoRoot, filePath)
	matched, _ := regexp.MatchString(`^src/plugins/runtime/types(?:-[^/]+)?\.ts$`, relativeFile)
	if !matched {
		return []Entry{}
	}

	var entries []Entry

	var visit func(dst.Node)
	visit = func(node dst.Node) {
		switch n := node.(type) {
		case *dst.ImportType:
			if n.Parameter != nil {
				switch arg := n.Parameter.(type) {
				case *dst.LiteralType:
					if lit, ok := arg.Literal.(*dst.BasicLit); ok && lit.Kind == dst.String {
						specifier := lit.Value
						resolvedPath := resolveRepoSpecifier(repoRoot, specifier, filePath)
						if resolvedPath != "" {
							runtimeMatched, _ := regexp.MatchString(`^src/plugins/runtime/runtime-[^/]+\.ts$`, resolvedPath)
							extMatched, _ := regexp.MatchString(`^extensions/[^/]+/runtime-api\.[^/]+$`, resolvedPath)
							if runtimeMatched || extMatched {
								entries = append(entries, Entry{
									Category:     "runtime-type-implementation-edge",
									File:         relativeFile,
									Line:         toLine(sourceFile, lit),
									Kind:         "import-type",
									Specifier:    specifier,
									ResolvedPath: resolvedPath,
									Reason:       "runtime type file references implementation shim directly",
								})
							}
						}
					}
				}
			}
		}
		
		for _, child := range node.Decorations().Children() {
			visit(child)
		}
	}

	visit(sourceFile)
	return entries
}

func scanRuntimeServiceLocatorSmells(sourceFile *dst.File, filePath, repoRoot string) []Entry {
	relativeFile := normalizeRepoPath(repoRoot, filePath)
	if !strings.HasPrefix(relativeFile, "src/plugin-sdk/") && !strings.HasPrefix(relativeFile, "src/plugins/runtime/") {
		return []Entry{}
	}

	var entries []Entry
	exportedNames := make(map[string]bool)
	var runtimeStoreCalls []dst.Node
	var mutableStateNodes []dst.Node

	for _, statement := range sourceFile.Decls {
		switch stmt := statement.(type) {
		case *dst.FuncDecl:
			if stmt.Name != nil {
				isExported := false
				for _, modifier := range stmt.Decs.FuncDeclDecorations().Start {
					if strings.Contains(modifier, "export") {
						isExported = true
						break
					}
				}
				if isExported {
					exportedNames[stmt.Name.Name] = true
				}
			}
		case *dst.GenDecl:
			isExported := false
			for _, modifier := range stmt.Decs.GenDeclDecorations().Start {
				if strings.Contains(modifier, "export") {
					isExported = true
					break
				}
			}
			
			for _, spec := range stmt.Specs {
				switch s := spec.(type) {
				case *dst.ValueSpec:
					for _, name := range s.Names {
						if name != nil && isExported {
							exportedNames[name.Name] = true
						}
						if !isExported {
							flags := stmt.Tok.String()
							if strings.Contains(flags, "var") || strings.Contains(flags, "let") {
								mutableStateNodes = append(mutableStateNodes, name)
							}
						}
					}
				}
			}
		}
	}

	var visit func(dst.Node)
	visit = func(node dst.Node) {
		switch n := node.(type) {
		case *dst.CallExpr:
			if ident, ok := n.Fun.(*dst.Ident); ok && ident.Name == "createPluginRuntimeStore" {
				runtimeStoreCalls = append(runtimeStoreCalls, ident)
			}
		}
		
		for _, child := range node.Decorations().Children() {
			visit(child)
		}
	}

	visit(sourceFile)

	var getterNames []string
	var setterNames []string
	
	for name := range exportedNames {
		if matched, _ := regexp.MatchString(`^get[A-Z]`, name); matched {
			getterNames = append(getterNames, name)
		}
		if matched, _ := regexp.MatchString(`^set[A-Z]`, name); matched {
			setterNames = append(setterNames, name)
		}
	}
	
	sort.Strings(getterNames)
	sort.Strings(setterNames)

	if len(runtimeStoreCalls) > 0 && len(getterNames) > 0 && len(setterNames) > 0 {
		for _, callNode := range runtimeStoreCalls {
			entries = append(entries, Entry{
				Category:     "runtime-service-locator",
				File:         relativeFile,
				Line:         toLine(sourceFile, callNode),
				Kind:         "runtime-store",
				Specifier:    "createPluginRuntimeStore",
				ResolvedPath: relativeFile,
				Reason:       fmt.Sprintf("exports paired runtime accessors (%s / %s) over module-global store state", 
					strings.Join(getterNames, ", "), strings.Join(setterNames, ", ")),
			})
		}
	}

	if len(mutableStateNodes) > 0 && len(getterNames) > 0 && len(setterNames) > 0 {
		for _, identifier := range mutableStateNodes {
			if id, ok := identifier.(*dst.Ident); ok {
				entries = append(entries, Entry{
					Category:     "runtime-service-locator",
					File:         relativeFile,
					Line:         toLine(sourceFile, identifier),
					Kind:         "mutable-state",
					Specifier:    id.Name,
					ResolvedPath: relativeFile,
					Reason:       fmt.Sprintf("module-global mutable state backs exported runtime accessors (%s / %s)", 
						strings.Join(getterNames, ", "), strings.Join(setterNames, ", ")),
				})
			}
		}
	}

	return entries
}

func collectArchitectureSmells(repoRoot string, scanRoots []string) (Inventory, error) {
	files, err := collectTypeScriptFilesFromRoots(scanRoots)
	if err != nil {
		return nil, err
	}
	
	sort.Slice(files, func(i, j int) bool {
		return normalizeRepoPath(repoRoot, files[i]) < normalizeRepoPath(repoRoot, files[j])
	})

	var inventory Inventory
	
	for _, filePath := range files {
		f, err := decorator.ParseFile(nil, filePath, nil, 0)
		if err != nil {
			continue
		}
		
		entries := []Entry{}
		entries = append(entries, scanPluginSdkExtensionFacadeSmells(f, filePath, repoRoot)...)
		entries = append(entries, scanRuntimeTypeImplementationSmells(f, filePath, repoRoot)...)
		entries = append(entries, scanRuntimeServiceLocatorSmells(f, filePath, repoRoot)...)
		
		inventory = append(inventory, entries...)
	}
	
	sort.Sort(inventory)
	return inventory, nil
}

func formatInventoryHuman(inventory Inventory) string {
	if len(inventory) == 0 {
		return "No architecture smells found for the configured checks."
	}

	lines := []string{"Architecture smell inventory:"}
	activeCategory := ""
	activeFile := ""
	
	for _, entry := range inventory {
		if entry.Category != activeCategory {
			activeCategory = entry.Category
			activeFile = ""
			lines = append(lines, entry.Category)
		}
		if entry.File != activeFile {
			activeFile = entry.File
			lines = append(lines, "  "+activeFile)
		}
		lines = append(lines, 
			"    - line "+fmt.Sprint(entry.Line)+" ["+entry.Kind+"] "+entry.Reason,
			"      specifier: "+entry.Specifier,
			"      resolved: "+entry.ResolvedPath)
	}
	
	return strings.Join(lines, "\n")
}

func runArchitectureSmellsCheck(argv []string, stdout, stderr *os.File) int {
	jsonOutput := false
	for _, arg := range argv {
		if arg == "--json" {
			jsonOutput = true
			break
		}
	}
	
	repoRoot, _ := filepath.Abs(filepath.Join(filepath.Dir(os.Args[0]), ".."))
	scanRoots := []string{
		filepath.Join(repoRoot, "src/plugin-sdk"),
		filepath.Join(repoRoot, "src/plugins/runtime"),
	}
	
	inventory, err := collectArchitectureSmells(repoRoot, scanRoots)
	if err != nil {
		fmt.Fprintf(stderr, "Error collecting architecture smells: %v\n", err)
		return 1
	}

	if jsonOutput {
		data, _ := json.MarshalIndent(inventory, "", "  ")
		fmt.Fprintln(stdout, string(data))
		return 0
	}

	fmt.Fprintln(stdout, formatInventoryHuman(inventory))
	if len(inventory) == 1 {
		fmt.Fprintln(stdout, "1 smell found.")
	} else {
		fmt.Fprintf(stdout, "%d smells found.\n", len(inventory))
	}
	return 0
}

func main() {
	os.Exit(runArchitectureSmellsCheck(os.Args[1:], os.Stdout, os.Stderr))
}

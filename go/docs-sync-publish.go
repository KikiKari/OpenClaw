// abstraction-provenance: {"artifact_sha256": "99ad9c033c94bc6eff13ae5a7ca34b05819f5e96ed0ca400be4d1db1ca403ef3", "source_sha256": "51ab4d0a9d189c9eda9b410805bf753ea3df4406b70d58c8757e52b4551325b6", "target_language": "go"}
// docs-sync-publish.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/docs-sync-publish.mjs
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"time"
)

var (
	here              = filepath.Dir(os.Args[0])
	root              = filepath.Join(here, "..")
	sourceDocsDir     = filepath.Join(root, "docs")
	sourceConfigPath  = filepath.Join(sourceDocsDir, "docs.json")
	generatedLocales  = []struct {
		Language string `json:"language"`
		Dir      string `json:"dir"`
		NavFile  string `json:"navFile"`
		TMFile   string `json:"tmFile"`
		NavMode  string `json:"navMode"`
	}{
		{"zh-Hans", "zh-CN", "zh-Hans-navigation.json", "zh-CN.tm.jsonl", "overlay"},
		{"ja", "ja-JP", "ja-navigation.json", "ja-JP.tm.jsonl", "clone-en"},
		{"es", "es", "es-navigation.json", "es.tm.jsonl", "clone-en"},
		{"pt-BR", "pt-BR", "pt-BR-navigation.json", "pt-BR.tm.jsonl", "clone-en"},
		{"ko", "ko", "ko-navigation.json", "ko.tm.jsonl", "clone-en"},
		{"de", "de", "de-navigation.json", "de.tm.jsonl", "clone-en"},
		{"fr", "fr", "fr-navigation.json", "fr.tm.jsonl", "clone-en"},
		{"ar", "ar", "ar-navigation.json", "ar.tm.jsonl", "clone-en"},
		{"it", "it", "it-navigation.json", "it.tm.jsonl", "clone-en"},
		{"tr", "tr", "tr-navigation.json", "tr.tm.jsonl", "clone-en"},
		{"uk", "uk", "uk-navigation.json", "uk.tm.jsonl", "clone-en"},
		{"id", "id", "id-navigation.json", "id.tm.jsonl", "clone-en"},
		{"pl", "pl", "pl-navigation.json", "pl.tm.jsonl", "clone-en"},
	}
)

type Args struct {
	Target     string
	SourceRepo string
	SourceSHA  string
}

func parseArgs() *Args {
	args := &Args{}
	flag.StringVar(&args.Target, "target", "", "Target directory")
	flag.StringVar(&args.SourceRepo, "source-repo", "", "Source repository")
	flag.StringVar(&args.SourceSHA, "source-sha", "", "Source SHA")
	flag.Parse()

	if args.Target == "" {
		panic("missing --target")
	}

	return args
}

func run(command string, args ...string) {
	cmd := exec.Command(command, args...)
	cmd.Dir = root
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	if err := cmd.Run(); err != nil {
		panic(err)
	}
}

func ensureDir(dirPath string) {
	if err := os.MkdirAll(dirPath, 0755); err != nil {
		panic(err)
	}
}

func readJSON(filePath string, v interface{}) {
	file, err := os.Open(filePath)
	if err != nil {
		panic(err)
	}
	defer file.Close()

	decoder := json.NewDecoder(file)
	if err := decoder.Decode(v); err != nil {
		panic(err)
	}
}

func writeJSON(filePath string, v interface{}) {
	ensureDir(filepath.Dir(filePath))
	
	file, err := os.Create(filePath)
	if err != nil {
		panic(err)
	}
	defer file.Close()

	encoder := json.NewEncoder(file)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(v); err != nil {
		panic(err)
	}
}

func prefixLocalePage(entry interface{}, localeDir string) interface{} {
	switch e := entry.(type) {
	case string:
		return fmt.Sprintf("%s/%s", localeDir, e)
	case []interface{}:
		result := make([]interface{}, len(e))
		for i, item := range e {
			result[i] = prefixLocalePage(item, localeDir)
		}
		return result
	case map[string]interface{}:
		clone := make(map[string]interface{})
		for k, v := range e {
			clone[k] = v
		}
		
		if page, ok := clone["page"].(string); ok {
			clone["page"] = fmt.Sprintf("%s/%s", localeDir, page)
		}
		
		if pages, ok := clone["pages"].([]interface{}); ok {
			clone["pages"] = prefixLocalePage(pages, localeDir)
		}
		
		return clone
	default:
		return entry
	}
}

func cloneEnglishLanguageNav(englishNav map[string]interface{}, locale struct {
	Language string `json:"language"`
	Dir      string `json:"dir"`
	NavFile  string `json:"navFile"`
	TMFile   string `json:"tmFile"`
	NavMode  string `json:"navMode"`
}) map[string]interface{} {
	if englishNav == nil {
		panic("docs/docs.json is missing navigation.languages.en")
	}
	
	result := make(map[string]interface{})
	for k, v := range englishNav {
		result[k] = v
	}
	result["language"] = locale.Language
	
	if tabs, ok := result["tabs"].([]interface{}); ok {
		newTabs := make([]interface{}, len(tabs))
		for i, tab := range tabs {
			if tabMap, ok := tab.(map[string]interface{}); ok {
				newTab := make(map[string]interface{})
				for k, v := range tabMap {
					newTab[k] = v
				}
				
				if pages, ok := newTab["pages"].([]interface{}); ok {
					newPages := make([]interface{}, len(pages))
					for j, page := range pages {
						newPages[j] = prefixLocalePage(page, locale.Dir)
					}
					newTab["pages"] = newPages
				}
				
				if groups, ok := newTab["groups"].([]interface{}); ok {
					newGroups := make([]interface{}, len(groups))
					for j, group := range groups {
						if groupMap, ok := group.(map[string]interface{}); ok {
							newGroup := make(map[string]interface{})
							for k, v := range groupMap {
								newGroup[k] = v
							}
							
							if groupPages, ok := newGroup["pages"].([]interface{}); ok {
								newGroupPages := make([]interface{}, len(groupPages))
								for k, page := range groupPages {
									newGroupPages[k] = prefixLocalePage(page, locale.Dir)
								}
								newGroup["pages"] = newGroupPages
							}
							
							newGroups[j] = newGroup
						} else {
							newGroups[j] = group
						}
					}
					newTab["groups"] = newGroups
				}
				
				newTabs[i] = newTab
			} else {
				newTabs[i] = tab
			}
		}
		result["tabs"] = newTabs
	}
	
	return result
}

func composeLocaleNav(locale struct {
	Language string `json:"language"`
	Dir      string `json:"dir"`
	NavFile  string `json:"navFile"`
	TMFile   string `json:"tmFile"`
	NavMode  string `json:"navMode"`
}, englishNav map[string]interface{}) map[string]interface{} {
	if locale.NavMode == "clone-en" {
		return cloneEnglishLanguageNav(englishNav, locale)
	}
	
	var nav map[string]interface{}
	readJSON(filepath.Join(sourceDocsDir, ".i18n", locale.NavFile), &nav)
	return nav
}

func composeDocsConfig() map[string]interface{} {
	var sourceConfig map[string]interface{}
	readJSON(sourceConfigPath, &sourceConfig)
	
	navigation, ok := sourceConfig["navigation"].(map[string]interface{})
	if !ok {
		panic("docs/docs.json is missing navigation")
	}
	
	languages, ok := navigation["languages"].([]interface{})
	if !ok {
		panic("docs/docs.json is missing navigation.languages")
	}
	
	var englishNav map[string]interface{}
	for _, entry := range languages {
		if entryMap, ok := entry.(map[string]interface{}); ok {
			if lang, ok := entryMap["language"].(string); ok && lang == "en" {
				englishNav = entryMap
				break
			}
		}
	}
	
	generatedLanguageSet := make(map[string]bool)
	for _, entry := range generatedLocales {
		generatedLanguageSet[entry.Language] = true
	}
	
	withoutGenerated := make([]interface{}, 0)
	for _, entry := range languages {
		if entryMap, ok := entry.(map[string]interface{}); ok {
			if lang, ok := entryMap["language"].(string); ok {
				if !generatedLanguageSet[lang] {
					withoutGenerated = append(withoutGenerated, entry)
				}
			} else {
				withoutGenerated = append(withoutGenerated, entry)
			}
		} else {
			withoutGenerated = append(withoutGenerated, entry)
		}
	}
	
	enIndex := -1
	for i, entry := range withoutGenerated {
		if entryMap, ok := entry.(map[string]interface{}); ok {
			if lang, ok := entryMap["language"].(string); ok && lang == "en" {
				enIndex = i
				break
			}
		}
	}
	
	generated := make([]interface{}, len(generatedLocales))
	for i, entry := range generatedLocales {
		generated[i] = composeLocaleNav(entry, englishNav)
	}
	
	if enIndex == -1 {
		withoutGenerated = append(withoutGenerated, generated...)
	} else {
		// Insert generated locales after English
		newSlice := make([]interface{}, len(withoutGenerated)+len(generated))
		copy(newSlice, withoutGenerated[:enIndex+1])
		copy(newSlice[enIndex+1:], generated)
		copy(newSlice[enIndex+1+len(generated):], withoutGenerated[enIndex+1:])
		withoutGenerated = newSlice
	}
	
	navigation["languages"] = withoutGenerated
	sourceConfig["navigation"] = navigation
	
	return sourceConfig
}

func syncDocsTree(targetRoot string) {
	targetDocsDir := filepath.Join(targetRoot, "docs")
	ensureDir(targetDocsDir)
	
	localeFilters := make([]string, 0)
	for _, entry := range generatedLocales {
		localeFilters = append(localeFilters, 
			"--filter", fmt.Sprintf("P %s/", entry.Dir),
			"--filter", fmt.Sprintf("P .i18n/%s", entry.TMFile),
			"--exclude", fmt.Sprintf("%s/", entry.Dir),
			"--exclude", fmt.Sprintf(".i18n/%s", entry.TMFile))
	}
	
	rsyncArgs := []string{
		"-a",
		"--delete",
		"--filter", "P .i18n/README.md",
		"--exclude", ".i18n/README.md",
	}
	
	rsyncArgs = append(rsyncArgs, localeFilters...)
	rsyncArgs = append(rsyncArgs, 
		fmt.Sprintf("%s/", sourceDocsDir),
		fmt.Sprintf("%s/", targetDocsDir))
	
	run("rsync", rsyncArgs...)
	
	for _, locale := range generatedLocales {
		sourceTmPath := filepath.Join(sourceDocsDir, ".i18n", locale.TMFile)
		targetTmPath := filepath.Join(targetDocsDir, ".i18n", locale.TMFile)
		
		if _, err := os.Stat(targetTmPath); os.IsNotExist(err) {
			if _, err := os.Stat(sourceTmPath); err == nil {
				ensureDir(filepath.Dir(targetTmPath))
				sourceFile, err := os.Open(sourceTmPath)
				if err != nil {
					panic(err)
				}
				defer sourceFile.Close()
				
				targetFile, err := os.Create(targetTmPath)
				if err != nil {
					panic(err)
				}
				defer targetFile.Close()
				
				if _, err := io.Copy(targetFile, sourceFile); err != nil {
					panic(err)
				}
			}
		}
	}
	
	writeJSON(filepath.Join(targetDocsDir, "docs.json"), composeDocsConfig())
}

func writeSyncMetadata(targetRoot string, args *Args) {
	metadata := map[string]interface{}{
		"repository": args.SourceRepo,
		"sha":        args.SourceSHA,
		"syncedAt":   time.Now().Format(time.RFC3339),
	}
	
	writeJSON(filepath.Join(targetRoot, ".openclaw-sync", "source.json"), metadata)
}

func main() {
	args := parseArgs()
	targetRoot, err := filepath.Abs(args.Target)
	if err != nil {
		panic(err)
	}
	
	if _, err := os.Stat(targetRoot); os.IsNotExist(err) {
		panic(fmt.Sprintf("target does not exist: %s", targetRoot))
	}
	
	syncDocsTree(targetRoot)
	writeSyncMetadata(targetRoot, args)
}

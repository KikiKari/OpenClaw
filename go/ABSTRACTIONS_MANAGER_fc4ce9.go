// abstraction-provenance: {"artifact_sha256": "8e8d27781890e49e02f85b64b155b66c1651089d5f4e36dee22148d3877c51e3", "source_sha256": "fc4ce94d8389188be8aa35f040d616ca2baa44095f057fa78606f347d342ff4b", "target_language": "go"}
// ABSTRACTIONS_MANAGER.py — portiert nach go
// Quelle: python, workspace@local:git/skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

// Configuration
var (
	workspace       = getEnv("ABSTRACTIONS_WORKSPACE", "/home/openclaw/.openclaw/workspace")
	abstractionsRepo = filepath.Join(workspace, "git", "OpenClaw-gateway1-abstractions")
	sourcesDir      = filepath.Join(workspace, "git", "quellen")
	logDir          = filepath.Join(workspace, "logs", "abstractions-manager")
	stateFile       = filepath.Join(workspace, "db", "abstractions_state.json")
	githubUser      = "KikiKari"
	sources         = []map[string]interface{}{
		{"repo": "OpenClaw", "branches": []string{"main", "gateway1", "gateway2"}},
		{"repo": "Projects", "branches": "alle"},
		{"repo": "Onboarding", "branches": []string{"main"}},
	}
	sourceLanguages = map[string]string{
		".pl":   "perl5",
		".pm":   "perl5",
		".ps1":  "powershell",
		".psm1": "powershell",
		".sh":   "shell",
		".bash": "shell",
		".tcl":  "tcl",
		".html": "html",
		".htm":  "html",
		".js":   "javascript",
		".mjs":  "javascript",
		".cjs":  "javascript",
		".py":   "python",
		".css":  "css",
	}
	targetLanguages = map[string]map[string]string{
		"javascript": {"ext": ".js", "bezeichnung": "JavaScript fuer Node 20"},
		"perl5":      {"ext": ".pl", "bezeichnung": "Perl 5 mit use strict und use warnings"},
		"powershell": {"ext": ".ps1", "bezeichnung": "PowerShell 7"},
		"python":     {"ext": ".py", "bezeichnung": "Python 3.12"},
		"shell":      {"ext": ".sh", "bezeichnung": "Bash 5 mit set -euo pipefail"},
		"tcl":        {"ext": ".tcl", "bezeichnung": "Tcl 8.6"},
	}
	exclusions = []string{
		"node_modules/", "/.git/", "__pycache__/", "dist/", "build/", "vendor/",
		".venv/", "site-packages/", "python-hardener-workspace/", ".artifacts/",
		"coverage/", ".next/", "target/",
	}
	maxBytes = 200000
	models = []string{
		"qwen/qwen3-coder",
		"deepseek/deepseek-chat-v3.1",
		"z-ai/glm-4.6",
		"mistralai/codestral-2508",
		"qwen/qwen-2.5-coder-32b-instruct",
	}
	apiURL    = "https://openrouter.ai/api/v1/chat/completions"
	timeout   = 240
	maxTries  = 3
	instruction = `Du portierst Quellcode zwischen Programmiersprachen.

Regeln:
1. Gib ausschliesslich den vollstaendigen Code der Zielsprache aus. Keine
   Erklaerung davor oder danach, keine Code-Zaeune.
2. Uebersetze die gesamte Funktionalitaet. Kein TODO, kein "hier waere",
   kein leerer Rumpf, kein Platzhalter.
3. Erhalte Verhalten, Ein- und Ausgaben, Aufrufparameter und Rueckgabewerte.
4. Verwende die Mittel der Zielsprache statt einer woertlichen Abschrift.
   Wo eine Bibliothek fehlt, loese es mit Bordmitteln der Zielsprache.
5. Kommentare uebernimmst du sinngemaess in der Sprache des Originals.
6. Beginne mit der passenden Shebang-Zeile.`
	markupHint = `Das Original ist {sprache}. Erzeuge ein Programm in der
Zielsprache, das dieses Dokument erzeugt und ueber einen Parameter in eine
Datei schreibt — kein blosses Einbetten als Zeichenkette, sondern eine
nachvollziehbare Erzeugung der Struktur.`
	verdict = []string{"TODO: Implementiere", "TODO: implement", "not implemented",
		"hier waere", "Platzhalter", "your code here", "pass  # TODO"}
	checkCommands = map[string][]string{
		"javascript": {"node", "--check"},
		"perl5":      {"perl", "-c"},
		"powershell": {"pwsh", "-NoProfile", "-Command"},
		"shell":      {"bash", "-n"},
		"tcl":        {"tclsh"},
	}
)

type State struct {
	Completed map[string][]string `json:"erledigt"`
	Stats     map[string]int      `json:"statistik"`
}

type SourceEntry struct {
	Hash      string   `json:"hash"`
	Name      string   `json:"name"`
	Stem      string   `json:"stamm"`
	Language  string   `json:"sprache"`
	Bytes     int      `json:"bytes"`
	Path      string   `json:"pfad"`
	Origin    []string `json:"herkunft"`
	Priority  string   `json:"prioritaet"`
}

type Counter struct {
	Generated    int `json:"erzeugt"`
	Skipped      int `json:"uebersprungen"`
	Discarded    int `json:"verworfen"`
	FilesProcessed int `json:"dateien"`
}

func getEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return fallback
}

func runGit(args []string, dir string) (string, error) {
	cmd := exec.Command("git", args...)
	if dir != "" {
		cmd.Dir = dir
	}
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &out
	err := cmd.Run()
	return out.String(), err
}

func fetchSources() ([][3]string, error) {
	var trees [][3]string
	err := os.MkdirAll(sourcesDir, 0755)
	if err != nil {
		return nil, err
	}

	for _, entry := range sources {
		repo := entry["repo"].(string)
		mirror := filepath.Join(sourcesDir, repo+".git")
		url := fmt.Sprintf("https://github.com/%s/%s.git", githubUser, repo)

		if _, err := os.Stat(mirror); os.IsNotExist(err) {
			log.Printf("%s wird geholt", repo)
			_, err := runGit([]string{"clone", "--mirror", "--filter=blob:none", url, mirror}, "")
			if err != nil {
				log.Printf("%s konnte nicht geholt werden: %v", repo, err)
				continue
			}
		} else {
			_, err := runGit([]string{"remote", "update", "--prune"}, mirror)
			if err != nil {
				log.Printf("%s konnte nicht aktualisiert werden: %v", repo, err)
			}
		}

		var branches []string
		if entry["branches"] == "alle" {
			out, _ := runGit([]string{"for-each-ref", "--format=%(refname:short)", "refs/heads"}, mirror)
			for _, line := range strings.Split(out, "\n") {
				if line = strings.TrimSpace(line); line != "" {
					branches = append(branches, line)
				}
			}
		} else {
			for _, b := range entry["branches"].([]string) {
				branches = append(branches, b)
			}
		}

		for _, branch := range branches {
			tree := filepath.Join(sourcesDir, "baeume", repo, strings.ReplaceAll(branch, "/", "_"))
			err := os.MkdirAll(tree, 0755)
			if err != nil {
				continue
			}
			_, err = runGit([]string{"--work-tree", tree, "checkout", "-f", branch, "--", "."}, mirror)
			if err != nil {
				log.Printf("%s@%s: Arbeitsbaum fehlgeschlagen: %v", repo, branch, err)
				continue
			}
			trees = append(trees, [3]string{repo, branch, tree})
		}
	}

	log.Printf("Quellen bereit: %d Arbeitsbaeume", len(trees))
	return trees, nil
}

func priority(path, language string) string {
	if language == "html" || language == "css" {
		return "low"
	}
	if strings.HasPrefix(path, "scripts/") || strings.Contains(path, "/scripts/") {
		return "high"
	}
	return "medium"
}

func buildInventory(trees [][3]string) ([]SourceEntry, error) {
	files := make(map[string]SourceEntry)

	for _, tree := range trees {
		repo, branch, root := tree[0], tree[1], tree[2]
		err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
			if err != nil || info.IsDir() {
				return nil
			}
			rel, err := filepath.Rel(root, path)
			if err != nil {
				return nil
			}
			rel = strings.ReplaceAll(rel, "\\", "/")
			excluded := false
			for _, pattern := range exclusions {
				if strings.Contains("/"+rel, pattern) {
					excluded = true
					break
				}
			}
			if excluded {
				return nil
			}
			ext := strings.ToLower(filepath.Ext(path))
			language, ok := sourceLanguages[ext]
			if !ok {
				return nil
			}
			content, err := os.ReadFile(path)
			if err != nil {
				return nil
			}
			if len(bytes.TrimSpace(content)) == 0 || len(content) > maxBytes {
				return nil
			}
			hash := fmt.Sprintf("%x", sha256.Sum256(content))[:16]
			entry, exists := files[hash]
			if !exists {
				entry = SourceEntry{
					Hash:     hash,
					Name:     filepath.Base(path),
					Stem:     strings.TrimSuffix(filepath.Base(path), ext),
					Language: language,
					Bytes:    len(content),
					Path:     path,
					Origin:   []string{},
					Priority: priority(rel, language),
				}
			}
			entry.Origin = append(entry.Origin, fmt.Sprintf("%s@%s:%s", repo, branch, rel))
			files[hash] = entry
			return nil
		})
		if err != nil {
			return nil, err
		}
	}

	var inventory []SourceEntry
	for _, entry := range files {
		inventory = append(inventory, entry)
	}

	priorityOrder := map[string]int{"high": 0, "medium": 1, "low": 2}
	sort.Slice(inventory, func(i, j int) bool {
		if priorityOrder[inventory[i].Priority] != priorityOrder[inventory[j].Priority] {
			return priorityOrder[inventory[i].Priority] < priorityOrder[inventory[j].Priority]
		}
		return inventory[i].Name < inventory[j].Name
	})

	log.Printf("Inventar: %d eindeutige Quelldateien aus %d Fundstellen", len(inventory), len(files))
	return inventory, nil
}

func removeFences(text string) string {
	lines := strings.Split(strings.TrimSpace(text), "\n")
	if len(lines) > 0 && strings.HasPrefix(strings.TrimSpace(lines[0]), "```") {
		lines = lines[1:]
		for len(lines) > 0 && !strings.HasPrefix(strings.TrimSpace(lines[len(lines)-1]), "```") {
			if strings.TrimSpace(lines[len(lines)-1]) != "" {
				break
			}
			lines = lines[:len(lines)-1]
		}
		if len(lines) > 0 && strings.HasPrefix(strings.TrimSpace(lines[len(lines)-1]), "```") {
			lines = lines[:len(lines)-1]
		}
	}
	return strings.Join(lines, "\n") + "\n"
}

func queryModel(source, sourceLanguage, targetLanguage, name, apiKey string) (string, error) {
	target := targetLanguages[targetLanguage]["bezeichnung"]
	prompt := fmt.Sprintf("Portiere die folgende Datei %s von %s nach %s.\n", name, sourceLanguage, target)
	if sourceLanguage == "html" || sourceLanguage == "css" {
		prompt += strings.ReplaceAll(markupHint, "{sprache}", strings.ToUpper(sourceLanguage)) + "\n"
	}
	prompt += fmt.Sprintf("\n----- Beginn %s -----\n%s\n----- Ende %s -----", name, source, name)

	model := getEnv("ABSTRACTIONS_MODELL", "")
	if model == "" {
		model = models[0]
	}

	for _, m := range models {
		for attempt := 1; attempt <= maxTries; attempt++ {
			requestBody, _ := json.Marshal(map[string]interface{}{
				"model": m,
				"messages": []map[string]string{
					{"role": "system", "content": instruction},
					{"role": "user", "content": prompt},
				},
				"temperature": 0.1,
				"max_tokens":  8000,
			})

			req, err := http.NewRequest("POST", apiURL, bytes.NewBuffer(requestBody))
			if err != nil {
				return "", err
			}
			req.Header.Set("Authorization", "Bearer "+apiKey)
			req.Header.Set("Content-Type", "application/json")
			req.Header.Set("HTTP-Referer", "https://github.com/KikiKari/Projects")
			req.Header.Set("X-Title", "Abstractions Manager")

			client := &http.Client{Timeout: time.Duration(timeout) * time.Second}
			resp, err := client.Do(req)
			if err != nil {
				log.Printf("%s -> %s: %v bei %s", name, targetLanguage, err, m)
				time.Sleep(time.Duration(math.Pow(2, float64(attempt))) * time.Second)
				continue
			}
			defer resp.Body.Close()

			if resp.StatusCode != http.StatusOK {
				body, _ := io.ReadAll(resp.Body)
				log.Printf("%s -> %s: HTTP %d von %s (%s)", name, targetLanguage, resp.StatusCode, m, string(body)[:200])
				if resp.StatusCode == http.StatusBadRequest || resp.StatusCode == http.StatusUnauthorized || resp.StatusCode == http.StatusPaymentRequired || resp.StatusCode == http.StatusNotFound {
					break
				}
				time.Sleep(time.Duration(math.Pow(2, float64(attempt))) * time.Second)
				continue
			}

			var result map[string]interface{}
			if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
				log.Printf("%s -> %s: %v bei %s", name, targetLanguage, err, m)
				time.Sleep(time.Duration(math.Pow(2, float64(attempt))) * time.Second)
				continue
			}

			content := result["choices"].([]interface{})[0].(map[string]interface{})["message"].(map[string]interface{})["content"].(string)
			if content != "" {
				return removeFences(content), nil
			}
			log.Printf("%s -> %s: leere Antwort von %s", name, targetLanguage, m)
			time.Sleep(time.Duration(math.Pow(2, float64(attempt))) * time.Second)
		}
	}

	log.Printf("%s -> %s: kein Modell hat geliefert", name, targetLanguage)
	return "", fmt.Errorf("no model responded")
}

func checkProduct(code, targetLanguage, source string) (bool, string) {
	sourceLines := len(strings.Split(source, "\n"))
	lines := len(strings.Fields(strings.TrimSpace(code)))
	minLines := max(2, min(6, sourceLines/3))
	if sourceLines > 0 {
		minLines = max(2, min(6, sourceLines/3))
	} else {
		minLines = 5
	}
	if lines < minLines {
		return false, fmt.Sprintf("zu kurz (%d statt mindestens %d Zeilen)", lines, minLines)
	}

	lowerSource := strings.ToLower(source)
	for _, pattern := range verdict {
		if strings.Contains(strings.ToLower(code), strings.ToLower(pattern)) && !strings.Contains(lowerSource, strings.ToLower(pattern)) {
			return false, fmt.Sprintf("unfertig (%s)", pattern)
		}
	}

	if targetLanguage == "python" {
		_, err := parser.ParseFile(token.NewFileSet(), "", code, parser.AllErrors)
		if err != nil {
			return false, fmt.Sprintf("Syntaxfehler Zeile %d", err.(*parser.Error).Pos)
		}
		return true, "syntax ok"
	}

	if cmd, ok := checkCommands[targetLanguage]; ok {
		ext := targetLanguages[targetLanguage]["ext"]
		file, err := os.CreateTemp("", "*"+ext)
		if err != nil {
			return true, "Interpreter fehlt — ohne Syntaxpruefung angenommen"
		}
		defer os.Remove(file.Name())
		defer file.Close()

		_, err = file.WriteString(code)
		if err != nil {
			return true, "Pruefung nicht moeglich — angenommen"
		}

		var args []string
		if targetLanguage == "powershell" {
			args = append(cmd, fmt.Sprintf("$null = [ScriptBlock]::Create((Get-Content -Raw '%s'))", file.Name()))
		} else if targetLanguage == "tcl" {
			cmd := exec.Command("tclsh")
			cmd.Stdin = strings.NewReader(fmt.Sprintf("if {[catch {info complete [read [open %s]]}]} {exit 1}", file.Name()))
			err := cmd.Run()
			if err != nil {
				return false, "Syntaxfehler"
			}
			return true, "syntax ok"
		} else {
			args = append(cmd, file.Name())
		}

		c := exec.Command(args[0], args[1:]...)
		var out bytes.Buffer
		c.Stdout = &out
		c.Stderr = &out
		err = c.Run()
		if err == nil {
			return true, "syntax ok"
		}

		message := out.String()
		if strings.Contains(message, "Can't locate") || strings.Contains(message, "Cannot find module") {
			return true, "Fremdmodul fehlt hier — Syntax nicht abschliessend geprueft"
		}
		firstLine := strings.Split(message, "\n")[0]
		if len(firstLine) > 90 {
			firstLine = firstLine[:90]
		}
		return false, "Syntaxfehler: " + firstLine
	}

	return true, "ohne Syntaxpruefung angenommen"
}

func targetFile(entry SourceEntry, targetLanguage string, occupied map[string]string) string {
	ext := targetLanguages[targetLanguage]["ext"]
	stem := entry.Stem
	key := fmt.Sprintf("%s/%s", targetLanguage, stem)
	if prev, exists := occupied[key]; exists && prev != entry.Hash {
		stem = fmt.Sprintf("%s_%s", stem, entry.Hash[:6])
	} else {
		occupied[key] = entry.Hash
	}
	return filepath.Join(abstractionsRepo, targetLanguage, stem+ext)
}

func header(entry SourceEntry, targetLanguage string) string {
	comment := "//"
	if targetLanguage == "javascript" {
		comment = "//"
	} else if targetLanguage == "python" {
		comment = "#"
	} else if targetLanguage == "shell" {
		comment = "#"
	} else if targetLanguage == "tcl" {
		comment = "#"
	} else if targetLanguage == "powershell" {
		comment = "#"
	} else if targetLanguage == "perl5" {
		comment = "#"
	}
	today := time.Now().UTC().Format("2006-01-02")
	lines := []string{
		fmt.Sprintf("%s %s — portiert nach %s", comment, entry.Name, targetLanguage),
		fmt.Sprintf("%s Quelle: %s, %s", comment, entry.Language, entry.Origin[0]),
	}
	for _, origin := range entry.Origin[1:4] {
		lines = append(lines, fmt.Sprintf("%s auch in: %s", comment, origin))
	}
	if len(entry.Origin) > 4 {
		lines = append(lines, fmt.Sprintf("%s auch in: %d weiteren Fundstellen", comment, len(entry.Origin)-4))
	}
	lines = append(lines, fmt.Sprintf("%s Erzeugt: %s durch ABSTRACTIONS_MANAGER.py", comment, today))
	return strings.Join(lines, "\n") + "\n"
}

func deposit(entry SourceEntry, targetLanguage, code string, occupied map[string]string) (string, error) {
	target := targetFile(entry, targetLanguage, occupied)
	err := os.MkdirAll(filepath.Dir(target), 0755)
	if err != nil {
		return "", fmt.Errorf("%s konnte nicht abgelegt werden: %v", target, err)
	}

	lines := strings.Split(code, "\n")
	if len(lines) > 0 && strings.HasPrefix(lines[0], "#!") {
		content := lines[0] + "\n" + header(entry, targetLanguage) + "\n" + strings.Join(lines[1:], "\n") + "\n"
		err = os.WriteFile(target, []byte(content), 0644)
	} else {
		content := header(entry, targetLanguage) + "\n" + code
		err = os.WriteFile(target, []byte(content), 0644)
	}
	if err != nil {
		return "", fmt.Errorf("%s konnte nicht abgelegt werden: %v", target, err)
	}
	return target, nil
}

func translate(inventory []SourceEntry, state State, priority string, count int, dryRun bool, apiKey string) Counter {
	counter := Counter{}
	occupied := make(map[string]string)
	completed := state.Completed

	var open []SourceEntry
	for _, entry := range inventory {
		if priority == "alle" || entry.Priority == priority {
			open = append(open, entry)
		}
	}
	log.Printf("Prioritaet %s: %d Quelldateien im Bestand", priority, len(open))

	for _, entry := range open {
		if counter.FilesProcessed >= count {
			log.Printf("Kontingent von %d Quelldateien erreicht", count)
			break
		}

		done := make(map[string]bool)
		for _, lang := range completed[entry.Hash] {
			done[lang] = true
		}
		var targets []string
		for lang := range targetLanguages {
			if lang != entry.Language && !done[lang] {
				targets = append(targets, lang)
			}
		}
		if len(targets) == 0 {
			continue
		}

		source, err := os.ReadFile(entry.Path)
		if err != nil {
			log.Printf("%s nicht lesbar: %v", entry.Name, err)
			continue
		}

		counter.FilesProcessed++
		log.Printf("[%s] %s (%s, %d B) -> %s", entry.Priority, entry.Name, entry.Language, entry.Bytes, strings.Join(targets, ", "))

		for _, targetLanguage := range targets {
			if dryRun {
				log.Printf("  %s: Probelauf, nichts gesendet", targetLanguage)
				counter.Skipped++
				continue
			}

			code, err := queryModel(string(source), entry.Language, targetLanguage, entry.Name, apiKey)
			if err != nil {
				counter.Discarded++
				continue
			}

			accepted, reason := checkProduct(code, targetLanguage, string(source))
			if !accepted {
				log.Printf("  %s: verworfen — %s", targetLanguage, reason)
				counter.Discarded++
				continue
			}

			target, err := deposit(entry, targetLanguage, code, occupied)
			if err != nil {
				log.Printf("%s konnte nicht abgelegt werden: %v", target, err)
				counter.Discarded++
				continue
			}

			log.Printf("  %s: %s (%s)", targetLanguage, filepath.Base(target), reason)
			counter.Generated++
			completed[entry.Hash] = append(completed[entry.Hash], targetLanguage)
		}
	}

	return counter
}

func writeReport(inventory []SourceEntry, state State, counter Counter) error {
	if _, err := os.Stat(abstractionsRepo); os.IsNotExist(err) {
		log.Printf("Abstraktions-Repository fehlt: %s", abstractionsRepo)
		return err
	}

	perLanguage := make(map[string]int)
	for lang := range targetLanguages {
		dir := filepath.Join(abstractionsRepo, lang)
		files, err := os.ReadDir(dir)
		if err != nil {
			continue
		}
		for _, file := range files {
			if !file.IsDir() {
				perLanguage[lang]++
			}
		}
	}

	priorityOrder := map[string]int{"high": 0, "medium": 1, "low": 2}
	perPriority := make(map[string]int)
	for _, entry := range inventory {
		perPriority[entry.Priority]++
	}
	completed := state.Completed
	open := 0
	for _, entry := range inventory {
		open += len(targetLanguages) - len(completed[entry.Hash])
	}

	lines := []string{
		"# Script Abstractions — Status",
		"",
		fmt.Sprintf("**Letzter Lauf:** %s UTC", time.Now().UTC().Format("2006-01-02 15:04")),
		"",
		"Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.",
		"Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige",
		"Syntax oder mit Platzhaltern werden verworfen.",
		"",
		"## Bestand",
		"",
		"| Zielsprache | Dateien |",
		"|---|---:|",
	}
	for lang, count := range perLanguage {
		lines = append(lines, fmt.Sprintf("| %s | %d |", lang, count))
	}
	lines = append(lines, fmt.Sprintf("| **gesamt** | **%d** |", len(perLanguage)))
	lines = append(lines, "",
		"## Quellen",
		"",
		"| Prioritaet | Quelldateien | Bedeutung |",
		"|---|---:|---|",
		fmt.Sprintf("| high | %d | Betriebsscripte aus scripts-Verzeichnissen |", perPriority["high"]),
		fmt.Sprintf("| medium | %d | uebriger ausfuehrbarer Code |", perPriority["medium"]),
		fmt.Sprintf("| low | %d | Markup und Stilvorlagen |", perPriority["low"]),
		fmt.Sprintf("| **gesamt** | **%d** | nach Inhalt dedupliziert |", len(inventory)),
		"",
		fmt.Sprintf("Noch offene Sprachpaare: **%d**", open),
		"",
		"## Letzter Lauf",
		"",
		fmt.Sprintf("- bearbeitete Quelldateien: %d", counter.FilesProcessed),
		fmt.Sprintf("- erzeugte Uebersetzungen: %d", counter.Generated),
		fmt.Sprintf("- verworfen: %d", counter.Discarded),
		"",
		"## Herkunft",
		"",
		"- `KikiKari/OpenClaw` — main, gateway1, gateway2",
		"- `KikiKari/Projects` — alle Branches",
		"- `KikiKari/Onboarding` — main",
		"",
		"Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.",
		"",
	)

	err := os.WriteFile(filepath.Join(abstractionsRepo, "STATUS.md"), []byte(strings.Join(lines, "\n")), 0644)
	if err != nil {
		log.Printf("STATUS.md konnte nicht geschrieben werden: %v", err)
		return err
	}
	log.Println("STATUS.md fortgeschrieben")
	return nil
}

func publish(message string) error {
	if _, err := os.Stat(filepath.Join(abstractionsRepo, ".git")); os.IsNotExist(err) {
		log.Printf("Kein Git-Arbeitsbaum in %s — nichts zu veroeffentlichen", abstractionsRepo)
		return nil
	}

	status, err := runGit([]string{"status", "--porcelain"}, abstractionsRepo)
	if err != nil || strings.TrimSpace(status) == "" {
		log.Println("Keine Aenderungen zu veroeffentlichen")
		return nil
	}

	for lang := range targetLanguages {
		_, err := runGit([]string{"add", lang}, abstractionsRepo)
		if err != nil {
			return err
		}
	}
	_, err = runGit([]string{"add", "STATUS.md"}, abstractionsRepo)
	if err != nil {
		return err
	}

	_, err = runGit([]string{"commit", "-m", message}, abstractionsRepo)
	if err != nil {
		log.Printf("Commit fehlgeschlagen: %v", err)
		return err
	}
	log.Printf("Commit gesetzt: %s", message)

	token := getEnv("GITHUB_TOKEN", "")
	if token == "" {
		token = getEnv("ABSTRACTIONS_PUSH_TOKEN", "")
	}
	if token == "" {
		log.Println("Kein Token in der Umgebung — Commit bleibt lokal")
		return nil
	}

	url := fmt.Sprintf("https://x-access-token:%s@github.com/%s/OpenClaw.git", token, githubUser)
	_, err = runGit([]string{"push", url, "HEAD:gateway1-abstractions"}, abstractionsRepo)
	if err != nil {
		log.Printf("Push fehlgeschlagen: %v", err)
		return err
	}
	log.Println("Nach OpenClaw@gateway1-abstractions veroeffentlicht")
	return nil
}

func main() {
	log.Println("Abstractions Manager gestartet — Arbeitsverzeichnis", workspace)

	apiKey := strings.TrimSpace(getEnv("OPENROUTER_API_KEY", ""))
	if apiKey == "" {
		log.Println("OPENROUTER_API_KEY ist leer oder besteht nur aus Leerraum — ohne Schluessel keine Uebersetzung")
		os.Exit(2)
	}
	if !strings.HasPrefix(apiKey, "sk-or-") {
		log.Printf("OPENROUTER_API_KEY sieht nicht nach einem OpenRouter-Schluessel aus (%d Zeichen, beginnt mit %q) — erwartet wird sk-or-...", len(apiKey), apiKey[:6])
		os.Exit(2)
	}
	log.Printf("Schluessel erkannt: %d Zeichen", len(apiKey))

	state := loadState()
	trees, err := fetchSources()
	if err != nil || len(trees) == 0 {
		log.Println("Keine Quellen verfuegbar")
		os.Exit(1)
	}

	inventory, err := buildInventory(trees)
	if err != nil || len(inventory) == 0 {
		log.Println("Inventar leer")
		os.Exit(1)
	}

	priority := getEnv("PRIORITY", "high")
	counter := translate(inventory, state, priority, 40, false, apiKey)

	state.NextPriority = map[string]string{"high": "medium", "medium": "low", "low": "high", "alle": "alle"}[priority]
	state.Stats = map[string]int{
		"letzter_lauf": time.Now().UTC().Unix(),
		"quelldateien": len(inventory),
		"erzeugt":      counter.Generated,
		"uebersprungen": counter.Skipped,
		"verworfen":   counter.Discarded,
		"dateien":      counter.FilesProcessed,
	}

	err = writeReport(inventory, state, counter)
	if err != nil {
		log.Printf("Fehler beim Schreiben des Berichts: %v", err)
	}

	err = saveState(state)
	if err != nil {
		log.Printf("Fehler beim Speichern des Zustands: %v", err)
	}

	if counter.Generated > 0 {
		err = publish(fmt.Sprintf("auto: %d Uebersetzungen (%s) aus %d Quelldateien", counter.Generated, priority, counter.FilesProcessed))
		if err != nil {
			log.Printf("Fehler beim Veröffentlichen: %v", err)
		}
	}

	log.Printf("Abgeschlossen: %d erzeugt, %d verworfen, %d Quelldateien bearbeitet", counter.Generated, counter.Discarded, counter.FilesProcessed)
}

func loadState() State {
	var state State
	if _, err := os.Stat(stateFile); os.IsNotExist(err) {
		return State{Completed: make(map[string][]string), Stats: make(map[string]int)}
	}
	data, err := os.ReadFile(stateFile)
	if err != nil {
		log.Printf("Zustand unlesbar (%v) — es wird neu begonnen", err)
		return State{Completed: make(map[string][]string), Stats: make(map[string]int)}
	}
	err = json.Unmarshal(data, &state)
	if err != nil {
		log.Printf("Zustand unlesbar (%v) — es wird neu begonnen", err)
		return State{Completed: make(map[string][]string), Stats: make(map[string]int)}
	}
	return state
}

func saveState(state State) error {
	data, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return err
	}
	tempFile, err := os.CreateTemp(filepath.Dir(stateFile), ".zustand_")
	if err != nil {
		return err
	}
	defer tempFile.Close()
	_, err = tempFile.Write(data)
	if err != nil {
		return err
	}
	err = tempFile.Close()
	if err != nil {
		return err
	}
	return os.Rename(tempFile.Name(), stateFile)
}

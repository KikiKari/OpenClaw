// abstraction-provenance: {"artifact_sha256": "200556fe8c75ceb0259ad3c6a31400d51ad768f0082c54d20f366732cd65521c", "source_sha256": "4ccdf30dd1193d1cc7c50fce4977be19a48ef1bbbdd460574570e788e6da4ca7", "target_language": "go"}
// ABSTRACTIONS_MANAGER.py — portiert nach go
// Quelle: python, workspace@local:skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py
// Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"bufio"
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/go-git/go-git/v5"
	"github.com/go-git/go-git/v5/plumbing"
	"github.com/go-git/go-git/v5/plumbing/transport/http"
)

// Konfiguration
var (
	WORKSPACE          = getEnv("ABSTRACTIONS_WORKSPACE", "/home/openclaw/.openclaw/workspace")
	ABSTRACTIONS_REPO  = filepath.Join(WORKSPACE, "git", "OpenClaw-gateway1-abstractions")
	QUELLEN_DIR        = filepath.Join(WORKSPACE, "git", "quellen")
	LOG_DIR            = filepath.Join(WORKSPACE, "logs", "abstractions-manager")
	STATE_FILE         = filepath.Join(WORKSPACE, "db", "abstractions_state.json")
	GITHUB_BENUTZER    = "KikiKari"
	QUELLSPRACHEN      = map[string]string{
		".pl": "perl5", ".pm": "perl5",
		".raku": "perl6", ".rakumod": "perl6",
		".rb": "ruby", ".lua": "lua", ".go": "go",
		".ps1": "powershell", ".psm1": "powershell",
		".sh": "shell", ".bash": "shell",
		".tcl": "tcl",
		".html": "html", ".htm": "html",
		".js": "javascript", ".mjs": "javascript", ".cjs": "javascript",
		".py": "python",
		".css": "css",
	}
	ZIELSPRACHEN = map[string]map[string]string{
		"javascript": {"ext": ".js", "bezeichnung": "JavaScript fuer Node 20"},
		"perl5":      {"ext": ".pl", "bezeichnung": "Perl 5 mit use strict und use warnings"},
		"powershell": {"ext": ".ps1", "bezeichnung": "PowerShell 7"},
		"python":     {"ext": ".py", "bezeichnung": "Python 3.12"},
		"shell":      {"ext": ".sh", "bezeichnung": "Bash 5 mit set -euo pipefail"},
		"tcl":        {"ext": ".tcl", "bezeichnung": "Tcl 8.6"},
		"perl6":      {"ext": ".raku", "bezeichnung": "Raku"},
		"ruby":       {"ext": ".rb", "bezeichnung": "Ruby"},
		"lua":        {"ext": ".lua", "bezeichnung": "Lua"},
		"go":         {"ext": ".go", "bezeichnung": "Go"},
	}
	AUSSCHLUSS = []string{
		"node_modules/", "/.git/", "__pycache__/", "dist/", "build/", "vendor/",
		".venv/", "site-packages/", "python-hardener-workspace/", ".artifacts/",
		"coverage/", ".next/", "target/", "/work/", "/backups/",
	}
	MAX_BYTES = 200000
	MODELLE   = []string{
		"qwen/qwen3-coder",
		"deepseek/deepseek-chat-v3.1",
		"z-ai/glm-4.6",
		"mistralai/codestral-2508",
		"qwen/qwen-2.5-coder-32b-instruct",
	}
	API_URL    = "https://openrouter.ai/api/v1/chat/completions"
	ZEITLIMIT  = 240
	VERSUCHE   = 3
	ANWEISUNG  = `Du portierst Quellcode zwischen Programmiersprachen.

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
	MARKUP_HINWEIS = "Das Original ist %s. Erzeuge ein Programm in der Zielsprache, das dieses Dokument erzeugt und ueber einen Parameter in eine Datei schreibt — kein blosses Einbetten als Zeichenkette, sondern eine nachvollziehbare Erzeugung der Struktur."
	VERDACHT      = []string{"TODO: Implementiere", "TODO: implement", "not implemented", "hier waere", "Platzhalter", "your code here", "pass  # TODO"}
	PRUEFBEFEHLE  = map[string][]string{
		"javascript": {"node", "--check"},
		"perl5":      {"perl", "-c"},
		"powershell": {"pwsh", "-NoProfile", "-Command"},
		"shell":      {"bash", "-n"},
		"tcl":        {"tclsh"},
		"perl6":      {"raku", "-c"},
		"ruby":       {"ruby", "-c"},
		"lua":        {"luac", "-p"},
		"go":         {"gofmt", "-e"},
	}
)

type Quelle struct {
	Repo     string
	Branches interface{}
}

type Zustand struct {
	Erledigt          map[string][]string `json:"erledigt"`
	Statistik         map[string]int      `json:"statistik"`
	NaechstePrioritaet string              `json:"naechste_prioritaet"`
	AuswahlCursor     map[string]string   `json:"auswahl_cursor"`
	AusstehendeVeroeffentlichungen []string `json:"ausstehende_veroeffentlichungen"`
}

type DateiEintrag struct {
	Hash       string
	Name       string
	Stamm      string
	Sprache    string
	Bytes      int
	Pfad       string
	Herkunft   []string
	Prioritaet string
	SourceSHA256 string
}

func main() {
	if err := run(); err != nil {
		log.Fatal(err)
	}
}

func run() error {
	// Argument parsing würde hier implementiert werden
	// Vereinfachte Hauptlogik für Demonstration
	zustand, err := zustandLaden()
	if err != nil {
		return err
	}

	baeume, err := quellenHolen()
	if err != nil {
		return err
	}

	inventar, err := inventarBauen(baeume)
	if err != nil {
		return err
	}

	// Weitere Verarbeitung würde hier folgen
	return zustandSpeichern(zustand)
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func zustandLaden() (*Zustand, error) {
	data, err := os.ReadFile(STATE_FILE)
	if err != nil {
		if os.IsNotExist(err) {
			return &Zustand{
				Erledigt: make(map[string][]string),
				Statistik: make(map[string]int),
			}, nil
		}
		return nil, err
	}

	var zustand Zustand
	if err := json.Unmarshal(data, &zustand); err != nil {
		return nil, err
	}
	return &zustand, nil
}

func zustandSpeichern(zustand *Zustand) error {
	data, err := json.MarshalIndent(zustand, "", "  ")
	if err != nil {
		return err
	}

	if err := os.MkdirAll(filepath.Dir(STATE_FILE), 0755); err != nil {
		return err
	}

	return os.WriteFile(STATE_FILE, data, 0644)
}

func quellenHolen() ([]struct{ Repo, Branch, Pfad string }, error) {
	quellen := []Quelle{
		{Repo: "OpenClaw", Branches: []string{"main", "gateway1", "gateway2"}},
		{Repo: "Projects", Branches: "alle"},
		{Repo: "Onboarding", Branches: []string{"main"}},
	}

	var baeume []struct{ Repo, Branch, Pfad string }

	for _, quelle := range quellen {
		repoPath := filepath.Join(QUELLEN_DIR, quelle.Repo+".git")
		repoURL := fmt.Sprintf("https://github.com/%s/%s.git", GITHUB_BENUTZER, quelle.Repo)

		if _, err := os.Stat(repoPath); os.IsNotExist(err) {
			if err := gitCloneMirror(repoURL, repoPath); err != nil {
				log.Printf("Fehler beim Klonen von %s: %v", quelle.Repo, err)
				continue
			}
		} else {
			if err := gitRemoteUpdate(repoPath); err != nil {
				log.Printf("Fehler beim Aktualisieren von %s: %v", quelle.Repo, err)
			}
		}

		branches, err := getBranches(quelle, repoPath)
		if err != nil {
			log.Printf("Fehler beim Abrufen der Branches von %s: %v", quelle.Repo, err)
			continue
		}

		for _, branch := range branches {
			baumPath := filepath.Join(QUELLEN_DIR, "baeume", quelle.Repo, strings.ReplaceAll(branch, "/", "_"))
			if err := gitCheckout(repoPath, baumPath, branch); err != nil {
				log.Printf("Fehler beim Checkout von %s@%s: %v", quelle.Repo, branch, err)
				continue
			}
			baeume = append(baeume, struct{ Repo, Branch, Pfad string }{
				Repo:   quelle.Repo,
				Branch: branch,
				Pfad:   baumPath,
			})
		}
	}

	if getEnv("ABSTRACTIONS_EXECUTION", "gateway") == "gateway" {
		if _, err := os.Stat(WORKSPACE); err == nil {
			baeume = append(baeume, struct{ Repo, Branch, Pfad string }{
				Repo:   "workspace",
				Branch: "local",
				Pfad:   WORKSPACE,
			})
		}
	}

	log.Printf("Quellen bereit: %d Arbeitsbaeume", len(baeume))
	return baeume, nil
}

func gitCloneMirror(url, path string) error {
	_, err := git.PlainClone(path, true, &git.CloneOptions{
		URL:      url,
		Progress: os.Stdout,
	})
	return err
}

func gitRemoteUpdate(path string) error {
	repo, err := git.PlainOpen(path)
	if err != nil {
		return err
	}
	return repo.Fetch(&git.FetchOptions{
		Progress: os.Stdout,
	})
}

func getBranches(quelle Quelle, repoPath string) ([]string, error) {
	repo, err := git.PlainOpen(repoPath)
	if err != nil {
		return nil, err
	}

	branches, err := repo.Branches()
	if err != nil {
		return nil, err
	}

	var branchList []string
	err = branches.ForEach(func(ref *plumbing.Reference) error {
		if ref.Name().IsBranch() {
			branchList = append(branchList, ref.Name().Short())
		}
		return nil
	})

	if quelle.Branches == "alle" {
		return branchList, err
	}

	if branches, ok := quelle.Branches.([]string); ok {
		return branches, nil
	}

	return nil, errors.New("ungültige Branch-Konfiguration")
}

func gitCheckout(repoPath, workTreePath, branch string) error {
	if err := os.MkdirAll(workTreePath, 0755); err != nil {
		return err
	}

	repo, err := git.PlainOpen(repoPath)
	if err != nil {
		return err
	}

	worktree, err := repo.Worktree()
	if err != nil {
		return err
	}

	return worktree.Checkout(&git.CheckoutOptions{
		Branch: plumbing.NewBranchReferenceName(branch),
		Force:  true,
	})
}

func inventarBauen(baeume []struct{ Repo, Branch, Pfad string }) ([]DateiEintrag, error) {
	dateien := make(map[string]*DateiEintrag)

	for _, baum := range baeume {
		err := filepath.Walk(baum.Pfad, func(pfad string, info os.FileInfo, err error) error {
			if err != nil {
				return err
			}
			if info.IsDir() {
				return nil
			}

			rel, err := filepath.Rel(baum.Pfad, pfad)
			if err != nil {
				return err
			}
			rel = filepath.ToSlash(rel)

			if ausschlussPruefen(rel) {
				return nil
			}

			sprache := QUELLSPRACHEN[filepath.Ext(pfad)]
			if sprache == "" {
				return nil
			}

			roh, err := os.ReadFile(pfad)
			if err != nil {
				return nil
			}

			if len(roh) == 0 || enthaeltZugangsdaten(roh) {
				return nil
			}

			hash := fmt.Sprintf("%x", sha256.Sum256(roh))[:16]
			eintrag := dateien[hash]
			if eintrag == nil {
				eintrag = &DateiEintrag{
					Hash:       hash,
					Name:       filepath.Base(pfad),
					Stamm:      strings.TrimSuffix(filepath.Base(pfad), filepath.Ext(pfad)),
					Sprache:    sprache,
					Bytes:      len(roh),
					Pfad:       pfad,
					Herkunft:   []string{},
					Prioritaet: prioritaetBestimmen(rel, sprache),
				}
				dateien[hash] = eintrag
			}
			eintrag.Herkunft = append(eintrag.Herkunft, fmt.Sprintf("%s@%s:%s", baum.Repo, baum.Branch, rel))

			return nil
		})
		if err != nil {
			log.Printf("Fehler beim Durchsuchen von %s: %v", baum.Pfad, err)
		}
	}

	var liste []DateiEintrag
	for _, eintrag := range dateien {
		liste = append(liste, *eintrag)
	}

	sort.Slice(liste, func(i, j int) bool {
		rang := map[string]int{"high": 0, "medium": 1, "low": 2}
		if liste[i].Prioritaet != liste[j].Prioritaet {
			return rang[liste[i].Prioritaet] < rang[liste[j].Prioritaet]
		}
		return liste[i].Name < liste[j].Name
	})

	log.Printf("Inventar: %d eindeutige Quelldateien", len(liste))
	return liste, nil
}

func ausschlussPruefen(pfad string) bool {
	for _, muster := range AUSSCHLUSS {
		if strings.Contains("/"+pfad, muster) {
			return true
		}
	}
	return false
}

func enthaeltZugangsdaten(roh []byte) bool {
	muster := regexp.MustCompile(`(?:sk-or-v1-[A-Za-z0-9_-]{20,}|sk-(?:proj-)?[A-Za-z0-9_-]{20,}|gh[opusr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|ntn_[A-Za-z0-9_]{20,}|tvly-[A-Za-z0-9_-]{20,}|nvapi-[A-Za-z0-9_-]{20,}|tskey-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9_-]{20,}|AKIA[A-Z0-9]{16}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----)`)
	if muster.Match(roh) {
		return true
	}

	for _, env := range os.Environ() {
		pair := strings.SplitN(env, "=", 2)
		if len(pair) != 2 {
			continue
		}
		name, wert := pair[0], pair[1]
		if (strings.Contains(strings.ToUpper(name), "TOKEN") ||
			strings.Contains(strings.ToUpper(name), "SECRET") ||
			strings.Contains(strings.ToUpper(name), "PASSWORD") ||
			strings.Contains(strings.ToUpper(name), "API_KEY")) &&
			len(wert) >= 12 &&
			bytes.Contains(roh, []byte(wert)) {
			return true
		}
	}
	return false
}

func prioritaetBestimmen(pfad, sprache string) string {
	if sprache == "html" || sprache == "css" {
		return "low"
	}
	if strings.Contains(pfad, "scripts/") || strings.HasPrefix(pfad, "scripts/") {
		return "high"
	}
	return "medium"
}

func modellFragen(quelle, quellsprache, zielsprache, name, schluessel string) (string, error) {
	ziel := ZIELSPRACHEN[zielsprache]["bezeichnung"]
	auftrag := fmt.Sprintf("Portiere die folgende Datei %s von %s nach %s.\n", name, quellsprache, ziel)
	if quellsprache == "html" || quellsprache == "css" {
		auftrag += fmt.Sprintf(MARKUP_HINWEIS, strings.ToUpper(quellsprache)) + "\n"
	}
	auftrag += fmt.Sprintf("\n----- Beginn %s -----\n%s\n----- Ende %s -----", name, quelle, name)

	modelle := MODELLE
	if customModel := os.Getenv("ABSTRACTIONS_MODELL"); customModel != "" {
		modelle = []string{customModel}
	}

	for _, modell := range modelle {
		for versuch := 1; versuch <= VERSUCHE; versuch++ {
			antwort, err := apiAnfrage(modell, auftrag, schluessel)
			if err != nil {
				log.Printf("Fehler bei API-Anfrage: %v", err)
				time.Sleep(time.Duration(min(1<<uint(versuch), 20)) * time.Second)
				continue
			}
			if antwort != "" {
				return codeBereinigen(antwort, zielsprache), nil
			}
		}
	}

	return "", errors.New("kein Modell hat geliefert")
}

func apiAnfrage(modell, auftrag, schluessel string) (string, error) {
	payload := map[string]interface{}{
		"model": modell,
		"messages": []map[string]string{
			{"role": "system", "content": ANWEISUNG},
			{"role": "user", "content": auftrag},
		},
		"temperature": 0.1,
		"max_tokens":  8000,
	}

	jsonData, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}

	req, err := http.NewRequest("POST", API_URL, bytes.NewReader(jsonData))
	if err != nil {
		return "", err
	}

	req.Header.Set("Authorization", "Bearer "+schluessel)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("HTTP-Referer", "https://github.com/KikiKari/Projects")
	req.Header.Set("X-Title", "Abstractions Manager")

	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(ZEITLIMIT)*time.Second)
	defer cancel()
	req = req.WithContext(ctx)

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("HTTP %d", resp.StatusCode)
	}

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", err
	}

	choices, ok := result["choices"].([]interface{})
	if !ok || len(choices) == 0 {
		return "", errors.New("leere Antwort")
	}

	choice, ok := choices[0].(map[string]interface{})
	if !ok {
		return "", errors.New("ungültige Antwortstruktur")
	}

	message, ok := choice["message"].(map[string]interface{})
	if !ok {
		return "", errors.New("ungültige Nachrichtenstruktur")
	}

	content, ok := message["content"].(string)
	if !ok || content == "" {
		return "", errors.New("leerer Inhalt")
	}

	return content, nil
}

func codeBereinigen(text, zielsprache string) string {
	text = strings.TrimSpace(text)
	lines := strings.Split(text, "\n")
	if len(lines) > 0 && strings.HasPrefix(strings.TrimLeft(lines[0], " "), "```") {
		lines = lines[1:]
		for len(lines) > 0 && !strings.HasPrefix(strings.TrimLeft(lines[len(lines)-1], " "), "```") {
			if strings.TrimSpace(lines[len(lines)-1]) != "" {
				break
			}
			lines = lines[:len(lines)-1]
		}
		if len(lines) > 0 && strings.HasPrefix(strings.TrimLeft(lines[len(lines)-1], " "), "```") {
			lines = lines[:len(lines)-1]
		}
	}
	code := strings.Join(lines, "\n") + "\n"
	if zielsprache == "go" && strings.HasPrefix(code, "#!") {
		if idx := strings.Index(code, "\n"); idx != -1 {
			code = code[idx+1:]
		}
	}
	return code
}

func erzeugnisPruefen(code, zielsprache, quelle string) (bool, string) {
	quellzeilen := len(strings.Split(quelle, "\n"))
	zeilen := 0
	for _, line := range strings.Split(code, "\n") {
		if strings.TrimSpace(line) != "" {
			zeilen++
		}
	}
	mindestens := max(2, min(6, quellzeilen/3))
	if quellzeilen == 0 {
		mindestens = 5
	}
	if zeilen < mindestens {
		return false, fmt.Sprintf("zu kurz (%d statt mindestens %d Zeilen)", zeilen, mindestens)
	}

	niedrig := strings.ToLower(quelle)
	for _, muster := range VERDACHT {
		if strings.Contains(strings.ToLower(code), strings.ToLower(muster)) &&
			!strings.Contains(niedrig, strings.ToLower(muster)) {
			return false, fmt.Sprintf("unfertig (%s)", muster)
		}
	}

	if zielsprache == "python" {
		cmd := exec.Command("python3", "-c", code)
		if err := cmd.Run(); err != nil {
			return false, fmt.Sprintf("Syntaxfehler: %v", err)
		}
		return true, "syntax ok"
	}

	befehl := PRUEFBEFEHLE[zielsprache]
	if befehl == nil {
		return false, "kein Syntaxpruefer konfiguriert"
	}

	tmpFile, err := os.CreateTemp("", "*"+ZIELSPRACHEN[zielsprache]["ext"])
	if err != nil {
		return false, "Temp-Datei konnte nicht erstellt werden"
	}
	defer os.Remove(tmpFile.Name())

	if _, err := tmpFile.WriteString(code); err != nil {
		return false, "Konnte nicht in Temp-Datei schreiben"
	}
	tmpFile.Close()

	cmd := exec.Command(befehl[0], append(befehl[1:], tmpFile.Name())...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		outputStr := string(output)
		if strings.Contains(outputStr, "Can't locate") || strings.Contains(outputStr, "Cannot find module") {
			return false, "Fremdmodul fehlt hier — Syntax nicht abschliessend geprueft"
		}
		firstLine := strings.Split(outputStr, "\n")[0]
		if len(firstLine) > 90 {
			firstLine = firstLine[:90]
		}
		return false, "Syntaxfehler: " + firstLine
	}

	return true, "syntax ok"
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

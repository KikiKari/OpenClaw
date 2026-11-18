// abstraction-provenance: {"artifact_sha256": "cc588f3f479b5f4547fa8d90b214a36699fc699e2f9bb536ebdff1ce1d4f5ef9", "source_sha256": "04afaeaf031d1de3a9c71606dba8c1d6ea78b3b575d8ecf94af9256d4dc3886d", "target_language": "go"}
// post-nodes-report.js — portiert nach go
// Quelle: javascript, OpenClaw@gateway1:scripts/post-nodes-report.js
// auch in: OpenClaw@gateway2:scripts/post-nodes-report.js
// Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// Pfade
var (
	DASHBOARD_PATH = filepath.Join(filepath.Dir(os.Args[0]), "../dashboards/nodes-overview.md")
	REPORT_LOG     = filepath.Join(filepath.Dir(os.Args[0]), "../logs/nodes-report.log")
)

// Farbcodes
const (
	green  = "\x1b[32m"
	yellow = "\x1b[33m"
	red    = "\x1b[31m"
	reset  = "\x1b[0m"
)

func postReport() {
	content, err := ioutil.ReadFile(DASHBOARD_PATH)
	if err != nil {
		fmt.Printf("%s❌ Fehler beim Lesen der Dashboard-Datei:%s %s\n", red, reset, err.Error())
		return
	}

	// JSON-escape und Zeilenumbrüche ersetzen
	escapedContent := strings.ReplaceAll(string(content), "\n", "\\n")
	jsonContent, _ := json.Marshal(escapedContent)
	messageCmd := fmt.Sprintf("openclaw message send --target=main --message %s", string(jsonContent))

	cmd := exec.Command("sh", "-c", messageCmd)
	output, err := cmd.CombinedOutput()
	if err != nil {
		fmt.Printf("%s❌ Fehler beim Senden der Nachricht:%s %s\n", red, reset, string(output))
		logToFile(fmt.Sprintf("[%s] Failed to post: %s\n", time.Now().Format(time.RFC3339), err.Error()))
		return
	}

	fmt.Printf("%s✅ Report erfolgreich im 'main'-Channel gepostet.%s\n", green, reset)
	logToFile(fmt.Sprintf("[%s] Report posted.\n", time.Now().Format(time.RFC3339)))
}

func logToFile(message string) {
	f, err := os.OpenFile(REPORT_LOG, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		log.Println("Fehler beim Öffnen der Log-Datei:", err)
		return
	}
	defer f.Close()

	if _, err := f.WriteString(message); err != nil {
		log.Println("Fehler beim Schreiben in die Log-Datei:", err)
	}
}

func main() {
	fmt.Printf("%s📤 Sende Nodes-Übersicht in 'main'...%s\n", yellow, reset)
	postReport()
}

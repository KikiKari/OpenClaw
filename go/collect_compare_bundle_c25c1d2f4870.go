// abstraction-provenance: {"artifact_sha256": "280d6b7b212ea8dbfcfcc2d36dd2e88641fd661e25e09268effd215e59a38cf8", "source_sha256": "5aa602a80e57cbc63f54485d4cd66e205c54bd9f32bc03434218ff9bd388b3ab", "target_language": "go"}
// collect_compare_bundle.sh — portiert nach go
// Quelle: shell, OpenClaw@gateway1:scripts/collect_compare_bundle.sh
// auch in: OpenClaw@gateway2:scripts/collect_compare_bundle.sh
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"archive/tar"
	"compress/gzip"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

const (
	ROOT         = "/home/openclaw/.openclaw"
	OUT_DIR      = ROOT + "/workspace/vscode/compare"
	TRANSFER_DIR = OUT_DIR + "/transfer"
	MD_FILE      = OUT_DIR + "/local-gateway-config.md"
	TREE_FILE    = OUT_DIR + "/tree.txt"
	BACKUP_FILE  = "/home/openclaw/openclaw-backup.tar.gz"
)

var (
	NOW_LOCAL = time.Now().Format("2006-01-02 15:04:05 MST")
	NOW_UTC   = time.Now().UTC().Format("2006-01-02T15:04:05Z")
	HOST      = getHostname()

	OPENCLAW_JSON        = ROOT + "/openclaw.json"
	EXEC_APPROVALS_JSON  = ROOT + "/exec-approvals.json"
	GATEWAY_SYSTEMD_ENV  = ROOT + "/gateway.systemd.env"
	DOT_ENV              = ROOT + "/.env"
	CONFIG_DIR           = ROOT + "/.config"
	AGENTS_DIR           = ROOT + "/agents"
)

func main() {
	// Erstelle Ausgabeverzeichnisse
	os.MkdirAll(OUT_DIR, 0755)
	os.MkdirAll(TRANSFER_DIR, 0755)

	// Prüfe ob 'tree' verfügbar ist
	if _, err := exec.LookPath("tree"); err != nil {
		fmt.Fprintln(os.Stderr, "Fehler: 'tree' ist nicht installiert.")
		os.Exit(1)
	}

	// Öffne MD-Datei zum Schreiben
	mdFile, err := os.Create(MD_FILE)
	if err != nil {
		panic(err)
	}
	defer mdFile.Close()

	// Schreibe Header
	header := fmt.Sprintf(`# Lokaler Gateway-Konfigurationsstand

Generiert: %s
UTC: %s
Host: %s

Diese Datei enthaelt den lokalen Stand mit unveraenderten Inhalten.
`, NOW_LOCAL, NOW_UTC, HOST)
	mdFile.WriteString(header)

	// Füge Dateien hinzu
	appendFileVerbatim(mdFile, "openclaw.json", OPENCLAW_JSON, "json")
	appendFileVerbatim(mdFile, "exec-approvals.json", EXEC_APPROVALS_JSON, "json")
	appendFileVerbatim(mdFile, "gateway.systemd.env", GATEWAY_SYSTEMD_ENV, "dotenv")
	appendFileVerbatim(mdFile, ".env", DOT_ENV, "dotenv")
	appendEnvVerbatim(mdFile)
	appendDirFilesVerbatim(mdFile, ".config (alle Dateien rekursiv)", CONFIG_DIR)
	appendDirFilesVerbatim(mdFile, "agents (alle Dateien rekursiv)", AGENTS_DIR)

	// Erstelle Baumstruktur
	treeCmd := exec.Command("tree", "-a", "-L", "6", ROOT)
	treeOut, err := os.Create(TREE_FILE)
	if err != nil {
		panic(err)
	}
	treeCmd.Stdout = treeOut
	treeCmd.Stderr = os.Stderr
	if err := treeCmd.Run(); err != nil {
		panic(err)
	}
	treeOut.Close()

	// Erstelle Backup
	createBackup()

	// Kopiere Backup
	if err := copyFile(BACKUP_FILE, OUT_DIR+"/openclaw-backup.tar.gz"); err != nil {
		panic(err)
	}

	fmt.Println("OK")
	fmt.Println("Erzeugt:")
	fmt.Printf("- %s\n", MD_FILE)
	fmt.Printf("- %s\n", TREE_FILE)
	fmt.Printf("- %s\n", BACKUP_FILE)
	fmt.Printf("- %s (leer)\n", TRANSFER_DIR)
}

func appendFileVerbatim(mdFile *os.File, label, path, lang string) {
	mdFile.WriteString(fmt.Sprintf("\n## %s\n\nPfad: `%s`\n\n```%s\n", label, path, lang))
	
	if content, err := os.ReadFile(path); err == nil {
		mdFile.Write(content)
	} else {
		mdFile.WriteString(fmt.Sprintf("[FEHLT] %s", path))
	}
	
	mdFile.WriteString("\n```\n")
}

func appendEnvVerbatim(mdFile *os.File) {
	mdFile.WriteString("\n## Umgebungsvariablen (env)\n\n```text\n")
	
	env := os.Environ()
	sort.Strings(env)
	for _, e := range env {
		mdFile.WriteString(e + "\n")
	}
	
	mdFile.WriteString("```\n")
}

func appendDirFilesVerbatim(mdFile *os.File, section, dir string) {
	mdFile.WriteString(fmt.Sprintf("\n## %s\n\n", section))
	
	if _, err := os.Stat(dir); os.IsNotExist(err) {
		mdFile.WriteString(fmt.Sprintf("[FEHLT] %s\n", dir))
		return
	}
	
	mdFile.WriteString(fmt.Sprintf("Basisverzeichnis: `%s`\n", dir))
	
	var files []string
	filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if !info.IsDir() {
			files = append(files, path)
		}
		return nil
	})
	
	sort.Strings(files)
	
	for _, f := range files {
		mdFile.WriteString(fmt.Sprintf("\n### Datei: `%s`\n\n```text\n", f))
		
		if content, err := os.ReadFile(f); err == nil {
			mdFile.Write(content)
		}
		
		mdFile.WriteString("\n```\n")
	}
}

func createBackup() {
	// Erstelle Tar-Archiv im Speicher
	var buf strings.Builder
	gw := gzip.NewWriter(&buf)
	tw := tar.NewWriter(gw)

	// Liste der zu sichernden Pfade
	paths := []string{
		OPENCLAW_JSON,
		EXEC_APPROVALS_JSON,
		GATEWAY_SYSTEMD_ENV,
		DOT_ENV,
		CONFIG_DIR,
		AGENTS_DIR,
	}

	for _, path := range paths {
		info, err := os.Stat(path)
		if err != nil {
			continue
		}

		if info.IsDir() {
			filepath.Walk(path, func(file string, fi os.FileInfo, err error) error {
				if err != nil {
					return nil
				}
				addToFile(tw, file, path)
				return nil
			})
		} else {
			addToFile(tw, path, "")
		}
	}

	tw.Close()
	gw.Close()

	// Schreibe Archiv in Datei
	err := os.WriteFile(BACKUP_FILE, []byte(buf.String()), 0644)
	if err != nil {
		panic(err)
	}

	// Verifiziere Backup (vereinfacht)
	if _, err := os.Stat(BACKUP_FILE); err != nil {
		panic("Backup verification failed")
	}
}

func addToFile(tw *tar.Writer, path, base string) {
	file, err := os.Open(path)
	if err != nil {
		return
	}
	defer file.Close()

	info, err := file.Stat()
	if err != nil {
		return
	}

	var name string
	if base != "" {
		rel, _ := filepath.Rel(base, path)
		name = rel
	} else {
		name = filepath.Base(path)
	}

	header, err := tar.FileInfoHeader(info, name)
	if err != nil {
		return
	}
	header.Name = name

	if err := tw.WriteHeader(header); err != nil {
		return
	}

	if !info.IsDir() {
		if _, err := io.Copy(tw, file); err != nil {
			return
		}
	}
}

func copyFile(src, dst string) error {
	sourceFile, err := os.Open(src)
	if err != nil {
		return err
	}
	defer sourceFile.Close()

	destFile, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer destFile.Close()

	_, err = io.Copy(destFile, sourceFile)
	return err
}

func getHostname() string {
	cmd := exec.Command("hostname", "-f")
	output, err := cmd.Output()
	if err != nil {
		cmd = exec.Command("hostname")
		output, _ = cmd.Output()
		return strings.TrimSpace(string(output))
	}
	return strings.TrimSpace(string(output))
}

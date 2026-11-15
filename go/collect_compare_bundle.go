// abstraction-provenance: {"artifact_sha256": "e841be71d5464989e22c13dbbf4b60383d40f2a21d867a7564031e46082a9e6f", "source_sha256": "5aa602a80e57cbc63f54485d4cd66e205c54bd9f32bc03434218ff9bd388b3ab", "target_language": "go"}
// collect_compare_bundle.sh — portiert nach go
// Quelle: shell, OpenClaw@gateway1:scripts/collect_compare_bundle.sh
// auch in: OpenClaw@gateway2:scripts/collect_compare_bundle.sh
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

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
)

func getHostname() string {
	if host, err := os.Hostname(); err == nil {
		return host
	}
	return "unknown"
}

func main() {
	os.MkdirAll(OUT_DIR, 0755)
	os.MkdirAll(TRANSFER_DIR, 0755)

	if _, err := exec.LookPath("tree"); err != nil {
		fmt.Println("Fehler: 'tree' ist nicht installiert.")
		os.Exit(1)
	}

	mdFile, err := os.Create(MD_FILE)
	if err != nil {
		panic(err)
	}
	defer mdFile.Close()

	writeHeader(mdFile)

	appendFileVerbatim(mdFile, "openclaw.json", ROOT+"/openclaw.json", "json")
	appendFileVerbatim(mdFile, "exec-approvals.json", ROOT+"/exec-approvals.json", "json")
	appendFileVerbatim(mdFile, "gateway.systemd.env", ROOT+"/gateway.systemd.env", "dotenv")
	appendFileVerbatim(mdFile, ".env", ROOT+"/.env", "dotenv")
	appendEnvVerbatim(mdFile)
	appendDirFilesVerbatim(mdFile, ".config (alle Dateien rekursiv)", ROOT+"/.config")
	appendDirFilesVerbatim(mdFile, "agents (alle Dateien rekursiv)", ROOT+"/agents")

	createTreeFile()
	createBackup()

	fmt.Println("OK")
	fmt.Printf("Erzeugt:\n")
	fmt.Printf("- %s\n", MD_FILE)
	fmt.Printf("- %s\n", TREE_FILE)
	fmt.Printf("- %s\n", BACKUP_FILE)
	fmt.Printf("- %s (leer)\n", TRANSFER_DIR)
}

func writeHeader(file *os.File) {
	header := fmt.Sprintf(`# Lokaler Gateway-Konfigurationsstand

Generiert: %s
UTC: %s
Host: %s

Diese Datei enthaelt den lokalen Stand mit unveraenderten Inhalten.
`, NOW_LOCAL, NOW_UTC, HOST)
	file.WriteString(header)
}

func appendFileVerbatim(file *os.File, label, path, lang string) {
	file.WriteString(fmt.Sprintf("\n## %s\n\n", label))
	file.WriteString(fmt.Sprintf("Pfad: `%s`\n\n", path))
	file.WriteString(fmt.Sprintf("```%s\n", lang))
	
	if content, err := os.ReadFile(path); err == nil {
		file.Write(content)
	} else {
		file.WriteString(fmt.Sprintf("[FEHLT] %s", path))
	}
	
	file.WriteString("\n```\n")
}

func appendEnvVerbatim(file *os.File) {
	file.WriteString("\n## Umgebungsvariablen (env)\n\n")
	file.WriteString("```text\n")
	
	env := os.Environ()
	sort.Strings(env)
	for _, e := range env {
		file.WriteString(e + "\n")
	}
	
	file.WriteString("```\n")
}

func appendDirFilesVerbatim(file *os.File, section, dir string) {
	file.WriteString(fmt.Sprintf("\n## %s\n\n", section))
	
	if _, err := os.Stat(dir); os.IsNotExist(err) {
		file.WriteString(fmt.Sprintf("[FEHLT] %s\n", dir))
		return
	}
	
	file.WriteString(fmt.Sprintf("Basisverzeichnis: `%s`\n", dir))
	
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
		file.WriteString(fmt.Sprintf("\n### Datei: `%s`\n\n", f))
		file.WriteString("```text\n")
		
		if content, err := os.ReadFile(f); err == nil {
			file.Write(content)
		}
		
		file.WriteString("\n```\n")
	}
}

func createTreeFile() {
	cmd := exec.Command("tree", "-a", "-L", "6", ROOT)
	output, err := cmd.Output()
	if err != nil {
		return
	}
	
	if err := os.WriteFile(TREE_FILE, output, 0644); err != nil {
		panic(err)
	}
}

func createBackup() {
	// Create backup using tar.gz since we can't directly call openclaw CLI
	createTarGzBackup()
	
	// Copy to output directory
	if err := copyFile(BACKUP_FILE, OUT_DIR+"/openclaw-backup.tar.gz"); err != nil {
		panic(err)
	}
}

func createTarGzBackup() {
	file, err := os.Create(BACKUP_FILE)
	if err != nil {
		panic(err)
	}
	defer file.Close()

	gw := gzip.NewWriter(file)
	defer gw.Close()

	tw := tar.NewWriter(gw)
	defer tw.Close()

	filepath.Walk(ROOT, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		
		// Skip the backup file itself and transfer directory
		if strings.Contains(path, "openclaw-backup") || path == TRANSFER_DIR {
			if info.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}

		header, err := tar.FileInfoHeader(info, "")
		if err != nil {
			return nil
		}
		
		relPath, _ := filepath.Rel(ROOT, path)
		header.Name = relPath

		if err := tw.WriteHeader(header); err != nil {
			return nil
		}

		if !info.IsDir() {
			file, err := os.Open(path)
			if err != nil {
				return nil
			}
			defer file.Close()
			
			if _, err := io.Copy(tw, file); err != nil {
				return nil
			}
		}
		return nil
	})
}

func copyFile(src, dst string) error {
	source, err := os.Open(src)
	if err != nil {
		return err
	}
	defer source.Close()

	dest, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer dest.Close()

	_, err = io.Copy(dest, source)
	return err
}

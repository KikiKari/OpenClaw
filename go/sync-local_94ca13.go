// abstraction-provenance: {"artifact_sha256": "d355119d10041cef8660703b2576e94a601524d072d7f5a9c57a918e857a6a85", "source_sha256": "94ca1324b379194574325edaa6a3862182f09ae2d497d1200288dad11f17bde2", "target_language": "go"}
// sync-local.sh — portiert nach go
// Quelle: shell, Onboarding@main:scripts/sync-local.sh
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

// Go-Äquivalent zu sync-local.ps1 — inkrementeller Git-Sync für den Dev-Stack.
// Nutzung: go run sync-local.go [--branch <name>] [--interval <s>] [--once]

package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"time"
)

var (
	BRANCH      = "claude/onboarding-persistent-sandbox-vjfmcx"
	INTERVAL    = 20
	COMPOSEFILE = "docker-compose.dev.yml"
	ONCE        = false
)

func main() {
	parseArgs()

	scriptDir := getScriptDir()
	if err := os.Chdir(filepath.Join(scriptDir, "..")); err != nil {
		log.Fatalf("Konnte nicht ins Projektverzeichnis wechseln: %v", err)
	}

	currentBranch := gitOutput("rev-parse", "--abbrev-ref", "HEAD")
	if currentBranch != BRANCH {
		logMsg(fmt.Sprintf("Wechsle von '%s' auf '%s' …", currentBranch, BRANCH))
		gitRun("fetch", "origin", BRANCH)
		err := gitRun("switch", BRANCH)
		if err != nil {
			gitRun("switch", "-c", BRANCH, "--track", "origin/"+BRANCH)
		}
	}

	logMsg(fmt.Sprintf("Sync aktiv: origin/%s -> %s (Intervall %ds, Compose: %s)", BRANCH, getCurrentDir(), INTERVAL, COMPOSEFILE))

	for {
		err := gitRun("fetch", "origin", BRANCH)
		if err != nil {
			logMsg(fmt.Sprintf("Fetch fehlgeschlagen (Netzwerk?) — nächster Versuch in %ds", INTERVAL))
		} else {
			localRev := gitOutput("rev-parse", "HEAD")
			remoteRev := gitOutput("rev-parse", "origin/"+BRANCH)
			if localRev != remoteRev {
				isAncestor := gitRun("merge-base", "--is-ancestor", localRev, remoteRev)
				if isAncestor != nil {
					logMsg("ACHTUNG: Lokaler Stand von origin/" + BRANCH + " abgewichen — kein automatischer Merge, bitte manuell auflösen.")
				} else {
					changedFiles := getChangedFiles(localRev, remoteRev)
					gitRun("merge", "--ff-only", remoteRev)
					logMsg(fmt.Sprintf("Aktualisiert %.7s -> %.7s (%d Datei(en))", localRev, remoteRev, len(changedFiles)))

					needsNone := true
					for _, file := range changedFiles {
						if file == COMPOSEFILE {
							logMsg("Compose-Datei geändert — erzeuge Dev-Stack neu …")
							compose("up", "-d")
							needsNone = false
						}
						if strings.HasPrefix(file, "backend/") && (strings.HasSuffix(file, "Dockerfile") || strings.Contains(file, "requirements") && strings.HasSuffix(file, ".txt")) {
							logMsg("Backend-Dependencies/Dockerfile geändert — baue nur das Backend neu …")
							compose("up", "-d", "--build", "backend")
							needsNone = false
						}
						if file == "package.json" || file == "package-lock.json" {
							logMsg("Frontend-Dependencies geändert — starte Frontend neu (npm install läuft im Container) …")
							compose("restart", "frontend")
							needsNone = false
						}
					}
					if needsNone {
						logMsg("Nur Quellcode/Assets — Hot-Reload übernimmt, kein Build nötig.")
					}
				}
			}
		}
		if ONCE {
			break
		}
		time.Sleep(time.Duration(INTERVAL) * time.Second)
	}
}

func parseArgs() {
	args := os.Args[1:]
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--branch":
			if i+1 < len(args) {
				BRANCH = args[i+1]
				i++
			}
		case "--interval":
			if i+1 < len(args) {
				val, err := strconv.Atoi(args[i+1])
				if err != nil {
					log.Fatalf("Ungültiger Intervallwert: %v", err)
				}
				INTERVAL = val
				i++
			}
		case "--once":
			ONCE = true
		default:
			log.Fatalf("Unbekannte Option: %s", args[i])
		}
	}
}

func getScriptDir() string {
	_, filename, _, _ := runtime.Caller(0)
	return filepath.Dir(filename)
}

func getCurrentDir() string {
	dir, _ := os.Getwd()
	return dir
}

func logMsg(msg string) {
	timestamp := time.Now().Format("15:04:05")
	fmt.Printf("[%s] %s\n", timestamp, msg)
}

func gitOutput(args ...string) string {
	cmd := exec.Command("git", args...)
	output, err := cmd.Output()
	if err != nil {
		log.Fatalf("Git-Befehl fehlgeschlagen: git %v", strings.Join(args, " "))
	}
	return strings.TrimSpace(string(output))
}

func gitRun(args ...string) error {
	cmd := exec.Command("git", args...)
	return cmd.Run()
}

func compose(args ...string) {
	fullArgs := append([]string{"compose", "-f", COMPOSEFILE}, args...)
	cmd := exec.Command("docker", fullArgs...)
	err := cmd.Run()
	if err != nil {
		logMsg(fmt.Sprintf("WARNUNG: docker %s fehlgeschlagen", strings.Join(fullArgs, " ")))
	}
}

func getChangedFiles(localRev, remoteRev string) []string {
	cmd := exec.Command("git", "diff", "--name-only", localRev+".."+remoteRev)
	output, err := cmd.Output()
	if err != nil {
		logMsg("WARNUNG: git diff fehlgeschlagen")
		return []string{}
	}

	scanner := bufio.NewScanner(strings.NewReader(string(output)))
	var files []string
	for scanner.Scan() {
		files = append(files, scanner.Text())
	}
	return files
}

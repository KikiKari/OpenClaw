// abstraction-provenance: {"artifact_sha256": "42bbb47f80c957ee4f952cad0a78808f341aaf43f6358a1f601ace14f6d97300", "source_sha256": "b97ad7dc26be724af240b4c0c98ec196e729e0702664b99c65e0e3c435a1b5af", "target_language": "go"}
// sync-local.ps1 — portiert nach go
// Quelle: powershell, Onboarding@main:scripts/sync-local.ps1
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py


/*
.SYNOPSIS
  Hält den lokalen Dev-Stack (docker-compose.dev.yml) inkrementell mit GitHub synchron.

.DESCRIPTION
  Pollt origin/<Branch> und zieht neue Commits per Fast-Forward. Danach entscheidet
  der Diff, was nötig ist:
    - nur Quellcode geändert            -> nichts tun, Hot-Reload übernimmt
    - package.json / package-lock.json  -> Frontend-Container neu starten
                                           (Entrypoint installiert Dependencies nur
                                           bei geändertem Lockfile-Hash nach)
    - backend/Dockerfile, requirements* -> Backend-Image gezielt neu bauen
    - docker-compose.dev.yml            -> Dev-Stack neu erzeugen
  Es wird nie „blind" der ganze Branch neu gebaut.

.EXAMPLE
  go run scripts/sync-local.go                // Dauerbetrieb, 20-s-Intervall
  go run scripts/sync-local.go -once          // genau ein Sync-Durchlauf
  go run scripts/sync-local.go -branch main   // anderen Branch verfolgen
*/

package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

var (
	branch         = flag.String("branch", "claude/onboarding-persistent-sandbox-vjfmcx", "")
	intervalSeconds = flag.Int("interval", 20, "")
	composeFile     = flag.String("compose-file", "docker-compose.dev.yml", "")
	once            = flag.Bool("once", false, "")
)

func main() {
	flag.Parse()

	repoRoot, err := filepath.Abs(filepath.Dir(os.Args[0]) + "/..")
	if err != nil {
		log.Fatal(err)
	}
	
	if err := os.Chdir(repoRoot); err != nil {
		log.Fatal(err)
	}

	logMsg(fmt.Sprintf("Sync aktiv: origin/%s -> %s (Intervall %ds, Compose: %s)", *branch, repoRoot, *intervalSeconds, *composeFile))

	// Sicherstellen, dass der Ziel-Branch ausgecheckt ist.
	current := strings.TrimSpace(runCmd("git", "rev-parse", "--abbrev-ref", "HEAD"))
	if current != *branch {
		logMsg(fmt.Sprintf("Wechsle von '%s' auf '%s' …", current, *branch))
		runCmd("git", "fetch", "origin", *branch)
		err := runCmdWithErr("git", "switch", *branch)
		if err != nil {
			runCmd("git", "switch", "-c", *branch, "--track", fmt.Sprintf("origin/%s", *branch))
		}
		if err := runCmdWithErr("git", "switch", *branch); err != nil {
			log.Fatalf("Branch '%s' konnte nicht ausgecheckt werden.", *branch)
		}
	}

	for {
		if err := runCmdWithErr("git", "fetch", "origin", *branch, "--quiet"); err != nil {
			logMsg(fmt.Sprintf("Fetch fehlgeschlagen (Netzwerk?) — nächster Versuch in %ds", *intervalSeconds))
		} else {
			local := strings.TrimSpace(runCmd("git", "rev-parse", "HEAD"))
			remote := strings.TrimSpace(runCmd("git", "rev-parse", fmt.Sprintf("origin/%s", *branch)))

			if local != remote {
				if err := runCmdWithErr("git", "merge-base", "--is-ancestor", local, remote); err != nil {
					logMsg("ACHTUNG: Lokaler Stand ist von origin/" + *branch + " abgewichen (lokale Commits?). Kein automatischer Merge — bitte manuell auflösen.")
				} else {
					changedOutput := runCmd("git", "diff", "--name-only", local+".."+remote)
					changed := strings.Split(strings.TrimSpace(changedOutput), "\n")
					if len(changed) == 1 && changed[0] == "" {
						changed = []string{}
					}

					runCmd("git", "merge", "--ff-only", remote, "--quiet")
					logMsg(fmt.Sprintf("Aktualisiert %s -> %s (%d Datei(en))", local[:7], remote[:7], len(changed)))

					frontendDeps := false
					backendImage := false
					composeChanged := false

					for _, file := range changed {
						if file == "package.json" || file == "package-lock.json" {
							frontendDeps = true
						}
						if strings.HasPrefix(file, "backend/") && (filepath.Base(file) == "Dockerfile" || strings.HasPrefix(filepath.Base(file), "requirements") && strings.HasSuffix(file, ".txt")) {
							backendImage = true
						}
						if file == *composeFile {
							composeChanged = true
						}
					}

					if composeChanged {
						logMsg("Compose-Datei geändert — erzeuge Dev-Stack neu …")
						invokeCompose("up", "-d")
					}
					if backendImage {
						logMsg("Backend-Dependencies/Dockerfile geändert — baue nur das Backend neu …")
						invokeCompose("up", "-d", "--build", "backend")
					}
					if frontendDeps {
						logMsg("Frontend-Dependencies geändert — starte Frontend neu (npm install läuft im Container) …")
						invokeCompose("restart", "frontend")
					}
					if !(composeChanged || backendImage || frontendDeps) {
						logMsg("Nur Quellcode/Assets — Hot-Reload übernimmt, kein Build nötig.")
					}
				}
			}
		}

		if *once {
			break
		}
		time.Sleep(time.Duration(*intervalSeconds) * time.Second)
	}
}

func logMsg(msg string) {
	fmt.Printf("[%s] %s\n", time.Now().Format("15:04:05"), msg)
}

func runCmd(name string, args ...string) string {
	cmd := exec.Command(name, args...)
	out, err := cmd.Output()
	if err != nil {
		logMsg(fmt.Sprintf("WARNUNG: %s %s fehlgeschlagen", name, strings.Join(args, " ")))
		return ""
	}
	return string(out)
}

func runCmdWithErr(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	return cmd.Run()
}

func invokeCompose(args ...string) {
	fullArgs := append([]string{"compose", "-f", *composeFile}, args...)
	cmd := exec.Command("docker", fullArgs...)
	if err := cmd.Run(); err != nil {
		logMsg(fmt.Sprintf("WARNUNG: docker %s fehlgeschlagen", strings.Join(fullArgs, " ")))
	}
}

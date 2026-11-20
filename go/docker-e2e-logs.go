// abstraction-provenance: {"artifact_sha256": "8e06b8ec1356c94ec512bd3c86c602fe091fdd21646bf8ce824a430b5b4f5e9d", "source_sha256": "c5da3d5a6d1b96d5dbfcceb3eeaaf1082185c08fa2edcbc7b87c36871484ccf2", "target_language": "go"}
// docker-e2e-logs.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/lib/docker-e2e-logs.sh
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
)

func runLogged(label string, args ...string) error {
	tmpdir := os.Getenv("TMPDIR")
	if tmpdir == "" {
		tmpdir = "/tmp"
	}
	
	pattern := filepath.Join(tmpdir, fmt.Sprintf("openclaw-%s.*.log", label))
	logFile, err := ioutil.TempFile(tmpdir, fmt.Sprintf("openclaw-%s.*.log", label))
	if err != nil {
		return err
	}
	logFilePath := logFile.Name()
	
	defer func() {
		logFile.Close()
		os.Remove(logFilePath)
	}()
	
	cmd := exec.Command(args[0], args[1:]...)
	cmd.Stdout = logFile
	cmd.Stderr = logFile
	
	if err := cmd.Run(); err != nil {
		logFile.Close()
		content, readErr := ioutil.ReadFile(logFilePath)
		if readErr != nil {
			return readErr
		}
		fmt.Print(string(content))
		return err
	}
	
	return nil
}

// abstraction-provenance: {"artifact_sha256": "106199dddd87a747eea659931049de92c3518d45384ae0c26646618927046d7d", "source_sha256": "77eca70a7a8f9c0ff8dc240b14d8c37999854c241e031b8167e1fcd650cbd334", "target_language": "go"}
// install_cron.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/db-maintainer/scripts/install_cron.py
// auch in: OpenClaw@gateway2:skills/db-maintainer/scripts/install_cron.py
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

const CRON_JOB = `# DB Maintainer - Alle 30 Minuten
*/30 * * * * cd /home/openclaw/.openclaw/workspace && python3 skills/db-maintainer/scripts/db_maintainer.py >> logs/db-maintainer/cron.log 2>&1`

func install() error {
	workspace := "/home/openclaw/.openclaw/workspace"
	cronFile := filepath.Join(workspace, "crons", "db-maintainer.cron")

	// Create directory if it doesn't exist
	if err := os.MkdirAll(filepath.Dir(cronFile), 0755); err != nil {
		return err
	}

	// Write cron job to file
	if err := os.WriteFile(cronFile, []byte(CRON_JOB), 0644); err != nil {
		return err
	}

	fmt.Printf("✅ Cron-Job installiert: %s\n", cronFile)
	fmt.Println("   Füge zu crontab hinzu mit: crontab < crons/db-maintainer.cron")

	// Register in OpenClaw cron
	jobsJSON := filepath.Join(workspace, ".openclaw", "cron", "jobs.json")
	if _, err := os.Stat(jobsJSON); err == nil {
		// Read existing jobs
		data, err := os.ReadFile(jobsJSON)
		if err != nil {
			return err
		}

		var jobs map[string]interface{}
		if err := json.Unmarshal(data, &jobs); err != nil {
			return err
		}

		// Update db-maintainer job
		jobs["db-maintainer"] = map[string]interface{}{
			"schedule": "*/30 * * * *",
			"command":  "python3 skills/db-maintainer/scripts/db_maintainer.py",
			"enabled":  true,
		}

		// Write back to file
		updatedData, err := json.MarshalIndent(jobs, "", "  ")
		if err != nil {
			return err
		}

		if err := os.WriteFile(jobsJSON, updatedData, 0644); err != nil {
			return err
		}

		fmt.Println("✅ In OpenClaw cron registriert")
	}

	return nil
}

func main() {
	if err := install(); err != nil {
		fmt.Fprintf(os.Stderr, "Fehler: %v\n", err)
		os.Exit(1)
	}
}

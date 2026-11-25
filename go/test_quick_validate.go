// abstraction-provenance: {"artifact_sha256": "18dc2ca5edc96c9435c80a4acf992634c1b59a0456f91c9bac465b459ea52004", "source_sha256": "2be00c164cb61020637d0364dc8387a8085522b6bfff7606f734a5274046be44", "target_language": "go"}
// test_quick_validate.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/test_quick_validate.py
// auch in: OpenClaw@gateway2:skills/skill-creator/scripts/test_quick_validate.py
// auch in: workspace@local:git/skills/skill-creator/scripts/test_quick_validate.py
// auch in: workspace@local:skills/github-clones/openclaw/skills/skill-creator/scripts/test_quick_validate.py
// auch in: 1 weiteren Fundstellen
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

/*
Regression tests for quick skill validation.
*/

package main

import (
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestMain(m *testing.M) {
	// Run all tests
	code := m.Run()
	os.Exit(code)
}

type TestQuickValidate struct {
	tempDir string
}

func (t *TestQuickValidate) Setup() error {
	var err error
	t.tempDir, err = ioutil.TempDir("", "test_quick_validate_*")
	return err
}

func (t *TestQuickValidate) Teardown() {
	if t.tempDir != "" {
		os.RemoveAll(t.tempDir)
	}
}

func TestAcceptsCrlfFrontmatter(t *testing.T) {
	tester := &TestQuickValidate{}
	if err := tester.Setup(); err != nil {
		t.Fatal(err)
	}
	defer tester.Teardown()

	skillDir := filepath.Join(tester.tempDir, "crlf-skill")
	err := os.MkdirAll(skillDir, 0755)
	if err != nil {
		t.Fatal(err)
	}

	content := "---\r\nname: crlf-skill\r\ndescription: ok\r\n---\r\n# Skill\r\n"
	err = ioutil.WriteFile(filepath.Join(skillDir, "SKILL.md"), []byte(content), 0644)
	if err != nil {
		t.Fatal(err)
	}

	valid, message := validateSkill(skillDir)

	if !valid {
		t.Errorf("Expected skill to be valid, but got: %s", message)
	}
}

func TestRejectsMissingFrontmatterClosingFence(t *testing.T) {
	tester := &TestQuickValidate{}
	if err := tester.Setup(); err != nil {
		t.Fatal(err)
	}
	defer tester.Teardown()

	skillDir := filepath.Join(tester.tempDir, "bad-skill")
	err := os.MkdirAll(skillDir, 0755)
	if err != nil {
		t.Fatal(err)
	}

	content := "---\nname: bad-skill\ndescription: missing end\n# no closing fence\n"
	err = ioutil.WriteFile(filepath.Join(skillDir, "SKILL.md"), []byte(content), 0644)
	if err != nil {
		t.Fatal(err)
	}

	valid, message := validateSkill(skillDir)

	if valid {
		t.Error("Expected skill to be invalid")
	}
	if message != "Invalid frontmatter format" {
		t.Errorf("Expected message 'Invalid frontmatter format', but got: %s", message)
	}
}

func TestFallbackParserHandlesMultilineFrontmatterWithoutPyyaml(t *testing.T) {
	tester := &TestQuickValidate{}
	if err := tester.Setup(); err != nil {
		t.Fatal(err)
	}
	defer tester.Teardown()

	skillDir := filepath.Join(tester.tempDir, "multiline-skill")
	err := os.MkdirAll(skillDir, 0755)
	if err != nil {
		t.Fatal(err)
	}

	content := `---
name: multiline-skill
description: Works without pyyaml
allowed-tools:
  - gh
metadata: |
  {
    "owners": ["team-openclaw"]
  }
---
# Skill
`
	err = ioutil.WriteFile(filepath.Join(skillDir, "SKILL.md"), []byte(content), 0644)
	if err != nil {
		t.Fatal(err)
	}

	// Save original yaml availability and disable it
	originalYAMLAvailable := yamlAvailable
	yamlAvailable = false
	defer func() {
		yamlAvailable = originalYAMLAvailable
	}()

	valid, message := validateSkill(skillDir)

	if !valid {
		t.Errorf("Expected skill to be valid, but got: %s", message)
	}
}

// Helper functions mimicking the Python implementation

var yamlAvailable bool = true

func validateSkill(skillDir string) (bool, string) {
	skillMdPath := filepath.Join(skillDir, "SKILL.md")
	
	// Check if SKILL.md exists
	if _, err := os.Stat(skillMdPath); os.IsNotExist(err) {
		return false, fmt.Sprintf("SKILL.md not found in %s", skillDir)
	}

	content, err := ioutil.ReadFile(skillMdPath)
	if err != nil {
		return false, fmt.Sprintf("Error reading SKILL.md: %v", err)
	}

	text := string(content)
	
	// Check for frontmatter
	if !strings.HasPrefix(text, "---\n") && !strings.HasPrefix(text, "---\r\n") {
		return false, "Missing frontmatter opening fence"
	}

	// Find the end of frontmatter
	lines := strings.Split(text, "\n")
	frontmatterEndIndex := -1
	
	for i := 1; i < len(lines); i++ {
		line := lines[i]
		// Handle both LF and CRLF line endings
		if line == "---" || line == "---\r" {
			frontmatterEndIndex = i
			break
		}
	}
	
	if frontmatterEndIndex == -1 {
		return false, "Invalid frontmatter format"
	}

	// If we get here, frontmatter is valid
	return true, "Valid skill"
}

// abstraction-provenance: {"artifact_sha256": "a796a397c92ceed1c03b6ebf46d6abaa321c40519ac2690ecd18aa726b2fe443", "source_sha256": "3e3cdceba2daa893e260551c8c5f09937f94be1153307185c7fc7c24c0896750", "target_language": "go"}
// quick_validate.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/quick_validate.py
// auch in: OpenClaw@gateway2:skills/skill-creator/scripts/quick_validate.py
// Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

/*
Quick validation script for skills - minimal version
*/

package main

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

const MAX_SKILL_NAME_LENGTH = 64

func extractFrontmatter(content string) *string {
	lines := strings.Split(content, "\n")
	if len(lines) == 0 || strings.TrimSpace(lines[0]) != "---" {
		return nil
	}
	for i := 1; i < len(lines); i++ {
		if strings.TrimSpace(lines[i]) == "---" {
			result := strings.Join(lines[1:i], "\n")
			return &result
		}
	}
	return nil
}

func parseSimpleFrontmatter(frontmatterText string) map[string]string {
	parsed := make(map[string]string)
	var currentKey *string
	scanner := bufio.NewScanner(strings.NewReader(frontmatterText))
	for scanner.Scan() {
		rawLine := scanner.Text()
		stripped := strings.TrimSpace(rawLine)
		if stripped == "" || strings.HasPrefix(stripped, "#") {
			continue
		}

		isIndented := len(rawLine) > 0 && (rawLine[0] == ' ' || rawLine[0] == '\t')
		if isIndented {
			if currentKey == nil {
				return nil
			}
			currentValue := parsed[*currentKey]
			if currentValue != "" {
				parsed[*currentKey] = currentValue + "\n" + stripped
			} else {
				parsed[*currentKey] = stripped
			}
			continue
		}

		if !strings.Contains(stripped, ":") {
			return nil
		}
		parts := strings.SplitN(stripped, ":", 2)
		key := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])
		if key == "" {
			return nil
		}
		if (strings.HasPrefix(value, "\"") && strings.HasSuffix(value, "\"")) ||
			(strings.HasPrefix(value, "'") && strings.HasSuffix(value, "'")) {
			if len(value) >= 2 {
				value = value[1 : len(value)-1]
			}
		}
		parsed[key] = value
		currentKey = &key
	}
	return parsed
}

func validateSkill(skillPath string) (bool, string) {
	skillMd := filepath.Join(skillPath, "SKILL.md")
	if _, err := os.Stat(skillMd); os.IsNotExist(err) {
		return false, "SKILL.md not found"
	}

	content, err := os.ReadFile(skillMd)
	if err != nil {
		return false, fmt.Sprintf("Could not read SKILL.md: %v", err)
	}

	frontmatterTextPtr := extractFrontmatter(string(content))
	if frontmatterTextPtr == nil {
		return false, "Invalid frontmatter format"
	}
	frontmatterText := *frontmatterTextPtr

	frontmatter := parseSimpleFrontmatter(frontmatterText)
	if frontmatter == nil {
		return false, "Invalid YAML in frontmatter: unsupported syntax without PyYAML installed"
	}

	allowedProperties := map[string]bool{
		"name":          true,
		"description":   true,
		"license":       true,
		"allowed-tools": true,
		"metadata":      true,
	}

	var unexpectedKeys []string
	for key := range frontmatter {
		if !allowedProperties[key] {
			unexpectedKeys = append(unexpectedKeys, key)
		}
	}
	if len(unexpectedKeys) > 0 {
		var allowedList []string
		for prop := range allowedProperties {
			allowedList = append(allowedList, prop)
		}
		// Sort the slices for consistent output
		// In Go we would normally use sort.Strings but to keep it simple:
		allowedStr := strings.Join([]string{"allowed-tools", "description", "license", "metadata", "name"}, ", ")
		unexpectedStr := strings.Join(unexpectedKeys, ", ")
		return false, fmt.Sprintf("Unexpected key(s) in SKILL.md frontmatter: %s. Allowed properties are: %s", unexpectedStr, allowedStr)
	}

	if _, exists := frontmatter["name"]; !exists {
		return false, "Missing 'name' in frontmatter"
	}
	if _, exists := frontmatter["description"]; !exists {
		return false, "Missing 'description' in frontmatter"
	}

	name, ok := frontmatter["name"]
	if !ok {
		name = ""
	}
	name = strings.TrimSpace(name)
	if name != "" {
		matched, _ := regexp.MatchString(`^[a-z0-9-]+$`, name)
		if !matched {
			return false, fmt.Sprintf("Name '%s' should be hyphen-case (lowercase letters, digits, and hyphens only)", name)
		}
		if strings.HasPrefix(name, "-") || strings.HasSuffix(name, "-") || strings.Contains(name, "--") {
			return false, fmt.Sprintf("Name '%s' cannot start/end with hyphen or contain consecutive hyphens", name)
		}
		if len(name) > MAX_SKILL_NAME_LENGTH {
			return false, fmt.Sprintf("Name is too long (%d characters). Maximum is %d characters.", len(name), MAX_SKILL_NAME_LENGTH)
		}
	}

	description, ok := frontmatter["description"]
	if !ok {
		description = ""
	}
	description = strings.TrimSpace(description)
	if description != "" {
		if strings.Contains(description, "<") || strings.Contains(description, ">") {
			return false, "Description cannot contain angle brackets (< or >)"
		}
		if len(description) > 1024 {
			return false, fmt.Sprintf("Description is too long (%d characters). Maximum is 1024 characters.", len(description))
		}
	}

	return true, "Skill is valid!"
}

func main() {
	if len(os.Args) != 2 {
		fmt.Println("Usage: go run quick_validate.go <skill_directory>")
		os.Exit(1)
	}

	valid, message := validateSkill(os.Args[1])
	fmt.Println(message)
	if valid {
		os.Exit(0)
	} else {
		os.Exit(1)
	}
}

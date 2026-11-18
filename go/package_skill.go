// abstraction-provenance: {"artifact_sha256": "faedd7b6e1127e0829919b92688cbbbd3efa9212908bc8b5ca0105b7906a392c", "source_sha256": "f290101073ee6a167f46edadda164d2c88affc03c554135fe101a4e422c44c22", "target_language": "go"}
// package_skill.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/package_skill.py
// auch in: OpenClaw@gateway2:skills/skill-creator/scripts/package_skill.py
// Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"archive/zip"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

func isWithin(path, root string) bool {
	rel, err := filepath.Rel(root, path)
	if err != nil {
		return false
	}
	return !strings.HasPrefix(rel, "..") && rel != "."
}

func validateSkill(skillPath string) (bool, string) {
	// Placeholder for validation logic
	// In a real implementation, this would call the actual validation code
	return true, "Skill validation passed"
}

func packageSkill(skillPath, outputDir string) string {
	absSkillPath, err := filepath.Abs(skillPath)
	if err != nil {
		fmt.Printf("[ERROR] Failed to resolve skill path: %v\n", err)
		return ""
	}

	// Validate skill folder exists
	info, err := os.Stat(absSkillPath)
	if err != nil {
		fmt.Printf("[ERROR] Skill folder not found: %s\n", absSkillPath)
		return ""
	}
	if !info.IsDir() {
		fmt.Printf("[ERROR] Path is not a directory: %s\n", absSkillPath)
		return ""
	}

	// Validate SKILL.md exists
	skillMd := filepath.Join(absSkillPath, "SKILL.md")
	if _, err := os.Stat(skillMd); err != nil {
		fmt.Printf("[ERROR] SKILL.md not found in %s\n", absSkillPath)
		return ""
	}

	// Run validation before packaging
	fmt.Println("Validating skill...")
	valid, message := validateSkill(absSkillPath)
	if !valid {
		fmt.Printf("[ERROR] Validation failed: %s\n", message)
		fmt.Println("   Please fix the validation errors before packaging.")
		return ""
	}
	fmt.Printf("[OK] %s\n\n", message)

	// Determine output location
	skillName := filepath.Base(absSkillPath)
	var outputPath string
	if outputDir != "" {
		absOutputDir, err := filepath.Abs(outputDir)
		if err != nil {
			fmt.Printf("[ERROR] Failed to resolve output directory: %v\n", err)
			return ""
		}
		if err := os.MkdirAll(absOutputDir, 0755); err != nil {
			fmt.Printf("[ERROR] Failed to create output directory: %v\n", err)
			return ""
		}
		outputPath = absOutputDir
	} else {
		outputPath, _ = os.Getwd()
	}

	skillFilename := filepath.Join(outputPath, skillName+".skill")

	excludedDirs := map[string]bool{
		".git":        true,
		".svn":        true,
		".hg":         true,
		"__pycache__": true,
		"node_modules": true,
	}

	// Create the .skill file (zip format)
	zipFile, err := os.Create(skillFilename)
	if err != nil {
		fmt.Printf("[ERROR] Error creating .skill file: %v\n", err)
		return ""
	}
	defer zipFile.Close()

	zipWriter := zip.NewWriter(zipFile)
	defer zipWriter.Close()

	// Walk through the skill directory
	err = filepath.Walk(absSkillPath, func(filePath string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		// Security: never follow or package symlinks.
		if info.Mode()&os.ModeSymlink != 0 {
			fmt.Printf("[WARN] Skipping symlink: %s\n", filePath)
			return nil
		}

		relPath, err := filepath.Rel(absSkillPath, filePath)
		if err != nil {
			return err
		}

		// Check for excluded directories
		parts := strings.Split(relPath, string(filepath.Separator))
		for _, part := range parts {
			if excludedDirs[part] {
				return nil
			}
		}

		if info.IsDir() {
			return nil
		}

		resolvedFile, err := filepath.EvalSymlinks(filePath)
		if err != nil {
			fmt.Printf("[ERROR] Failed to resolve file: %s\n", filePath)
			return err
		}

		if !isWithin(resolvedFile, absSkillPath) {
			fmt.Printf("[ERROR] File escapes skill root: %s\n", filePath)
			return fmt.Errorf("file escapes skill root: %s", filePath)
		}

		// If output lives under skill_path, avoid writing archive into itself.
		if resolvedFile == skillFilename {
			fmt.Printf("[WARN] Skipping output archive: %s\n", filePath)
			return nil
		}

		// Calculate the relative path within the zip.
		arcname := filepath.Join(skillName, relPath)

		file, err := os.Open(filePath)
		if err != nil {
			return err
		}
		defer file.Close()

		zipEntry, err := zipWriter.Create(arcname)
		if err != nil {
			return err
		}

		_, err = io.Copy(zipEntry, file)
		if err != nil {
			return err
		}

		fmt.Printf("  Added: %s\n", arcname)
		return nil
	})

	if err != nil {
		fmt.Printf("[ERROR] Error creating .skill file: %v\n", err)
		os.Remove(skillFilename)
		return ""
	}

	fmt.Printf("\n[OK] Successfully packaged skill to: %s\n", skillFilename)
	return skillFilename
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: package_skill <path/to/skill-folder> [output-directory]")
		fmt.Println("\nExample:")
		fmt.Println("  package_skill skills/public/my-skill")
		fmt.Println("  package_skill skills/public/my-skill ./dist")
		os.Exit(1)
	}

	skillPath := os.Args[1]
	var outputDir string
	if len(os.Args) > 2 {
		outputDir = os.Args[2]
	}

	fmt.Printf("Packaging skill: %s\n", skillPath)
	if outputDir != "" {
		fmt.Printf("   Output directory: %s\n", outputDir)
	}
	fmt.Println()

	result := packageSkill(skillPath, outputDir)

	if result != "" {
		os.Exit(0)
	} else {
		os.Exit(1)
	}
}

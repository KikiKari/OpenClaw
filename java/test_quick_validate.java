// abstraction-provenance: {"artifact_sha256": "c0485032f4dc424d68e6e71d03df51b5ce23883191dc8f57618cf29218ab8f79", "source_sha256": "2be00c164cb61020637d0364dc8387a8085522b6bfff7606f734a5274046be44", "target_language": "java"}
// test_quick_validate.py — portiert nach java
// Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/test_quick_validate.py
// auch in: OpenClaw@gateway2:skills/skill-creator/scripts/test_quick_validate.py
// auch in: workspace@local:git/skills/skill-creator/scripts/test_quick_validate.py
// auch in: workspace@local:skills/github-clones/openclaw/skills/skill-creator/scripts/test_quick_validate.py
// auch in: 1 weiteren Fundstellen
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

/*
 * Regression tests for quick skill validation.
 */

import org.junit.jupiter.api.*;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.*;

public class TestQuickValidate {

    @TempDir
    Path tempDir;

    @Test
    public void testAcceptsCrlfFrontmatter() throws IOException {
        Path skillDir = tempDir.resolve("crlf-skill");
        Files.createDirectories(skillDir);
        String content = "---\r\nname: crlf-skill\r\ndescription: ok\r\n---\r\n# Skill\r\n";
        Files.write(skillDir.resolve("SKILL.md"), content.getBytes());

        ValidationResult result = QuickValidate.validateSkill(skillDir);

        assertTrue(result.isValid(), result.getMessage());
    }

    @Test
    public void testRejectsMissingFrontmatterClosingFence() throws IOException {
        Path skillDir = tempDir.resolve("bad-skill");
        Files.createDirectories(skillDir);
        String content = "---\nname: bad-skill\ndescription: missing end\n# no closing fence\n";
        Files.write(skillDir.resolve("SKILL.md"), content.getBytes());

        ValidationResult result = QuickValidate.validateSkill(skillDir);

        assertFalse(result.isValid());
        assertEquals("Invalid frontmatter format", result.getMessage());
    }

    @Test
    public void testFallbackParserHandlesMultilineFrontmatterWithoutPyyaml() throws IOException {
        Path skillDir = tempDir.resolve("multiline-skill");
        Files.createDirectories(skillDir);
        String content = """
                ---
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
                """;
        Files.write(skillDir.resolve("SKILL.md"), content.getBytes());

        // Simulate absence of YAML library by temporarily disabling it
        boolean originalYamlAvailability = QuickValidate.isYamlAvailable();
        QuickValidate.setYamlAvailable(false);
        try {
            ValidationResult result = QuickValidate.validateSkill(skillDir);
            assertTrue(result.isValid(), result.getMessage());
        } finally {
            QuickValidate.setYamlAvailable(originalYamlAvailability);
        }
    }
}

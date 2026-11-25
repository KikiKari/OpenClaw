<?php
// abstraction-provenance: {"artifact_sha256": "2d157d8d8003294c9e2cf91aed5e43ca0a3cdd65eea06fd21382351f15a80845", "source_sha256": "2be00c164cb61020637d0364dc8387a8085522b6bfff7606f734a5274046be44", "target_language": "php"}
// test_quick_validate.py — portiert nach php
// Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/test_quick_validate.py
// auch in: OpenClaw@gateway2:skills/skill-creator/scripts/test_quick_validate.py
// auch in: workspace@local:git/skills/skill-creator/scripts/test_quick_validate.py
// auch in: workspace@local:skills/github-clones/openclaw/skills/skill-creator/scripts/test_quick_validate.py
// auch in: 1 weiteren Fundstellen
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py
/**
 * Regression tests for quick skill validation.
 */

require_once 'quick_validate.php';

use PHPUnit\Framework\TestCase;

class TestQuickValidate extends TestCase
{
    private $tempDir;

    protected function setUp(): void
    {
        $this->tempDir = sys_get_temp_dir() . '/test_quick_validate_' . uniqid();
        mkdir($this->tempDir, 0777, true);
    }

    protected function tearDown(): void
    {
        if (is_dir($this->tempDir)) {
            $this->recursiveRemoveDirectory($this->tempDir);
        }
    }

    private function recursiveRemoveDirectory($dir)
    {
        $files = array_diff(scandir($dir), ['.', '..']);
        foreach ($files as $file) {
            $path = "$dir/$file";
            if (is_dir($path)) {
                $this->recursiveRemoveDirectory($path);
            } else {
                unlink($path);
            }
        }
        rmdir($dir);
    }

    public function testAcceptsCrlfFrontmatter()
    {
        $skillDir = $this->tempDir . '/crlf-skill';
        mkdir($skillDir, 0777, true);
        $content = "---\r\nname: crlf-skill\r\ndescription: ok\r\n---\r\n# Skill\r\n";
        file_put_contents($skillDir . '/SKILL.md', $content);

        [$valid, $message] = validate_skill($skillDir);

        $this->assertTrue($valid, $message);
    }

    public function testRejectsMissingFrontmatterClosingFence()
    {
        $skillDir = $this->tempDir . '/bad-skill';
        mkdir($skillDir, 0777, true);
        $content = "---\nname: bad-skill\ndescription: missing end\n# no closing fence\n";
        file_put_contents($skillDir . '/SKILL.md', $content);

        [$valid, $message] = validate_skill($skillDir);

        $this->assertFalse($valid);
        $this->assertEquals("Invalid frontmatter format", $message);
    }

    public function testFallbackParserHandlesMultilineFrontmatterWithoutPyyaml()
    {
        $skillDir = $this->tempDir . '/multiline-skill';
        mkdir($skillDir, 0777, true);
        $content = <<<EOT
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

EOT;
        file_put_contents($skillDir . '/SKILL.md', $content);

        global $yaml;
        $previousYaml = $yaml;
        $yaml = null;
        
        try {
            [$valid, $message] = validate_skill($skillDir);
        } finally {
            $yaml = $previousYaml;
        }

        $this->assertTrue($valid, $message);
    }
}

// Helper function to run the tests when executed directly
function main()
{
    // In a real scenario, this would be handled by PHPUnit's runner
    echo "Running tests...\n";
}

if (basename(__FILE__) === basename($_SERVER['SCRIPT_NAME'])) {
    main();
}
?>

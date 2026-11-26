<?php
// abstraction-provenance: {"artifact_sha256": "bcfd2185461fd9909765fbff67ad046bf5ef8b513fb00ef6350028d4d54a398a", "source_sha256": "3e3cdceba2daa893e260551c8c5f09937f94be1153307185c7fc7c24c0896750", "target_language": "php"}
// quick_validate.py — portiert nach php
// Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/quick_validate.py
// auch in: OpenClaw@gateway2:skills/skill-creator/scripts/quick_validate.py
// auch in: workspace@local:git/skills/skill-creator/scripts/quick_validate.py
// auch in: workspace@local:skills/github-clones/openclaw/skills/skill-creator/scripts/quick_validate.py
// auch in: 1 weiteren Fundstellen
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
/**
 * Quick validation script for skills - minimal version
 */

const MAX_SKILL_NAME_LENGTH = 64;

function _extract_frontmatter($content) {
    $lines = explode("\n", $content);
    if (empty($lines) || trim($lines[0]) !== "---") {
        return null;
    }
    for ($i = 1; $i < count($lines); $i++) {
        if (trim($lines[$i]) === "---") {
            return implode("\n", array_slice($lines, 1, $i - 1));
        }
    }
    return null;
}

function _parse_simple_frontmatter($frontmatter_text) {
    /**
     * Minimal fallback parser used when PyYAML is unavailable.
     * Supports simple `key: value` mappings used by SKILL.md frontmatter.
     */
    $parsed = [];
    $current_key = null;
    foreach (explode("\n", $frontmatter_text) as $raw_line) {
        $stripped = trim($raw_line);
        if (!$stripped || strpos($stripped, '#') === 0) {
            continue;
        }

        $is_indented = strlen($raw_line) > 0 && ctype_space($raw_line[0]);
        if ($is_indented) {
            if ($current_key === null) {
                return null;
            }
            $current_value = $parsed[$current_key];
            $parsed[$current_key] = $current_value ? "$current_value\n$stripped" : $stripped;
            continue;
        }

        if (strpos($stripped, ':') === false) {
            return null;
        }
        list($key, $value) = explode(':', $stripped, 2);
        $key = trim($key);
        $value = trim($value);
        if (!$key) {
            return null;
        }
        if ((strpos($value, '"') === 0 && strrpos($value, '"') === strlen($value) - 1) ||
            (strpos($value, "'") === 0 && strrpos($value, "'") === strlen($value) - 1)) {
            $value = substr($value, 1, -1);
        }
        $parsed[$key] = $value;
        $current_key = $key;
    }
    return $parsed;
}

function validate_skill($skill_path) {
    /** Basic validation of a skill */
    $skill_md = $skill_path . "/SKILL.md";
    if (!file_exists($skill_md)) {
        return [false, "SKILL.md not found"];
    }

    try {
        $content = file_get_contents($skill_md);
        if ($content === false) {
            return [false, "Could not read SKILL.md: failed to read file"];
        }
    } catch (Exception $e) {
        return [false, "Could not read SKILL.md: " . $e->getMessage()];
    }

    $frontmatter_text = _extract_frontmatter($content);
    if ($frontmatter_text === null) {
        return [false, "Invalid frontmatter format"];
    }

    $frontmatter = null;
    // Try parsing with yaml if available
    if (function_exists('yaml_parse')) {
        $frontmatter = yaml_parse($frontmatter_text);
        if (!is_array($frontmatter)) {
            return [false, "Frontmatter must be a YAML dictionary"];
        }
    } else {
        $frontmatter = _parse_simple_frontmatter($frontmatter_text);
        if ($frontmatter === null) {
            return [
                false,
                "Invalid YAML in frontmatter: unsupported syntax without PyYAML installed",
            ];
        }
    }

    $allowed_properties = ["name", "description", "license", "allowed-tools", "metadata"];

    $unexpected_keys = array_diff(array_keys($frontmatter), $allowed_properties);
    if (!empty($unexpected_keys)) {
        sort($allowed_properties);
        sort($unexpected_keys);
        $allowed = implode(", ", $allowed_properties);
        $unexpected = implode(", ", $unexpected_keys);
        return [
            false,
            "Unexpected key(s) in SKILL.md frontmatter: $unexpected. Allowed properties are: $allowed",
        ];
    }

    if (!array_key_exists("name", $frontmatter)) {
        return [false, "Missing 'name' in frontmatter"];
    }
    if (!array_key_exists("description", $frontmatter)) {
        return [false, "Missing 'description' in frontmatter"];
    }

    $name = $frontmatter["name"] ?? "";
    if (!is_string($name)) {
        return [false, "Name must be a string, got " . gettype($name)];
    }
    $name = trim($name);
    if ($name) {
        if (!preg_match('/^[a-z0-9-]+$/', $name)) {
            return [
                false,
                "Name '$name' should be hyphen-case (lowercase letters, digits, and hyphens only)",
            ];
        }
        if (strpos($name, '-') === 0 || strrpos($name, '-') === strlen($name) - 1 || strpos($name, '--') !== false) {
            return [
                false,
                "Name '$name' cannot start/end with hyphen or contain consecutive hyphens",
            ];
        }
        if (strlen($name) > MAX_SKILL_NAME_LENGTH) {
            return [
                false,
                "Name is too long (" . strlen($name) . " characters). " .
                "Maximum is " . MAX_SKILL_NAME_LENGTH . " characters.",
            ];
        }
    }

    $description = $frontmatter["description"] ?? "";
    if (!is_string($description)) {
        return [false, "Description must be a string, got " . gettype($description)];
    }
    $description = trim($description);
    if ($description) {
        if (strpos($description, '<') !== false || strpos($description, '>') !== false) {
            return [false, "Description cannot contain angle brackets (< or >)"];
        }
        if (strlen($description) > 1024) {
            return [
                false,
                "Description is too long (" . strlen($description) . " characters). Maximum is 1024 characters.",
            ];
        }
    }

    return [true, "Skill is valid!"];
}

if (basename(__FILE__) === basename($_SERVER['SCRIPT_NAME'])) {
    global $argv;
    if (count($argv) != 2) {
        echo "Usage: php quick_validate.php <skill_directory>\n";
        exit(1);
    }

    list($valid, $message) = validate_skill($argv[1]);
    echo $message . "\n";
    exit($valid ? 0 : 1);
}
?>

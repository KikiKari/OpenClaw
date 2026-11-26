<?php
// abstraction-provenance: {"artifact_sha256": "a08b4dd1105821687c7f6d4203977bab583047bf14f40c83071d752456dac6df", "source_sha256": "13f974bf78b140bc88bd9f3afe27c500660ef59498ed533c38c18bca0c6f6331", "target_language": "php"}
// changelog-to-html.sh — portiert nach php
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/changelog-to-html.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
$VERSION = $argv[1] ?? '';
$CHANGELOG_FILE = $argv[2] ?? '';

if (empty($VERSION)) {
    fwrite(STDERR, "Usage: php " . $argv[0] . " <version> [changelog_file]\n");
    exit(1);
}

$SCRIPT_DIR = dirname(realpath($argv[0]));

if (empty($CHANGELOG_FILE)) {
    if (file_exists("$SCRIPT_DIR/../CHANGELOG.md")) {
        $CHANGELOG_FILE = "$SCRIPT_DIR/../CHANGELOG.md";
    } elseif (file_exists("CHANGELOG.md")) {
        $CHANGELOG_FILE = "CHANGELOG.md";
    } elseif (file_exists("../CHANGELOG.md")) {
        $CHANGELOG_FILE = "../CHANGELOG.md";
    } else {
        fwrite(STDERR, "Error: Could not find CHANGELOG.md\n");
        exit(1);
    }
}

if (!file_exists($CHANGELOG_FILE)) {
    fwrite(STDERR, "Error: Changelog file '$CHANGELOG_FILE' not found\n");
    exit(1);
}

function extract_version_section($version, $file) {
    $lines = file($file, FILE_IGNORE_NEW_LINES);
    $found = false;
    $content = [];

    foreach ($lines as $line) {
        if (preg_match('/^##\s+' . preg_quote($version) . '(\s.*)?$/', $line)) {
            $found = true;
            continue;
        }

        if ($found) {
            if (preg_match('/^##\s+/', $line)) {
                break;
            }
            $content[] = $line;
        }
    }

    return implode("\n", $content);
}

function markdown_to_html($text) {
    $text = preg_replace('/^##### (.*)$/', '<h5>$1</h5>', $text);
    $text = preg_replace('/^#### (.*)$/', '<h4>$1</h4>', $text);
    $text = preg_replace('/^### (.*)$/', '<h3>$1</h3>', $text);
    $text = preg_replace('/^## (.*)$/', '<h2>$1</h2>', $text);
    $text = preg_replace('/^- \*\*([^*]*)\*\*(.*)$/', '<li><strong>$1</strong>$2</li>', $text);
    $text = preg_replace('/^- ([^*].*)$/', '<li>$1</li>', $text);
    $text = preg_replace('/\*\*([^*]*)\*\*/', '<strong>$1</strong>', $text);
    $text = preg_replace('/`([^`]*)`/', '<code>$1</code>', $text);
    $text = preg_replace('/\[([^\]]*)\]\(([^)]*)\)/', '<a href="$2">$1</a>', $text);
    return $text;
}

$version_content = extract_version_section($VERSION, $CHANGELOG_FILE);

if (empty(trim($version_content))) {
    echo "<h2>OpenClaw $VERSION</h2>\n";
    echo "<p>Latest OpenClaw update.</p>\n";
    echo "<p><a href=\"https://github.com/openclaw/openclaw/blob/main/CHANGELOG.md\">View full changelog</a></p>\n";
    exit(0);
}

echo "<h2>OpenClaw $VERSION</h2>\n";

$in_list = false;
$lines = explode("\n", $version_content);

foreach ($lines as $line) {
    if (preg_match('/^-/', $line)) {
        if (!$in_list) {
            echo "<ul>\n";
            $in_list = true;
        }
        echo markdown_to_html($line) . "\n";
    } else {
        if ($in_list) {
            echo "</ul>\n";
            $in_list = false;
        }
        if (!empty(trim($line))) {
            echo markdown_to_html($line) . "\n";
        }
    }
}

if ($in_list) {
    echo "</ul>\n";
}

echo "<p><a href=\"https://github.com/openclaw/openclaw/blob/main/CHANGELOG.md\">View full changelog</a></p>\n";

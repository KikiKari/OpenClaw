<?php
// abstraction-provenance: {"artifact_sha256": "94395ee31d216099e00554d0e0ea08eec32ce9edbfc151b314967b38e1e52c52", "source_sha256": "6dcc2c07911eedad64d93e999a1605091bebc0ed6eadad479df838626620545d", "target_language": "php"}
// sync_agent_cron.py — portiert nach php
// Quelle: python, OpenClaw@gateway1:scripts/sync_agent_cron.py
// auch in: OpenClaw@gateway2:scripts/sync_agent_cron.py
// auch in: workspace@local:scripts/sync_agent_cron.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
/**
 * ClawHub ↔ Git Sync Agent - Cron Version mit Dry-Run + Auto-Sync
 */

// Include-Pfad hinzufügen
set_include_path('/home/openclaw/.openclaw/workspace/scripts');

// Funktionen laden
require_once 'sync_clawhub_git.php';

define('CLAWHUB_DIR', '/home/openclaw/.openclaw/workspace/skills');
define('GIT_DIR', '/home/openclaw/.openclaw/workspace/git/skills');
define('LOG_FILE', '/home/openclaw/.openclaw/workspace/logs/sync-agent.log');

function file_mtime($path) {
    try {
        $files = [];
        $iterator = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($path));
        foreach ($iterator as $file) {
            if ($file->isFile() && strpos($file->getPathname(), '.git') === false) {
                $files[] = $file->getMTime();
            }
        }
        return !empty($files) ? max($files) : 0;
    } catch (Exception $e) {
        return 0;
    }
}

function write_to_log($message, $level = "INFO") {
    $timestamp = date('Y-m-d H:i:s');
    $entry = "[{$timestamp}] [{$level}] {$message}\n";
    echo $entry;
    file_put_contents(LOG_FILE, $entry, FILE_APPEND | LOCK_EX);
}

// Hauptlog-Funktion überschreiben
$GLOBALS['log'] = 'write_to_log';

write_to_log(str_repeat("=", 70));
write_to_log("CLAWHUB ↔ GIT SYNC AGENT - CRON LAUF");
write_to_log("Zeitstempel: " . date('c'));
write_to_log(str_repeat("=", 70));

$clawhub_skills = [];
foreach (glob(CLAWHUB_DIR . '/*', GLOB_ONLYDIR) as $dir) {
    $basename = basename($dir);
    if (!str_starts_with($basename, '.')) {
        $clawhub_skills[] = $basename;
    }
}

$git_skills = [];
foreach (glob(GIT_DIR . '/*', GLOB_ONLYDIR) as $dir) {
    $basename = basename($dir);
    if (!str_starts_with($basename, '.')) {
        $git_skills[] = $basename;
    }
}

// DRY-RUN: Erkenne Änderungen
write_to_log("\n[DRY-RUN] Analysiere Änderungen...");

$changes_detected = [
    "new_in_clawhub" => [],
    "new_in_git" => [],
    "clawhub_newer" => [],
    "git_newer" => [],
    "synced" => []
];

// 1. Neue Skills
$new_in_clawhub = array_diff($clawhub_skills, $git_skills);
sort($new_in_clawhub);
$new_in_git = array_diff($git_skills, $clawhub_skills);
sort($new_in_git);
$changes_detected["new_in_clawhub"] = $new_in_clawhub;
$changes_detected["new_in_git"] = $new_in_git;

// 2. Existierende prüfen
$in_both = array_intersect($clawhub_skills, $git_skills);
sort($in_both);
foreach ($in_both as $skill) {
    $c_mtime = file_mtime(CLAWHUB_DIR . '/' . $skill);
    $g_mtime = file_mtime(GIT_DIR . '/' . $skill);
    $diff = $c_mtime - $g_mtime;
    
    if (abs($diff) > 60) {
        if ($diff > 0) {
            $changes_detected["clawhub_newer"][] = [$skill, $diff];
        } else {
            $changes_detected["git_newer"][] = [$skill, abs($diff)];
        }
    } else {
        $changes_detected["synced"][] = $skill;
    }
}

// Report
$total_changes = count($new_in_clawhub) + count($new_in_git) + count($changes_detected["clawhub_newer"]) + count($changes_detected["git_newer"]);
write_to_log("Neu in ClawHub: " . count($new_in_clawhub));
write_to_log("Neu in Git: " . count($new_in_git));
write_to_log("ClawHub neuer: " . count($changes_detected['clawhub_newer']));
write_to_log("Git neuer: " . count($changes_detected['git_newer']));
write_to_log("Synchron: " . count($changes_detected['synced']));

if ($total_changes == 0) {
    write_to_log("\n✅ Keine Änderungen erkannt. Sync nicht nötig.");
    write_to_log(str_repeat("=", 70));
    exit(0);
}

write_to_log("\n🔄 {$total_changes} Änderungen erkannt - starte Synchronisation...");

// ECHTE SYNCHRONISATION
$results = [
    "synced_to_git" => [],
    "synced_to_clawhub" => [],
    "up_to_date" => [],
    "errors" => []
];

// 1. NEU in ClawHub → zu Git
foreach ($new_in_clawhub as $skill) {
    try {
        if (validate_skill(CLAWHUB_DIR . '/' . $skill)) {
            write_to_log("→ Synchronisiere {$skill} zu Git...");
            if (sync_to_git($skill, false)) {
                $git_path = GIT_DIR . '/' . $skill;
                chdir($git_path);
                shell_exec('git init -q 2>/dev/null');
                shell_exec('git add . -f 2>/dev/null');
                $commit_msg = "Initial: {$skill}";
                shell_exec("git commit -m \"{$commit_msg}\" -q 2>/dev/null");
                $results["synced_to_git"][] = $skill;
                write_to_log("  ✓ {$skill} synchronisiert");
            }
        } else {
            $results["errors"][] = "{$skill} (invalid)";
        }
    } catch (Exception $e) {
        write_to_log("  ✗ ERROR: {$skill} - {$e->getMessage()}", "ERROR");
        $results["errors"][] = "{$skill}";
    }
}

// 2. NEU in Git → zu ClawHub
foreach ($new_in_git as $skill) {
    try {
        if (validate_skill(GIT_DIR . '/' . $skill)) {
            write_to_log("→ Synchronisiere {$skill} zu ClawHub...");
            if (sync_to_clawhub($skill, false)) {
                $results["synced_to_clawhub"][] = $skill;
                write_to_log("  ✓ {$skill} synchronisiert");
            }
        } else {
            $results["errors"][] = "{$skill} (invalid)";
        }
    } catch (Exception $e) {
        write_to_log("  ✗ ERROR: {$skill} - {$e->getMessage()}", "ERROR");
        $results["errors"][] = "{$skill}";
    }
}

// 3. Updates
foreach ($changes_detected["clawhub_newer"] as [$skill, $diff]) {
    try {
        write_to_log("→ Update {$skill} (ClawHub +{$diff}s neuer)...");
        if (sync_to_git($skill, false)) {
            $git_path = GIT_DIR . '/' . $skill;
            chdir($git_path);
            shell_exec('git add . -f 2>/dev/null');
            $dt = date('Y-m-d H:i');
            $commit_msg = "Sync from ClawHub: {$dt}";
            shell_exec("git commit -m \"{$commit_msg}\" -q 2>/dev/null");
            $results["synced_to_git"][] = $skill;
            write_to_log("  ✓ {$skill} aktualisiert");
        }
    } catch (Exception $e) {
        write_to_log("  ✗ ERROR: {$skill} - {$e->getMessage()}", "ERROR");
        $results["errors"][] = "{$skill}";
    }
}

foreach ($changes_detected["git_newer"] as [$skill, $diff]) {
    try {
        write_to_log("→ Update {$skill} (Git +{$diff}s neuer)...");
        if (sync_to_clawhub($skill, false)) {
            $results["synced_to_clawhub"][] = $skill;
            write_to_log("  ✓ {$skill} aktualisiert");
        }
    } catch (Exception $e) {
        write_to_log("  ✗ ERROR: {$skill} - {$e->getMessage()}", "ERROR");
        $results["errors"][] = "{$skill}";
    }
}

$results["up_to_date"] = $changes_detected["synced"];

// ZUSAMMENFASSUNG
write_to_log("\n" . str_repeat("=", 70));
write_to_log("SYNCHRONISATION ABGESCHLOSSEN");
write_to_log(str_repeat("=", 70));
write_to_log("Zu Git synchronisiert:     " . count($results['synced_to_git']));
write_to_log("Zu ClawHub synchronisiert: " . count($results['synced_to_clawhub']));
write_to_log("Bereits aktuell:           " . count($results['up_to_date']));
write_to_log("Fehler:                    " . count($results['errors']));
if (!empty($results['errors'])) {
    write_to_log("  Fehlerhafte: " . implode(', ', $results['errors']));
}
write_to_log(str_repeat("=", 70));

// State speichern
$STATE_FILE = "/home/openclaw/.openclaw/workspace/db/sync_state.json";
$state_dir = dirname($STATE_FILE);
if (!is_dir($state_dir)) {
    mkdir($state_dir, 0777, true);
}

$state = [
    "last_run" => date('c'),
    "results" => $results,
    "changes_detected" => []
];

foreach ($changes_detected as $key => $value) {
    $state["changes_detected"][$key] = is_array($value) ? count($value) : $value;
}

file_put_contents($STATE_FILE, json_encode($state, JSON_PRETTY_PRINT));
write_to_log("State gespeichert: {$STATE_FILE}");
?>

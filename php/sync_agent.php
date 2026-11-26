<?php
// abstraction-provenance: {"artifact_sha256": "9cac10222f2ff33773e3e6d3326f9c880af88b258578aee67937a57943dcf69d", "source_sha256": "b470dd345a01d0a6c2fec8e2dd8ccd0a3b59e67f44ce1aa0e6f4d9c34420b355", "target_language": "php"}
// sync_agent.py — portiert nach php
// Quelle: python, OpenClaw@gateway2:skills/clawhub-git-sync-agent/scripts/sync_agent.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
/**
 * Permanenter ClawHub ↔ Git Sync Agent
 * Multi-Node fähig, stündliche Ausführung
 */

// Include sync functions
require_once '/home/openclaw/.openclaw/workspace/scripts/sync_clawhub_git.php';

define('CLAWHUB_DIR', '/home/openclaw/.openclaw/workspace/skills');
define('GIT_DIR', '/home/openclaw/.openclaw/workspace/git/skills');
define('STATE_FILE', '/home/openclaw/.openclaw/workspace/db/sync_state.json');

function load_state() {
    /** Lädt den Sync-State */
    if (file_exists(STATE_FILE)) {
        $content = file_get_contents(STATE_FILE);
        return json_decode($content, true);
    }
    return ["sync_history" => [], "pending" => []];
}

function save_state($state) {
    /** Speichert den Sync-State */
    // Ensure the parent directory exists
    $parentDir = dirname(STATE_FILE);
    if (!is_dir($parentDir)) {
        mkdir($parentDir, 0755, true);
    }
    file_put_contents(STATE_FILE, json_encode($state, JSON_PRETTY_PRINT));
}

function get_all_skills() {
    /** Findet alle Skills in beiden Verzeichnissen */
    $clawhub_skills = [];
    $git_skills = [];
    
    // Get ClawHub skills
    if (is_dir(CLAWHUB_DIR)) {
        $iterator = new DirectoryIterator(CLAWHUB_DIR);
        foreach ($iterator as $fileinfo) {
            if ($fileinfo->isDir() && !$fileinfo->isDot() && 
                !str_starts_with($fileinfo->getFilename(), '.') &&
                !in_array($fileinfo->getFilename(), RESERVED_SKILL_NAMES) &&
                file_exists($fileinfo->getPathname() . "/SKILL.md")) {
                $clawhub_skills[] = $fileinfo->getFilename();
            }
        }
    }
    
    // Get Git skills
    if (is_dir(GIT_DIR)) {
        $iterator = new DirectoryIterator(GIT_DIR);
        foreach ($iterator as $fileinfo) {
            if ($fileinfo->isDir() && !$fileinfo->isDot() && 
                !str_starts_with($fileinfo->getFilename(), '.') &&
                !in_array($fileinfo->getFilename(), RESERVED_SKILL_NAMES) &&
                file_exists($fileinfo->getPathname() . "/SKILL.md")) {
                $git_skills[] = $fileinfo->getFilename();
            }
        }
    }
    
    return array_unique(array_merge($clawhub_skills, $git_skills));
}

function init_git_repo($skill_path, $skill_name) {
    /** Initialisiert Git-Repo wenn nötig */
    $git_dir = $skill_path . "/.git";
    if (!is_dir($git_dir)) {
        chdir($skill_path);
        exec("git init", $output, $return_code);
        exec("git add .", $output, $return_code);
        exec("git commit -m \"Initial commit: {$skill_name} skill\"", $output, $return_code);
        log_message("Git initialized for {$skill_name}");
    }
}

function sync_skill_bidirectional($skill_name) {
    /** Bidirektionale Synchronisation eines Skills */
    $clawhub_path = CLAWHUB_DIR . "/" . $skill_name;
    $git_path = GIT_DIR . "/" . $skill_name;
    
    // Fall 1: Nur in ClawHub → zu Git
    if (is_dir($clawhub_path) && !is_dir($git_path)) {
        log_message("NEW in ClawHub: {$skill_name} → syncing to Git");
        if (sync_to_git($skill_name, false)) {
            init_git_repo($git_path, $skill_name);
            return "synced_to_git";
        }
    }
    
    // Fall 2: Nur in Git → zu ClawHub
    elseif (is_dir($git_path) && !is_dir($clawhub_path)) {
        log_message("NEW in Git: {$skill_name} → syncing to ClawHub");
        if (sync_to_clawhub($skill_name, false)) {
            return "synced_to_clawhub";
        }
    }
    
    // Fall 3: In beiden vorhanden
    elseif (is_dir($clawhub_path) && is_dir($git_path)) {
        if (!validate_skill($clawhub_path)) {
            log_message("Validation failed for ClawHub skill: {$skill_name}", "ERROR");
            return "error";
        }
        if (!validate_skill($git_path)) {
            log_message("Validation failed for Git skill: {$skill_name}", "ERROR");
            return "error";
        }

        $clawhub_changes = preview_changes($clawhub_path, $git_path);
        $git_changes = preview_changes($git_path, $clawhub_path);

        if (empty($clawhub_changes) && empty($git_changes)) {
            log_message("Content is identical for: {$skill_name}");
            return "no_change";
        }

        if (!empty($clawhub_changes) && empty($git_changes)) {
            log_message("Content difference detected for: {$skill_name}");
            log_message("UPDATE: {$skill_name} ClawHub content is newer or different → syncing to Git");
            if (sync_to_git($skill_name, false)) {
                chdir($git_path);
                exec("git add .", $output, $return_code);
                $timestamp = date('Y-m-d H:i');
                exec("git commit -m \"Sync from ClawHub content diff: {$timestamp}\"", $output, $return_code);
                return "updated_git";
            }
            log_message("Failed to sync {$skill_name} to Git after content diff", "ERROR");
            return "error";
        }

        if (!empty($git_changes) && empty($clawhub_changes)) {
            log_message("Content difference detected for: {$skill_name}");
            log_message("UPDATE: {$skill_name} Git content is newer or different → syncing to ClawHub");
            if (sync_to_clawhub($skill_name, false)) {
                return "updated_clawhub";
            }
            log_message("Failed to sync {$skill_name} to ClawHub after content diff", "ERROR");
            return "error";
        }

        log_message("Content difference detected for: {$skill_name}");
        if (newest_mtime($clawhub_path) >= newest_mtime($git_path)) {
            log_message("UPDATE: {$skill_name} ClawHub content is newer or different → syncing to Git");
            if (sync_to_git($skill_name, false)) {
                chdir($git_path);
                exec("git add .", $output, $return_code);
                $timestamp = date('Y-m-d H:i');
                exec("git commit -m \"Sync from ClawHub content diff: {$timestamp}\"", $output, $return_code);
                return "updated_git";
            }
        } else {
            log_message("UPDATE: {$skill_name} Git content is newer or different → syncing to ClawHub");
            if (sync_to_clawhub($skill_name, false)) {
                return "updated_clawhub";
            }
        }

        log_message("Failed to resolve content diff for {$skill_name}", "ERROR");
        return "error";
    }
    
    return "no_change";
}

function get_hashes($skill_dir) {
    /** Erzeugt ein Dictionary von Datei-Hashes für einen Skill-Ordner. */
    $hashes = [];
    $files = iter_sync_files($skill_dir);
    foreach ($files as $item) {
        $file_path = $item[0];
        $rel_path = $item[1];
        $hashes[$rel_path] = get_file_hash($file_path);
    }
    return $hashes;
}

function preview_changes($source_dir, $target_dir) {
    /** Berechnet Sync-Änderungen in einer Richtung, ohne zu schreiben. */
    $changes = [];
    $files = iter_sync_files($source_dir);
    foreach ($files as $item) {
        $src_file = $item[0];
        $rel_path = $item[1];
        $tgt_file = $target_dir . "/" . $rel_path;
        
        if (!file_exists($tgt_file)) {
            $changes[] = "ADD " . $rel_path;
        } elseif (get_file_hash($src_file) !== get_file_hash($tgt_file)) {
            $changes[] = "UPDATE " . $rel_path;
        }
    }
    return $changes;
}

function newest_mtime($skill_dir) {
    /** Ermittelt die neueste mtime über alle relevanten Dateien. */
    $mtimes = [];
    $files = iter_sync_files($skill_dir);
    foreach ($files as $item) {
        $file_path = $item[0];
        $mtimes[] = filemtime($file_path);
    }
    return !empty($mtimes) ? max($mtimes) : 0.0;
}

function main() {
    /** Hauptfunktion des Sync-Agents mit Dry-Run Phase */
    log_message("=== ClawHub ↔ Git Sync Agent gestartet ===");
    
    // Load previous state
    $state = load_state();
    $all_skills = get_all_skills();
    log_message("Gefundene Skills: " . count($all_skills));
    
    // Dry-Run Phase: only report changes, no actual modifications
    log_message("--- Dry-Run Phase Start ---");
    foreach (array_values($all_skills) as $skill) {
        // Perform dry-run sync in both directions to capture potential changes
        sync_to_git($skill, true);
        sync_to_clawhub($skill, true);
    }
    log_message("--- Dry-Run Phase End ---");
    
    $results = [
        "synced_to_git" => [],
        "synced_to_clawhub" => [],
        "updated_git" => [],
        "updated_clawhub" => [],
        "no_change" => [],
        "errors" => []
    ];
    
    // Actual Sync Phase
    foreach (array_values($all_skills) as $skill) {
        try {
            $result = sync_skill_bidirectional($skill);
            $results[$result][] = $skill;
        } catch (Exception $e) {
            log_message("ERROR syncing {$skill}: " . $e->getMessage(), "ERROR");
            $results["errors"][] = $skill;
        }
    }
    
    // Zusammenfassung
    log_message("\n=== SYNC ZUSAMMENFASSUNG ===");
    log_message("Neu in Git: " . count($results['synced_to_git']) . " - " . json_encode($results['synced_to_git']));
    log_message("Neu in ClawHub: " . count($results['synced_to_clawhub']) . " - " . json_encode($results['synced_to_clawhub']));
    log_message("Git aktualisiert: " . count($results['updated_git']) . " - " . json_encode($results['updated_git']));
    log_message("ClawHub aktualisiert: " . count($results['updated_clawhub']) . " - " . json_encode($results['updated_clawhub']));
    log_message("Keine Änderung: " . count($results['no_change']));
    log_message("Fehler: " . count($results['errors']) . " - " . json_encode($results['errors']));
    
    // State speichern
    if (!isset($state["sync_history"])) {
        $state["sync_history"] = [];
    }
    $state["sync_history"][] = [
        "timestamp" => date('c'),
        "results" => $results
    ];
    // Nur letzte 100 Einträge behalten
    $state["sync_history"] = array_slice($state["sync_history"], -100);
    save_state($state);
    
    log_message("=== Sync Agent beendet ===\n");
}

main();
?>

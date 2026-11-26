<?php
// abstraction-provenance: {"artifact_sha256": "2f7cd69f72d0996410045f8084c023ed69f6319b496eb4460486f266689473da", "source_sha256": "e86a7b42e9bd3c3d2f9321883c9d29b0e6b2774e4eb99056dd5093ca64b5b5c8", "target_language": "php"}
// sync_bulk.py — portiert nach php
// Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/sync_bulk.py
// auch in: OpenClaw@gateway2:skills/sync-utils/scripts/sync_bulk.py
// auch in: workspace@local:git/skills/sync-utils/scripts/sync_bulk.py
// auch in: workspace@local:skills/sync-utils/scripts/sync_bulk.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
/**
 * Bulk Sync - Synchronisiert alle Skills
 */

// Include sync functions
require_once '/home/openclaw/.openclaw/workspace/scripts/sync_clawhub_git.php';

define('CLAWHUB_DIR', '/home/openclaw/.openclaw/workspace/skills');
define('GIT_DIR', '/home/openclaw/.openclaw/workspace/git/skills');

function sync_all_skills($dry_run = true) {
    // Alle Skills finden
    $all_skills = [];

    if (is_dir(CLAWHUB_DIR)) {
        foreach (scandir(CLAWHUB_DIR) as $item) {
            if ($item[0] !== '.' && is_dir(CLAWHUB_DIR . '/' . $item)) {
                $all_skills[] = $item;
            }
        }
    }

    if (is_dir(GIT_DIR)) {
        foreach (scandir(GIT_DIR) as $item) {
            if ($item[0] !== '.' && is_dir(GIT_DIR . '/' . $item)) {
                $all_skills[] = $item;
            }
        }
    }

    $all_skills = array_unique($all_skills);
    sort($all_skills);

    log_message("Bulk Sync: " . count($all_skills) . " Skills gefunden");

    $results = [
        "synced" => [],
        "skipped" => [],
        "failed" => []
    ];

    foreach ($all_skills as $skill) {
        $clawhub_path = CLAWHUB_DIR . '/' . $skill;
        $git_path = GIT_DIR . '/' . $skill;

        try {
            // Nur in ClawHub → zu Git
            if (file_exists($clawhub_path) && !file_exists($git_path)) {
                if (validate_skill($clawhub_path)) {
                    log_message("Syncing {$skill} to Git...");
                    if (sync_to_git($skill, $dry_run)) {
                        $results["synced"][] = "{$skill} → Git";
                    } else {
                        $results["failed"][] = $skill;
                    }
                } else {
                    $results["skipped"][] = "{$skill} (validation failed)";
                }
            }
            // Nur in Git → zu ClawHub
            elseif (file_exists($git_path) && !file_exists($clawhub_path)) {
                if (validate_skill($git_path)) {
                    log_message("Syncing {$skill} to ClawHub...");
                    if (sync_to_clawhub($skill, $dry_run)) {
                        $results["synced"][] = "{$skill} → ClawHub";
                    } else {
                        $results["failed"][] = $skill;
                    }
                } else {
                    $results["skipped"][] = "{$skill} (validation failed)";
                }
            }
            // In beiden - prüfe ob Update nötig
            elseif (file_exists($clawhub_path) && file_exists($git_path)) {
                // Vereinfachte Prüfung
                $clawhub_files = new RecursiveIteratorIterator(
                    new RecursiveDirectoryIterator($clawhub_path, RecursiveDirectoryIterator::SKIP_DOTS)
                );
                $clawhub_mtime = 0;
                foreach ($clawhub_files as $file) {
                    if ($file->isFile()) {
                        $clawhub_mtime = max($clawhub_mtime, $file->getMTime());
                    }
                }

                $git_files = new RecursiveIteratorIterator(
                    new RecursiveDirectoryIterator($git_path, RecursiveDirectoryIterator::SKIP_DOTS)
                );
                $git_mtime = 0;
                foreach ($git_files as $file) {
                    if ($file->isFile() && strpos($file->getPath(), '/.git/') === false) {
                        $git_mtime = max($git_mtime, $file->getMTime());
                    }
                }

                if (abs($clawhub_mtime - $git_mtime) > 60) {
                    if ($clawhub_mtime > $git_mtime) {
                        log_message("Updating {$skill} in Git...");
                        if (sync_to_git($skill, $dry_run)) {
                            $results["synced"][] = "{$skill} → Git (update)";
                        } else {
                            $results["failed"][] = $skill;
                        }
                    } else {
                        log_message("Updating {$skill} in ClawHub...");
                        if (sync_to_clawhub($skill, $dry_run)) {
                            $results["synced"][] = "{$skill} → ClawHub (update)";
                        } else {
                            $results["failed"][] = $skill;
                        }
                    }
                } else {
                    $results["skipped"][] = "{$skill} (already synced)";
                }
            }
        } catch (Exception $e) {
            log_message("Error processing {$skill}: " . $e->getMessage(), "ERROR");
            $results["failed"][] = $skill;
        }
    }

    // Zusammenfassung
    echo "\n" . str_repeat("=", 60) . "\n";
    echo "Bulk Sync " . ($dry_run ? "DRY-RUN" : "EXECUTED") . " - Zusammenfassung\n";
    echo str_repeat("=", 60) . "\n";
    echo "✅ Synchronisiert: " . count($results['synced']) . "\n";
    foreach ($results["synced"] as $item) {
        echo "   - {$item}\n";
    }
    echo "\n⏭️  Übersprungen: " . count($results['skipped']) . "\n";
    if (count($results["skipped"]) <= 10) {
        foreach ($results["skipped"] as $item) {
            echo "   - {$item}\n";
        }
    } else {
        echo "   - " . count($results['skipped']) . " Skills (bereits synchron oder Validierung fehlgeschlagen)\n";
    }
    echo "\n❌ Fehlgeschlagen: " . count($results['failed']) . "\n";
    foreach ($results["failed"] as $item) {
        echo "   - {$item}\n";
    }
    echo str_repeat("=", 60) . "\n";
}

function main() {
    global $argv;

    $dry_run = in_array('--dry-run', $argv);
    $execute = in_array('--execute', $argv);

    if (!$dry_run && !$execute) {
        echo "Bitte --dry-run oder --execute angeben\n";
        exit(1);
    }

    sync_all_skills($dry_run);
}

main();
?>

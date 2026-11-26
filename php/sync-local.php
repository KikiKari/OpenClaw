<?php
// abstraction-provenance: {"artifact_sha256": "801250b8bd55043bc5b1fbbdc085d2e4cda8499203f583574d4f03fe0ad43aed", "source_sha256": "b97ad7dc26be724af240b4c0c98ec196e729e0702664b99c65e0e3c435a1b5af", "target_language": "php"}
// sync-local.ps1 — portiert nach php
// Quelle: powershell, Onboarding@main:scripts/sync-local.ps1
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
/**
 * SYNOPSIS
 *   Hält den lokalen Dev-Stack (docker-compose.dev.yml) inkrementell mit GitHub synchron.
 *
 * DESCRIPTION
 *   Pollt origin/<Branch> und zieht neue Commits per Fast-Forward. Danach entscheidet
 *   der Diff, was nötig ist:
 *     - nur Quellcode geändert            -> nichts tun, Hot-Reload übernimmt
 *     - package.json / package-lock.json  -> Frontend-Container neu starten
 *                                            (Entrypoint installiert Dependencies nur
 *                                            bei geändertem Lockfile-Hash nach)
 *     - backend/Dockerfile, requirements* -> Backend-Image gezielt neu bauen
 *     - docker-compose.dev.yml            -> Dev-Stack neu erzeugen
 *   Es wird nie „blind" der ganze Branch neu gebaut.
 *
 * EXAMPLE
 *   php scripts/sync-local.php                // Dauerbetrieb, 20-s-Intervall
 *   php scripts/sync-local.php --once         // genau ein Sync-Durchlauf
 *   php scripts/sync-local.php --branch main // anderen Branch verfolgen
 */

// Parameter parsen
$options = getopt("", ["branch::", "intervalSeconds::", "composeFile::", "once"]);
$branch = $options['branch'] ?? "claude/onboarding-persistent-sandbox-vjfmcx";
$intervalSeconds = (int)($options['intervalSeconds'] ?? 20);
$composeFile = $options['composeFile'] ?? "docker-compose.dev.yml";
$once = isset($options['once']);

// Fehlermodus setzen
set_error_handler(function($severity, $message, $file, $line) {
    throw new ErrorException($message, 0, $severity, $file, $line);
});

// Repository-Root bestimmen
$repoRoot = dirname(__DIR__);
chdir($repoRoot);

function logMsg($msg) {
    echo "[" . date("H:i:s") . "] " . $msg . "\n";
}

function invokeCompose($composeArgs, $composeFile) {
    $cmd = "docker compose -f " . escapeshellarg($composeFile) . " " . implode(" ", array_map('escapeshellarg', $composeArgs));
    $output = null;
    $returnCode = 0;
    exec($cmd, $output, $returnCode);
    if ($returnCode !== 0) {
        logMsg("WARNUNG: docker compose " . implode(" ", $composeArgs) . " fehlgeschlagen (Exit $returnCode)");
    }
}

// Sicherstellen, dass der Ziel-Branch ausgecheckt ist.
$current = trim(shell_exec("git rev-parse --abbrev-ref HEAD"));
if ($current !== $branch) {
    logMsg("Wechsle von '$current' auf '$branch' …");
    shell_exec("git fetch origin " . escapeshellarg($branch));
    $switchOutput = null;
    $switchReturn = 0;
    exec("git switch " . escapeshellarg($branch), $switchOutput, $switchReturn);
    if ($switchReturn !== 0) {
        $createOutput = null;
        $createReturn = 0;
        exec("git switch -c " . escapeshellarg($branch) . " --track origin/" . escapeshellarg($branch), $createOutput, $createReturn);
        if ($createReturn !== 0) {
            throw new Exception("Branch '$branch' konnte nicht ausgecheckt werden.");
        }
    }
}

logMsg("Sync aktiv: origin/$branch -> $repoRoot (Intervall {$intervalSeconds}s, Compose: $composeFile)");

while (true) {
    $fetchOutput = null;
    $fetchReturn = 0;
    exec("git fetch origin " . escapeshellarg($branch) . " --quiet", $fetchOutput, $fetchReturn);
    if ($fetchReturn !== 0) {
        logMsg("Fetch fehlgeschlagen (Netzwerk?) — nächster Versuch in {$intervalSeconds}s");
    } else {
        $local = trim(shell_exec("git rev-parse HEAD"));
        $remote = trim(shell_exec("git rev-parse origin/" . escapeshellarg($branch)));

        if ($local !== $remote) {
            $ancestorOutput = null;
            $ancestorReturn = 0;
            exec("git merge-base --is-ancestor " . escapeshellarg($local) . " " . escapeshellarg($remote), $ancestorOutput, $ancestorReturn);
            if ($ancestorReturn !== 0) {
                logMsg("ACHTUNG: Lokaler Stand ist von origin/$branch abgewichen (lokale Commits?). Kein automatischer Merge — bitte manuell auflösen.");
            } else {
                $diffOutput = [];
                $diffReturn = 0;
                exec("git diff --name-only " . escapeshellarg("$local..$remote"), $diffOutput, $diffReturn);
                $changed = array_filter($diffOutput); // Entferne leere Zeilen

                $mergeOutput = null;
                $mergeReturn = 0;
                exec("git merge --ff-only " . escapeshellarg($remote) . " --quiet", $mergeOutput, $mergeReturn);
                logMsg("Aktualisiert " . substr($local, 0, 7) . " -> " . substr($remote, 0, 7) . " (" . count($changed) . " Datei(en))");

                $frontendDeps = array_filter($changed, function($file) {
                    return in_array($file, ["package.json", "package-lock.json"]);
                });

                $backendImage = array_filter($changed, function($file) {
                    return preg_match('/^backend\/(Dockerfile|requirements.*\.txt)$/', $file);
                });

                $composeChanged = in_array($composeFile, $changed);

                if ($composeChanged) {
                    logMsg("Compose-Datei geändert — erzeuge Dev-Stack neu …");
                    invokeCompose(["up", "-d"], $composeFile);
                }
                if (!empty($backendImage)) {
                    logMsg("Backend-Dependencies/Dockerfile geändert — baue nur das Backend neu …");
                    invokeCompose(["up", "-d", "--build", "backend"], $composeFile);
                }
                if (!empty($frontendDeps)) {
                    logMsg("Frontend-Dependencies geändert — starte Frontend neu (npm install läuft im Container) …");
                    invokeCompose(["restart", "frontend"], $composeFile);
                }
                if (!$composeChanged && empty($backendImage) && empty($frontendDeps)) {
                    logMsg("Nur Quellcode/Assets — Hot-Reload übernimmt, kein Build nötig.");
                }
            }
        }
    }

    if ($once) { break; }
    sleep($intervalSeconds);
}
?>

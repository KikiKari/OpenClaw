<?php
// abstraction-provenance: {"artifact_sha256": "b88bd0cf9d9969fca13243f161869e0a290496c77965c550b33ae8dd5072bfa6", "source_sha256": "e51b94641336291974fe14bf4bb7299a75ec7dcce49e1d413282c8043e9f09f1", "target_language": "php"}
// openclaw-audit.sh — portiert nach php
// Quelle: shell, OpenClaw@gateway1:scripts/openclaw-audit.sh
// auch in: OpenClaw@gateway2:scripts/openclaw-audit.sh
// auch in: workspace@local:scripts/openclaw-audit.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
// OpenClaw read-only audit/diagnostic sweep
// Output: openclaw-audit-YYYY-MM-DD.log im selben Verzeichnis wie dieses Script

function getScriptDir() {
    return dirname(realpath($_SERVER['SCRIPT_NAME']));
}

$dateStamp = date('Y-m-d');
$out = getScriptDir() . "/openclaw-audit-{$dateStamp}.log";

$oc = ['openclaw', '--no-color'];

// Start logging
$logContent = "================================================================\n";
$logContent .= "OpenClaw audit run\n";
$logContent .= "Started:  " . date('c') . "\n";
$logContent .= "Host:     " . gethostname() . "\n";
$logContent .= "User:     " . get_current_user() . "\n";

// Get version
$versionOutput = [];
exec('openclaw --version 2>/dev/null', $versionOutput, $versionResult);
$version = !empty($versionOutput) ? implode("\n", $versionOutput) : 'unknown';
$logContent .= "Version:  {$version}\n";
$logContent .= "Output:   {$out}\n";
$logContent .= "================================================================\n";

file_put_contents($out, $logContent);

function runCmd($title, $cmdArray, $outFile) {
    $cmdString = implode(' ', array_map('escapeshellarg', $cmdArray));
    
    $logEntry = "\n";
    $logEntry .= "----------------------------------------------------------------\n";
    $logEntry .= "### {$title}\n";
    $logEntry .= "### \$ {$cmdString}\n";
    $logEntry .= "### " . date('c') . "\n";
    $logEntry .= "----------------------------------------------------------------\n";
    
    file_put_contents($outFile, $logEntry, FILE_APPEND);
    
    // Execute command and capture output
    $output = [];
    $resultCode = 0;
    exec("{$cmdString} 2>&1", $output, $resultCode);
    
    if (!empty($output)) {
        file_put_contents($outFile, implode("\n", $output) . "\n", FILE_APPEND);
    }
    
    file_put_contents($outFile, "[exit: {$resultCode}]\n", FILE_APPEND);
}

runCmd("tasks audit --severity error", array_merge($oc, ['tasks', 'audit', '--severity', 'error']), $out);
runCmd("secrets audit", array_merge($oc, ['secrets', 'audit']), $out);
runCmd("security audit", array_merge($oc, ['security', 'audit']), $out);
runCmd("plugins doctor", array_merge($oc, ['plugins', 'doctor']), $out);
runCmd("plugins deps", array_merge($oc, ['plugins', 'deps']), $out);
runCmd("plugins registry", array_merge($oc, ['plugins', 'registry']), $out);
runCmd("skills check", array_merge($oc, ['skills', 'check']), $out);
runCmd("hooks check", array_merge($oc, ['hooks', 'check']), $out);
runCmd("gateway status --deep", array_merge($oc, ['gateway', 'status', '--deep']), $out);
runCmd("channels status --probe", array_merge($oc, ['channels', 'status', '--probe']), $out);
runCmd("memory status --deep", array_merge($oc, ['memory', 'status', '--deep']), $out);
runCmd("sessions --all-agents", array_merge($oc, ['sessions', '--all-agents']), $out);
runCmd("tasks list", array_merge($oc, ['tasks', 'list']), $out);
runCmd("cron list", array_merge($oc, ['cron', 'list']), $out);

// End logging
$endLogContent = "\n";
$endLogContent .= "================================================================\n";
$endLogContent .= "Audit complete: " . date('c') . "\n";
$endLogContent .= "================================================================\n";

file_put_contents($out, $endLogContent, FILE_APPEND);

echo "Audit complete. Output: {$out}\n";
?>

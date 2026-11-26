<?php
// abstraction-provenance: {"artifact_sha256": "fad711d49a690900ec9653dadccf79113becf58089228a00c8fead0bc7ee5bd2", "source_sha256": "38390e5c16266050829f3193f79ca05d8ec898095dc834f407431d87ecfadeb8", "target_language": "php"}
// server-maintenance.sh — portiert nach php
// Quelle: shell, OpenClaw@gateway1:scripts/server-maintenance.sh
// auch in: OpenClaw@gateway2:scripts/server-maintenance.sh
// auch in: workspace@local:scripts/server-maintenance.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
// Server Maintenance Script
// RAM: 8GB, Uhr: Europe/Berlin

$logFile = "/var/log/server-maintenance.log";
$date = date('Y-m-d H:i:s');
$host = gethostname();

// Farben für Terminal
$red = "\033[0;31m";
$green = "\033[0;32m";
$yellow = "\033[1;33m";
$nc = "\033[0m";

function logMessage($message, $logFile) {
    $timestamp = date('Y-m-d H:i:s');
    file_put_contents($logFile, "[$timestamp] $message\n", FILE_APPEND | LOCK_EX);
    echo "[$timestamp] $message\n";
}

logMessage("=== Server Maintenance Check ===", $logFile);

// 1. APT Update Check
logMessage("Checking for updates...", $logFile);
$updateOutput = shell_exec("apt update -qq 2>&1");
$lines = explode("\n", trim($updateOutput));
$lastLines = array_slice($lines, -5);
foreach ($lastLines as $line) {
    if (!empty($line)) {
        logMessage($line, $logFile);
    }
}
$upgradablePackages = intval(shell_exec("apt list --upgradable 2>/dev/null | wc -l"));
if ($upgradablePackages > 1) {
    logMessage("⚠️ $upgradablePackages packages can be upgraded", $logFile);
}

// 2. RAM Check (8GB total)
logMessage("Checking RAM usage...", $logFile);
$ramTotal = 8192; // 8GB in MB
$freeOutput = shell_exec("free -m");
$freeLines = explode("\n", trim($freeOutput));
$memLine = "";
foreach ($freeLines as $line) {
    if (strpos($line, "Mem:") === 0) {
        $memLine = $line;
        break;
    }
}
if (!empty($memLine)) {
    $memParts = preg_split('/\s+/', trim($memLine));
    $ramUsed = intval($memParts[2]);
    $ramPercent = intval(($ramUsed * 100) / $ramTotal);
    logMessage("RAM: {$ramUsed}MB / {$ramTotal}MB ({$ramPercent}%)", $logFile);
    if ($ramPercent > 90) {
        logMessage("🔴 WARNING: RAM usage > 90%!", $logFile);
    } elseif ($ramPercent > 80) {
        logMessage("🟡 WARNING: RAM usage > 80%", $logFile);
    }
}

// 3. Disk Space Check
logMessage("Checking disk space...", $logFile);
$diskOutput = shell_exec("df -h / | tail -1");
$diskLine = trim($diskOutput);
$diskParts = preg_split('/\s+/', $diskLine);
if (count($diskParts) >= 5) {
    $used = $diskParts[2];
    $total = $diskParts[1];
    $percent = $diskParts[4];
    logMessage("Disk: $used / $total ($percent used)", $logFile);
    $diskPercent = intval(str_replace('%', '', $percent));
    if ($diskPercent > 90) {
        logMessage("🔴 WARNING: Disk > 90%!", $logFile);
    } elseif ($diskPercent > 80) {
        logMessage("🟡 WARNING: Disk > 80%", $logFile);
    }
}

// 4. NTP Check
logMessage("Checking NTP sync...", $logFile);
$timedatectlOutput = shell_exec("timedatectl status");
if (strpos($timedatectlOutput, "NTP synchronized: yes") !== false) {
    logMessage("✅ NTP synchronized", $logFile);
} else {
    logMessage("⚠️ NTP not synchronized", $logFile);
}

// 5. OpenClaw Gateway Status
logMessage("Checking OpenClaw Gateway...", $logFile);
$isActive = shell_exec("systemctl is-active openclaw-gateway");
if (trim($isActive) === "active") {
    logMessage("✅ OpenClaw Gateway running", $logFile);
} else {
    logMessage("🔴 OpenClaw Gateway NOT running!", $logFile);
    shell_exec("systemctl restart openclaw-gateway");
}

// 6. Load Average
$uptimeOutput = shell_exec("uptime");
$loadAvgPos = strpos($uptimeOutput, "load average:");
if ($loadAvgPos !== false) {
    $loadPart = substr($uptimeOutput, $loadAvgPos + strlen("load average:"));
    $loads = explode(",", $loadPart);
    $load = trim(str_replace(',', '', $loads[0]));
    logMessage("Load Average: $load", $logFile);
}

logMessage("=== Maintenance Complete ===", $logFile);
logMessage("", $logFile);

?>

<?php
// abstraction-provenance: {"artifact_sha256": "30fc9891a45bcb1e67a655be4d90e259133f0bce0dc448f8b1be0e03d7d85ccd", "source_sha256": "f85931ea8f1a58309ac3ba2c5899fd4b8f2c55777f90b132269efd74bb35362b", "target_language": "php"}
// setup-xvfb-node3.sh — portiert nach php
// Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node3.sh
// auch in: OpenClaw@gateway2:scripts/setup-xvfb-node3.sh
// auch in: workspace@local:scripts/setup-xvfb-node3.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
// Xvfb Setup für Node 3 (xNetX VPS)
// Erstellt: 2026-04-09
// Hinweis: Altes VNC-Setup wird entfernt

echo "=== Xvfb + Chromium Setup für Node 3 ===\n";
echo "=== Entferne altes VNC-Setup ===\n";

// Altes VNC stoppen & entfernen (falls vorhanden)
exec("sudo systemctl stop vncserver@* 2>/dev/null", $output, $return_var);
exec("sudo systemctl disable vncserver@* 2>/dev/null", $output, $return_var);
exec("sudo apt-get remove -y tightvncserver tigervnc-standalone-server 2>/dev/null", $output, $return_var);
exec("sudo rm -rf ~/.vnc /tmp/.X11-unix/X*", $output, $return_var);

echo "=== Installiere Xvfb + Chromium ===\n";

// Update & Install
exec("sudo apt-get update", $output, $return_var);
if ($return_var !== 0) {
    die("Fehler beim Aktualisieren der Paketliste\n");
}

$packages = [
    "xvfb",
    "chromium",
    "chromium-driver",
    "fonts-liberation",
    "libappindicator3-1",
    "libasound2",
    "libatk-bridge2.0-0",
    "libatk1.0-0",
    "libcups2",
    "libgtk-3-0",
    "libnspr4",
    "libnss3",
    "libxss1",
    "xdg-utils"
];

exec("sudo apt-get install -y " . implode(" ", $packages), $output, $return_var);
if ($return_var !== 0) {
    die("Fehler bei der Installation der Pakete\n");
}

// Xvfb Systemd Service erstellen
$xvfbServiceContent = <<<EOF
[Unit]
Description=X Virtual Framebuffer
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF;

file_put_contents("/tmp/xvfb.service", $xvfbServiceContent);
exec("sudo mv /tmp/xvfb.service /etc/systemd/system/xvfb.service", $output, $return_var);
if ($return_var !== 0) {
    die("Fehler beim Erstellen der Xvfb-Service-Datei\n");
}

// Service aktivieren
exec("sudo systemctl daemon-reload", $output, $return_var);
if ($return_var !== 0) {
    die("Fehler beim Neuladen des Systemd-Daemons\n");
}

exec("sudo systemctl enable xvfb", $output, $return_var);
if ($return_var !== 0) {
    die("Fehler beim Aktivieren des Xvfb-Services\n");
}

exec("sudo systemctl start xvfb", $output, $return_var);
if ($return_var !== 0) {
    die("Fehler beim Starten des Xvfb-Services\n");
}

echo "=== Xvfb läuft auf DISPLAY :99 ===\n";
echo "Chromium Version:\n";

exec("chromium --version", $chromiumVersion, $return_var);
if ($return_var === 0) {
    echo implode("\n", $chromiumVersion) . "\n";
} else {
    echo "Chromium nicht gefunden\n";
}

echo "=== Setup abgeschlossen ===\n";
echo "=== Altes VNC-Setup wurde entfernt ===\n";
?>

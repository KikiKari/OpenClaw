<?php
// abstraction-provenance: {"artifact_sha256": "bea4532df1e7499bdb72c61cc7cbc8a6f6d0366a618d87b27f756cb12812f5cf", "source_sha256": "580708ba8136a21db9caeff52911141c9a4f2ed6daed6f9b9dacaaf4beae3f0b", "target_language": "php"}
// setup-xvfb-node2.sh — portiert nach php
// Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node2.sh
// auch in: OpenClaw@gateway2:scripts/setup-xvfb-node2.sh
// auch in: workspace@local:scripts/setup-xvfb-node2.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
// Xvfb Setup für Node 2 (Netcup VPS)
// Erstellt: 2026-04-09

echo "=== Xvfb + Chromium Setup für Node 2 ===\n";

// Update & Install
exec('sudo apt-get update', $output, $return_var);
if ($return_var !== 0) {
    die("Fehler beim Ausführen von apt-get update\n");
}

$packages = [
    'xvfb',
    'chromium-browser',
    'chromium-chromedriver',
    'fonts-liberation',
    'libappindicator3-1',
    'libasound2',
    'libatk-bridge2.0-0',
    'libatk1.0-0',
    'libcups2',
    'libgtk-3-0',
    'libnspr4',
    'libnss3',
    'libxss1',
    'xdg-utils'
];

$package_list = implode(' ', $packages);
exec("sudo apt-get install -y $package_list", $output, $return_var);
if ($return_var !== 0) {
    die("Fehler beim Installieren der Pakete\n");
}

// Xvfb Systemd Service erstellen
$xvfbServiceContent = <<<EOF
[Unit]
Description=X Virtual Framebuffer
After=network.target

[Service]
Type=simple
User=openclaw
ExecStart=/usr/bin/Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF;

file_put_contents('/tmp/xvfb.service', $xvfbServiceContent);
exec('sudo mv /tmp/xvfb.service /etc/systemd/system/xvfb.service', $output, $return_var);
if ($return_var !== 0) {
    die("Fehler beim Erstellen der Xvfb Service-Datei\n");
}

// Service aktivieren
exec('sudo systemctl daemon-reload', $output, $return_var);
if ($return_var !== 0) {
    die("Fehler beim Neuladen des Systemd-Daemons\n");
}

exec('sudo systemctl enable xvfb', $output, $return_var);
if ($return_var !== 0) {
    die("Fehler beim Aktivieren des Xvfb-Services\n");
}

exec('sudo systemctl start xvfb', $output, $return_var);
if ($return_var !== 0) {
    die("Fehler beim Starten des Xvfb-Services\n");
}

echo "=== Xvfb läuft auf DISPLAY :99 ===\n";
echo "Chromium Version:\n";

exec('chromium-browser --version', $chromiumOutput, $return_var);
if ($return_var === 0) {
    echo implode("\n", $chromiumOutput) . "\n";
} else {
    echo "Chromium nicht gefunden\n";
}

echo "=== Setup abgeschlossen ===\n";
?>

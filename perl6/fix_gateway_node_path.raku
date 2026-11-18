#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "c97f8a4fa9c559a576ec1ff7b13fefbd9be81e487f6496bcbba8882bca2c4690", "source_sha256": "04518825207cd6ef771c2d840daf0a025f3144f4e384f1d13b46e016570f59df", "target_language": "perl6"}
# fix_gateway_node_path.sh — portiert nach perl6
# Quelle: shell, OpenClaw@gateway1:scripts/fix_gateway_node_path.sh
# auch in: OpenClaw@gateway2:scripts/fix_gateway_node_path.sh
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

# Backup der originalen Service-Datei
my $backup-path = "/etc/systemd/system/openclaw-gateway.service.backup-{DateTime.now.strftime('%Y%m%d_%H%M%S')}";
"/etc/systemd/system/openclaw-gateway.service".IO.copy($backup-path);

# Korrektur des Node.js Pfads in der Service-Datei
# Annahme: Node.js ist unter /usr/bin/node verfügbar (wie von 'which node' gezeigt)
my $content = slurp "/etc/systemd/system/openclaw-gateway.service";
$content .= subst: /'/home/openclaw/.nvm/versions/node/v22.22.2/bin/node'/, '/usr/bin/node', :g;
spurt "/etc/systemd/system/openclaw-gateway.service", $content;

# Service neu laden und neu starten
shell "systemctl daemon-reload";
shell "systemctl restart openclaw-gateway";

# Status prüfen
shell "systemctl status openclaw-gateway --no-pager";

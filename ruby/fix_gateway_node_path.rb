#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "3a6a66aae246221ce23958a754a778dac2dd7e5c03be7607f4684d960225ee3e", "source_sha256": "04518825207cd6ef771c2d840daf0a025f3144f4e384f1d13b46e016570f59df", "target_language": "ruby"}
# fix_gateway_node_path.sh — portiert nach ruby
# Quelle: shell, OpenClaw@gateway1:scripts/fix_gateway_node_path.sh
# auch in: OpenClaw@gateway2:scripts/fix_gateway_node_path.sh
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

# Backup der originalen Service-Datei
backup_timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
backup_file = "/etc/systemd/system/openclaw-gateway.service.backup-#{backup_timestamp}"
FileUtils.cp('/etc/systemd/system/openclaw-gateway.service', backup_file)

# Korrektur des Node.js Pfads in der Service-Datei
# Annahme: Node.js ist unter /usr/bin/node verfügbar (wie von 'which node' gezeigt)
service_file = '/etc/systemd/system/openclaw-gateway.service'
content = File.read(service_file)
updated_content = content.gsub(%r{/home/openclaw/.nvm/versions/node/v22.22.2/bin/node}, '/usr/bin/node')
File.write(service_file, updated_content)

# Service neu laden und neu starten
system('systemctl daemon-reload')
system('systemctl restart openclaw-gateway')

# Status prüfen
system('systemctl status openclaw-gateway --no-pager')

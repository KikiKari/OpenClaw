#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "aaa00afd216baf7309c63ee75f27d8c3a813e28016c6095f03fa5b06b26a1284", "source_sha256": "04518825207cd6ef771c2d840daf0a025f3144f4e384f1d13b46e016570f59df", "target_language": "perl5"}
# fix_gateway_node_path.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway1:scripts/fix_gateway_node_path.sh
# auch in: OpenClaw@gateway2:scripts/fix_gateway_node_path.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use POSIX qw(strftime);

# Backup der originalen Service-Datei
my $timestamp = strftime("%Y%m%d_%H%M%S", localtime);
my $backup_file = "/etc/systemd/system/openclaw-gateway.service.backup-$timestamp";
system("cp /etc/systemd/system/openclaw-gateway.service $backup_file");

# Korrektur des Node.js Pfads in der Service-Datei
# Annahme: Node.js ist unter /usr/bin/node verfügbar (wie von 'which node' gezeigt)
{
    local @ARGV = ("/etc/systemd/system/openclaw-gateway.service");
    my $file_content;
    {
        local $/;
        $file_content = <>;
    }
    $file_content =~ s|/home/openclaw/.nvm/versions/node/v22.22.2/bin/node|/usr/bin/node|g;
    open(my $fh, '>', "/etc/systemd/system/openclaw-gateway.service") or die "Kann Datei nicht öffnen: $!";
    print $fh $file_content;
    close($fh);
}

# Service neu laden und neu starten
system("systemctl daemon-reload");
system("systemctl restart openclaw-gateway");

# Status prüfen
system("systemctl status openclaw-gateway --no-pager");

#!/usr/bin/perl
# fix_gateway_node_path.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway1:scripts/fix_gateway_node_path.sh
# auch in: OpenClaw@gateway2:scripts/fix_gateway_node_path.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use POSIX qw(strftime);

# Backup der originalen Service-Datei
my $service_file = "/etc/systemd/system/openclaw-gateway.service";
my $timestamp = strftime("%Y%m%d_%H%M%S", localtime);
my $backup_file = "${service_file}.backup-${timestamp}";

open(my $in, '<', $service_file) or die "Kann $service_file nicht lesen: $!";
open(my $out, '>', $backup_file) or die "Kann $backup_file nicht schreiben: $!";

while (my $line = <$in>) {
    print $out $line;
}

close($in);
close($out);

# Korrektur des Node.js Pfads in der Service-Datei
# Annahme: Node.js ist unter /usr/bin/node verfügbar (wie von 'which node' gezeigt)
{
    open(my $in, '<', $service_file) or die "Kann $service_file nicht lesen: $!";
    my @lines = <$in>;
    close($in);

    open(my $out, '>', $service_file) or die "Kann $service_file nicht schreiben: $!";
    for my $line (@lines) {
        $line =~ s|/home/openclaw/.nvm/versions/node/v22.22.2/bin/node|/usr/bin/node|g;
        print $out $line;
    }
    close($out);
}

# Service neu laden und neu starten
system("systemctl daemon-reload");
system("systemctl restart openclaw-gateway");

# Status prüfen
system("systemctl status openclaw-gateway --no-pager");

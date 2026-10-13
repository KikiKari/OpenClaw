#!/usr/bin/perl
# update-nodes-report.js — portiert nach perl5
# Quelle: javascript, OpenClaw@gateway1:scripts/update-nodes-report.js
# auch in: OpenClaw@gateway2:scripts/update-nodes-report.js
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use JSON;
use File::Spec;
use POSIX qw(strftime);

# Pfade
my $dashboard_path = File::Spec->catfile(File::Spec->updir(), 'dashboards', 'nodes-overview.md');

# Farbcodes für Konsole
my %C = (
    green  => "\x1b[32m",
    yellow => "\x1b[33m",
    red    => "\x1b[31m",
    blue   => "\x1b[34m",
    reset  => "\x1b[0m"
);

sub get_node_status {
    my $output;
    eval {
        $output = `openclaw nodes status --json 2>/dev/null`;
        if ($@) {
            die "Fehler beim Abrufen des Node-Status: $@";
        }
    };
    if ($@) {
        print $C{red} . "❌ Fehler beim Abrufen des Node-Status:" . $C{reset} . " $@\n";
        return [];
    }
    my $json = JSON->new;
    my $data = $json->decode($output);
    return $data;
}

sub update_dashboard {
    my ($nodes_ref) = @_;
    my @nodes = @$nodes_ref;

    my $now = strftime "%d.%m.%Y, %H:%M:%S", localtime;

    # Manuelle Ergänzung statischer Konfigurationen (da nicht alle Infos über CLI)
    my %node_config = (
        '1' => { name => 'Gateway',       os => 'Ubuntu 22.04', ip => '152.53.145.65',   wg => '10.10.0.1', tunnel => '–', mode => 'Gateway' },
        '2' => { name => 'Netcup Server', os => 'Ubuntu 22.04', ip => '78.46.123.10',  wg => '10.10.0.2', tunnel => '–', mode => 'Node' },
        '3' => { name => 'xNetX VPS',     os => 'Debian 11',    ip => '5.45.105.20',   wg => '–',        tunnel => 'Port 18794', mode => 'Node' },
        '4' => { name => 'Webhosting',    os => 'Shared Linux', ip => '–',              wg => '–',        tunnel => '–', mode => '–' },
        '5' => { name => 'Redmi Note 11', os => 'Android',      ip => '–',              wg => '10.10.0.5', tunnel => '–', mode => 'Node' },
        '6' => { name => 'Lenovo (Win)',  os => 'Windows 11',   ip => '–',              wg => '–',        tunnel => '–', mode => 'Node' }
    );

    my @rows;
    for my $node_id (sort keys %node_config) {
        my $cfg = $node_config{$node_id};
        my ($node) = grep { $_->{nodeId} eq $node_id || (exists $_->{name} && index($_->{name}, (split /\s+/, $cfg->{name})[0]) != -1) } @nodes;

        my $status_vpn = $node ? ($node->{status} eq 'paired' ? '✅' : '🔴') : '⚠️';
        my $status_ssh = $cfg->{tunnel} ne '–' ? '✅' : '❌';
        my $ssh_key = grep(/^$node_id$/, qw(2 3)) ? '❌ (Pending)' : ($node_id eq '1' ? 'Local (id_ed25519)' : '❌');

        my $last_check = $node ? strftime("%d.%m.%Y, %H:%M:%S", localtime($node->{lastSeen})) : '–';

        push @rows, sprintf "| %-4s | %-13s | %-12s | %-14s | %-10s | %-18s | %-19s | %-9s | %-9s | %-19s | %-19s |",
            $node_id,
            $cfg->{name},
            $cfg->{os},
            $cfg->{ip},
            $cfg->{mode},
            $cfg->{wg},
            $cfg->{tunnel},
            $status_vpn,
            $status_ssh,
            $ssh_key,
            $last_check;
    }

    my $content = "# Nodes Overview (Network Status)\n\n";
    $content .= "| Node | Name          | OS           | IP             | Mode       | Primär WG IP       | Sekundär/SSH Tunnel | StatusVPN | StatusSSH | SSH Key (Deployed) | Letzter Check       |\n";
    $content .= "|------|---------------|--------------|----------------|------------|--------------------|---------------------|-----------|-----------|---------------------|---------------------|\n";
    $content .= join("\n", @rows) . "\n\n";
    $content .= "> 💡 **Legende:** \n";
    $content .= "> - **Primär WG IP**: Die WireGuard-VPN-IP des Nodes\n";
    $content .= "> - **Sekundär/SSH Tunnel**: Fallback-Mechanismus (z. B. Reverse-Tunnel)\n";
    $content .= "> - **StatusVPN**: Verbunden über OpenClaw/WireGuard\n";
    $content .= "> - **StatusSSH**: SSH-Zugriff via Reverse-Tunnel aktiv\n";
    $content .= "> - **SSH Key (Deployed)**: Zeigt an, ob der Gateway-Schlüssel (`id_ed25519`) auf dem Ziel bereitgestellt ist\n";
    $content .= "> - Letzter Stand: **" . $now . " CET**\n\n";
    $content .= "*Größe: ~1.8 KB | Automatisch aktualisiert via `update-nodes-report.js`*\n";

    open(my $fh, '>:encoding(UTF-8)', $dashboard_path) or do {
        print $C{red} . "❌ Fehler beim Schreiben der Datei:" . $C{reset} . " $!\n";
        return;
    };
    print $fh $content;
    close($fh);
    print $C{green} . "✅ Dashboard aktualisiert:" . $C{reset} . " $dashboard_path\n";
}

# Hauptausführung
print $C{blue} . "🔄 Aktualisiere Nodes-Übersicht..." . $C{reset} . "\n";
my $nodes_ref = get_node_status();
update_dashboard($nodes_ref);

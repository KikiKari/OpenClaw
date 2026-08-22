#!/usr/bin/env perl
# sandbox-vpn.sh — portiert nach perl5
# Quelle: shell, Onboarding@main:scripts/sandbox-vpn.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Basename;
use Cwd qw(abs_path);

# Bringt die Sandbox reproduzierbar in das Tailscale-Tailnet des Nutzers —
# als Brücke am Agent-MITM-Proxy vorbei (sauberer Egress via SOCKS5) und mit
# Tailscale-SSH, damit die eigenen Geräte des Nutzers in die Sandbox kommen.
#
# Nutzt den WIEDERVERWENDBAREN Auth-Key aus der .env (nichts committet).
# userspace-networking: verändert NICHT die Host-Routen/den Agent-Proxy dieser
# Session; stellt einen SOCKS5-Proxy auf localhost:1055 bereit.
#
# Aufruf: scripts/sandbox-vpn.sh   (idempotent; No-op ohne Auth-Key/tailscale)

my $script_dir = dirname(abs_path($0));
my $project_dir = dirname($script_dir);
chdir($project_dir) or die "Cannot change directory to $project_dir: $!";

sub log_msg {
    my ($msg) = @_;
    print "[sandbox-vpn] $msg\n";
}

# Auth-Key aus .env lesen (ohne die gesamte .env zu sourcen)
my $key = "";
if (-f ".env") {
    open(my $fh, '<', '.env') or die "Cannot open .env: $!";
    while (my $line = <$fh>) {
        if ($line =~ /^TAILSCALE_AUTH_KEY="(.*)"/) {
            $key = $1;
            last;
        }
    }
    close($fh);
}

if (!$key) {
    log_msg("kein TAILSCALE_AUTH_KEY in .env — überspringe VPN");
    exit(0);
}

# Tailscale installieren, falls nicht vorhanden
unless (`which tailscale 2>/dev/null`) {
    log_msg("installiere Tailscale …");
    system("curl -fsSL https://tailscale.com/install.sh | sh >/dev/null 2>&1");
    unless ($? == 0) {
        log_msg("WARNUNG: Tailscale-Install fehlgeschlagen");
        exit(0);
    }
}

# tailscaled im userspace-Modus starten (SOCKS5 + HTTP-Proxy für Tailnet-Egress)
unless (system("tailscale status >/dev/null 2>&1") == 0) {
    log_msg("starte tailscaled (userspace, SOCKS5 localhost:1055) …");
    system("mkdir -p /var/lib/tailscale");
    
    my $cmd = "nohup tailscaled --tun=userspace-networking " .
              "--socks5-server=localhost:1055 " .
              "--outbound-http-proxy-listen=localhost:1056 " .
              "--statedir=/var/lib/tailscale >/tmp/tailscaled.log 2>&1 &";
    
    system($cmd);
    sleep(4);
}

# Ins Tailnet, mit Tailscale-SSH aktiviert
my $status_output = `tailscale status 2>/dev/null`;
if ($status_output !~ /claude-sandbox/) {
    log_msg("tailscale up (hostname=claude-sandbox, --ssh) …");
    my $cmd = "tailscale up --authkey=\"$key\" --hostname=claude-sandbox --ssh --accept-routes >/dev/null 2>&1";
    system($cmd);
    if ($? != 0) {
        log_msg("WARNUNG: tailscale up fehlgeschlagen");
    }
} else {
    system("tailscale set --ssh >/dev/null 2>&1");
}

if (system("tailscale status >/dev/null 2>&1") == 0) {
    my $ip_output = `tailscale ip -4 2>/dev/null`;
    my @ips = split(/\n/, $ip_output);
    my $ip = @ips ? $ips[0] : "?";
    chomp($ip);
    log_msg("im Tailnet: claude-sandbox ${ip} · SSH aktiv · SOCKS5 localhost:1055");
}

exit(0);

#!/usr/bin/perl
# collect_ist_gateway_a.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway1:scripts/collect_ist_gateway_a.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use POSIX qw(strftime);
use File::Path qw(make_path);
use File::Basename qw(basename);
use Cwd qw(realpath);

my $BASE_DIR = $ENV{'HOME'} . "/.openclaw";
my $OUT_DIR = $BASE_DIR . "/workspace/vscode";
my $NOW_UTC = strftime("%Y-%m-%dT%H:%M:%SZ", gmtime);
my $NOW_LOCAL = strftime("%Y-%m-%d %H:%M:%S %Z", localtime);
my $TS = strftime("%Y%m%d-%H%M%S", localtime);

make_path($OUT_DIR) unless -d $OUT_DIR;

my $IST_FILE = "$OUT_DIR/IST-ZUSTAND_GATEWAY-A_NODE1.md";
my $INV_FILE = "$OUT_DIR/ARTEFAKT-INVENTAR_GATEWAY-A_NODE1.md";
my $CFG_FILE = "$OUT_DIR/OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-A_NODE1.md";
my $ENV_FILE = "$OUT_DIR/ENV-STATUS_GATEWAY-A_NODE1.md";
my $RUN_FILE = "$OUT_DIR/RUN-$TS.md";

my $OPENCLAW_JSON = "$BASE_DIR/openclaw.json";
my $ENV_DOT = "$BASE_DIR/.env";
my $ENV_SYSTEMD = "$BASE_DIR/gateway.systemd.env";
my $VSCODE_DIR = "$BASE_DIR/.vscode";

my $HOSTNAME_FQDN = `hostname -f 2>/dev/null` || `hostname`;
chomp $HOSTNAME_FQDN;
my $HOSTNAME_SHORT = `hostname`;
chomp $HOSTNAME_SHORT;
my $ARCH = `uname -m`;
chomp $ARCH;
my $KERNEL = `uname -r`;
chomp $KERNEL;
my $OS_PRETTY = "";
if (-f "/etc/os-release") {
    open my $fh, '<', '/etc/os-release';
    while (<$fh>) {
        if (/^PRETTY_NAME=(.*)/) {
            $OS_PRETTY = $1;
            $OS_PRETTY =~ s/^"(.*)"$/$1/;
            last;
        }
    }
    close $fh;
}
my $IPV4_ALL = `hostname -I 2>/dev/null`;
chomp $IPV4_ALL;
$IPV4_ALL =~ s/\s+$//;
my $PUBLIC_IP = `curl -4 -s --max-time 4 ifconfig.me 2>/dev/null`;
chomp $PUBLIC_IP;
my $TAILSCALE_IP = `tailscale ip -4 2>/dev/null | head -n1`;
chomp $TAILSCALE_IP;
my $OPENCLAW_VER = `openclaw --version 2>/dev/null`;
chomp $OPENCLAW_VER;
my $NODE_VER = `node -v 2>/dev/null`;
chomp $NODE_VER;

$PUBLIC_IP = "(nicht ermittelt)" if !$PUBLIC_IP;
$TAILSCALE_IP = "(nicht ermittelt)" if !$TAILSCALE_IP;
$OPENCLAW_VER = "(nicht ermittelt)" if !$OPENCLAW_VER;
$NODE_VER = "(nicht ermittelt)" if !$NODE_VER;

open my $ist_fh, '>', $IST_FILE or die "Cannot write to $IST_FILE: $!";
print $ist_fh "# IST-Zustand: Gateway A / Node 1\n\n";
print $ist_fh "Stand (lokal): $NOW_LOCAL  \n";
print $ist_fh "Stand (UTC): $NOW_UTC\n\n";
print $ist_fh "## 1) Identitaet & System\n\n";
print $ist_fh "- Gateway: **A**\n";
print $ist_fh "- Node: **1**\n";
print $ist_fh "- Hostname (short): `$HOSTNAME_SHORT`\n";
print $ist_fh "- Hostname (FQDN): `$HOSTNAME_FQDN`\n";
print $ist_fh "- Architektur: `$ARCH`\n";
print $ist_fh "- Kernel: `$KERNEL`\n";
print $ist_fh "- OS: `$OS_PRETTY`\n";
print $ist_fh "- IPv4 (lokal): `$IPV4_ALL`\n";
print $ist_fh "- Public IPv4: `$PUBLIC_IP`\n";
print $ist_fh "- Tailscale IPv4: `$TAILSCALE_IP`\n";
print $ist_fh "- OpenClaw Version: `$OPENCLAW_VER`\n";
print $ist_fh "- Node.js Version: `$NODE_VER`\n\n";
print $ist_fh "## 2) Arbeitsverzeichnisse\n\n";
print $ist_fh "- Basis: `$BASE_DIR`\n";
print $ist_fh "- Funktionell VSCode: `$VSCODE_DIR`\n";
print $ist_fh "- Workspace Doku: `$OUT_DIR`\n\n";
print $ist_fh "## 3) Kernartefakte (Existenz)\n\n";

sub file_status {
    my ($file) = @_;
    return (-f $file) ? "vorhanden" : "fehlt";
}

print $ist_fh "- `$OPENCLAW_JSON`: " . file_status($OPENCLAW_JSON) . "\n";
print $ist_fh "- `$ENV_DOT`: " . file_status($ENV_DOT) . "\n";
print $ist_fh "- `$ENV_SYSTEMD`: " . file_status($ENV_SYSTEMD) . "\n";
print $ist_fh "- `${BASE_DIR}/plugins/installs.json`: " . file_status("$BASE_DIR/plugins/installs.json") . "\n";
print $ist_fh "- `${BASE_DIR}/plugin-skills`: " . ((-d "$BASE_DIR/plugin-skills") ? "vorhanden" : "fehlt") . "\n";
close $ist_fh;

open my $inv_fh, '>', $INV_FILE or die "Cannot write to $INV_FILE: $!";
print $inv_fh "# Artefakt-Inventar: Gateway A / Node 1\n\n";
print $inv_fh "Stand: $NOW_LOCAL\n\n";
print $inv_fh "## Top-Level in ~/.openclaw\n\n";
print $inv_fh '```text' . "\n";
opendir(my $dir, $BASE_DIR);
my @top_level = readdir($dir);
closedir($dir);
for my $item (sort @top_level) {
    next if $item eq '.' || $item eq '..';
    print $inv_fh "$item\n";
}
print $inv_fh "```\n\n";

print $inv_fh "## ~/.openclaw/.vscode\n\n";
print $inv_fh '```text' . "\n";
if (-d $VSCODE_DIR) {
    opendir(my $vscode_dir, $VSCODE_DIR);
    my @vscode_items = readdir($vscode_dir);
    closedir($vscode_dir);
    for my $item (sort @vscode_items) {
        next if $item eq '.' || $item eq '..';
        my $full_path = "$VSCODE_DIR/$item";
        my @stat = stat($full_path);
        printf $inv_fh "%s %s %s %s\n", 
               sprintf("%9s", $stat[2] & 0777),
               scalar(localtime($stat[9])),
               $item,
               (-d $full_path) ? '/' : '';
    }
} else {
    print $inv_fh "(nicht vorhanden)\n";
}
print $inv_fh "```\n\n";

print $inv_fh "## plugin-skills/\n\n";
print $inv_fh '```text' . "\n";
if (-d "$BASE_DIR/plugin-skills") {
    opendir(my $skills_dir, "$BASE_DIR/plugin-skills");
    my @skills_items = readdir($skills_dir);
    closedir($skills_dir);
    for my $item (sort @skills_items) {
        next if $item eq '.' || $item eq '..';
        print $inv_fh "$item\n";
    }
} else {
    print $inv_fh "(nicht vorhanden)\n";
}
print $inv_fh "```\n\n";

print $inv_fh "## openclaw.json Backups\n\n";
print $inv_fh '```text' . "\n";
my @backups = glob("$BASE_DIR/openclaw.json.bak*");
if (@backups) {
    for my $backup (@backups) {
        print $inv_fh basename($backup) . "\n";
    }
} else {
    print $inv_fh "(keine gefunden)\n";
}
print $inv_fh "```\n";
close $inv_fh;

open my $cfg_fh, '>', $CFG_FILE or die "Cannot write to $CFG_FILE: $!";
print $cfg_fh "# OpenClaw Config Snapshot: Gateway A / Node 1\n\n";
print $cfg_fh "Stand: $NOW_LOCAL\n\n";
print $cfg_fh "## Schluesselpositionen (grep)\n\n";
print $cfg_fh '```text' . "\n";
if (-f $OPENCLAW_JSON) {
    open my $json_fh, '<', $OPENCLAW_JSON;
    my $line_num = 1;
    while (my $line = <$json_fh>) {
        if ($line =~ /"gateway"|\"session\"|\"dmScope\"|\"auth\"|\"secrets\"|\"tools\"|\"plugins\"|\"profile\"|\"alsoAllow\"|\"denyCommands\"/) {
            print $cfg_fh "$line_num: $line";
        }
        $line_num++;
    }
    close $json_fh;
} else {
    print $cfg_fh "openclaw.json fehlt\n";
}
print $cfg_fh "```\n\n";

print $cfg_fh "## Ausschnitt gateway/session/auth\n\n";
print $cfg_fh '```json' . "\n";
if (-f $OPENCLAW_JSON) {
    open my $json_fh, '<', $OPENCLAW_JSON;
    my $line_num = 1;
    while (my $line = <$json_fh>) {
        if ($line_num >= 580 && $line_num <= 780) {
            print $cfg_fh $line;
        }
        last if $line_num > 780;
        $line_num++;
    }
    close $json_fh;
} else {
    print $cfg_fh '{ "error": "openclaw.json fehlt" }' . "\n";
}
print $cfg_fh "```\n";
close $cfg_fh;

open my $env_fh, '>', $ENV_FILE or die "Cannot write to $ENV_FILE: $!";
print $env_fh "# ENV-Status: Gateway A / Node 1\n\n";
print $env_fh "Stand: $NOW_LOCAL\n\n";
print $env_fh "## Dateien\n\n";
print $env_fh '```text' . "\n";
if (-f $ENV_DOT && -f $ENV_SYSTEMD) {
    my @stat_dot = stat($ENV_DOT);
    my @stat_systemd = stat($ENV_SYSTEMD);
    printf $env_fh "%9s %s %s\n", 
           sprintf("%o", $stat_dot[2] & 0777), 
           scalar(localtime($stat_dot[9])), 
           basename($ENV_DOT);
    printf $env_fh "%9s %s %s\n", 
           sprintf("%o", $stat_systemd[2] & 0777), 
           scalar(localtime($stat_systemd[9])), 
           basename($ENV_SYSTEMD);
} elsif (-f $ENV_DOT) {
    my @stat_dot = stat($ENV_DOT);
    printf $env_fh "%9s %s %s\n", 
           sprintf("%o", $stat_dot[2] & 0777), 
           scalar(localtime($stat_dot[9])), 
           basename($ENV_DOT);
} elsif (-f $ENV_SYSTEMD) {
    my @stat_systemd = stat($ENV_SYSTEMD);
    printf $env_fh "%9s %s %s\n", 
           sprintf("%o", $stat_systemd[2] & 0777), 
           scalar(localtime($stat_systemd[9])), 
           basename($ENV_SYSTEMD);
}
print $env_fh "```\n\n";

print $env_fh "## .env (vollstaendig)\n\n";
print $env_fh '```dotenv' . "\n";
if (-f $ENV_DOT) {
    open my $dot_fh, '<', $ENV_DOT;
    while (my $line = <$dot_fh>) {
        print $env_fh $line;
    }
    close $dot_fh;
} else {
    print $env_fh "# .env fehlt\n";
}
print $env_fh "```\n\n";

print $env_fh "## gateway.systemd.env (vollstaendig)\n\n";
print $env_fh '```dotenv' . "\n";
if (-f $ENV_SYSTEMD) {
    open my $sysd_fh, '<', $ENV_SYSTEMD;
    while (my $line = <$sysd_fh>) {
        print $env_fh $line;
    }
    close $sysd_fh;
} else {
    print $env_fh "# gateway.systemd.env fehlt\n";
}
print $env_fh "```\n";
close $env_fh;

open my $run_fh, '>', $RUN_FILE or die "Cannot write to $RUN_FILE: $!";
print $run_fh "# Laufprotokoll Gateway A / Node 1\n\n";
print $run_fh "- Zeit (lokal): $NOW_LOCAL\n";
print $run_fh "- Zeit (UTC): $NOW_UTC\n";
print $run_fh "- Script: " . realpath($0) . "\n\n";
print $run_fh "## Erzeugte Dateien\n\n";
print $run_fh "- " . basename($IST_FILE) . "\n";
print $run_fh "- " . basename($INV_FILE) . "\n";
print $run_fh "- " . basename($CFG_FILE) . "\n";
print $run_fh "- " . basename($ENV_FILE) . "\n";
close $run_fh;

print "OK: IST-Zustand erfasst.\n";
opendir(my $out_dir, $OUT_DIR);
my @files = readdir($out_dir);
closedir($out_dir);
for my $file (sort @files) {
    next if $file eq '.' || $file eq '..';
    print "- $file\n";
}

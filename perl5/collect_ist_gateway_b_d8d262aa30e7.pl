#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "cf7fe5a32b432c3db0fe52c1b18d592093fbcc7f0da774666c2d44e057f8522d", "source_sha256": "da890cc26fb848b78b6a85373d6cfa4e08f6e7c2002921e1c0247960b8b361d7", "target_language": "perl5"}
# collect_ist_gateway_b.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway2:scripts/collect_ist_gateway_b.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Path qw(make_path);
use File::Basename;
use POSIX qw(strftime);

my $BASE_DIR = $ENV{'HOME'} . "/.openclaw";
my $OUT_DIR = $BASE_DIR . "/workspace/vscode";
my $NOW_UTC = strftime("%Y-%m-%dT%H:%M:%SZ", gmtime);
my $NOW_LOCAL = strftime("%Y-%m-%d %H:%M:%S %Z", localtime);
my $TS = strftime("%Y%m%d-%H%M%S", localtime);

make_path($OUT_DIR) unless -d $OUT_DIR;

my $IST_FILE = $OUT_DIR . "/IST-ZUSTAND_GATEWAY-B_NODE7.md";
my $INV_FILE = $OUT_DIR . "/ARTEFAKT-INVENTAR_GATEWAY-B_NODE7.md";
my $CFG_FILE = $OUT_DIR . "/OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-B_NODE7.md";
my $ENV_FILE = $OUT_DIR . "/ENV-STATUS_GATEWAY-B_NODE7.md";
my $RUN_FILE = $OUT_DIR . "/RUN-" . $TS . ".md";

my $OPENCLAW_JSON = $BASE_DIR . "/openclaw.json";
my $ENV_DOT = $BASE_DIR . "/.env";
my $ENV_SYSTEMD = $BASE_DIR . "/gateway.systemd.env";
my $VSCODE_DIR = $BASE_DIR . "/.vscode";

my $HOSTNAME_FQDN = `hostname -f 2>/dev/null` || `hostname`;
chomp $HOSTNAME_FQDN;
$HOSTNAME_FQDN = "(nicht ermittelt)" if $HOSTNAME_FQDN eq "";

my $HOSTNAME_SHORT = `hostname`;
chomp $HOSTNAME_SHORT;

my $ARCH = `uname -m`;
chomp $ARCH;

my $KERNEL = `uname -r`;
chomp $KERNEL;

my $OS_PRETTY = "";
if (-f "/etc/os-release") {
    open(my $fh, '<', '/etc/os-release') or warn "Could not open /etc/os-release: $!";
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
$PUBLIC_IP = "(nicht ermittelt)" if $PUBLIC_IP eq "";

my $TAILSCALE_IP = `tailscale ip -4 2>/dev/null | head -n1`;
chomp $TAILSCALE_IP;
$TAILSCALE_IP = "(nicht ermittelt)" if $TAILSCALE_IP eq "";

my $OPENCLAW_VER = `openclaw --version 2>/dev/null`;
chomp $OPENCLAW_VER;
$OPENCLAW_VER = "(nicht ermittelt)" if $OPENCLAW_VER eq "";

my $NODE_VER = `node -v 2>/dev/null`;
chomp $NODE_VER;
$NODE_VER = "(nicht ermittelt)" if $NODE_VER eq "";

open(my $ist_fh, '>', $IST_FILE) or die "Cannot write to $IST_FILE: $!";

print $ist_fh "# IST-Zustand: Gateway B / Node 7\n\n";
print $ist_fh "Stand (lokal): $NOW_LOCAL  \n";
print $ist_fh "Stand (UTC): $NOW_UTC\n\n";
print $ist_fh "## 1) Identität & System\n\n";
print $ist_fh "- Gateway: **B**\n";
print $ist_fh "- Node: **7**\n";
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
print $ist_fh "- `$OPENCLAW_JSON`: " . (-f $OPENCLAW_JSON ? "vorhanden" : "fehlt") . "\n";
print $ist_fh "- `$ENV_DOT`: " . (-f $ENV_DOT ? "vorhanden" : "fehlt") . "\n";
print $ist_fh "- `$ENV_SYSTEMD`: " . (-f $ENV_SYSTEMD ? "vorhanden" : "fehlt") . "\n";
print $ist_fh "- `$BASE_DIR/plugins/installs.json`: " . (-f "$BASE_DIR/plugins/installs.json" ? "vorhanden" : "fehlt") . "\n";
print $ist_fh "- `$BASE_DIR/plugin-skills`: " . (-d "$BASE_DIR/plugin-skills" ? "vorhanden" : "fehlt") . "\n\n";
print $ist_fh "## 4) Hinweis\n\n";
print $ist_fh "Diese Datei wird bei jedem Lauf neu geschrieben.\n";
print $ist_fh "Zusätzlich wird ein Laufprotokoll als `RUN-*.md` erzeugt.\n";

close $ist_fh;

open(my $inv_fh, '>', $INV_FILE) or die "Cannot write to $INV_FILE: $!";

print $inv_fh "# Artefakt-Inventar: Gateway B / Node 7\n\n";
print $inv_fh "Stand: $NOW_LOCAL\n\n";
print $inv_fh "## Top-Level in ~/.openclaw\n\n";
print $inv_fh '```text' . "\n";
if (opendir(my $dir, $BASE_DIR)) {
    my @files = readdir($dir);
    closedir($dir);
    for my $file (@files) {
        next if $file eq '.' || $file eq '..';
        print $inv_fh "$file\n";
    }
} else {
    print $inv_fh "(nicht lesbar)\n";
}
print $inv_fh '```' . "\n\n";

print $inv_fh "## ~/.openclaw/.vscode\n\n";
print $inv_fh '```text' . "\n";
if (-d $VSCODE_DIR) {
    opendir(my $dir, $VSCODE_DIR) or warn "Cannot open directory $VSCODE_DIR: $!";
    my @files = readdir($dir);
    closedir($dir);
    for my $file (@files) {
        next if $file eq '.' || $file eq '..';
        my $full_path = "$VSCODE_DIR/$file";
        my @stat = stat($full_path);
        printf $inv_fh "%s %s %s\n", 
               (-d $full_path ? 'd' : '-'), 
               (defined $stat[2] ? sprintf("%04o", $stat[2] & 07777) : '----'),
               $file;
    }
} else {
    print $inv_fh "(nicht vorhanden)\n";
}
print $inv_fh '```' . "\n\n";

print $inv_fh "## plugin-skills/\n\n";
print $inv_fh '```text' . "\n";
if (-d "$BASE_DIR/plugin-skills") {
    opendir(my $dir, "$BASE_DIR/plugin-skills") or warn "Cannot open directory $BASE_DIR/plugin-skills: $!";
    my @files = readdir($dir);
    closedir($dir);
    for my $file (@files) {
        next if $file eq '.' || $file eq '..';
        print $inv_fh "$file\n";
    }
} else {
    print $inv_fh "(nicht vorhanden)\n";
}
print $inv_fh '```' . "\n\n";

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
print $inv_fh '```' . "\n";

close $inv_fh;

open(my $cfg_fh, '>', $CFG_FILE) or die "Cannot write to $CFG_FILE: $!";

print $cfg_fh "# OpenClaw Config Snapshot: Gateway B / Node 7\n\n";
print $cfg_fh "Stand: $NOW_LOCAL\n\n";
print $cfg_fh "## Schlüsselpositionen (grep)\n\n";
print $cfg_fh '```text' . "\n";
if (-f $OPENCLAW_JSON) {
    open(my $json_fh, '<', $OPENCLAW_JSON) or warn "Cannot read $OPENCLAW_JSON: $!";
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
print $cfg_fh '```' . "\n\n";

print $cfg_fh "## Ausschnitt gateway/session/auth (ungefiltert, betriebsnah)\n\n";
print $cfg_fh '```json' . "\n";
if (-f $OPENCLAW_JSON) {
    open(my $json_fh, '<', $OPENCLAW_JSON) or warn "Cannot read $OPENCLAW_JSON: $!";
    my $line_count = 0;
    while (my $line = <$json_fh>) {
        $line_count++;
        last if $line_count > 780;
        print $cfg_fh $line if $line_count >= 580;
    }
    close $json_fh;
} else {
    print $cfg_fh "{ \"error\": \"openclaw.json fehlt\" }\n";
}
print $cfg_fh '```' . "\n";

close $cfg_fh;

open(my $env_fh, '>', $ENV_FILE) or die "Cannot write to $ENV_FILE: $!";

print $env_fh "# ENV-Status: Gateway B / Node 7\n\n";
print $env_fh "Stand: $NOW_LOCAL\n\n";
print $env_fh "## Dateien\n\n";
print $env_fh '```text' . "\n";
for my $file ($ENV_DOT, $ENV_SYSTEMD) {
    if (-f $file) {
        my @stat = stat($file);
        if (@stat) {
            my $mode = sprintf("%04o", $stat[2] & 07777);
            print $env_fh "$mode $file\n";
        }
    }
}
print $env_fh '```' . "\n\n";

print $env_fh "## .env (vollständig, ungefiltert)\n\n";
print $env_fh '```dotenv' . "\n";
if (-f $ENV_DOT) {
    open(my $dot_fh, '<', $ENV_DOT) or warn "Cannot read $ENV_DOT: $!";
    while (my $line = <$dot_fh>) {
        print $env_fh $line;
    }
    close $dot_fh;
} else {
    print $env_fh "# .env fehlt\n";
}
print $env_fh '```' . "\n\n";

print $env_fh "## gateway.systemd.env (vollständig, ungefiltert)\n\n";
print $env_fh '```dotenv' . "\n";
if (-f $ENV_SYSTEMD) {
    open(my $sys_fh, '<', $ENV_SYSTEMD) or warn "Cannot read $ENV_SYSTEMD: $!";
    while (my $line = <$sys_fh>) {
        print $env_fh $line;
    }
    close $sys_fh;
} else {
    print $env_fh "# gateway.systemd.env fehlt\n";
}
print $env_fh '```' . "\n";

close $env_fh;

open(my $run_fh, '>', $RUN_FILE) or die "Cannot write to $RUN_FILE: $!";

print $run_fh "# Laufprotokoll Gateway B / Node 7\n\n";
print $run_fh "- Zeit (lokal): $NOW_LOCAL\n";
print $run_fh "- Zeit (UTC): $NOW_UTC\n";
print $run_fh "- Script: $0\n\n";
print $run_fh "## Erzeugte Dateien\n\n";
print $run_fh "- " . basename($IST_FILE) . "\n";
print $run_fh "- " . basename($INV_FILE) . "\n";
print $run_fh "- " . basename($CFG_FILE) . "\n";
print $run_fh "- " . basename($ENV_FILE) . "\n";

close $run_fh;

print "OK: IST-Zustand erfasst.\n";
print "Ausgabeordner: $OUT_DIR\n";
print "Dateien:\n";

opendir(my $out_dir, $OUT_DIR) or die "Cannot open directory $OUT_DIR: $!";
my @files = readdir($out_dir);
closedir($out_dir);

for my $file (@files) {
    next if $file eq '.' || $file eq '..';
    print "- $file\n";
}

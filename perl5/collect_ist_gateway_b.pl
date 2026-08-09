#!/usr/bin/env perl
# collect_ist_gateway_b.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway2:scripts/collect_ist_gateway_b.sh
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

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

my $IST_FILE = "$OUT_DIR/IST-ZUSTAND_GATEWAY-B_NODE7.md";
my $INV_FILE = "$OUT_DIR/ARTEFAKT-INVENTAR_GATEWAY-B_NODE7.md";
my $CFG_FILE = "$OUT_DIR/OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-B_NODE7.md";
my $ENV_FILE = "$OUT_DIR/ENV-STATUS_GATEWAY-B_NODE7.md";
my $RUN_FILE = "$OUT_DIR/RUN-$TS.md";

my $OPENCLAW_JSON = "$BASE_DIR/openclaw.json";
my $ENV_DOT = "$BASE_DIR/.env";
my $ENV_SYSTEMD = "$BASE_DIR/gateway.systemd.env";
my $VSCODE_DIR = "$BASE_DIR/.vscode";

sub safe_backtick {
    my ($cmd) = @_;
    my $result = `$cmd 2>/dev/null`;
    chomp $result;
    return $result // "";
}

my $HOSTNAME_FQDN = safe_backtick("hostname -f") || safe_backtick("hostname");
my $HOSTNAME_SHORT = safe_backtick("hostname");
my $ARCH = safe_backtick("uname -m");
my $KERNEL = safe_backtick("uname -r");
my $OS_PRETTY = safe_backtick('grep "^PRETTY_NAME=" /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d \'"\'');
my $IPV4_ALL = join(" ", split(/\s+/, safe_backtick("hostname -I")));
my $PUBLIC_IP = safe_backtick("curl -4 -s --max-time 4 ifconfig.me") || "(nicht ermittelt)";
my $TAILSCALE_IP = safe_backtick("tailscale ip -4") || "(nicht ermittelt)";
my $OPENCLAW_VER = safe_backtick("openclaw --version") || "(nicht ermittelt)";
my $NODE_VER = safe_backtick("node -v") || "(nicht ermittelt)";

open(my $ist_fh, '>', $IST_FILE) or die "Could not open file '$IST_FILE': $!";
print $ist_fh <<EOF;
# IST-Zustand: Gateway B / Node 7

Stand (lokal): $NOW_LOCAL  
Stand (UTC): $NOW_UTC

## 1) Identität & System

- Gateway: **B**
- Node: **7**
- Hostname (short): \`$HOSTNAME_SHORT\`
- Hostname (FQDN): \`$HOSTNAME_FQDN\`
- Architektur: \`$ARCH\`
- Kernel: \`$KERNEL\`
- OS: \`$OS_PRETTY\`
- IPv4 (lokal): \`$IPV4_ALL\`
- Public IPv4: \`$PUBLIC_IP\`
- Tailscale IPv4: \`$TAILSCALE_IP\`
- OpenClaw Version: \`$OPENCLAW_VER\`
- Node.js Version: \`$NODE_VER\`

## 2) Arbeitsverzeichnisse

- Basis: \`$BASE_DIR\`
- Funktionell VSCode: \`$VSCODE_DIR\`
- Workspace Doku: \`$OUT_DIR\`

## 3) Kernartefakte (Existenz)

- \`$OPENCLAW_JSON\`: @{[(-f $OPENCLAW_JSON) ? "vorhanden" : "fehlt"]}
- \`$ENV_DOT\`: @{[(-f $ENV_DOT) ? "vorhanden" : "fehlt"]}
- \`$ENV_SYSTEMD\`: @{[(-f $ENV_SYSTEMD) ? "vorhanden" : "fehlt"]}
- \`$BASE_DIR/plugins/installs.json\`: @{[(-f "$BASE_DIR/plugins/installs.json") ? "vorhanden" : "fehlt"]}
- \`$BASE_DIR/plugin-skills\`: @{[(-d "$BASE_DIR/plugin-skills") ? "vorhanden" : "fehlt"]}

## 4) Hinweis

Diese Datei wird bei jedem Lauf neu geschrieben.
Zusätzlich wird ein Laufprotokoll als \`RUN-*.md\` erzeugt.
EOF
close($ist_fh);

open(my $inv_fh, '>', $INV_FILE) or die "Could not open file '$INV_FILE': $!";
print $inv_fh "# Artefakt-Inventar: Gateway B / Node 7\n\n";
print $inv_fh "Stand: $NOW_LOCAL\n\n";
print $inv_fh "## Top-Level in ~/.openclaw\n\n";
print $inv_fh '```text' . "\n";
if (opendir(my $dir, $BASE_DIR)) {
    while (readdir($dir)) {
        next if /^\.\.?$/;
        print $inv_fh "$_\n";
    }
    closedir($dir);
}
print $inv_fh "```\n\n";
print $inv_fh "## ~/.openclaw/.vscode\n\n";
print $inv_fh '```text' . "\n";
if (-d $VSCODE_DIR) {
    opendir(my $dir, $VSCODE_DIR) or die "Cannot opendir $VSCODE_DIR: $!";
    my @files = readdir($dir);
    closedir($dir);
    for my $file (@files) {
        next if $file eq '.' || $file eq '..';
        my $full_path = "$VSCODE_DIR/$file";
        my @stat = stat($full_path);
        printf $inv_fh "%-10s %-5d %-5d %-8d %s %s\n", 
            sprintf("%04o", ($stat[2] & 07777)), 
            $stat[5], 
            $stat[4], 
            $stat[7], 
            strftime("%b %d %H:%M", localtime($stat[9])), 
            $file;
    }
} else {
    print $inv_fh "(nicht vorhanden)\n";
}
print $inv_fh "```\n\n";
print $inv_fh "## plugin-skills/\n\n";
print $inv_fh '```text' . "\n";
if (-d "$BASE_DIR/plugin-skills") {
    opendir(my $dir, "$BASE_DIR/plugin-skills") or die "Cannot opendir $BASE_DIR/plugin-skills: $!";
    while (readdir($dir)) {
        next if /^\.\.?$/;
        print $inv_fh "$_\n";
    }
    closedir($dir);
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
close($inv_fh);

open(my $cfg_fh, '>', $CFG_FILE) or die "Could not open file '$CFG_FILE': $!";
print $cfg_fh "# OpenClaw Config Snapshot: Gateway B / Node 7\n\n";
print $cfg_fh "Stand: $NOW_LOCAL\n\n";
print $cfg_fh "## Schlüsselpositionen (grep)\n\n";
print $cfg_fh '```text' . "\n";
if (-f $OPENCLAW_JSON) {
    open(my $fh, '<', $OPENCLAW_JSON) or die "Cannot read $OPENCLAW_JSON: $!";
    my $line_num = 1;
    while (my $line = <$fh>) {
        if ($line =~ /"(gateway|session|dmScope|auth|secrets|tools|plugins|profile|alsoAllow|denyCommands)"/) {
            print $cfg_fh "$line_num:$line";
        }
        $line_num++;
    }
    close($fh);
} else {
    print $cfg_fh "openclaw.json fehlt\n";
}
print $cfg_fh "```\n\n";
print $cfg_fh "## Ausschnitt gateway/session/auth (ungefiltert, betriebsnah)\n\n";
print $cfg_fh '```json' . "\n";
if (-f $OPENCLAW_JSON) {
    open(my $fh, '<', $OPENCLAW_JSON) or die "Cannot read $OPENCLAW_JSON: $!";
    my $count = 0;
    while (my $line = <$fh>) {
        $count++;
        last if $count > 780;
        print $cfg_fh $line if $count >= 580;
    }
    close($fh);
} else {
    print $cfg_fh "{ \"error\": \"openclaw.json fehlt\" }\n";
}
print $cfg_fh "```\n";
close($cfg_fh);

open(my $env_fh, '>', $ENV_FILE) or die "Could not open file '$ENV_FILE': $!";
print $env_fh "# ENV-Status: Gateway B / Node 7\n\n";
print $env_fh "Stand: $NOW_LOCAL\n\n";
print $env_fh "## Dateien\n\n";
print $env_fh '```text' . "\n";
for my $file ($ENV_DOT, $ENV_SYSTEMD) {
    if (-e $file) {
        my @stat = stat($file);
        printf $env_fh "%-10s %-5d %-5d %-8d %s %s\n", 
            sprintf("%04o", ($stat[2] & 07777)), 
            $stat[5], 
            $stat[4], 
            $stat[7], 
            strftime("%b %d %H:%M", localtime($stat[9])), 
            basename($file);
    }
}
print $env_fh "```\n\n";
print $env_fh "## .env (vollständig, ungefiltert)\n\n";
print $env_fh '```dotenv' . "\n";
if (-f $ENV_DOT) {
    open(my $fh, '<', $ENV_DOT) or die "Cannot read $ENV_DOT: $!";
    print $env_fh do { local $/; <$fh> };
    close($fh);
} else {
    print $env_fh "# .env fehlt\n";
}
print $env_fh "```\n\n";
print $env_fh "## gateway.systemd.env (vollständig, ungefiltert)\n\n";
print $env_fh '```dotenv' . "\n";
if (-f $ENV_SYSTEMD) {
    open(my $fh, '<', $ENV_SYSTEMD) or die "Cannot read $ENV_SYSTEMD: $!";
    print $env_fh do { local $/; <$fh> };
    close($fh);
} else {
    print $env_fh "# gateway.systemd.env fehlt\n";
}
print $env_fh "```\n";
close($env_fh);

open(my $run_fh, '>', $RUN_FILE) or die "Could not open file '$RUN_FILE': $!";
print $run_fh <<EOF;
# Laufprotokoll Gateway B / Node 7

- Zeit (lokal): $NOW_LOCAL
- Zeit (UTC): $NOW_UTC
- Script: $0

## Erzeugte Dateien

- @{[basename($IST_FILE)]}
- @{[basename($INV_FILE)]}
- @{[basename($CFG_FILE)]}
- @{[basename($ENV_FILE)]}

EOF
close($run_fh);

print "OK: IST-Zustand erfasst.\n";
print "Ausgabeordner: $OUT_DIR\n";
print "Dateien:\n";

opendir(my $dir, $OUT_DIR) or die "Cannot opendir $OUT_DIR: $!";
while (readdir($dir)) {
    next if /^\.\.?$/;
    print "- $_\n";
}
closedir($dir);

#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "531cf1b74c5d703e8c08017c416c1d92bcdd6fa94d24b0cd47038150a25f6b17", "source_sha256": "47064dbc7b32c01d57d42222f8cc3ac7caf9c8d82b98029dc5fc6ecb0d32f2c9", "target_language": "perl5"}
# collect_ist_gateway_a.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway1:scripts/collect_ist_gateway_a.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use POSIX qw(strftime);
use File::Path qw(make_path);
use File::Basename qw(basename dirname);
use Cwd qw(realpath getcwd);

my $home = $ENV{'HOME'} // '/root';
my $base_dir = "$home/.openclaw";
my $out_dir = "$base_dir/workspace/vscode";

my $now_utc = strftime("%Y-%m-%dT%H:%M:%SZ", gmtime);
my $now_local = strftime("%Y-%m-%d %H:%M:%S %Z", localtime);
my $ts = strftime("%Y%m%d-%H%M%S", localtime);

make_path($out_dir) unless -d $out_dir;

my $ist_file = "$out_dir/IST-ZUSTAND_GATEWAY-A_NODE1.md";
my $inv_file = "$out_dir/ARTEFAKT-INVENTAR_GATEWAY-A_NODE1.md";
my $cfg_file = "$out_dir/OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-A_NODE1.md";
my $env_file = "$out_dir/ENV-STATUS_GATEWAY-A_NODE1.md";
my $run_file = "$out_dir/RUN-$ts.md";

my $openclaw_json = "$base_dir/openclaw.json";
my $env_dot = "$base_dir/.env";
my $env_systemd = "$base_dir/gateway.systemd.env";
my $vscode_dir = "$base_dir/.vscode";

my $hostname_fqdn = `hostname -f 2>/dev/null` || `hostname`;
chomp $hostname_fqdn;
my $hostname_short = `hostname`;
chomp $hostname_short;
my $arch = `uname -m`;
chomp $arch;
my $kernel = `uname -r`;
chomp $kernel;

my $os_pretty = "";
if (-f "/etc/os-release") {
    open(my $fh, '<', '/etc/os-release') or warn "Could not open /etc/os-release: $!";
    while (<$fh>) {
        if (/^PRETTY_NAME=(.*)/) {
            $os_pretty = $1;
            $os_pretty =~ s/^"(.*)"$/$1/;
            last;
        }
    }
    close $fh;
}

my $ipv4_all = `hostname -I 2>/dev/null`;
chomp $ipv4_all;
$ipv4_all =~ s/\s+$//;
$ipv4_all =~ s/^\s+//;
$ipv4_all =~ s/\s+/ /g;

my $public_ip = `curl -4 -s --max-time 4 ifconfig.me 2>/dev/null`;
chomp $public_ip;
$public_ip = "(nicht ermittelt)" if !$public_ip;

my $tailscale_ip = `tailscale ip -4 2>/dev/null | head -n1`;
chomp $tailscale_ip;
$tailscale_ip = "(nicht ermittelt)" if !$tailscale_ip;

my $openclaw_ver = `openclaw --version 2>/dev/null`;
chomp $openclaw_ver;
$openclaw_ver = "(nicht ermittelt)" if !$openclaw_ver;

my $node_ver = `node -v 2>/dev/null`;
chomp $node_ver;
$node_ver = "(nicht ermittelt)" if !$node_ver;

open(my $ist_fh, '>', $ist_file) or die "Cannot write to $ist_file: $!";

print $ist_fh <<EOM;
# IST-Zustand: Gateway A / Node 1

Stand (lokal): $now_local  
Stand (UTC): $now_utc

## 1) Identitaet & System

- Gateway: **A**
- Node: **1**
- Hostname (short): \`$hostname_short\`
- Hostname (FQDN): \`$hostname_fqdn\`
- Architektur: \`$arch\`
- Kernel: \`$kernel\`
- OS: \`$os_pretty\`
- IPv4 (lokal): \`$ipv4_all\`
- Public IPv4: \`$public_ip\`
- Tailscale IPv4: \`$tailscale_ip\`
- OpenClaw Version: \`$openclaw_ver\`
- Node.js Version: \`$node_ver\`

## 2) Arbeitsverzeichnisse

- Basis: \`$base_dir\`
- Funktionell VSCode: \`$vscode_dir\`
- Workspace Doku: \`$out_dir\`

## 3) Kernartefakte (Existenz)

- \`$openclaw_json\`: @{[(-f $openclaw_json ? "vorhanden" : "fehlt")]}
- \`$env_dot\`: @{[(-f $env_dot ? "vorhanden" : "fehlt")]}
- \`$env_systemd\`: @{[(-f $env_systemd ? "vorhanden" : "fehlt")]}
- \`$base_dir/plugins/installs.json\`: @{[(-f "$base_dir/plugins/installs.json" ? "vorhanden" : "fehlt")]}
- \`$base_dir/plugin-skills\`: @{[(-d "$base_dir/plugin-skills" ? "vorhanden" : "fehlt")]}
EOM

close $ist_fh;

open(my $inv_fh, '>', $inv_file) or die "Cannot write to $inv_file: $!";

print $inv_fh "# Artefakt-Inventar: Gateway A / Node 1\n\n";
print $inv_fh "Stand: $now_local\n\n";
print $inv_fh "## Top-Level in ~/.openclaw\n\n";
print $inv_fh '```text' . "\n";

if (opendir(my $dir, $base_dir)) {
    my @files = readdir($dir);
    closedir($dir);
    for my $file (@files) {
        next if $file eq '.' || $file eq '..';
        print $inv_fh "$file\n";
    }
} else {
    print $inv_fh "Error reading directory: $!\n";
}

print $inv_fh "```\n\n";
print $inv_fh "## ~/.openclaw/.vscode\n\n";
print $inv_fh '```text' . "\n";

if (-d $vscode_dir) {
    opendir(my $dir, $vscode_dir) or warn "Cannot open $vscode_dir: $!";
    my @files = readdir($dir);
    closedir($dir);
    for my $file (@files) {
        next if $file eq '.' || $file eq '..';
        my $full_path = "$vscode_dir/$file";
        my @stat_info = stat($full_path);
        printf $inv_fh "%s %s %s %s %s %s %s\n", 
               (map { $_ // '' } @stat_info[2,3,4,5,7]),
               scalar(localtime($stat_info[9])),
               $file;
    }
} else {
    print $inv_fh "(nicht vorhanden)\n";
}

print $inv_fh "```\n\n";
print $inv_fh "## plugin-skills/\n\n";
print $inv_fh '```text' . "\n";

if (-d "$base_dir/plugin-skills") {
    opendir(my $dir, "$base_dir/plugin-skills") or warn "Cannot open plugin-skills: $!";
    my @files = readdir($dir);
    closedir($dir);
    for my $file (@files) {
        next if $file eq '.' || $file eq '..';
        print $inv_fh "$file\n";
    }
} else {
    print $inv_fh "(nicht vorhanden)\n";
}

print $inv_fh "```\n\n";
print $inv_fh "## openclaw.json Backups\n\n";
print $inv_fh '```text' . "\n";

my @backup_files = glob("$base_dir/openclaw.json.bak*");
if (@backup_files) {
    for my $file (@backup_files) {
        print $inv_fh basename($file) . "\n";
    }
} else {
    print $inv_fh "(keine gefunden)\n";
}

print $inv_fh "```\n";
close $inv_fh;

open(my $cfg_fh, '>', $cfg_file) or die "Cannot write to $cfg_file: $!";

print $cfg_fh "# OpenClaw Config Snapshot: Gateway A / Node 1\n\n";
print $cfg_fh "Stand: $now_local\n\n";
print $cfg_fh "## Schluesselpositionen (grep)\n\n";
print $cfg_fh '```text' . "\n";

if (-f $openclaw_json) {
    open(my $fh, '<', $openclaw_json) or warn "Cannot read $openclaw_json: $!";
    my $line_num = 1;
    while (my $line = <$fh>) {
        chomp $line;
        if ($line =~ /"gateway"|\"session\"|\"dmScope\"|\"auth\"|\"secrets\"|\"tools\"|\"plugins\"|\"profile\"|\"alsoAllow\"|\"denyCommands\"/) {
            print $cfg_fh "$line_num: $line\n";
        }
        $line_num++;
    }
    close $fh;
} else {
    print $cfg_fh "openclaw.json fehlt\n";
}

print $cfg_fh "```\n\n";
print $cfg_fh "## Ausschnitt gateway/session/auth\n\n";
print $cfg_fh '```json' . "\n";

if (-f $openclaw_json) {
    open(my $fh, '<', $openclaw_json) or warn "Cannot read $openclaw_json: $!";
    my $line_count = 0;
    while (my $line = <$fh>) {
        $line_count++;
        if ($line_count >= 580 && $line_count <= 780) {
            print $cfg_fh $line;
        }
        last if $line_count > 780;
    }
    close $fh;
} else {
    print $cfg_fh '{ "error": "openclaw.json fehlt" }' . "\n";
}

print $cfg_fh "```\n";
close $cfg_fh;

open(my $env_fh, '>', $env_file) or die "Cannot write to $env_file: $!";

print $env_fh "# ENV-Status: Gateway A / Node 1\n\n";
print $env_fh "Stand: $now_local\n\n";
print $env_fh "## Dateien\n\n";
print $env_fh '```text' . "\n";

for my $file ($env_dot, $env_systemd) {
    if (-f $file) {
        my @stat_info = stat($file);
        printf $env_fh "%s %s %s %s %s %s %s\n", 
               (map { $_ // '' } @stat_info[2,3,4,5,7]),
               scalar(localtime($stat_info[9])),
               basename($file);
    }
}

print $env_fh "```\n\n";
print $env_fh "## .env (vollstaendig)\n\n";
print $env_fh '```dotenv' . "\n";

if (-f $env_dot) {
    open(my $fh, '<', $env_dot) or warn "Cannot read $env_dot: $!";
    while (my $line = <$fh>) {
        print $env_fh $line;
    }
    close $fh;
} else {
    print $env_fh "# .env fehlt\n";
}

print $env_fh "```\n\n";
print $env_fh "## gateway.systemd.env (vollstaendig)\n\n";
print $env_fh '```dotenv' . "\n";

if (-f $env_systemd) {
    open(my $fh, '<', $env_systemd) or warn "Cannot read $env_systemd: $!";
    while (my $line = <$fh>) {
        print $env_fh $line;
    }
    close $fh;
} else {
    print $env_fh "# gateway.systemd.env fehlt\n";
}

print $env_fh "```\n";
close $env_fh;

open(my $run_fh, '>', $run_file) or die "Cannot write to $run_file: $!";

print $run_fh <<EOM;
# Laufprotokoll Gateway A / Node 1

- Zeit (lokal): $now_local
- Zeit (UTC): $now_utc
- Script: @{[realpath($0)]}

## Erzeugte Dateien

- @{[basename($ist_file)]}
- @{[basename($inv_file)]}
- @{[basename($cfg_file)]}
- @{[basename($env_file)]}
EOM

close $run_fh;

print "OK: IST-Zustand erfasst.\n";
opendir(my $dir, $out_dir) or warn "Cannot open $out_dir: $!";
my @files = readdir($dir);
closedir($dir);
for my $file (@files) {
    next if $file eq '.' || $file eq '..';
    print "- $file\n";
}

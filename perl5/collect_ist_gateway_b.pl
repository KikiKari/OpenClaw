#!/usr/bin/perl
# collect_ist_gateway_b.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway2:scripts/collect_ist_gateway_b.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use POSIX qw(strftime);
use File::Path qw(make_path);
use File::Basename qw(basename dirname);
use Cwd qw(realpath);

my $base_dir = $ENV{'HOME'} . "/.openclaw";
my $out_dir = $base_dir . "/workspace/vscode";

my $now_utc = strftime("%Y-%m-%dT%H:%M:%SZ", gmtime);
my $now_local = strftime("%Y-%m-%d %H:%M:%S %Z", localtime);
my $ts = strftime("%Y%m%d-%H%M%S", localtime);

make_path($out_dir) unless -d $out_dir;

my $ist_file = "$out_dir/IST-ZUSTAND_GATEWAY-B_NODE7.md";
my $inv_file = "$out_dir/ARTEFAKT-INVENTAR_GATEWAY-B_NODE7.md";
my $cfg_file = "$out_dir/OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-B_NODE7.md";
my $env_file = "$out_dir/ENV-STATUS_GATEWAY-B_NODE7.md";
my $run_file = "$out_dir/RUN-$ts.md";

my $openclaw_json = "$base_dir/openclaw.json";
my $env_dot = "$base_dir/.env";
my $env_systemd = "$base_dir/gateway.systemd.env";
my $vscode_dir = "$base_dir/.vscode";

my $hostname_fqdn = `hostname -f 2>/dev/null` || `hostname`;
chomp $hostname_fqdn;
$hostname_fqdn =~ s/\s+$//;

my $hostname_short = `hostname`;
chomp $hostname_short;
$hostname_short =~ s/\s+$//;

my $arch = `uname -m`;
chomp $arch;
$arch =~ s/\s+$//;

my $kernel = `uname -r`;
chomp $kernel;
$kernel =~ s/\s+$//;

my $os_pretty = "";
if (-f "/etc/os-release") {
    open(my $fh, '<', '/etc/os-release') or warn "Could not open /etc/os-release: $!";
    while (<$fh>) {
        if (/^PRETTY_NAME=(.*)/) {
            $os_pretty = $1;
            $os_pretty =~ s/^["']|["']$//g;
            last;
        }
    }
    close $fh;
}

my $ipv4_all = `hostname -I 2>/dev/null`;
chomp $ipv4_all;
$ipv4_all =~ s/\s+$//;
$ipv4_all =~ s/^\s+|\s+$//g;

my $public_ip = `curl -4 -s --max-time 4 ifconfig.me 2>/dev/null`;
chomp $public_ip;
$public_ip = "(nicht ermittelt)" if !$public_ip || $public_ip eq "";

my $tailscale_ip = `tailscale ip -4 2>/dev/null | head -n1`;
chomp $tailscale_ip;
$tailscale_ip = "(nicht ermittelt)" if !$tailscale_ip || $tailscale_ip eq "";

my $openclaw_ver = `openclaw --version 2>/dev/null`;
chomp $openclaw_ver;
$openclaw_ver = "(nicht ermittelt)" if !$openclaw_ver || $openclaw_ver eq "";

my $node_ver = `node -v 2>/dev/null`;
chomp $node_ver;
$node_ver = "(nicht ermittelt)" if !$node_ver || $node_ver eq "";

open(my $fh, '>', $ist_file) or die "Cannot write to $ist_file: $!";

print $fh <<EOF;
# IST-Zustand: Gateway B / Node 7

Stand (lokal): $now_local  
Stand (UTC): $now_utc

## 1) Identität & System

- Gateway: **B**
- Node: **7**
- Hostname (short): \\`$hostname_short\\`
- Hostname (FQDN): \\`$hostname_fqdn\\`
- Architektur: \\`$arch\\`
- Kernel: \\`$kernel\\`
- OS: \\`$os_pretty\\`
- IPv4 (lokal): \\`$ipv4_all\\`
- Public IPv4: \\`$public_ip\\`
- Tailscale IPv4: \\`$tailscale_ip\\`
- OpenClaw Version: \\`$openclaw_ver\\`
- Node.js Version: \\`$node_ver\\`

## 2) Arbeitsverzeichnisse

- Basis: \\`$base_dir\\`
- Funktionell VSCode: \\`$vscode_dir\\`
- Workspace Doku: \\`$out_dir\\`

## 3) Kernartefakte (Existenz)

- \\`$openclaw_json\\`: @{[(-f $openclaw_json ? "vorhanden" : "fehlt")]}
- \\`$env_dot\\`: @{[(-f $env_dot ? "vorhanden" : "fehlt")]}
- \\`$env_systemd\\`: @{[(-f $env_systemd ? "vorhanden" : "fehlt")]}
- \\`$base_dir/plugins/installs.json\\`: @{[(-f "$base_dir/plugins/installs.json" ? "vorhanden" : "fehlt")]}
- \\`$base_dir/plugin-skills\\`: @{[(-d "$base_dir/plugin-skills" ? "vorhanden" : "fehlt")]}

## 4) Hinweis

Diese Datei wird bei jedem Lauf neu geschrieben.
Zusätzlich wird ein Laufprotokoll als \\`RUN-*.md\\` erzeugt.
EOF

close $fh;

open($fh, '>', $inv_file) or die "Cannot write to $inv_file: $!";

print $fh "# Artefakt-Inventar: Gateway B / Node 7\n\n";
print $fh "Stand: $now_local\n\n";
print $fh "## Top-Level in ~/.openclaw\n\n";
print $fh "\\`\\`\\`text\n";
if (opendir(my $dir_fh, $base_dir)) {
    my @files = readdir($dir_fh);
    closedir($dir_fh);
    for my $file (@files) {
        next if $file eq '.' || $file eq '..';
        print $fh "$file\n";
    }
} else {
    print $fh "(nicht lesbar)\n";
}
print $fh "\\`\\`\\`\n\n";

print $fh "## ~/.openclaw/.vscode\n\n";
print $fh "\\`\\`\\`text\n";
if (-d $vscode_dir) {
    opendir(my $dir_fh, $vscode_dir) or warn "Cannot read directory $vscode_dir: $!";
    my @files = readdir($dir_fh);
    closedir($dir_fh);
    for my $file (@files) {
        next if $file eq '.' || $file eq '..';
        my $full_path = "$vscode_dir/$file";
        my @stat_info = stat($full_path);
        printf $fh "%s %s %s %s %s %s %s\n", 
                  substr(sprintf("%07o", ($stat_info[2] & 0777)), -3),
                  (getpwuid($stat_info[4]))[0],
                  (getgrgid($stat_info[5]))[0],
                  $stat_info[9],
                  $stat_info[7],
                  strftime("%b %d %H:%M", localtime($stat_info[9])),
                  $file;
    }
} else {
    print $fh "(nicht vorhanden)\n";
}
print $fh "\\`\\`\\`\n\n";

print $fh "## plugin-skills/\n\n";
print $fh "\\`\\`\\`text\n";
if (-d "$base_dir/plugin-skills") {
    opendir(my $dir_fh, "$base_dir/plugin-skills") or warn "Cannot read directory $base_dir/plugin-skills: $!";
    my @files = readdir($dir_fh);
    closedir($dir_fh);
    for my $file (@files) {
        next if $file eq '.' || $file eq '..';
        print $fh "$file\n";
    }
} else {
    print $fh "(nicht vorhanden)\n";
}
print $fh "\\`\\`\\`\n\n";

print $fh "## openclaw.json Backups\n\n";
print $fh "\\`\\`\\`text\n";
my @backups = glob("$base_dir/openclaw.json.bak*");
if (@backups) {
    for my $backup (@backups) {
        print $fh basename($backup), "\n";
    }
} else {
    print $fh "(keine gefunden)\n";
}
print $fh "\\`\\`\\`\n";

close $fh;

open($fh, '>', $cfg_file) or die "Cannot write to $cfg_file: $!";

print $fh "# OpenClaw Config Snapshot: Gateway B / Node 7\n\n";
print $fh "Stand: $now_local\n\n";
print $fh "## Schlüsselpositionen (grep)\n\n";
print $fh "\\`\\`\\`text\n";
if (-f $openclaw_json) {
    open(my $json_fh, '<', $openclaw_json) or warn "Could not open $openclaw_json: $!";
    my $line_num = 1;
    while (my $line = <$json_fh>) {
        chomp $line;
        if ($line =~ /"gateway"|\"session\"|\"dmScope\"|\"auth\"|\"secrets\"|\"tools\"|\"plugins\"|\"profile\"|\"alsoAllow\"|\"denyCommands\"/) {
            print $fh "$line_num:$line\n";
        }
        $line_num++;
    }
    close $json_fh;
} else {
    print $fh "openclaw.json fehlt\n";
}
print $fh "\\`\\`\\`\n\n";

print $fh "## Ausschnitt gateway/session/auth (ungefiltert, betriebsnah)\n\n";
print $fh "\\`\\`\\`json\n";
if (-f $openclaw_json) {
    open(my $json_fh, '<', $openclaw_json) or warn "Could not open $openclaw_json: $!";
    my $line_count = 0;
    while (my $line = <$json_fh>) {
        $line_count++;
        last if $line_count > 780;
        print $fh $line if $line_count >= 580;
    }
    close $json_fh;
} else {
    print $fh "{ \"error\": \"openclaw.json fehlt\" }\n";
}
print $fh "\\`\\`\\`\n";

close $fh;

open($fh, '>', $env_file) or die "Cannot write to $env_file: $!";

print $fh "# ENV-Status: Gateway B / Node 7\n\n";
print $fh "Stand: $now_local\n\n";
print $fh "## Dateien\n\n";
print $fh "\\`\\`\\`text\n";
if (-f $env_dot && -f $env_systemd) {
    my @stat_env = stat($env_dot);
    my @stat_systemd = stat($env_systemd);
    printf $fh "%s %s %s %s %s %s %s\n", 
              substr(sprintf("%07o", ($stat_env[2] & 0777)), -3),
              (getpwuid($stat_env[4]))[0],
              (getgrgid($stat_env[5]))[0],
              $stat_env[9],
              $stat_env[7],
              strftime("%b %d %H:%M", localtime($stat_env[9])),
              basename($env_dot);
    printf $fh "%s %s %s %s %s %s %s\n", 
              substr(sprintf("%07o", ($stat_systemd[2] & 0777)), -3),
              (getpwuid($stat_systemd[4]))[0],
              (getgrgid($stat_systemd[5]))[0],
              $stat_systemd[9],
              $stat_systemd[7],
              strftime("%b %d %H:%M", localtime($stat_systemd[9])),
              basename($env_systemd);
} elsif (-f $env_dot) {
    my @stat_env = stat($env_dot);
    printf $fh "%s %s %s %s %s %s %s\n", 
              substr(sprintf("%07o", ($stat_env[2] & 0777)), -3),
              (getpwuid($stat_env[4]))[0],
              (getgrgid($stat_env[5]))[0],
              $stat_env[9],
              $stat_env[7],
              strftime("%b %d %H:%M", localtime($stat_env[9])),
              basename($env_dot);
} elsif (-f $env_systemd) {
    my @stat_systemd = stat($env_systemd);
    printf $fh "%s %s %s %s %s %s %s\n", 
              substr(sprintf("%07o", ($stat_systemd[2] & 0777)), -3),
              (getpwuid($stat_systemd[4]))[0],
              (getgrgid($stat_systemd[5]))[0],
              $stat_systemd[9],
              $stat_systemd[7],
              strftime("%b %d %H:%M", localtime($stat_systemd[9])),
              basename($env_systemd);
} else {
    print $fh "(keine ENV-Dateien gefunden)\n";
}
print $fh "\\`\\`\\`\n\n";

print $fh "## .env (vollständig, ungefiltert)\n\n";
print $fh "\\`\\`\\`dotenv\n";
if (-f $env_dot) {
    open(my $env_fh, '<', $env_dot) or warn "Could not open $env_dot: $!";
    while (my $line = <$env_fh>) {
        print $fh $line;
    }
    close $env_fh;
} else {
    print $fh "# .env fehlt\n";
}
print $fh "\\`\\`\\`\n\n";

print $fh "## gateway.systemd.env (vollständig, ungefiltert)\n\n";
print $fh "\\`\\`\\`dotenv\n";
if (-f $env_systemd) {
    open(my $systemd_fh, '<', $env_systemd) or warn "Could not open $env_systemd: $!";
    while (my $line = <$systemd_fh>) {
        print $fh $line;
    }
    close $systemd_fh;
} else {
    print $fh "# gateway.systemd.env fehlt\n";
}
print $fh "\\`\\`\\`\n";

close $fh;

open($fh, '>', $run_file) or die "Cannot write to $run_file: $!";

my $script_path = realpath($0);

print $fh <<EOF;
# Laufprotokoll Gateway B / Node 7

- Zeit (lokal): $now_local
- Zeit (UTC): $now_utc
- Script: $script_path

## Erzeugte Dateien

- @{[basename($ist_file)]}
- @{[basename($inv_file)]}
- @{[basename($cfg_file)]}
- @{[basename($env_file)]}

EOF

close $fh;

print "OK: IST-Zustand erfasst.\n";
print "Ausgabeordner: $out_dir\n";
print "Dateien:\n";

opendir(my $dir_fh, $out_dir) or die "Cannot read directory $out_dir: $!";
my @files = readdir($dir_fh);
closedir($dir_fh);
for my $file (@files) {
    next if $file eq '.' || $file eq '..';
    print "- $file\n";
}

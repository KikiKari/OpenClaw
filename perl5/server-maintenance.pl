#!/usr/bin/perl
# server-maintenance.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway1:scripts/server-maintenance.sh
# auch in: OpenClaw@gateway2:scripts/server-maintenance.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use POSIX qw(strftime);

# Server Maintenance Script
# RAM: 8GB, Uhr: Europe/Berlin

my $LOG_FILE = "/var/log/server-maintenance.log";
my $DATE = strftime('%Y-%m-%d %H:%M:%S', localtime);
my $HOST = `hostname`;
chomp($HOST);

# Farben für Terminal
my $RED = "\033[0;31m";
my $GREEN = "\033[0;32m";
my $YELLOW = "\033[1;33m";
my $NC = "\033[0m";

log_message("=== Server Maintenance Check ===");

# 1. APT Update Check
log_message("Checking for updates...");
my @apt_update_output = `apt update -qq 2>&1`;
my @last_5_lines = @apt_update_output[-5..-1];
foreach my $line (@last_5_lines) {
    log_message($line);
}
my $updates_count = `apt list --upgradable 2>/dev/null | wc -l`;
chomp($updates_count);
if ($updates_count > 1) {
    log_message("⚠️ $updates_count packages can be upgraded");
}

# 2. RAM Check (8GB total)
log_message("Checking RAM usage...");
my $RAM_TOTAL = 8192;  # 8GB in MB
my $RAM_USED = 0;
open(my $fh, '-|', 'free -m') or die "Konnte free nicht ausführen: $!";
while (my $line = <$fh>) {
    if ($line =~ /^Mem:/) {
        my @fields = split(/\s+/, $line);
        $RAM_USED = $fields[2];
        last;
    }
}
close($fh);
my $RAM_PERCENT = int(($RAM_USED * 100) / $RAM_TOTAL);
log_message("RAM: ${RAM_USED}MB / ${RAM_TOTAL}MB (${RAM_PERCENT}%)");
if ($RAM_PERCENT > 90) {
    log_message("🔴 WARNING: RAM usage > 90%!");
} elsif ($RAM_PERCENT > 80) {
    log_message("🟡 WARNING: RAM usage > 80%");
}

# 3. Disk Space Check
log_message("Checking disk space...");
my $disk_info = `df -h / | tail -1`;
chomp($disk_info);
$disk_info =~ s/^.*\s+(\S+)\s+(\S+)\s+\((\d+%)\).*$/Disk: $1 \/ $2 \($3 used\)/;
log_message($disk_info);
my $DISK_PERCENT = `df / | tail -1 | awk '{print \$5}' | sed 's/%//'`;
chomp($DISK_PERCENT);
if ($DISK_PERCENT > 90) {
    log_message("🔴 WARNING: Disk > 90%!");
} elsif ($DISK_PERCENT > 80) {
    log_message("🟡 WARNING: Disk > 80%");
}

# 4. NTP Check
log_message("Checking NTP sync...");
my $timedatectl_status = `timedatectl status`;
if ($timedatectl_status =~ /NTP synchronized: yes/) {
    log_message("✅ NTP synchronized");
} else {
    log_message("⚠️ NTP not synchronized");
}

# 5. OpenClaw Gateway Status
log_message("Checking OpenClaw Gateway...");
my $gateway_status = `systemctl is-active --quiet openclaw-gateway; echo \$?`;
chomp($gateway_status);
if ($gateway_status == 0) {
    log_message("✅ OpenClaw Gateway running");
} else {
    log_message("🔴 OpenClaw Gateway NOT running!");
    system("systemctl restart openclaw-gateway");
}

# 6. Load Average
my $LOAD = `uptime | awk -F'load average:' '{print \\\$2}' | awk '{print \\\$1}' | sed 's/,//'`;
chomp($LOAD);
log_message("Load Average: $LOAD");

log_message("=== Maintenance Complete ===");
log_message("");

sub log_message {
    my ($message) = @_;
    my $timestamp = strftime('%Y-%m-%d %H:%M:%S', localtime);
    my $log_line = "[$timestamp] $message\n";
    
    print $log_line;
    open(my $log_fh, '>>', $LOG_FILE) or die "Konnte Log-Datei nicht öffnen: $!";
    print $log_fh $log_line;
    close($log_fh);
}

#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "381869278172dd98284522cce44e69bd85eebf708a458df9333e8946deddbed7", "source_sha256": "38390e5c16266050829f3193f79ca05d8ec898095dc834f407431d87ecfadeb8", "target_language": "perl5"}
# server-maintenance.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway1:scripts/server-maintenance.sh
# auch in: OpenClaw@gateway2:scripts/server-maintenance.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

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

log_and_print("[$DATE] === Server Maintenance Check ===");

# 1. APT Update Check
log_and_print("[$DATE] Checking for updates...");
my @apt_update_output = `apt update -qq 2>&1`;
my @last_5_lines = @apt_update_output[-5..-1];
foreach my $line (@last_5_lines) {
    log_and_print($line);
}
my $updates_count = scalar(`apt list --upgradable 2>/dev/null | wc -l`);
chomp($updates_count);
if ($updates_count > 1) {
    log_and_print("[$DATE] ⚠️ $updates_count packages can be upgraded");
}

# 2. RAM Check (8GB total)
log_and_print("[$DATE] Checking RAM usage...");
my $RAM_TOTAL = 8192;  # 8GB in MB
my $ram_info = `free -m`;
my ($RAM_USED) = $ram_info =~ /^Mem:\s+(\d+)/m;
my $RAM_PERCENT = int(($RAM_USED * 100) / $RAM_TOTAL);
log_and_print("[$DATE] RAM: ${RAM_USED}MB / ${RAM_TOTAL}MB (${RAM_PERCENT}%)");
if ($RAM_PERCENT > 90) {
    log_and_print("[$DATE] 🔴 WARNING: RAM usage > 90%!");
} elsif ($RAM_PERCENT > 80) {
    log_and_print("[$DATE] 🟡 WARNING: RAM usage > 80%");
}

# 3. Disk Space Check
log_and_print("[$DATE] Checking disk space...");
my $disk_info = `df -h / | tail -1`;
chomp($disk_info);
$disk_info =~ s/^([^ ]+) +([^ ]+) +([^ ]+) +([^ ]+) +([^ ]+) +(.*)$/Disk: $3 \/ $2 \($5 used\)/;
log_and_print("[$DATE] $disk_info");
my $disk_percent_line = `df / | tail -1`;
my ($DISK_PERCENT) = $disk_percent_line =~ /(\d+)%/;
if ($DISK_PERCENT > 90) {
    log_and_print("[$DATE] 🔴 WARNING: Disk > 90%!");
} elsif ($DISK_PERCENT > 80) {
    log_and_print("[$DATE] 🟡 WARNING: Disk > 80%");
}

# 4. NTP Check
log_and_print("[$DATE] Checking NTP sync...");
my $timedatectl_status = `timedatectl status`;
if ($timedatectl_status =~ /NTP synchronized: yes/) {
    log_and_print("[$DATE] ✅ NTP synchronized");
} else {
    log_and_print("[$DATE] ⚠️ NTP not synchronized");
}

# 5. OpenClaw Gateway Status
log_and_print("[$DATE] Checking OpenClaw Gateway...");
my $gateway_status = `systemctl is-active --quiet openclaw-gateway; echo \$?`;
chomp($gateway_status);
if ($gateway_status == 0) {
    log_and_print("[$DATE] ✅ OpenClaw Gateway running");
} else {
    log_and_print("[$DATE] 🔴 OpenClaw Gateway NOT running!");
    system("systemctl restart openclaw-gateway");
}

# 6. Load Average
my $uptime_output = `uptime`;
my ($LOAD) = $uptime_output =~ /load average:\s*([\d.]+)/;
log_and_print("[$DATE] Load Average: $LOAD");

log_and_print("[$DATE] === Maintenance Complete ===");
log_and_print("");

sub log_and_print {
    my ($message) = @_;
    print "$message\n";
    open(my $fh, '>>', $LOG_FILE) or die "Could not open file '$LOG_FILE' $!";
    print $fh "$message\n";
    close $fh;
}

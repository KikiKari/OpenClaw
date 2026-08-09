#!/usr/bin/perl
# channel_status.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:skills/channel-status-agent/scripts/channel_status.py
# auch in: OpenClaw@gateway2:skills/channel-status-agent/scripts/channel_status.py
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use JSON;
use File::Path qw(make_path);
use File::Spec;
use POSIX qw(strftime);

# Konfiguration
my $WORKSPACE = "/home/openclaw/.openclaw/workspace";
my $LOGS_DB = "$WORKSPACE/db/logs.db";
my $CONFIG_FILE = "$WORKSPACE/config/channel-status.json";
my $LOG_FILE = "$WORKSPACE/logs/channel-status.log";

sub log_message {
    my ($message, $level) = @_;
    $level //= "INFO";
    my $timestamp = strftime('%Y-%m-%d %H:%M:%S', localtime);
    my $entry = "[$timestamp] [$level] $message\n";
    print $entry;
    open(my $fh, '>>', $LOG_FILE) or die "Could not open log file: $!";
    print $fh $entry;
    close $fh;
}

sub get_system_status {
    my %status = (
        timestamp => strftime('%Y-%m-%dT%H:%M:%S', localtime),
        nodes => {},
        agents => {},
        system => {}
    );

    # Node-Status (vereinfacht)
    my %nodes = (
        node1 => { name => "Gateway", status => "online" },
        node2 => { name => "Worker", status => "online" },
        node3 => { name => "Relay", status => "offline", reason => "disk full" },
        node5 => { name => "Redmi", status => "intermittent" },
        node7 => { name => "Docker", status => "planned" }
    );
    $status{nodes} = \%nodes;

    # Agent-Status aus Cron
    my $cron_result = `crontab -l 2>/dev/null`;
    if ($? == 0) {
        my @lines = grep { !/^\s*#/ } split(/\n/, $cron_result);
        $status{agents}->{active_crons} = scalar @lines;
    } else {
        $status{agents}->{active_crons} = "unknown";
    }

    # System-Metriken
    eval {
        # Disk usage
        my $df_output = `df -h / 2>/dev/null`;
        for my $line (split(/\n/, $df_output)) {
            if ($line =~ m|/| && $line =~ /%/) {
                my @parts = split(/\s+/, $line);
                $status{system}->{disk_used} = $parts[4];
                last;
            }
        }

        # RAM usage
        my $free_output = `free -h 2>/dev/null`;
        for my $line (split(/\n/, $free_output)) {
            if ($line =~ /Mem:/) {
                my @parts = split(/\s+/, $line);
                $status{system}->{ram_total} = $parts[1];
                $status{system}->{ram_used} = $parts[2];
                last;
            }
        }
    };

    return \%status;
}

sub format_daily_status {
    my ($status) = @_;
    my $nodes = $status->{nodes};
    my $online_count = 0;
    for my $node (values %$nodes) {
        $online_count++ if $node->{status} eq "online";
    }

    my $message = "📊 **Täglicher Status-Report**\n";
    $message .= "🗓️ " . strftime('%Y-%m-%d %H:%M', localtime) . "\n\n";
    $message .= "**🖥️ Nodes ($online_count/5 online):**\n";

    for my $node_id (sort keys %$nodes) {
        my $info = $nodes->{$node_id};
        my $emoji = $info->{status} eq "online" ? "🟢" : 
                   ($info->{status} eq "offline" ? "🔴" : "🟡");
        $message .= "$emoji $info->{name}: $info->{status}";
        if (exists $info->{reason}) {
            $message .= " ($info->{reason})";
        }
        $message .= "\n";
    }

    $message .= "\n**🤖 Agents:**\n";
    $message .= "Aktive Cron-Jobs: $status->{agents}->{active_crons}\n";

    if (exists $status->{system}->{disk_used}) {
        $message .= "\n**💾 System:**\n";
        $message .= "Disk: $status->{system}->{disk_used} belegt\n";
        $message .= "RAM: $status->{system}->{ram_used} / $status->{system}->{ram_total}\n";
    }

    return $message;
}

sub format_weekly_status {
    my $message = "📈 **Wöchentlicher Report**\n";
    $message .= "📅 Woche " . strftime('%V', localtime) . " - " . strftime('%Y', localtime) . "\n\n";
    $message .= "**Zusammenfassung:**\n";
    $message .= "- 5 aktive Sub-Agents\n";
    $message .= "- 11 Skills synchronisiert\n";
    $message .= "- 3 neue Features implementiert\n\n";
    $message .= "**Top-Ereignisse:**\n";
    $message .= "1. ClawHub-Git Sync implementiert ✅\n";
    $message .= "2. Node 3 Disk voll (95%) ⚠️\n";
    $message .= "3. Channel-Status-Agent aktiviert 🆕\n\n";
    $message .= "**Geplante Wartungen:**\n";
    $message .= "- Node 3: Disk-Cleanup erforderlich\n";
    $message .= "- Node 7: Docker-Setup ausstehend\n";
    return $message;
}

sub send_to_channel {
    my ($message, $channel_type, $channel_id) = @_;
    $channel_type //= "telegram";
    $channel_id //= "-1002381931352";

    if ($channel_type eq "telegram") {
        # Nutze OpenClaw message tool
        my @cmd = ("openclaw", "message", "send", "--target", $channel_id, "--message", $message);
        system(@cmd) == 0 or do {
            log_message("Failed to send message: $!", "ERROR");
            return 0;
        };
        log_message("Message sent to $channel_type $channel_id");
        return 1;
    } else {
        log_message("Channel type $channel_type not implemented", "WARN");
        return 0;
    }
}

sub main {
    my %args = parse_args();
    log_message("Starting $args{type} status update");

    # Status sammeln
    my $status = get_system_status();

    # Message formatieren
    my $message;
    if ($args{type} eq 'daily') {
        $message = format_daily_status($status);
    } elsif ($args{type} eq 'weekly') {
        $message = format_weekly_status($status);
    } elsif ($args{type} eq 'alert') {
        $message = "🚨 **ALERT**\n" . ($args{message} || 'Manual alert');
    }

    # Senden oder Dry-Run
    if ($args{dry_run}) {
        print "\n--- DRY RUN ---\n";
        print $message;
        print "\n--- END ---\n";
    } else {
        send_to_channel($message, "telegram", $args{channel});
    }

    log_message("Status update completed");
}

sub parse_args {
    my %args;
    my $arg_type;
    for my $i (0..$#ARGV) {
        my $arg = $ARGV[$i];
        if ($arg eq '--type') {
            $args{type} = $ARGV[++$i];
        } elsif ($arg eq '--message') {
            $args{message} = $ARGV[++$i];
        } elsif ($arg eq '--channel') {
            $args{channel} = $ARGV[++$i];
        } elsif ($arg eq '--dry-run') {
            $args{dry_run} = 1;
        }
    }
    
    die "Missing required argument --type\n" unless $args{type};
    $args{channel} //= "-1002381931352";
    return %args;
}

# Create log directory if it doesn't exist
my ($log_volume, $log_dirs) = File::Spec->splitpath($LOG_FILE);
make_path($log_volume . $log_dirs) unless -d $log_volume . $log_dirs;

main();

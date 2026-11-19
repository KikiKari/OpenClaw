#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "d3614f94fe554bca1c9073eed31b71fc30ae695a3082a6618398d7908f7d48f3", "source_sha256": "705cb2cc5900c507db1038d107f06e2f8452a95c37d0611cd27dfe2ed61dd498", "target_language": "perl6"}
# channel_status.py — portiert nach perl6
# Quelle: python, OpenClaw@gateway1:skills/channel-status-agent/scripts/channel_status.py
# auch in: OpenClaw@gateway2:skills/channel-status-agent/scripts/channel_status.py
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

use v6;

# Konfiguration
my $WORKSPACE = "/home/openclaw/.openclaw/workspace";
my $LOGS_DB = "$WORKSPACE/db/logs.db";
my $CONFIG_FILE = "$WORKSPACE/config/channel-status.json";
my $LOG_FILE = "$WORKSPACE/logs/channel-status.log";

sub log-message($message, $level = "INFO") {
    # Logging
    my $timestamp = DateTime.now.Str.subst(/\.\d+$/, '');
    my $entry = "[{$timestamp}] [$level] $message";
    say $entry;
    spurt($LOG_FILE, "$entry\n", :append);
}

sub get-system-status() {
    # Sammelt System-Status
    my %status = (
        timestamp => DateTime.now.Rat,
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
    %status<nodes> = %nodes;

    # Agent-Status aus Cron
    try {
        my $result = run(<crontab -l>, :out);
        my $cron-lines = $result.out.lines.elems - $result.out.lines.grep(* ~~ /'#'/).elems;
        %status<agents><active_crons> = $cron-lines;
        CATCH {
            %status<agents><active_crons> = "unknown";
        }
    }

    # System-Metriken
    try {
        # Disk usage
        my $df = run(<df -h />, :out);
        for $df.out.lines -> $line {
            if $line ~~ /'/'/ && $line ~~ /'%'/ {
                my @parts = $line.words;
                %status<system><disk_used> = @parts[4];
                last;
            }
        }

        # RAM usage
        my $free = run(<free -h>, :out);
        for $free.out.lines -> $line {
            if $line ~~ /'Mem:'/ {
                my @parts = $line.words;
                %status<system><ram_total> = @parts[1];
                %status<system><ram_used> = @parts[2];
                last;
            }
        }
        CATCH {
            # ignore errors
        }
    }

    return %status;
}

sub format-daily-status(%status) {
    # Formatiert täglichen Status
    my %nodes = %status<nodes>;
    my $online = %nodes.values.grep({ $_<status> eq "online" }).elems;

    my $message = q:to/END/;
📊 **Täglicher Status-Report**
🗓️ {DateTime.now.strftime('%Y-%m-%d %H:%M')}

**🖥️ Nodes ({$online}/5 online):**
END

    for %nodes.kv -> $node-id, %info {
        my $emoji = %info<status> eq "online" ?? "🟢" !! 
                   (%info<status> eq "offline" ?? "🔴" !! "🟡");
        $message ~= "$emoji {%info<name>}: {%info<status>}";
        if %info<reason>:exists {
            $message ~= " ({%info<reason>})";
        }
        $message ~= "\n";
    }

    $message ~= "\n**🤖 Agents:**\n";
    $message ~= "Aktive Cron-Jobs: {%status<agents><active_crons>}\n";

    if %status<system><disk_used>:exists {
        $message ~= "\n**💾 System:**\n";
        $message ~= "Disk: {%status<system><disk_used>} belegt\n";
        $message ~= "RAM: {%status<system><ram_used>} / {%status<system><ram_total>}\n";
    }

    return $message;
}

sub format-weekly-status(%status) {
    # Formatiert wöchentlichen Status
    my $message = q:to/END/;
📈 **Wöchentlicher Report**
📅 Woche {DateTime.now.strftime('%V')} - {DateTime.now.strftime('%Y')}

**Zusammenfassung:**
- 5 aktive Sub-Agents
- 11 Skills synchronisiert
- 3 neue Features implementiert

**Top-Ereignisse:**
1. ClawHub-Git Sync implementiert ✅
2. Node 3 Disk voll (95%) ⚠️
3. Channel-Status-Agent aktiviert 🆕

**Geplante Wartungen:**
- Node 3: Disk-Cleanup erforderlich
- Node 7: Docker-Setup ausstehend
END
    return $message;
}

sub send-to-channel($message, $channel-type = "telegram", $channel-id = "-1002381931352") {
    # Sendet Nachricht an Channel
    my @cmd;
    if $channel-type eq "telegram" {
        # Nutze OpenClaw message tool
        @cmd = <openclaw message send --target $channel-id --message $message>;
    } else {
        log-message("Channel type $channel-type not implemented", "WARN");
        return False;
    }

    try {
        my $result = run(@cmd, :out, :err);
        if $result.exitcode == 0 {
            log-message("Message sent to $channel-type $channel-id");
            return True;
        } else {
            log-message("Failed to send: {$result.err.slurp}", "ERROR");
            return False;
        }
        CATCH {
            log-message("Send error: $_", "ERROR");
            return False;
        }
    }
}

sub MAIN(
    Str :$type where * eq any(<daily weekly alert>) = "daily",
    Str :$message,
    Str :$channel = "-1002381931352",
    Bool :$dry-run = False
) {
    # Hauptfunktion
    log-message("Starting $type status update");

    # Status sammeln
    my %status = get-system-status();

    # Message formatieren
    my $msg;
    if $type eq 'daily' {
        $msg = format-daily-status(%status);
    } elsif $type eq 'weekly' {
        $msg = format-weekly-status(%status);
    } elsif $type eq 'alert' {
        $msg = "🚨 **ALERT**\n" ~ ($message || 'Manual alert');
    }

    # Senden oder Dry-Run
    if $dry-run {
        say "\n--- DRY RUN ---";
        say $msg;
        say "--- END ---";
    } else {
        send-to-channel($msg, channel-id => $channel);
    }

    log-message("Status update completed");
}

# Ensure log directory exists
mkdir($LOG_FILE.IO.dirname, :parents) unless $LOG_FILE.IO.dirname.IO.d;

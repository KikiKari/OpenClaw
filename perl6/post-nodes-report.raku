#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "f5034ec38e30949140e5404c3eec35030bd1797ba9d9a98a7e67fdb5120f469a", "source_sha256": "04afaeaf031d1de3a9c71606dba8c1d6ea78b3b575d8ecf94af9256d4dc3886d", "target_language": "perl6"}
# post-nodes-report.js — portiert nach perl6
# Quelle: javascript, OpenClaw@gateway1:scripts/post-nodes-report.js
# auch in: OpenClaw@gateway2:scripts/post-nodes-report.js
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

use v6;

# Pfade
my $DASHBOARD-PATH = $*PROGRAM.parent.parent.add('dashboards/nodes-overview.md');
my $REPORT-LOG = $*PROGRAM.parent.parent.add('logs/nodes-report.log');

# Farbcodes
my %C = (
    green => "\x1b[32m",
    yellow => "\x1b[33m",
    red => "\x1b[31m",
    reset => "\x1b[0m"
);

sub post-report() {
    my $content;
    try {
        $content = slurp $DASHBOARD-PATH;
        CATCH {
            default {
                note "{%C<red>}❌ Fehler beim Lesen der Dashboard-Datei:{%C<reset>} {.message}";
                return;
            }
        }
    }

    # Nachricht über OpenClaw message senden
    my $escaped-content = $content.subst("\n", "\\n", :global);
    my $message-cmd = "openclaw message send --target=main --message \"$escaped-content\"";

    try {
        my $proc = shell $message-cmd, :out, :err;
        if $proc.exitcode == 0 {
            say "{%C<green>}✅ Report erfolgreich im 'main'-Channel gepostet.{%C<reset>}";
            spurt $REPORT-LOG, "[{DateTime.now.Str}] Report posted.\n", :append;
        } else {
            my $error-output = $proc.err.slurp(:close) // $proc.exception.message;
            note "{%C<red>}❌ Fehler beim Senden der Nachricht:{%C<reset>} $error-output";
            spurt $REPORT-LOG, "[{DateTime.now.Str}] Failed to post: $error-output\n", :append;
        }
        CATCH {
            default {
                note "{%C<red>}❌ Fehler beim Senden der Nachricht:{%C<reset>} {.message}";
                spurt $REPORT-LOG, "[{DateTime.now.Str}] Failed to post: {.message}\n", :append;
            }
        }
    }
}

# Hauptausführung
say "{%C<yellow>}📤 Sende Nodes-Übersicht in 'main'...{%C<reset>}";
post-report();

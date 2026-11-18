#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "07ebc61746483546c2e8177ae20fd3f97ee6bc3e0e2e3a8a595dc6514a562c2e", "source_sha256": "8621f6f7e524474de82b3d877ee62bbcbd9fa3b247b69c437b063b71fa995f5a", "target_language": "perl6"}
# ops-hub-heartbeat.js — portiert nach perl6
# Quelle: javascript, OpenClaw@gateway1:scripts/ops-hub-heartbeat.js
# auch in: OpenClaw@gateway2:scripts/ops-hub-heartbeat.js
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

use v6;

sub update-heartbeat() {
    my $status-path = $*PROGRAM.parent.parent.add('docs/ops-hub/status.md');

    my $content;
    try {
        $content = $status-path.slurp(:enc<utf-8>);
        CATCH {
            default {
                note '❌ Konnte status.md nicht lesen: ' ~ .message;
                return;
            }
        }
    }

    my $now = DateTime.now(:timezone(3600)).formatter(
        { sprintf "%02d.%02d.%04d, %02d:%02d:%02d", .day, .month, .year, .hour, .minute, .second }
    ).Str;
    
    my $updated = $content.subst(/( 'Letzter Heartbeat:' ) \s+ <-[\n]>*/, "$0 $now");

    try {
        spurt($status-path, $updated, :enc<utf-8>);
        say "✅ Heartbeat aktualisiert: $now";
        CATCH {
            default {
                note '❌ Konnte status.md nicht schreiben: ' ~ .message;
            }
        }
    }
}

update-heartbeat();

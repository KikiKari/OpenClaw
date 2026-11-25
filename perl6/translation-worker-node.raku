#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "c8d38497c52151e655c0dac9051bb27cadbd1e08e8fd61d980690968aeda4113", "source_sha256": "9caa03d9bb15f9d91f7e2672653c8c81852b35f9076edf8b7f839f4f06ac7dfd", "target_language": "perl6"}
# translation-worker-node.sh — portiert nach perl6
# Quelle: shell, workspace@local:skills/multi-nodes-utils/scripts/translation-worker-node.sh
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

# Run on the selected node after transferring its native worker. JSON stdin is
# forwarded unchanged to the worker in run mode.

use v6;

sub MAIN($node, $action) {
    if @*ARGS.elems != 2 {
        note 'Usage: translation-worker-node.raku node2|node3|node4|node6 prepare|health|run';
        exit 2;
    }

    my ($worker, $expected);
    given $node {
        when 'node2' { $worker = '/home/node/.openclaw/workers/translation-worker'; $expected = '565bba6c22954e7f75a217fc49aa33b5e6d5fd6aa1c8488ffc82e8780c4d1286'; }
        when 'node3' { $worker = '/home/openclaw/.openclaw/workers/translation-worker'; $expected = '9164bdb00dcc99ae70a6fa072e80068f695726aefa4d752345a80fe24e5426de'; }
        when 'node4' { $worker = '/root/.openclaw/workers/translation-worker'; $expected = '565bba6c22954e7f75a217fc49aa33b5e6d5fd6aa1c8488ffc82e8780c4d1286'; }
        when 'node6' { $worker = '/home/node/.openclaw/workers/translation-worker'; $expected = '9164bdb00dcc99ae70a6fa072e80068f695726aefa4d752345a80fe24e5426de'; }
        default { note 'Unknown or non-POSIX node'; exit 2; }
    }

    unless $action eq any(<prepare health run>) {
        note 'Unknown action';
        exit 2;
    }

    if !"$worker".IO.f || "$worker".IO.l {
        note "Missing worker or symlink rejected: $worker";
        exit 1;
    }

    my $actual = qqx[sha256sum "$worker"].split(' ')[0];
    if $actual ne $expected {
        note "Worker checksum mismatch: $worker";
        exit 1;
    }

    chmod 0o755, $worker;

    given $action {
        when 'prepare' { say "Worker verified and executable: $worker"; }
        when 'health' { run "$worker", '--health'; }
        when 'run' { run "$worker"; }
    }
}

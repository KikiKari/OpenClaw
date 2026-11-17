#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "b81aa91586651cae79dc43d9134196f5b9106fa91041f22501d6256142e87ef4", "source_sha256": "e51b94641336291974fe14bf4bb7299a75ec7dcce49e1d413282c8043e9f09f1", "target_language": "perl6"}
# openclaw-audit.sh — portiert nach perl6
# Quelle: shell, OpenClaw@gateway1:scripts/openclaw-audit.sh
# auch in: OpenClaw@gateway2:scripts/openclaw-audit.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

use v6;

# OpenClaw read-only audit/diagnostic sweep
# Output: openclaw-audit-YYYY-MM-DD.log im selben Verzeichnis wie dieses Script

my $script-dir = $*PROGRAM.parent.absolute;
my $date-stamp = DateTime.now.Str.subst(/\T.*/, '');
my $out = "$script-dir/openclaw-audit-$date-stamp.log";

my @oc = <openclaw --no-color>;

sub run-cmd($title, *@args) {
    my $timestamp = DateTime.now.utc.truncated-to('second').Str;
    
    spurt($out, "\n----------------------------------------------------------------\n", :append);
    spurt($out, "### $title\n", :append);
    spurt($out, "### \$ " ~ @args.join(' ') ~ "\n", :append);
    spurt($out, "### $timestamp\n", :append);
    spurt($out, "----------------------------------------------------------------\n", :append);
    
    my $proc = run(|@args, :out, :err);
    my $output = $proc.out.slurp-rest ~ $proc.err.slurp-rest;
    spurt($out, $output, :append);
    spurt($out, "[exit: {$proc.exitcode}]\n", :append);
}

# Write header
spurt($out, "================================================================\n");
spurt($out, "OpenClaw audit run\n", :append);
spurt($out, "Started:  " ~ DateTime.now.utc.truncated-to('second').Str ~ "\n", :append);
spurt($out, "Host:     " ~ run(<hostname>, :out).out.slurp-rest.chomp ~ "\n", :append);
spurt($out, "User:     " ~ $*USER.Str ~ "\n", :append);

my $version-output = '';
try {
    $version-output = run(<openclaw --version>, :out).out.slurp-rest.chomp;
    CATCH { $version-output = 'unknown'; }
}
spurt($out, "Version:  $version-output\n", :append);
spurt($out, "Output:   $out\n", :append);
spurt($out, "================================================================\n", :append);

# Run all commands
run-cmd("tasks audit --severity error", |@oc, "tasks", "audit", "--severity", "error");
run-cmd("secrets audit", |@oc, "secrets", "audit");
run-cmd("security audit", |@oc, "security", "audit");
run-cmd("plugins doctor", |@oc, "plugins", "doctor");
run-cmd("plugins deps", |@oc, "plugins", "deps");
run-cmd("plugins registry", |@oc, "plugins", "registry");
run-cmd("skills check", |@oc, "skills", "check");
run-cmd("hooks check", |@oc, "hooks", "check");
run-cmd("gateway status --deep", |@oc, "gateway", "status", "--deep");
run-cmd("channels status --probe", |@oc, "channels", "status", "--probe");
run-cmd("memory status --deep", |@oc, "memory", "status", "--deep");
run-cmd("sessions --all-agents", |@oc, "sessions", "--all-agents");
run-cmd("tasks list", |@oc, "tasks", "list");
run-cmd("cron list", |@oc, "cron", "list");

# Write footer
spurt($out, "\n================================================================\n", :append);
spurt($out, "Audit complete: " ~ DateTime.now.utc.truncated-to('second').Str ~ "\n", :append);
spurt($out, "================================================================\n", :append);

say "Audit complete. Output: $out";

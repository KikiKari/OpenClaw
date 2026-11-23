#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "c3b1c0bca5e47ae8404bb632ebfb2566f333340b1e9bccf365db9f4fdf0eee7f", "source_sha256": "f911bfbdbdc66c53e970ead9851f23e8c415a17f83d92cea3a53539f83a49ad2", "target_language": "perl6"}
# spawn_agent.py — portiert nach perl6
# Quelle: python, OpenClaw@gateway2:skills/sub-agents-utils/scripts/spawn_agent.py
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

use v6;

# Verfügbare Modelle - hier simuliert, da keine Python-Bibliotheken vorhanden
my @MODELS = <openrouter/anthropic/claude-haiku-4.5 openrouter/meta-llama/llama-3.1-70b-instruct>;

class SubAgentSpawner {
    # Erstellt Konfiguration für sessions_spawn
    method get-spawn-config(
        Str:D :$task!,
        Str :$label,
        Str :$model,
        Str :$thinking,
        Int :$timeout,
        Bool :$thread = False,
        Str :$mode = "run"
    --> Hash
    ) {
        my %config = task => $task;

        %config<label> = $label if $label;
        %config<model> = $model if $model && $model ∈ @MODELS;
        %config<thinking> = $thinking if $thinking;
        %config<runTimeoutSeconds> = $timeout if $timeout;

        if $thread {
            %config<thread> = True;
            %config<mode> = "session"; # thread erfordert session mode
        } else {
            %config<mode> = $mode;
        }

        return %config;
    }

    # Gibt das equivalente Tool-Kommando aus
    method print-spawn-command(%config) {
        say "\n🛠️  Tool-Aufruf:";
        say "=" x 50;
        say "sessions_spawn(";
        for %config.kv -> $key, $value {
            if $value ~~ Str {
                say "    $key=\"$value\"";
            } else {
                say "    $key=$value";
            }
        }
        say ")";
        say "=" x 50;
    }

    # Gibt das equivalente Slash-Kommando aus
    method print-slash-command(%config) {
        my $task = %config<task> // "";
        my $label = %config<label> // "agent";
        my $model = %config<model> // "";

        my $cmd = "/subagents spawn $label \"$task\"";
        $cmd ~= " --model $model" if $model;
        $cmd ~= " --thinking {%config<thinking>}" if %config<thinking>;

        say "\n💬 Slash Command:";
        say "=" x 50;
        say $cmd;
        say "=" x 50;
    }
}

sub MAIN(
    Str :$task! where * ~~ /\S/,                  # Aufgabenbeschreibung
    Str :$label,                                  # Optionaler Label
    Str :$model where * ∈ @MODELS | Nil,          # KI-Modell
    Str :$thinking where * ∈ <low medium high> | Nil, # Thinking Level
    Int :$timeout = 900,                          # Timeout in Sekunden (default: 900)
    Bool :$thread = False,                        # Thread-Binding aktivieren
    Str :$mode where * ∈ <run session> = "run",   # Run mode
    Str :$output where * ∈ <tool slash json> = "tool" # Output format
) {
    my $spawner = SubAgentSpawner.new;
    my %config = $spawner.get-spawn-config(
        :$task,
        :$label,
        :$model,
        :$thinking,
        :$timeout,
        :$thread,
        :$mode
    );

    say "✅ Sub-Agent Konfiguration:";
    say %config.raku;

    if $output eq "tool" {
        $spawner.print-spawn-command(%config);
    } elsif $output eq "slash" {
        $spawner.print-slash-command(%config);
    } elsif $output eq "json" {
        say "\n📄 JSON:";
        say %config.to-json(:pretty);

        # Speichere als Datei
        my $label-name = %config<label> // "spawn";
        my $output-file = "/tmp/subagent_$label-name.json";
        spurt($output-file, %config.to-json(:pretty));
        say "💾 Gespeichert: $output-file";
    }
}

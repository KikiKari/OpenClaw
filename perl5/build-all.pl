#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "1f33de0e56bff072b1cd3ce769df2a1017c79a71d94cf8fa50e1306fd12732d4", "source_sha256": "c07aee6a3f0a90788cfe647dfcc79cf95df841ce0459eb8ffd9bf6aaa426ea38", "target_language": "perl5"}
# build-all.mjs — portiert nach perl5
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/build-all.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use Config;
use File::Spec;
use Cwd 'abs_path';

# Konstanten
my $WINDOWS_BUILD_MAX_OLD_SPACE_MB = 4096;

# Build-Schritte Definition
my @BUILD_ALL_STEPS = (
    { label => "canvas:a2ui:bundle", kind => "pnpm", pnpmArgs => ["canvas:a2ui:bundle"] },
    { label => "tsdown", kind => "node", args => ["scripts/tsdown-build.mjs"] },
    { label => "runtime-postbuild", kind => "node", args => ["scripts/runtime-postbuild.mjs"] },
    {
        label => "write-npm-update-compat-sidecars",
        kind => "node",
        args => ["scripts/write-npm-update-compat-sidecars.mjs"],
    },
    { label => "build-stamp", kind => "node", args => ["scripts/build-stamp.mjs"] },
    {
        label => "build:plugin-sdk:dts",
        kind => "pnpm",
        pnpmArgs => ["build:plugin-sdk:dts"],
        windowsNodeOptions => "--max-old-space-size=$WINDOWS_BUILD_MAX_OLD_SPACE_MB",
    },
    {
        label => "write-plugin-sdk-entry-dts",
        kind => "node",
        args => ["--import", "tsx", "scripts/write-plugin-sdk-entry-dts.ts"],
    },
    {
        label => "check-plugin-sdk-exports",
        kind => "node",
        args => ["scripts/check-plugin-sdk-exports.mjs"],
    },
    {
        label => "canvas-a2ui-copy",
        kind => "node",
        args => ["--import", "tsx", "scripts/canvas-a2ui-copy.ts"],
    },
    {
        label => "copy-hook-metadata",
        kind => "node",
        args => ["--import", "tsx", "scripts/copy-hook-metadata.ts"],
    },
    {
        label => "copy-export-html-templates",
        kind => "node",
        args => ["--import", "tsx", "scripts/copy-export-html-templates.ts"],
    },
    {
        label => "write-build-info",
        kind => "node",
        args => ["--import", "tsx", "scripts/write-build-info.ts"],
    },
    {
        label => "write-cli-startup-metadata",
        kind => "node",
        args => ["--experimental-strip-types", "scripts/write-cli-startup-metadata.ts"],
    },
    {
        label => "write-cli-compat",
        kind => "node",
        args => ["--import", "tsx", "scripts/write-cli-compat.ts"],
    },
);

# Hilfsfunktionen
sub get_node_bin {
    return $^X;
}

sub resolve_step_env {
    my ($step, $env_ref, $platform) = @_;
    
    # Wenn nicht Windows oder keine windowsNodeOptions, dann nichts ändern
    if ($platform ne "MSWin32" || !$step->{windowsNodeOptions}) {
        return $env_ref;
    }
    
    my %new_env = %$env_ref;
    my $current_options = $new_env{NODE_OPTIONS} // "";
    $current_options =~ s/^\s+|\s+$//g; # trim
    
    # Prüfen ob Option bereits enthalten ist
    if (index($current_options, $step->{windowsNodeOptions}) != -1) {
        return $env_ref;
    }
    
    if ($current_options) {
        $new_env{NODE_OPTIONS} = "$current_options $step->{windowsNodeOptions}";
    } else {
        $new_env{NODE_OPTIONS} = $step->{windowsNodeOptions};
    }
    
    return \%new_env;
}

# Lade pnpm-runner Funktion (vereinfacht)
sub resolve_pnpm_runner {
    my ($params) = @_;
    
    my $pnpm_args = $params->{pnpmArgs};
    my $platform = $params->{platform};
    my $comspec = $params->{comSpec};
    my $npm_execpath = $params->{npmExecPath};
    
    my @cmd;
    my $shell = 0;
    my $verbatim = 0;
    
    if ($platform eq 'MSWin32') {
        if ($comspec && -f $comspec) {
            @cmd = ($comspec, '/d', '/s', '/c');
            $verbatim = 1;
        } else {
            @cmd = ('cmd.exe', '/d', '/s', '/c');
            $verbatim = 1;
        }
        push @cmd, "pnpm";
    } else {
        @cmd = ("pnpm");
    }
    
    return {
        command => $cmd[0],
        args => [@cmd[1..$#cmd], @$pnpm_args],
        shell => $shell,
        windowsVerbatimArguments => $verbatim,
    };
}

sub resolve_build_all_step {
    my ($step, $params) = @_;
    
    $params //= {};
    my $platform = $params->{platform} // $Config{osname} eq 'MSWin32' ? 'MSWin32' : 'unix';
    my $env_ref = resolve_step_env($step, $params->{env} // {%ENV}, $platform);
    
    if ($step->{kind} eq "pnpm") {
        my $runner = resolve_pnpm_runner({
            pnpmArgs => $step->{pnpmArgs},
            nodeExecPath => $params->{nodeExecPath} // get_node_bin(),
            npmExecPath => $params->{npmExecPath} // $ENV{npm_execpath},
            comSpec => $params->{comSpec} // $ENV{ComSpec},
            platform => $platform,
        });
        
        return {
            command => $runner->{command},
            args => $runner->{args},
            options => {
                env => $env_ref,
                shell => $runner->{shell},
                windowsVerbatimArguments => $runner->{windowsVerbatimArguments},
            },
        };
    } else {
        return {
            command => $params->{nodeExecPath} // get_node_bin(),
            args => $step->{args},
            options => {
                env => $env_ref,
            },
        };
    }
}

# Hauptausführung
sub is_main_module {
    # In Perl gibt es keinen direkten Weg, dies zu prüfen.
    # Wir führen immer aus, da das Skript direkt aufgerufen wird.
    return 1;
}

if (is_main_module()) {
    foreach my $step (@BUILD_ALL_STEPS) {
        print STDERR "[build-all] $step->{label}\n";
        my $invocation = resolve_build_all_step($step);
        
        my @cmd_parts = ($invocation->{command}, @{$invocation->{args}});
        my $cmd_str = join(" ", map { "'$_'" } @cmd_parts);
        
        # Setze Umgebungsvariablen
        local %ENV = %{$invocation->{options}->{env}};
        
        # Führe den Befehl aus
        my $exit_code = system($cmd_str);
        
        if ($exit_code == -1) {
            die "Konnte Befehl nicht ausführen: $!";
        } elsif ($exit_code & 127) {
            printf STDERR "Kindprozess mit Signal %d beendet\n", ($exit_code & 127);
            exit 1;
        } else {
            my $status = $exit_code >> 8;
            if ($status != 0) {
                exit $status;
            }
        }
    }
}

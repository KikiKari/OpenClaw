#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "ead30b53dce3c16603cf09d8f8c74cc39ba9be7fd0aa0c54e78aabf974bc97bd", "source_sha256": "0f2bb155d699e769ad3eb99a6500cc6dbb27948a57f7493a3b98c731200853d4", "target_language": "perl5"}
# test-extension.mjs — portiert nach perl5
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-extension.mjs
# Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Cwd qw(abs_path getcwd);
use File::Basename qw(dirname);

# Füge das lib-Verzeichnis zum @INC-Pfad hinzu, um Module zu finden
use lib dirname(abs_path(__FILE__)) . '/lib';

# Da Perl keine direkte Entsprechung für ES-Module hat, simulieren wir den Import
# durch require und manuelles Exportieren der Funktionen

# Simuliere Import von error-format.mjs
require 'error_format.pm';
my $format_error_message = \&error_format::formatErrorMessage;

# Simuliere Import von extension-test-plan.mjs
require 'extension_test_plan.pm';
my $resolve_extension_test_plan = \&extension_test_plan::resolveExtensionTestPlan;

# Simuliere Import von vitest-batch-runner.mjs
require 'vitest_batch_runner.pm';
my $is_direct_script_run = \&vitest_batch_runner::isDirectScriptRun;
my $run_vitest_batch = \&vitest_batch_runner::runVitestBatch;

sub print_usage {
    print STDERR "Usage: pnpm test:extension <extension-name|path> [vitest args...]\n";
    print STDERR "       node scripts/test-extension.mjs [extension-name|path] [vitest args...]\n";
}

sub print_no_tests_message {
    my ($plan) = @_;
    print "[test-extension] No tests found for $$plan{extensionDir}. Skipping.\n";
}

sub run {
    my @raw_args = @ARGV;
    
    # Filtere --help und -h Argumente
    my $has_help = grep { $_ eq '--help' || $_ eq '-h' } @raw_args;
    if ($has_help) {
        print_usage();
        return;
    }
    
    # Filtere -- Argumente heraus
    my @passthrough_args = grep { $_ ne '--' } @raw_args;
    
    my $target_arg;
    # Wenn das erste Argument kein Flag ist, verwenden wir es als Ziel
    if (@passthrough_args && $passthrough_args[0] !~ /^-/) {
        $target_arg = shift @passthrough_args;
    }
    
    my $plan;
    eval {
        $plan = $resolve_extension_test_plan->({
            cwd => getcwd(),
            targetArg => $target_arg
        });
        1;
    } or do {
        my $error = $@ || 'Unknown error';
        print_usage();
        print STDERR $format_error_message->($error);
        exit 1;
    };
    
    if (!$plan->{hasTests}) {
        print_no_tests_message($plan);
        return;
    }
    
    print "[test-extension] Running $$plan{testFileCount} test files for $$plan{extensionId}\n";
    
    my $exit_code = $run_vitest_batch->({
        args => \@passthrough_args,
        config => $plan->{config},
        env => \%ENV,
        targets => $plan->{roots}
    });
    
    exit $exit_code;
}

# Prüfe ob dieses Skript direkt ausgeführt wird
if ($is_direct_script_run->(__FILE__)) {
    run();
}

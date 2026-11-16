#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "1054a85fdd338ec532f4fe95ba2728fab1521f0b35deb33f6e25d8163a36c972", "source_sha256": "913a32ef02a0f4e83bb9d65b279088c91abd5e717e9dbba62e17a4a50836e586", "target_language": "perl5"}
# check-architecture-smells.mjs — portiert nach perl5
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-architecture-smells.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Spec;
use File::Basename;
use Cwd 'abs_path';
use JSON::PP;
use lib dirname(__FILE__);

# Simulated imports from other modules
# In a real scenario, these would be proper Perl modules or libraries
my $BUNDLED_PLUGIN_PATH_PREFIX = "extensions/";

sub collectTypeScriptInventory {
    my ($config) = @_;
    my @entries;
    my $files = $config->{files};
    my $collectEntries = $config->{collectEntries};

    for my $file (@$files) {
        # This would normally parse TypeScript files
        # For now we'll just simulate with empty results
        my @file_entries = $collectEntries->({}, $file);
        push @entries, @file_entries;
    }

    @entries = sort { $config->{compareEntries}->($a, $b) } @entries;
    return \@entries;
}

sub normalizeRepoPath {
    my ($repoRoot, $filePath) = @_;
    # Simplified path normalization
    $filePath =~ s/^$repoRoot//;
    $filePath =~ s/^\/+//;
    return $filePath;
}

sub resolveRepoSpecifier {
    my ($repoRoot, $specifier, $filePath) = @_;
    # Simplified resolution logic
    if ($specifier =~ m{^\./} || $specifier =~ m{^\.\./}) {
        my $dir = dirname($filePath);
        return File::Spec->catfile($dir, $specifier);
    }
    return $specifier;
}

sub visitModuleSpecifiers {
    my ($ts, $sourceFile, $callback) = @_;
    # Placeholder for visiting module specifiers
    # In reality this would walk the AST
}

sub writeLine {
    my ($stream, $line) = @_;
    print $stream "$line\n";
}

sub collectTypeScriptFilesFromRoots {
    my ($roots) = @_;
    # Placeholder for collecting TypeScript files
    return [];
}

sub resolveSourceRoots {
    my ($repoRoot, $paths) = @_;
    my @results;
    for my $path (@$paths) {
        push @results, File::Spec->catdir($repoRoot, $path);
    }
    return \@results;
}

sub runAsScript {
    my ($url, $main_func) = @_;
    # Check if running as script
    if (!caller) {
        &$main_func();
    }
}

sub toLine {
    my ($sourceFile, $node) = @_;
    # Placeholder for getting line number
    return 1;
}

my $repoRoot = abs_path(dirname(__FILE__) . "/..");
my $scanRoots = resolveSourceRoots($repoRoot, ["src/plugin-sdk", "src/plugins/runtime"]);

sub compareEntries {
    my ($left, $right) = @_;
    return ($left->{category} cmp $right->{category}) ||
           ($left->{file} cmp $right->{file}) ||
           ($left->{line} <=> $right->{line}) ||
           ($left->{kind} cmp $right->{kind}) ||
           ($left->{specifier} cmp $right->{specifier}) ||
           ($left->{reason} cmp $right->{reason});
}

sub pushEntry {
    my ($entries, $entry) = @_;
    push @$entries, $entry;
}

sub scanPluginSdkExtensionFacadeSmells {
    my ($sourceFile, $filePath) = @_;
    my $relativeFile = normalizeRepoPath($repoRoot, $filePath);
    if (!$relativeFile =~ /^src\/plugin-sdk\//) {
        return [];
    }

    my @entries = ();

    # Placeholder for actual scanning logic
    return \@entries;
}

sub scanRuntimeTypeImplementationSmells {
    my ($sourceFile, $filePath) = @_;
    my $relativeFile = normalizeRepoPath($repoRoot, $filePath);
    if ($relativeFile !~ /^src\/plugins\/runtime\/types(?:-[^\/]+)?\.ts$/) {
        return [];
    }

    my @entries = ();
    # Placeholder for actual scanning logic
    return \@entries;
}

sub scanRuntimeServiceLocatorSmells {
    my ($sourceFile, $filePath) = @_;
    my $relativeFile = normalizeRepoPath($repoRoot, $filePath);
    if (!($relativeFile =~ /^src\/plugin-sdk\// || $relativeFile =~ /^src\/plugins\/runtime\//)) {
        return [];
    }

    my @entries = ();
    my %exportedNames = ();
    my @runtimeStoreCalls = ();
    my @mutableStateNodes = ();

    # Placeholder for actual scanning logic
    return \@entries;
}

sub collectArchitectureSmells {
    my @files = @{collectTypeScriptFilesFromRoots($scanRoots)};
    @files = sort { normalizeRepoPath($repoRoot, $a) cmp normalizeRepoPath($repoRoot, $b) } @files;

    return collectTypeScriptInventory({
        files => \@files,
        compareEntries => \&compareEntries,
        collectEntries => sub {
            my ($sourceFile, $filePath) = @_;
            my @plugin_sdk_smells = @{scanPluginSdkExtensionFacadeSmells($sourceFile, $filePath)};
            my @runtime_type_smells = @{scanRuntimeTypeImplementationSmells($sourceFile, $filePath)};
            my @service_locator_smells = @{scanRuntimeServiceLocatorSmells($sourceFile, $filePath)};
            return (@plugin_sdk_smells, @runtime_type_smells, @service_locator_smells);
        }
    });
}

sub formatInventoryHuman {
    my ($inventory) = @_;
    if (@$inventory == 0) {
        return "No architecture smells found for the configured checks.";
    }

    my @lines = ("Architecture smell inventory:");
    my $activeCategory = "";
    my $activeFile = "";

    for my $entry (@$inventory) {
        if ($entry->{category} ne $activeCategory) {
            $activeCategory = $entry->{category};
            $activeFile = "";
            push @lines, $entry->{category};
        }
        if ($entry->{file} ne $activeFile) {
            $activeFile = $entry->{file};
            push @lines, "  $entry->{file}";
        }
        push @lines, "    - line $entry->{line} [$entry->{kind}] $entry->{reason}";
        push @lines, "      specifier: $entry->{specifier}";
        push @lines, "      resolved: $entry->{resolvedPath}";
    }
    return join("\n", @lines);
}

sub runArchitectureSmellsCheck {
    my ($argv, $io) = @_;
    $argv //= [@ARGV[2..$#ARGV]];  # Skip script name and first two args
    $io //= { stdout => *STDOUT, stderr => *STDERR };

    my $json = grep { $_ eq "--json" } @$argv;
    my $inventory = collectArchitectureSmells();

    if ($json) {
        writeLine($io->{stdout}, JSON::PP->new->pretty->encode($inventory));
        return 0;
    }

    writeLine($io->{stdout}, formatInventoryHuman($inventory));
    my $count = scalar @$inventory;
    my $suffix = $count == 1 ? "" : "s";
    writeLine($io->{stdout}, "$count smell$suffix found.");
    return 0;
}

sub main {
    my ($argv, $io) = @_;
    return runArchitectureSmellsCheck($argv, $io);
}

runAsScript(__FILE__, \&main);

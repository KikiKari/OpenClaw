#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "f8b259e51c0c965f207589697d2248d3a65bee91e8544fbf85d2b1c90aa23841", "source_sha256": "c1ed4f7faa3c799c1ac7104f76f48529711802b8f045a3a2fa20f18a82447b76", "target_language": "perl5"}
# check-extension-plugin-sdk-boundary.mjs — portiert nach perl5
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-extension-plugin-sdk-boundary.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use File::Find;
use File::Spec;
use Cwd qw(abs_path);
use JSON::PP;
use File::Basename;

# Globale Variablen
my $repo_root = dirname(dirname(__FILE__));
my $bundled_plugin_root_dir = "src/extensions";
my $extensions_root = File::Spec->catdir($repo_root, $bundled_plugin_root_dir);

my %modes = (
    "src-outside-plugin-sdk" => 1,
    "plugin-sdk-internal" => 1,
    "relative-outside-package" => 1,
);

my %baseline_path_by_mode = (
    "src-outside-plugin-sdk" => File::Spec->catfile($repo_root, "test", "fixtures", "extension-src-outside-plugin-sdk-inventory.json"),
    "plugin-sdk-internal" => File::Spec->catfile($repo_root, "test", "fixtures", "extension-plugin-sdk-internal-inventory.json"),
    "relative-outside-package" => File::Spec->catfile($repo_root, "test", "fixtures", "extension-relative-outside-package-inventory.json"),
);

my $all_inventory_by_mode_promise;
my $parsed_extension_source_files_promise;

my %rule_text_by_mode = (
    "src-outside-plugin-sdk" => "Rule: production bundled plugins must not import src/** outside src/plugin-sdk/**",
    "plugin-sdk-internal" => "Rule: production bundled plugins must not import src/plugin-sdk-internal/**",
    "relative-outside-package" => "Rule: production bundled plugins must not use relative imports that escape their own package root",
);

sub is_code_file {
    my ($file_name) = @_;
    return $file_name =~ /\.(ts|tsx|mts|cts|js|jsx|mjs|cjs)$/;
}

sub is_boundary_canary_file {
    my ($file_name) = @_;
    return $file_name =~ /__rootdir_boundary_canary__/;
}

sub normalize_repo_path {
    my ($repo_root, $full_path) = @_;
    $full_path = abs_path($full_path);
    $repo_root = abs_path($repo_root);
    my $relative = File::Spec->abs2rel($full_path, $repo_root);
    $relative =~ s!\\!/!g;
    return $relative;
}

sub classify_bundled_extension_source_path {
    my ($relative_path) = @_;
    my $is_test_like = $relative_path =~ m{(?:^|/)__(?:tests?|mocks?|fixtures?)__/} ||
                       $relative_path =~ m{(?:^|/)(?:test|mock|fixture)} ||
                       $relative_path =~ /\.test\./ ||
                       $relative_path =~ /\.spec\./;
    return { isTestLike => $is_test_like };
}

sub collect_extension_source_files {
    my ($root_dir) = @_;
    my @out;
    
    find(sub {
        return if $_ eq 'dist' || $_ eq 'node_modules';
        return unless -f $_;
        return unless is_code_file($_);
        return if is_boundary_canary_file($_);
        
        my $full_path = $File::Find::name;
        my $relative_path = normalize_repo_path($repo_root, $full_path);
        return if classify_bundled_extension_source_path($relative_path)->{isTestLike};
        
        push @out, $full_path;
    }, $root_dir);
    
    @out = sort { normalize_repo_path($repo_root, $a) cmp normalize_repo_path($repo_root, $b) } @out;
    return @out;
}

sub collect_parsed_extension_source_files {
    if (!$parsed_extension_source_files_promise) {
        my @files = collect_extension_source_files($extensions_root);
        my @result;
        for my $file_path (@files) {
            open my $fh, '<:encoding(UTF-8)', $file_path or die "Cannot read $file_path: $!";
            my $source = do { local $/; <$fh> };
            close $fh;
            
            # In Perl, we can't parse TypeScript, so we'll store the source for later processing
            push @result, {
                filePath => $file_path,
                source => $source,
            };
        }
        $parsed_extension_source_files_promise = \@result;
    }
    return @$parsed_extension_source_files_promise;
}

sub resolve_extension_root {
    my ($file_path) = @_;
    my $relative_path = normalize_repo_path($repo_root, $file_path);
    my @segments = split '/', $relative_path;
    return undef unless $segments[0] eq $bundled_plugin_root_dir && $segments[1];
    return "$segments[0]/$segments[1]";
}

sub classify_reason {
    my ($mode, $kind, $resolved_path, $specifier) = @_;
    my $verb = $kind eq "export" ? "re-exports" :
               $kind eq "dynamic-import" ? "dynamically imports" :
                                           "imports";
                                           
    if ($mode eq "relative-outside-package") {
        if (defined $resolved_path && $resolved_path =~ /^src\/plugin-sdk\//) {
            return "$verb plugin-sdk via relative path; use openclaw/plugin-sdk/<subpath>";
        }
        if (defined $resolved_path && $resolved_path =~ /^src\//) {
            return "$verb core src path via relative path outside the extension package";
        }
        if (defined $resolved_path && $resolved_path =~ /^$bundled_plugin_root_dir/) {
            return "$verb another bundled plugin via relative path outside the extension package";
        }
        return "$verb relative path $specifier outside the extension package";
    }
    if ($mode eq "plugin-sdk-internal") {
        return "$verb src/plugin-sdk-internal from an extension";
    }
    if (defined $resolved_path && $resolved_path =~ /^src\/plugin-sdk\//) {
        return "$verb allowed plugin-sdk path";
    }
    return "$verb core src path outside plugin-sdk from an extension";
}

sub compare_entries {
    my ($left, $right) = @_;
    my $file_cmp = $left->{file} cmp $right->{file};
    return $file_cmp if $file_cmp != 0;
    my $line_cmp = $left->{line} <=> $right->{line};
    return $line_cmp if $line_cmp != 0;
    my $kind_cmp = $left->{kind} cmp $right->{kind};
    return $kind_cmp if $kind_cmp != 0;
    my $specifier_cmp = $left->{specifier} cmp $right->{specifier};
    return $specifier_cmp if $specifier_cmp != 0;
    return $left->{resolvedPath} cmp $right->{resolvedPath};
}

sub should_report {
    my ($mode, $resolved_path) = @_;
    if ($mode eq "relative-outside-package") {
        return 0;
    }
    return 0 unless defined $resolved_path && $resolved_path =~ /^src\//;
    if ($mode eq "plugin-sdk-internal") {
        return $resolved_path =~ /^src\/plugin-sdk-internal\//;
    }
    return $resolved_path !~ /^src\/plugin-sdk\//;
}

sub collect_entries_by_mode_from_source_file {
    my ($source, $file_path) = @_;
    my %entries_by_mode = (
        "src-outside-plugin-sdk" => [],
        "plugin-sdk-internal" => [],
        "relative-outside-package" => [],
    );
    
    my $extension_root = resolve_extension_root($file_path);
    my $relative_file = normalize_repo_path($repo_root, $file_path);
    
    # In Perl, we can't parse AST like TypeScript, so we'll use regex to find imports
    # This is a simplified approach - in a real implementation you'd want a proper parser
    
    # Find all import statements
    while ($source =~ /(import\s+(?:.*?from\s+)?['"](\.{1,2}[^'"]*)['"])/g) {
        my $full_match = $1;
        my $specifier = $2;
        my $line_number = ($` =~ tr/\n/\n/) + 1;
        
        # Simplified resolution - in reality this would be more complex
        my $resolved_path = resolve_repo_specifier($repo_root, $specifier, $file_path);
        
        my $base_entry = {
            file => $relative_file,
            line => $line_number,
            kind => "import",
            specifier => $specifier,
            resolvedPath => $resolved_path // "",
        };
        
        if ($specifier =~ /^\./ && defined $resolved_path && defined $extension_root) {
            if (!($resolved_path eq $extension_root || $resolved_path =~ /^\Q$extension_root\E\//)) {
                push @{$entries_by_mode{"relative-outside-package"}}, {
                    %$base_entry,
                    reason => classify_reason("relative-outside-package", "import", $resolved_path, $specifier),
                };
            }
        }
        
        for my $mode ("src-outside-plugin-sdk", "plugin-sdk-internal") {
            next unless should_report($mode, $resolved_path);
            push @{$entries_by_mode{$mode}}, {
                %$base_entry,
                reason => classify_reason($mode, "import", $resolved_path, $specifier),
            };
        }
    }
    
    return %entries_by_mode;
}

sub resolve_repo_specifier {
    my ($repo_root, $specifier, $file_path) = @_;
    # Simplified resolver - in reality this would need to handle various module resolution strategies
    if ($specifier =~ /^\.\.?\/(.*)/) {
        my $relative_path = $1;
        my $dir = dirname($file_path);
        my $resolved = File::Spec->catfile($dir, $relative_path);
        return normalize_repo_path($repo_root, $resolved);
    }
    return $specifier;
}

sub collect_extension_plugin_sdk_boundary_inventory {
    my ($mode) = @_;
    die "Unknown mode: $mode" unless exists $modes{$mode};
    
    if (!$all_inventory_by_mode_promise) {
        my @files = collect_parsed_extension_source_files();
        my %inventory_by_mode = (
            "src-outside-plugin-sdk" => [],
            "plugin-sdk-internal" => [],
            "relative-outside-package" => [],
        );
        
        for my $file_data (@files) {
            my $file_path = $file_data->{filePath};
            my $source = $file_data->{source};
            my %entries_by_mode = collect_entries_by_mode_from_source_file($source, $file_path);
            
            for my $inventory_mode (keys %modes) {
                push @{$inventory_by_mode{$inventory_mode}}, @{$entries_by_mode{$inventory_mode}};
            }
        }
        
        for my $inventory_mode (keys %modes) {
            @{$inventory_by_mode{$inventory_mode}} = sort { compare_entries($a, $b) } @{$inventory_by_mode{$inventory_mode}};
        }
        
        $all_inventory_by_mode_promise = \%inventory_by_mode;
    }
    
    my $inventory_by_mode = $all_inventory_by_mode_promise;
    return $inventory_by_mode->{$mode};
}

sub read_expected_inventory {
    my ($mode) = @_;
    my $baseline_path = $baseline_path_by_mode{$mode};
    
    if (-e $baseline_path) {
        open my $fh, '<:encoding(UTF-8)', $baseline_path or die "Cannot read $baseline_path: $!";
        my $content = do { local $/; <$fh> };
        close $fh;
        my $json = JSON::PP->new;
        return $json->decode($content);
    } else {
        if ($mode eq "plugin-sdk-internal" || $mode eq "src-outside-plugin-sdk" || $mode eq "relative-outside-package") {
            return [];
        }
        die "Cannot read $baseline_path: $!";
    }
}

sub diff_inventory_entries {
    my ($expected, $actual, $compare_func) = @_;
    my @missing;
    my @unexpected;
    
    # Convert arrays to hashes for easier comparison
    my %expected_hash;
    my %actual_hash;
    
    for my $item (@$expected) {
        my $key = join "|", $item->{file}, $item->{line}, $item->{kind}, $item->{specifier}, $item->{resolvedPath};
        $expected_hash{$key} = $item;
    }
    
    for my $item (@$actual) {
        my $key = join "|", $item->{file}, $item->{line}, $item->{kind}, $item->{specifier}, $item->{resolvedPath};
        $actual_hash{$key} = $item;
    }
    
    # Find missing items
    for my $key (keys %expected_hash) {
        push @missing, $expected_hash{$key} unless exists $actual_hash{$key};
    }
    
    # Find unexpected items
    for my $key (keys %actual_hash) {
        push @unexpected, $actual_hash{$key} unless exists $expected_hash{$key};
    }
    
    return {
        missing => \@missing,
        unexpected => \@unexpected,
    };
}

sub diff_inventory {
    my ($expected, $actual) = @_;
    return diff_inventory_entries($expected, $actual, \&compare_entries);
}

sub format_inventory_human {
    my ($mode, $inventory) = @_;
    my @lines = ($rule_text_by_mode{$mode});
    
    if (@$inventory == 0) {
        push @lines, "No extension plugin-sdk boundary violations found.";
        return join("\n", @lines);
    }
    
    push @lines, "Extension boundary inventory:";
    my $active_file = "";
    
    for my $entry (@$inventory) {
        if ($entry->{file} ne $active_file) {
            $active_file = $entry->{file};
            push @lines, $active_file;
        }
        push @lines, "  - line $entry->{line} [$entry->{kind}] $entry->{reason}";
        push @lines, "    specifier: $entry->{specifier}";
        push @lines, "    resolved: $entry->{resolvedPath}";
    }
    
    return join("\n", @lines);
}

sub write_line {
    my ($fh, $line) = @_;
    print $fh "$line\n";
}

sub run_extension_plugin_sdk_boundary_check {
    my ($argv_ref, $io) = @_;
    my @argv = @$argv_ref;
    $io //= { stdout => *STDOUT, stderr => *STDERR };
    
    my $json = grep { $_ eq "--json" } @argv;
    my ($mode_arg) = grep { $_ =~ /^--mode=/ } @argv;
    my $mode = $mode_arg ? substr($mode_arg, 7) : "src-outside-plugin-sdk";
    die "Unknown mode: $mode" unless exists $modes{$mode};
    
    my $actual = collect_extension_plugin_sdk_boundary_inventory($mode);
    
    if ($json) {
        my $json_encoder = JSON::PP->new->pretty;
        write_line($io->{stdout}, $json_encoder->encode($actual));
        return 0;
    }
    
    write_line($io->{stdout}, format_inventory_human($mode, $actual));
    
    if ($mode eq "relative-outside-package") {
        if (@$actual == 0) {
            return 0;
        }
        write_line($io->{stderr}, "Relative outside-package violations found (" . scalar(@$actual) . "); this mode no longer uses a baseline.");
        return 1;
    }
    
    my $expected = read_expected_inventory($mode);
    my $diff = diff_inventory($expected, $actual);
    
    if (@{$diff->{missing}} == 0 && @{$diff->{unexpected}} == 0) {
        write_line($io->{stdout}, "Baseline matches (" . scalar(@$actual) . " entries).");
        return 0;
    }
    
    if (@{$diff->{missing}} > 0) {
        write_line($io->{stderr}, "Missing baseline entries (" . scalar(@{$diff->{missing}}) . "):");
        for my $entry (@{$diff->{missing}}) {
            write_line($io->{stderr}, "  - $entry->{file}:$entry->{line} $entry->{reason}");
        }
    }
    
    if (@{$diff->{unexpected}} > 0) {
        write_line($io->{stderr}, "Unexpected inventory entries (" . scalar(@{$diff->{unexpected}}) . "):");
        for my $entry (@{$diff->{unexpected}}) {
            write_line($io->{stderr}, "  - $entry->{file}:$entry->{line} $entry->{reason}");
        }
    }
    
    return 1;
}

sub main {
    my ($argv_ref, $io) = @_;
    $argv_ref //= [@ARGV];
    
    my $exit_code = run_extension_plugin_sdk_boundary_check($argv_ref, $io);
    
    unless ($io) {
        exit $exit_code;
    }
    
    return $exit_code;
}

# Wenn das Skript direkt ausgeführt wird
if (!caller) {
    main();
}

1;

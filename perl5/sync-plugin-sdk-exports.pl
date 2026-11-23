#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "08e53aafc63b2fec30ec02c0d4bc6f115a0989bc44e7c8c89307f6911f674fc0", "source_sha256": "44c9196ec2dbaf8ef45323397e44f66d128313ddae44f9dfc8bba7439fe6e844", "target_language": "perl5"}
# sync-plugin-sdk-exports.mjs — portiert nach perl5
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/sync-plugin-sdk-exports.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use JSON::PP;
use File::Spec;
use Cwd;

# Helper function to get command line arguments
sub get_args {
    return @ARGV;
}

# Check if --check flag is present
my @args = get_args();
my $check_only = grep { $_ eq "--check" } @args;

# Get current working directory and package.json path
my $cwd = cwd();
my $package_json_path = File::Spec->catfile($cwd, "package.json");

# Read and parse package.json
open my $fh, '<:encoding(UTF-8)', $package_json_path or die "Could not open $package_json_path: $!";
my $content = do { local $/; <$fh> };
close $fh;

my $json = JSON::PP->new;
my $package_json = $json->decode($content);

# Get current exports or initialize empty hash
my $current_exports = $package_json->{exports} // {};

# Build synced plugin SDK exports (this would be the Perl equivalent of the JS function)
my $synced_plugin_sdk_exports = build_plugin_sdk_package_exports();

# Create next exports hash
my %next_exports = ();
my $inserted_plugin_sdk_exports = 0;

# Process current exports
for my $key (sort keys %$current_exports) {
    my $value = $current_exports->{$key};
    
    if ($key =~ m/^\.\/plugin-sdk/) {
        if (!$inserted_plugin_sdk_exports) {
            # Merge synced exports
            for my $export_key (keys %$synced_plugin_sdk_exports) {
                $next_exports{$export_key} = $synced_plugin_sdk_exports->{$export_key};
            }
            $inserted_plugin_sdk_exports = 1;
        }
        next;
    }
    
    $next_exports{$key} = $value;
    
    if ($key eq "." && !$inserted_plugin_sdk_exports) {
        # Merge synced exports
        for my $export_key (keys %$synced_plugin_sdk_exports) {
            $next_exports{$export_key} = $synced_plugin_sdk_exports->{$export_key};
        }
        $inserted_plugin_sdk_exports = 1;
    }
}

# If we haven't inserted plugin SDK exports yet, do it now
if (!$inserted_plugin_sdk_exports) {
    # Merge synced exports
    for my $export_key (keys %$synced_plugin_sdk_exports) {
        $next_exports{$export_key} = $synced_plugin_sdk_exports->{$export_key};
    }
}

# Convert hashes to JSON strings for comparison
my $next_exports_json = $json->encode(\%next_exports);
my $current_exports_json = $json->encode($current_exports);

# Handle check-only mode
if ($check_only) {
    if ($current_exports_json ne $next_exports_json) {
        print STDERR "plugin-sdk exports out of sync. Run `pnpm plugin-sdk:sync-exports`.\n";
        exit 1;
    }
    print "plugin-sdk exports synced.\n";
    exit 0;
}

# Update package.json with new exports
$package_json->{exports} = \%next_exports;

# Write updated package.json back to file
my $updated_content = $json->pretty->encode($package_json) . "\n";
open $fh, '>:encoding(UTF-8)', $package_json_path or die "Could not write to $package_json_path: $!";
print $fh $updated_content;
close $fh;

# Function to build plugin SDK package exports (Perl equivalent)
sub build_plugin_sdk_package_exports {
    # This should replicate the logic from ./lib/plugin-sdk-entries.mjs
    # Since that file isn't provided, creating a placeholder structure
    
    my $exports = {
        "./plugin-sdk" => {
            "types" => "./dist/plugin-sdk/index.d.ts",
            "default" => "./dist/plugin-sdk/index.js"
        },
        "./plugin-sdk/*" => {
            "types" => "./dist/plugin-sdk/*.d.ts",
            "default" => "./dist/plugin-sdk/*.js"
        },
        "./plugin-sdk/package.json" => "./package.json"
    };
    
    return $exports;
}

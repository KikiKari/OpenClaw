#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "4dc756caf469f33c90772598a9c33113c5f5208478057b716c9983837d718f32", "source_sha256": "fd0e09df4d2dcc4aafd9784f264f0b9e5a046c02335886978c614026a9f3648c", "target_language": "perl5"}
# runtime-postbuild.mjs — portiert nach perl5
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/runtime-postbuild.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use File::Spec;
use File::Copy;
use File::Find;
use Cwd qw(abs_path);

# Lade benötigte Module
require "./copy-bundled-plugin-metadata.pl";
require "./copy-plugin-sdk-root-alias.pl";
require "./runtime-postbuild-shared.pl";
require "./stage-bundled-plugin-runtime-deps.pl";
require "./stage-bundled-plugin-runtime.pl";
require "./write-official-channel-catalog.pl";

# Konstanten
my $ROOT = File::Spec->catdir(File::Spec->updir(), File::Spec->curdir());
$ROOT = abs_path($ROOT);

# Pattern für Runtime-Aliase
my $ROOT_RUNTIME_ALIAS_PATTERN = qr/^(?<base>.+\.(?:runtime|contract))-[A-Za-z0-9_-]+\.js$/;

# Statische Assets
my @STATIC_EXTENSION_ASSETS = (
    # acpx MCP proxy
    {
        src => "extensions/acpx/src/runtime-internals/mcp-proxy.mjs",
        dest => "dist/extensions/acpx/mcp-proxy.mjs"
    },
    # diffs viewer runtime bundle
    {
        src => "extensions/diffs/assets/viewer-runtime.js",
        dest => "dist/extensions/diffs/assets/viewer-runtime.js"
    }
);

sub listStaticExtensionAssetOutputs {
    my %params = @_;
    my $assets_ref = $params{assets} // \@STATIC_EXTENSION_ASSETS;
    
    my @destinations = map { $_->{dest} =~ s/\\/\//gr } @$assets_ref;
    @destinations = sort { $a cmp $b } @destinations;
    return @destinations;
}

sub copyStaticExtensionAssets {
    my %params = @_;
    my $rootDir = $params{rootDir} // $ROOT;
    my $assets_ref = $params{assets} // \@STATIC_EXTENSION_ASSETS;
    my $warn_sub = $params{warn} // sub { warn @_ };
    
    for my $asset (@$assets_ref) {
        my $src = $asset->{src};
        my $dest = $asset->{dest};
        
        my $srcPath = File::Spec->catfile($rootDir, $src);
        my $destPath = File::Spec->catfile($rootDir, $dest);
        
        if (-e $srcPath) {
            my ($volume, $directories, $filename) = File::Spec->splitpath($destPath);
            my @dirs = File::Spec->splitdir($directories);
            pop @dirs if $dirs[-1] eq '';
            my $destDir = File::Spec->catdir(@dirs);
            
            unless (-d $destDir) {
                mkpath($destDir) or die "Konnte Verzeichnis $destDir nicht erstellen: $!";
            }
            
            copy($srcPath, $destPath) or die "Konnte $srcPath nicht nach $destPath kopieren: $!";
        } else {
            $warn_sub->("[runtime-postbuild] static asset not found, skipping: $src\n");
        }
    }
}

sub writeStableRootRuntimeAliases {
    my %params = @_;
    my $rootDir = $params{rootDir} // $ROOT;
    my $distDir = File::Spec->catdir($rootDir, "dist");
    
    opendir(my $dh, $distDir) or return;
    my @entries = readdir($dh);
    closedir($dh);
    
    for my $entry (@entries) {
        next if $entry =~ /^\.\.?$/; # Überspringe . und ..
        my $fullPath = File::Spec->catfile($distDir, $entry);
        next unless -f $fullPath;
        
        if ($entry =~ /$ROOT_RUNTIME_ALIAS_PATTERN/) {
            my $base = $+{base};
            if ($base) {
                my $aliasPath = File::Spec->catfile($distDir, "$base.js");
                writeTextFileIfChanged($aliasPath, "export * from \"./$entry\";\n");
            }
        }
    }
}

sub runRuntimePostBuild {
    my %params = @_;
    
    copyPluginSdkRootAlias(%params);
    copyBundledPluginMetadata(%params);
    writeOfficialChannelCatalog(%params);
    stageBundledPluginRuntimeDeps(%params);
    stageBundledPluginRuntime(%params);
    writeStableRootRuntimeAliases(%params);
    copyStaticExtensionAssets(%params);
}

# Hauptausführung wenn das Skript direkt aufgerufen wird
if (!caller) {
    runRuntimePostBuild();
}

1;

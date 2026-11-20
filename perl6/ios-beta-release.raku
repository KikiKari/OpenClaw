#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "cb21153a2a4583d0822671025db1945ab425054a1f05bd277ce9788dd491d13c", "source_sha256": "74168ccc75bdca2481fb7bf1298fad30cea4e5fdd917205e7f1815e86948ca0c", "target_language": "perl6"}
# ios-beta-release.sh — portiert nach perl6
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-beta-release.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

use MONKEY-SEE-NO-EVAL;

sub usage() {
    say q:to/EOF/;
Usage:
  scripts/ios-beta-release.sh [--build-number 7]

Archives and uploads a beta-release IPA to TestFlight locally.
EOF
}

my $BUILD_NUMBER = %*ENV<IOS_BETA_BUILD_NUMBER> // '';
my $ROOT_DIR = EVAL('Cwd::cwd()').parent.child('..').absolute;

sub MAIN(*@args) {
    my @argv = @args;
    
    while @argv.elems > 0 {
        given @argv.shift {
            when '--' {
                # noop
            }
            when '--build-number' {
                $BUILD_NUMBER = @argv.shift // '';
            }
            when '-h'|'--help' {
                usage();
                exit 0;
            }
            default {
                note "Unknown argument: $_";
                usage();
                exit 1;
            }
        }
    }
    
    my $ios_dir = $ROOT_DIR.child('apps').child('ios');
    if $ios_dir.d {
        CATCH {
            default {
                note "Error changing to directory: " ~ $ios_dir.Str;
                exit 1;
            }
        }
        
        # Set environment variable and run fastlane command
        %*ENV<IOS_BETA_BUILD_NUMBER> = $BUILD_NUMBER;
        shell "fastlane ios beta", :cwd($ios_dir.Str);
    } else {
        note "Directory does not exist: " ~ $ios_dir.Str;
        exit 1;
    }
}

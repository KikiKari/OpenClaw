#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "a48d7bc703396c8e22af36115b68930718c2b2a1dfab4188a775a63b41bd3ac5", "source_sha256": "2cdcdc862375b173b06398d139b611f6f002e0435191f56d26d3e48a3cef02cf", "target_language": "perl6"}
# ios-beta-archive.sh — portiert nach perl6
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-beta-archive.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

use v6;

sub usage() {
    say q:to/EOF/.trim-trailing;
    Usage:
      scripts/ios-beta-archive.sh [--build-number 7]

    Archives and exports a beta-release IPA locally without uploading.
    EOF
}

my $BUILD_NUMBER = %*ENV<IOS_BETA_BUILD_NUMBER> // '';
my $ROOT_DIR = IO::Path.new($?FILE).parent(2).absolute;

sub MAIN(|args) {
    my @arguments = @*ARGS;
    while @arguments {
        given @arguments[0] {
            when '--' {
                @arguments.shift;
            }
            when '--build-number' {
                $BUILD_NUMBER = @arguments[1] // '';
                @arguments.splice(0, 2);
            }
            when '-h' | '--help' {
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

    my $cwd = $*CWD;
    LEAVE $*CWD = $cwd;
    
    chdir("$ROOT_DIR/apps/ios");
    %*ENV<IOS_BETA_BUILD_NUMBER> = $BUILD_NUMBER;
    
    run('fastlane', 'ios', 'beta_archive');
}

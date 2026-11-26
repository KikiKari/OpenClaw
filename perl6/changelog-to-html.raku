#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "f40d6787ab62f7aa82d9fc8693da6f9f9e5c305c3673f1997f706a864941dda6", "source_sha256": "13f974bf78b140bc88bd9f3afe27c500660ef59498ed533c38c18bca0c6f6331", "target_language": "perl6"}
# changelog-to-html.sh — portiert nach perl6
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/changelog-to-html.sh
# Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

use v6;

sub MAIN($version = "", $changelog-file = "") {
    if $version eq "" {
        note "Usage: {$*PROGRAM.name} <version> [changelog_file]";
        exit 1;
    }

    my $script-dir = $*PROGRAM.parent.absolute;
    my $changelog-path = $changelog-file;

    if $changelog-path eq "" {
        if "$script-dir/../CHANGELOG.md".IO.f {
            $changelog-path = "$script-dir/../CHANGELOG.md";
        } elsif "CHANGELOG.md".IO.f {
            $changelog-path = "CHANGELOG.md";
        } elsif "../CHANGELOG.md".IO.f {
            $changelog-path = "../CHANGELOG.md";
        } else {
            note "Error: Could not find CHANGELOG.md";
            exit 1;
        }
    }

    if not $changelog-path.IO.f {
        note "Error: Changelog file '$changelog-path' not found";
        exit 1;
    }

    sub extract-version-section($ver, $file) {
        my @lines = $file.IO.lines;
        my $found = False;
        my @result;

        for @lines -> $line {
            if $line ~~ /^ '## ' / {
                if $line ~~ /^ '## ' $ver [\s .*]? $/ {
                    $found = True;
                    next;
                }
                if $found {
                    last;
                }
            }
            if $found {
                @result.push($line);
            }
        }
        return @result.join("\n");
    }

    sub markdown-to-html($text) {
        $text ~~ s:g/^ '##### ' (.*) $/<h5>$0<\/h5>/;
        $text ~~ s:g/^ '#### ' (.*) $/<h4>$0<\/h4>/;
        $text ~~ s:g/^ '### ' (.*) $/<h3>$0<\/h3>/;
        $text ~~ s:g/^ '## ' (.*) $/<h2>$0<\/h2>/;
        $text ~~ s:g/^ '- **' (.*?) '**' (.*) $/<li><strong>$0<\/strong>$1<\/li>/;
        $text ~~ s:g/^ '- ' (<!before '*'>.*) $/<li>$0<\/li>/;
        $text ~~ s:g/'**' (.*?) '**'/$0/;
        $text ~~ s:g/'`' (.*?) '`'/$0/;
        $text ~~ s:g/'[' (.*?) '](' (.*?) ')'/$0/;
        return $text;
    }

    my $version-content = extract-version-section($version, $changelog-path);

    if $version-content eq "" {
        say "<h2>OpenClaw $version</h2>";
        say "<p>Latest OpenClaw update.</p>";
        say "<p><a href=\"https://github.com/openclaw/openclaw/blob/main/CHANGELOG.md\">View full changelog</a></p>";
        exit 0;
    }

    say "<h2>OpenClaw $version</h2>";

    my $in-list = False;
    for $version-content.lines -> $line {
        if $line ~~ /^ '-' / {
            if not $in-list {
                say "<ul>";
                $in-list = True;
            }
            say markdown-to-html($line);
        } else {
            if $in-list {
                say "</ul>";
                $in-list = False;
            }
            if $line ne "" {
                say markdown-to-html($line);
            }
        }
    }

    if $in-list {
        say "</ul>";
    }

    say "<p><a href=\"https://github.com/openclaw/openclaw/blob/main/CHANGELOG.md\">View full changelog</a></p>";
}

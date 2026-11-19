#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "fa229cf7267f941f761b119fbbfdd4778a7f71efda12953068489dd85ccd93d5", "source_sha256": "5d90ebcd250a3cb80a0de664d94397af7ec03343d9d9fa64a28a9a11ad880754", "target_language": "perl6"}
# check_conflicts.py — portiert nach perl6
# Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/check_conflicts.py
# auch in: OpenClaw@gateway2:skills/sync-utils/scripts/check_conflicts.py
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

# Check Conflicts - Erkennt Sync-Konflikte

use v6;

# Define constants for directory paths
my $CLAWHUB-DIR = '/home/openclaw/.openclaw/workspace/skills';
my $GIT-DIR = '/home/openclaw/.openclaw/workspace/git/skills';

# Function to compute SHA-256 hash of a file
sub get-file-hash($file-path) {
    return '' unless $file-path.IO.e;
    my $hash = run('sha256sum', $file-path, :out).out.lines[0].split(' ')[0];
    return $hash;
}

# Main function to check for conflicts between ClawHub and Git
sub check-conflicts() {
    my @conflicts;

    # Get skills that exist in both directories
    my @common-skills;
    if $CLAWHUB-DIR.IO.d && $GIT-DIR.IO.d {
        my @clawhub-skills = $CLAWHUB-DIR.IO.dir.grep(*.d).map(*.basename);
        my @git-skills = $GIT-DIR.IO.dir.grep(*.d).map(*.basename);
        @common-skills = @clawhub-skills (&) @git-skills;
    }

    say "Prüfe {@common-skills.elems} Skills auf Konflikte...\n";

    for @common-skills.sort -> $skill {
        my $clawhub-path = $CLAWHUB-DIR ~ '/' ~ $skill;
        my $git-path = $GIT-DIR ~ '/' ~ $skill;

        # Compare all files within the skill directory
        my %clawhub-files;
        for $clawhub-path.IO.dir(:!hidden, :recursive) -> $f {
            next unless $f.f;
            my $rel-path = $f.relative($clawhub-path);
            %clawhub-files{$rel-path} = $f.Str;
        }

        my %git-files;
        for $git-path.IO.dir(:!hidden, :recursive) -> $f {
            next unless $f.f;
            my $rel-path = $f.relative($git-path);
            %git-files{$rel-path} = $f.Str;
        }

        # Find conflicting files with different hashes
        my @skill-conflicts;
        for %clawhub-files.keys ∩ %git-files.keys -> $rel-path {
            my $clawhub-file = %clawhub-files{$rel-path};
            my $git-file = %git-files{$rel-path};

            if get-file-hash($clawhub-file) ne get-file-hash($git-file) {
                my $clawhub-mtime = DateTime.new($clawhub-file.IO.changed).strftime('%Y-%m-%d %H:%M:%S');
                my $git-mtime = DateTime.new($git-file.IO.changed).strftime('%Y-%m-%d %H:%M:%S');

                @skill-conflicts.push({
                    file => $rel-path,
                    clawhub-modified => $clawhub-mtime,
                    git-modified => $git-mtime,
                    newer => $clawhub-mtime gt $git-mtime ?? 'clawhub' !! 'git'
                });
            }
        }

        if @skill-conflicts.elems > 0 {
            @conflicts.push({
                skill => $skill,
                conflicts => @skill-conflicts
            });
        }
    }

    # Output results
    if @conflicts.elems > 0 {
        say "⚠️  KONFLIKTE GEFUNDEN:";
        say "=" x 80;

        for @conflicts -> $conflict {
            say "\n📦 Skill: {$conflict<skill>}";
            say "-" x 40;

            for $conflict<conflicts>.list -> $file-conflict {
                say "  📄 {$file-conflict<file>}";
                say "     ClawHub: {$file-conflict<clawhub-modified>}";
                say "     Git:     {$file-conflict<git-modified>}";
                say "     Neuer:   {$file-conflict<newer>.uc}";
                say "";
            }
        }

        say "=" x 80;
        say "Gesamt: {@conflicts.elems} Skills mit Konflikten";
        say "\nNutze 'sync_utils/scripts/resolve_conflict.py' zum Auflösen.";
    } else {
        say "✅ Keine Konflikte gefunden!";
        say "Alle gemeinsamen Skills sind synchron.";
    }
}

# Entry point
sub MAIN() {
    check-conflicts();
}

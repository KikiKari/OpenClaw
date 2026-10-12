#!/usr/bin/perl
# test_sync_real.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:scripts/test_sync_real.py
# auch in: OpenClaw@gateway2:scripts/test_sync_real.py
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Find;
use File::Spec;

# Test echte Synchronisation

# Füge das Verzeichnis zum @INC Pfad hinzu
push @INC, '/home/openclaw/.openclaw/workspace/scripts';

# Da Perl keine direkte Entsprechung zu Python's module import hat,
# müssen wir eine Art finden, die Funktionen zu laden.
# In diesem Fall gehen wir davon aus, dass sync_clawhub_git.pm existiert
# und die benötigten Funktionen bereitstellt.
require sync_clawhub_git;

# Test: db-maintainer ClawHub → Git (ECHT)
print "=== TEST: db-maintainer sync (REAL) ===\n";
my $skill = "db-maintainer";
my $result = sync_clawhub_git::sync_to_git($skill, 0); # 0 für dry_run=false
print "Result: " . ($result ? 'SUCCESS' : 'FAILED') . "\n";

# Prüfe Ergebnis
my $target = "/home/openclaw/.openclaw/workspace/git/skills/db-maintainer";
if (-d $target) {
    print "\n✅ Git-Repo erstellt: $target\n";
    
    # Rekursives Verzeichnislisting ähnlich wie os.walk
    find(sub {
        my $dir = $File::Find::dir;
        my $file = $_;
        
        # Bestimme die Tiefe im Verzeichnisbaum
        my $relative_path = substr($dir, length($target));
        $relative_path =~ s|^/||; # Entferne führenden Slash
        my @path_parts = grep { $_ ne '' } split('/', $relative_path);
        my $level = scalar(@path_parts);
        
        # Für das aktuelle Verzeichnis
        if (-d $_ && $_ eq $_) {
            my $basename = ($_ eq '.' ? '' : $_);
            if ($basename ne '') {
                my $indent = ' ' x (2 * $level);
                print "${indent}${basename}/\n";
            }
        }
        # Für Dateien
        elsif (-f $_) {
            my $subindent = ' ' x (2 * ($level + 1));
            print "${subindent}${_}\n";
        }
    }, $target);
}

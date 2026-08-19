#!/usr/bin/env perl
# install_cron.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:skills/db-maintainer/scripts/install_cron.py
# auch in: OpenClaw@gateway2:skills/db-maintainer/scripts/install_cron.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use JSON;
use File::Path qw(make_path);
use File::Spec;

# Installiert den DB-Maintainer als Cron-Job

my $CRON_JOB = <<'EOF';
# DB Maintainer - Alle 30 Minuten
*/30 * * * * cd /home/openclaw/.openclaw/workspace && python3 skills/db-maintainer/scripts/db_maintainer.py >> logs/db-maintainer/cron.log 2>&1
EOF

sub install_cron {
    my $workspace = "/home/openclaw/.openclaw/workspace";
    my $cron_file = "$workspace/crons/db-maintainer.cron";
    
    # Erstelle das Verzeichnis falls es nicht existiert
    my ($volume, $directories) = File::Spec->splitpath($cron_file);
    my $cron_dir = File::Spec->catpath($volume, $directories, '');
    make_path($cron_dir) unless -d $cron_dir;
    
    # Schreibe den Cron-Job in die Datei
    open(my $fh, '>', $cron_file) or die "Konnte Datei '$cron_file' nicht öffnen: $!";
    print $fh $CRON_JOB;
    close($fh);
    
    print "✅ Cron-Job installiert: $cron_file\n";
    print "   Füge zu crontab hinzu mit: crontab < crons/db-maintainer.cron\n";
    
    # Auch in OpenClaw cron registrieren
    my $jobs_json = "$workspace/.openclaw/cron/jobs.json";
    if (-e $jobs_json) {
        # Lese die bestehende JSON-Datei
        open(my $json_fh, '<', $jobs_json) or die "Konnte Datei '$jobs_json' nicht öffnen: $!";
        local $/;
        my $json_text = <$json_fh>;
        close($json_fh);
        
        my $jobs = decode_json($json_text);
        
        # Aktualisiere oder füge den neuen Job hinzu
        $jobs->{'db-maintainer'} = {
            schedule => '*/30 * * * *',
            command  => 'python3 skills/db-maintainer/scripts/db_maintainer.py',
            enabled  => JSON::true
        };
        
        # Schreibe die aktualisierte JSON-Datei zurück
        open($json_fh, '>', $jobs_json) or die "Konnte Datei '$jobs_json' nicht öffnen: $!";
        print $json_fh encode_json($jobs);
        close($json_fh);
        
        print "✅ In OpenClaw cron registriert\n";
    }
}

install_cron() if __FILE__ eq $0;

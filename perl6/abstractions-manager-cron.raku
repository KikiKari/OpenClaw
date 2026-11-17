#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "28c89da946b276e2d844b0502a149f612d949d29d326a937c4dd4d06375c2973", "source_sha256": "1b01ca0f5943b16d3905faf557953600ee54f15ecf1dc18c1461585eba94d376", "target_language": "perl6"}
# abstractions-manager-cron.sh — portiert nach perl6
# Quelle: shell, OpenClaw@gateway1:scripts/abstractions-manager-cron.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use v6;

# Setzt die Umgebungsvariablen und führt das Python-Skript mit Locking aus

# Setze PATH
%*ENV<PATH> = '/home/openclaw/.local/bin:/usr/local/bin:/usr/bin:/bin';

# Lade Umgebungsvariablen aus der .env-Datei
my $env-file = '/home/openclaw/.openclaw/.env';
if $env-file.IO.e {
    for $env-file.IO.lines -> $line {
        next if $line ~~ /^ \s* '#' /;  # Überspringe Kommentare
        next unless $line ~~ / '=' /;   # Überspringe Zeilen ohne Zuweisung
        my ($key, $value) = $line.split('=', 2);
        $key .= trim;
        $value .= trim;
        # Entferne umschließende Anführungszeichen falls vorhanden
        $value ~~ s/^\"(.*)\"$/$0/;
        $value ~~ s/^\'(.*)\'$/$0/;
        %*ENV{$key} = $value;
    }
}

# Prüfe ob OPENROUTER_API_KEY gesetzt ist
die "OPENROUTER_API_KEY fehlt" unless %*ENV<OPENROUTER_API_KEY>:exists;

# Setze GITHUB_TOKEN aus Alternativen
%*ENV<GITHUB_TOKEN> = %*ENV<GITHUB_TOKEN> // %*ENV<GH_TOKEN> // %*ENV<GH_ACCESS_TOKEN> // '';

# Führe flock Befehl aus
my $lockfile = '/home/openclaw/.openclaw/locks/abstractions-manager.lock';
my $python-script = '/home/openclaw/.openclaw/workspace/skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py';

# Prüfe ob die benötigten Dateien existieren
die "Lockfile nicht gefunden: $lockfile" unless $lockfile.IO.e or $lockfile.IO.d;
die "Python-Skript nicht gefunden: $python-script" unless $python-script.IO.e;

# Führe flock mit exec aus (non-blocking)
my @cmd = 'flock', '--nonblock', $lockfile, 'python3', $python-script, |@*ARGS;
run(|@cmd) or die "Fehler beim Ausführen des Kommandos: {@cmd.join(' ')}";

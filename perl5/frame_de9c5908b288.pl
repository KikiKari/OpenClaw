#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "73db7beee82e870776d35e102135e0bd65486766392fe3e0e938bed11fafd496", "source_sha256": "b339455e9e618c836ccf2e3732e4fec9897f079730d8814eadb716e2459df453", "target_language": "perl5"}
# frame.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway1:skills/video-frames/scripts/frame.sh
# auch in: OpenClaw@gateway2:skills/video-frames/scripts/frame.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Getopt::Long;
use File::Basename;
use File::Path qw(make_path);
use Pod::Usage;

sub usage {
    print STDERR <<'EOF';
Usage:
  frame.sh <video-file> [--time HH:MM:SS] [--index N] --out /path/to/frame.jpg

Examples:
  frame.sh video.mp4 --out /tmp/frame.jpg
  frame.sh video.mp4 --time 00:00:10 --out /tmp/frame-10s.jpg
  frame.sh video.mp4 --index 0 --out /tmp/frame0.png
EOF
    exit 2;
}

# Prüfe auf Hilfe-Optionen oder leere Eingabe
if (!@ARGV || $ARGV[0] eq '-h' || $ARGV[0] eq '--help') {
    usage();
}

my $in = shift @ARGV;

my ($time, $index, $out);
GetOptions(
    'time=s'  => \$time,
    'index=s' => \$index,
    'out=s'   => \$out,
) or usage();

# Prüfe ob Eingabedatei existiert
if (!-f $in) {
    print STDERR "File not found: $in\n";
    exit 1;
}

# Prüfe ob Ausgabepfad angegeben wurde
if (!defined $out || $out eq '') {
    print STDERR "Missing --out\n";
    usage();
}

# Erstelle Zielverzeichnis falls nötig
my $outdir = dirname($out);
make_path($outdir) or die "Could not create directory $outdir: $!" unless -d $outdir;

# Führe ffmpeg-Befehl entsprechend den Optionen aus
if (defined $index && $index ne '') {
    system('ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
           '-i', $in,
           '-vf', "select=eq(n\\,$index)",
           '-vframes', '1',
           $out) == 0 or die "ffmpeg failed: $?";
} elsif (defined $time && $time ne '') {
    system('ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
           '-ss', $time,
           '-i', $in,
           '-frames:v', '1',
           $out) == 0 or die "ffmpeg failed: $?";
} else {
    system('ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
           '-i', $in,
           '-vf', 'select=eq(n\\,0)',
           '-vframes', '1',
           $out) == 0 or die "ffmpeg failed: $?";
}

print "$out\n";

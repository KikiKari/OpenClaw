#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "1e42d5d7f10454f4b739a274abdb04fcbcdce3d6092f27b83d8fca44637dba84", "source_sha256": "b339455e9e618c836ccf2e3732e4fec9897f079730d8814eadb716e2459df453", "target_language": "perl6"}
# frame.sh — portiert nach perl6
# Quelle: shell, OpenClaw@gateway1:skills/video-frames/scripts/frame.sh
# auch in: OpenClaw@gateway2:skills/video-frames/scripts/frame.sh
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

use v6;

sub usage() {
    note q:to/EOF/;
    Usage:
      frame.raku <video-file> [--time HH:MM:SS] [--index N] --out /path/to/frame.jpg

    Examples:
      frame.raku video.mp4 --out /tmp/frame.jpg
      frame.raku video.mp4 --time 00:00:10 --out /tmp/frame-10s.jpg
      frame.raku video.mp4 --index 0 --out /tmp/frame0.png
    EOF
    exit 2;
}

sub MAIN($in? is copy, *@args) {
    # Help handling
    if !$in.defined || $in eq '-h' || $in eq '--help' {
        usage();
    }

    # Parse arguments
    my $time = '';
    my $index = '';
    my $out = '';

    my @argv = @args;
    while @argv.elems > 0 {
        given @argv[0] {
            when '--time' {
                if @argv.elems < 2 {
                    note "Missing value for --time";
                    usage();
                }
                $time = @argv[1];
                @argv.splice(0, 2);
            }
            when '--index' {
                if @argv.elems < 2 {
                    note "Missing value for --index";
                    usage();
                }
                $index = @argv[1];
                @argv.splice(0, 2);
            }
            when '--out' {
                if @argv.elems < 2 {
                    note "Missing value for --out";
                    usage();
                }
                $out = @argv[1];
                @argv.splice(0, 2);
            }
            default {
                note "Unknown arg: $_";
                usage();
            }
        }
    }

    # Check input file
    if ! $in.IO.f {
        note "File not found: $in";
        exit 1;
    }

    # Check output file
    if $out eq '' {
        note "Missing --out";
        usage();
    }

    # Create output directory
    my $outdir = $out.IO.dirname;
    unless $outdir eq '.' || $outdir.IO.d {
        mkdir $outdir;
    }

    # Run ffmpeg command based on provided options
    if $index ne '' {
        run 'ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
            '-i', $in,
            '-vf', "select=eq(n\\,$index)",
            '-vframes', '1',
            $out;
    } elsif $time ne '' {
        run 'ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
            '-ss', $time,
            '-i', $in,
            '-frames:v', '1',
            $out;
    } else {
        run 'ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
            '-i', $in,
            '-vf', 'select=eq(n\,0)',
            '-vframes', '1',
            $out;
    }

    say $out;
}

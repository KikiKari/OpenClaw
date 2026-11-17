#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "703e8f894d084be4f8ba9c6f8a09d4d9bacd80e76889aeb6f129e1e351ec2151", "source_sha256": "b339455e9e618c836ccf2e3732e4fec9897f079730d8814eadb716e2459df453", "target_language": "perl6"}
# frame.sh — portiert nach perl6
# Quelle: shell, OpenClaw@gateway1:skills/video-frames/scripts/frame.sh
# auch in: OpenClaw@gateway2:skills/video-frames/scripts/frame.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

use v6;

sub usage() {
    note q:to/EOF/.trim-trailing;
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
    if !$in.defined || $in eq '-h' || $in eq '--help' {
        usage();
    }

    my $time = '';
    my $index = '';
    my $out = '';

    my @remaining = @args;
    while @remaining.elems > 0 {
        given @remaining[0] {
            when '--time' {
                if @remaining.elems < 2 {
                    note "Missing value for --time";
                    usage();
                }
                $time = @remaining[1];
                @remaining = @remaining[2..*];
            }
            when '--index' {
                if @remaining.elems < 2 {
                    note "Missing value for --index";
                    usage();
                }
                $index = @remaining[1];
                @remaining = @remaining[2..*];
            }
            when '--out' {
                if @remaining.elems < 2 {
                    note "Missing value for --out";
                    usage();
                }
                $out = @remaining[1];
                @remaining = @remaining[2..*];
            }
            default {
                note "Unknown arg: $_";
                usage();
            }
        }
    }

    if !"$in".IO.f {
        note "File not found: $in";
        exit 1;
    }

    if $out eq '' {
        note "Missing --out";
        usage();
    }

    # Create output directory if it doesn't exist
    my $outdir = $out.IO.dirname;
    unless $outdir eq '.' || $outdir.IO.d {
        mkdir $outdir;
    }

    my @cmd;
    if $index ne '' {
        @cmd = <
            ffmpeg -hide_banner -loglevel error -y
            -i {in}
            -vf select=eq(n\,{index})
            -vframes 1
            {out}
        >;
    } elsif $time ne '' {
        @cmd = <
            ffmpeg -hide_banner -loglevel error -y
            -ss {time}
            -i {in}
            -frames:v 1
            {out}
        >;
    } else {
        @cmd = <
            ffmpeg -hide_banner -loglevel error -y
            -i {in}
            -vf select=eq(n\,0)
            -vframes 1
            {out}
        >;
    }

    run(@cmd) or die "Failed to run ffmpeg";

    say $out;
}

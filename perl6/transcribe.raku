#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "3a20f29838e91a2c77dcb67caf0dbb700f2615e5bda56b3f6bbd2916becbd842", "source_sha256": "9c8abc93c198b77f804a6837db7baf1e85c902dc35a853c8086222a89f83fc89", "target_language": "perl6"}
# transcribe.sh — portiert nach perl6
# Quelle: shell, workspace@local:skills/github-clones/openclaw/skills/openai-whisper-api/scripts/transcribe.sh
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

use v6;

sub usage() {
    note q:to/EOF/;
    Usage:
      transcribe.raku <audio-file> [--model whisper-1] [--out /path/to/out.txt] [--language en] [--prompt "hint"] [--json]
    EOF
    exit 2;
}

sub MAIN($in where { !*.defined || $_ eq '-h' || $_ eq '--help' } = '', *@args) {
    usage() unless $in && $in ne '-h' && $in ne '--help';
    
    my %options = (
        model => 'whisper-1',
        out => '',
        language => '',
        prompt => '',
        json => False,
    );
    
    my @remaining = @args;
    while @remaining.elems > 0 {
        given @remaining[0] {
            when '--model' {
                if @remaining.elems < 2 {
                    note "Missing value for --model";
                    usage();
                }
                %options<model> = @remaining[1];
                @remaining = @remaining[2..*];
            }
            when '--out' {
                if @remaining.elems < 2 {
                    note "Missing value for --out";
                    usage();
                }
                %options<out> = @remaining[1];
                @remaining = @remaining[2..*];
            }
            when '--language' {
                if @remaining.elems < 2 {
                    note "Missing value for --language";
                    usage();
                }
                %options<language> = @remaining[1];
                @remaining = @remaining[2..*];
            }
            when '--prompt' {
                if @remaining.elems < 2 {
                    note "Missing value for --prompt";
                    usage();
                }
                %options<prompt> = @remaining[1];
                @remaining = @remaining[2..*];
            }
            when '--json' {
                %options<json> = True;
                @remaining.shift;
            }
            default {
                note "Unknown arg: $_";
                usage();
            }
        }
    }
    
    if ! $in.IO.f {
        note "File not found: $in";
        exit 1;
    }
    
    my $OPENAI_API_KEY = %*ENV<OPENAI_API_KEY>;
    if !$OPENAI_API_KEY.defined || $OPENAI_API_KEY eq '' {
        note "Missing OPENAI_API_KEY";
        exit 1;
    }
    
    my $out = %options<out>;
    if $out eq '' {
        my $base = $in ~~ s/\.([^.]*)$// ?? ~$/ !! $in;
        if %options<json> {
            $out = "$base.json";
        } else {
            $out = "$base.txt";
        }
    }
    
    # Create directory if needed
    my $dir = $out ~~ m/^(.*)\/[^\/]*$/ ?? ~$0 !! '.';
    if $dir ne '.' {
        mkdir $dir unless $dir.IO.d;
    }
    
    my $response_format = %options<json> ?? 'json' !! 'text';
    my $api_base = %*ENV<OPENAI_BASE_URL> // 'https://api.openai.com/v1';
    $api_base ~~ s/\/$//;
    
    my @curl-args = (
        'curl', '-sS', "$api_base/audio/transcriptions",
        '-H', "Authorization: Bearer $OPENAI_API_KEY",
        '-H', 'Accept: application/json',
        '-F', "file=@$in",
        '-F', "model={%options<model>}",
        '-F', "response_format=$response_format"
    );
    
    if %options<language> ne '' {
        @curl-args.push('-F', "language={%options<language>}");
    }
    
    if %options<prompt> ne '' {
        @curl-args.push('-F', "prompt={%options<prompt>}");
    }
    
    @curl-args.push('>', $out);
    
    my $command = @curl-args.join(' ');
    shell($command);
    
    say $out;
}

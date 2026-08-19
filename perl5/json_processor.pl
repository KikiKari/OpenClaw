#!/usr/bin/env perl
# json_processor.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_processor.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_processor.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use JSON qw(decode_json encode_json);
use File::Slurp qw(read_file);
use Getopt::Long qw(GetOptions);
use Pod::Usage qw(pod2usage);

# JSON Processor mit Validierung und Reparatur.
# Für robuste Verarbeitung von LLM-Outputs.

# Globale Variablen
my $HAS_JSON_REPAIR = 0; # In Perl nicht direkt verfügbar, daher immer 0

# Base exception for JSON processing errors
package JSONProcessingError {
    use base 'Exception::Class::Base';
    __PACKAGE__->mk_accessors(qw(message));
}

# Raised when JSON validation fails
package JSONValidationError {
    use base 'JSONProcessingError';
}

# Raised when JSON repair fails
package JSONRepairError {
    use base 'JSONProcessingError';
}

# Repariert häufige JSON-Fehler aus LLM-Outputs
sub repair_json_string {
    my ($raw_json) = @_;
    
    # Fallback: Manuelle Reparaturen
    my $cleaned = $raw_json;
    $cleaned =~ s/^\s+|\s+$//g; # strip
    
    # Entferne JavaScript-Kommentare
    $cleaned =~ s|//.*?\n|\n|g;
    $cleaned =~ s|/\*.*?\*/||gs;
    
    # Entferne trailing commas vor ] oder }
    $cleaned =~ s/,(\s*[\}\]])/$1/g;
    
    return $cleaned;
}

# Parst JSON-String mit optionaler automatischer Reparatur
sub parse_json {
    my ($raw_input, $repair) = @_;
    $repair //= 1;
    $raw_input =~ s/^\s+|\s+$//g; # strip
    
    # Versuche zuerst direktes Parsing
    eval {
        return decode_json($raw_input);
    };
    if ($@) {
        # Extrahiere JSON aus Markdown-Code-Blöcken
        if ($raw_input =~ /```/) {
            # Suche nach JSON in ```json ... ``` oder ``` ... ```
            my @patterns = (
                qr/```json\s*(.*?)\s*```/s,
                qr/```\s*(\{.*?\})\s*```/s,
                qr/```\s*(\[.*?\])\s*```/s,
            );
            for my $pattern (@patterns) {
                while ($raw_input =~ /$pattern/g) {
                    my $match = $1;
                    eval {
                        return decode_json($match);
                    };
                }
            }
        }
        
        # Versuche Reparatur
        if ($repair) {
            eval {
                my $repaired = repair_json_string($raw_input);
                return decode_json($repaired);
            };
            if ($@) {
                JSONProcessingError->throw(message => "Could not parse JSON even after repair: $@");
            }
        }
        JSONProcessingError->throw(message => "Could not parse JSON");
    }
}

# Parst JSON und validiert (vereinfachte Version ohne Pydantic)
sub parse_and_validate {
    my ($raw_input, $model_class, $repair, $strict) = @_;
    $repair //= 1;
    $strict //= 0;
    
    my $data;
    eval {
        $data = parse_json($raw_input, $repair);
    };
    if ($@) {
        JSONValidationError->throw(message => "JSON parsing failed: $@");
    }
    
    # In Perl keine strenge Modellvalidierung wie in Pydantic
    # Hier einfach das geparste Datenobjekt zurückgeben
    return $data;
}

# Validiert einen OpenClaw/Tool-Call JSON
sub validate_tool_call {
    my ($raw_json, $tool_name) = @_;
    
    my $tool_call = parse_and_validate($raw_json, undef, 1, 0);
    
    # Prüfe ob tool_call die benötigten Felder hat
    unless (ref $tool_call eq 'HASH' && exists $tool_call->{tool}) {
        JSONValidationError->throw(message => "Invalid tool call structure");
    }
    
    if (defined $tool_name && $tool_call->{tool} ne $tool_name) {
        JSONValidationError->throw(
            message => "Expected tool '$tool_name', got '" . $tool_call->{tool} . "'"
        );
    }
    
    return {
        tool      => $tool_call->{tool},
        arguments => $tool_call->{arguments} || {},
        reasoning => $tool_call->{reasoning}
    };
}

# Sicheres JSON-Parsing mit Fallback auf Default-Wert
sub safe_json_loads {
    my ($raw_input, $default, $repair) = @_;
    $default //= undef;
    $repair  //= 1;
    
    eval {
        return parse_json($raw_input, $repair);
    };
    if ($@) {
        return $default;
    }
}

# Extrahiert alle JSON-Objekte aus einem Text
sub extract_json_from_text {
    my ($text) = @_;
    
    my @results = ();
    
    # Pattern für JSON-Objekte und Arrays
    my @patterns = (
        qr/\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}/,  # Objekte
        qr/\[[^\[\]]*(?:\[[^\[\]]*\][^\[\]]*)*\]/,  # Arrays
    );
    
    for my $pattern (@patterns) {
        while ($text =~ /$pattern/g) {
            my $match = $&;
            eval {
                my $parsed = parse_json($match, 1);
                push @results, $parsed;
            };
        }
    }
    
    return \@results;
}

# Hauptprogramm
sub main {
    my ($input, $is_file, $repair, $pretty, $help);
    GetOptions(
        'input=s'     => \$input,
        'file|f'      => \$is_file,
        'repair|r'    => \$repair,
        'no-repair'   => sub { $repair = 0 },
        'pretty|p'    => \$pretty,
        'help|h'      => \$help,
    ) or pod2usage(2);
    
    pod2usage(1) if $help;
    pod2usage(2) unless defined $input;
    
    $repair //= 1;
    
    my $content;
    if ($is_file) {
        $content = read_file($input);
    } else {
        $content = $input;
    }
    
    eval {
        my $result = parse_json($content, $repair);
        my $output = encode_json($result);
        unless ($pretty) {
            print "$output\n";
        } else {
            # Pretty-printing mit JSON::PP
            my $json = JSON->new->utf8->pretty;
            print $json->encode($result) . "\n";
        }
    };
    if ($@) {
        if ($@->isa('JSONProcessingError')) {
            print STDERR "Error: " . $@->message . "\n";
        } else {
            print STDERR "Unexpected error: $@\n";
        }
        exit 1;
    }
}

main() unless caller;

__END__

=head1 NAME

json_processor.pl - JSON Processor mit Reparatur

=head1 SYNOPSIS

json_processor.pl [options] input

 Options:
   -f, --file              Input ist ein Dateipfad
   -r, --repair            Aktiviere JSON-Reparatur (Standard)
       --no-repair         Deaktiviere JSON-Reparatur
   -p, --pretty            Pretty Print Ausgabe
   -h, --help              Zeige diese Hilfe

=head1 DESCRIPTION

Dieses Skript verarbeitet JSON-Eingaben mit automatischer Reparatur
häufiger Fehler aus LLM-Ausgaben.

=cut

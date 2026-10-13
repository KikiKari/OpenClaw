#!/usr/bin/env perl
# validate_tool_output.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/validate_tool_output.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/validate_tool_output.py
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Getopt::Long;
use JSON;
use File::Slurp;
use Data::Dumper;

# Simuliere das Verhalten von pydantic und json_processor
# Da Perl keine direkte Entsprechung zu Pydantic hat, implementieren wir eine einfache Validierung

# Globale Variablen für Optionen
my $schema_file;
my $is_file = 0;
my $repair = 1;
my $strict = 0;
my $help = 0;

# Hilfetext
my $usage = <<'EOF';
Usage: validate_tool_output.pl [options] <json_input>
Validate tool output against schema

Options:
  --schema, -s FILE    JSON schema file (required)
  --file, -f           Input is a file
  --repair, -r         Repair mode (default: on)
  --strict             Strict validation
  --help, -h           Show this help message
EOF

# Argumente parsen
GetOptions(
    'schema|s=s' => \$schema_file,
    'file|f'     => \$is_file,
    'repair|r!'  => \$repair,
    'strict'     => \$strict,
    'help|h'     => \$help,
) or die $usage;

# Hilfe anzeigen
if ($help || !$schema_file) {
    print $usage;
    exit(0);
}

# Eingabedaten holen
my $json_input = shift @ARGV;
die "Missing json_input argument\n$usage" unless defined $json_input;

# Schema laden
my $schema;
eval {
    my $schema_content = read_file($schema_file);
    $schema = decode_json($schema_content);
};
if ($@) {
    print STDERR "Error loading schema: $@\n";
    exit(1);
}

# Eingabe laden
my $raw_input;
eval {
    if ($is_file) {
        $raw_input = read_file($json_input);
    } else {
        $raw_input = $json_input;
    }
};
if ($@) {
    print STDERR "Error loading input: $@\n";
    exit(1);
}

# Dynamisches Modell erstellen und validieren
eval {
    my $result = parse_and_validate($raw_input, $schema, $repair, $strict);
    print to_json($result, { pretty => 1, utf8 => 1 }) . "\n";
};
if ($@) {
    if ($@ =~ /^Validation error:/) {
        print STDERR $@;
        exit(1);
    } else {
        die $@;
    }
};

# Funktionen

sub create_dynamic_model {
    my ($schema) = @_;
    # In Perl simulieren wir das Modell durch das Schema selbst
    return $schema;
}

sub parse_and_validate {
    my ($raw_input, $schema, $repair, $strict) = @_;

    # JSON parsen
    my $data;
    eval {
        $data = decode_json($raw_input);
    };
    if ($@) {
        die "Validation error: Invalid JSON: $@\n";
    }

    # Validierung gemäß Schema
    my $validated_data = validate_data($data, $schema, $strict);

    # Reparatur bei Bedarf
    if ($repair) {
        $validated_data = repair_data($validated_data, $schema);
    }

    return $validated_data;
}

sub validate_data {
    my ($data, $schema, $strict) = @_;
    my $errors = [];

    # Prüfe, ob Daten ein Objekt sind
    unless (ref($data) eq 'HASH') {
        push @$errors, "Root element must be an object";
    }

    # Prüfe Eigenschaften
    my $properties = $schema->{properties} || {};
    my $required = {};
    if (exists $schema->{required}) {
        for my $req (@{$schema->{required}}) {
            $required->{$req} = 1;
        }
    }

    for my $key (keys %$properties) {
        my $prop = $properties->{$key};
        my $value = $data->{$key};

        # Typüberprüfung
        if (exists $data->{$key}) {
            my $expected_type = $prop->{type};
            my $actual_type = get_perl_type($value);

            unless (type_matches($actual_type, $expected_type)) {
                push @$errors, "Field '$key': expected type '$expected_type', got '$actual_type'";
            }
        } elsif ($required->{$key}) {
            push @$errors, "Required field '$key' is missing";
        }
    }

    # Bei strikter Validierung: zusätzliche Felder prüfen
    if ($strict) {
        for my $key (keys %$data) {
            unless (exists $properties->{$key}) {
                push @$errors, "Unexpected field '$key' in strict mode";
            }
        }
    }

    if (@$errors > 0) {
        my $error_msg = join("\n", @$errors);
        die "Validation error: $error_msg\n";
    }

    return $data;
}

sub repair_data {
    my ($data, $schema) = @_;
    my $properties = $schema->{properties} || {};

    # Fehlende Felder mit Defaults füllen
    for my $key (keys %$properties) {
        my $prop = $properties->{$key};
        unless (exists $data->{$key}) {
            if (exists $prop->{default}) {
                $data->{$key} = $prop->{default};
            } elsif (!grep { $_ eq $key } @{$schema->{required} || []}) {
                $data->{$key} = undef;
            }
        }
    }

    return $data;
}

sub get_perl_type {
    my ($value) = @_;

    if (!defined $value) {
        return 'null';
    } elsif (ref($value) eq 'HASH') {
        return 'object';
    } elsif (ref($value) eq 'ARRAY') {
        return 'array';
    } elsif ($value =~ /^[+-]?\d+$/ && $value !~ /^[+-]?0\d+/) {
        return 'integer';
    } elsif ($value =~ /^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$/) {
        return 'number';
    } elsif ($value =~ /^(true|false)$/i) {
        return 'boolean';
    } else {
        return 'string';
    }
}

sub type_matches {
    my ($perl_type, $json_type) = @_;

    # Mapping von JSON-Typen zu Perl-Typen
    my %mapping = (
        'string'  => ['string'],
        'integer' => ['integer'],
        'number'  => ['integer', 'number'],
        'boolean' => ['boolean'],
        'array'   => ['array'],
        'object'  => ['object'],
        'null'    => ['null']
    );

    if (exists $mapping{$json_type}) {
        my @valid_types = @{$mapping{$json_type}};
        return grep { $_ eq $perl_type } @valid_types;
    }

    return 0;
}

#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "89bbb797b4683e5ec6573a22e4f62c0b0817c760573f9f8530dbbb50f2fc98d0", "source_sha256": "f55ff3c9a1d0fb13ff0d5dd08f91e1c1a304c7d83f3d1bb93f165f2437d276b9", "target_language": "perl5"}
# json_schema_validator.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_schema_validator.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_schema_validator.py
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use JSON::PP qw(decode_json encode_json);
use File::Spec::Functions qw(catfile);
use Getopt::Long qw(GetOptions);
use Pod::Usage qw(pod2usage);

# JSON Schema Validator - Validiert JSON gegen JSON Schema Draft 7/2020-12.
# Erweitert Pydantic mit externen Schema-Dateien.

# Globale Variablen für Fehlerbehandlung
my $HAS_JSONSCHEMA = eval {
    require JSON::Schema;
    JSON::Schema->import();
    1;
};

# JSON Processing Error Klassen (simuliert)
package JSONProcessingError {
    sub new {
        my ($class, $message) = @_;
        return bless { message => $message }, $class;
    }
    sub message { return $_[0]->{message}; }
}

package JSONValidationError {
    our @ISA = qw(JSONProcessingError);
}

package SchemaValidationError {
    our @ISA = qw(JSONValidationError);
    sub new {
        my ($class, $message) = @_;
        return $class->SUPER::new($message);
    }
}

# Hauptpaket
package main;

sub load_schema {
    my ($schema_source) = @_;
    
    # Falls bereits ein HashRef übergeben wurde
    if (ref($schema_source) eq 'HASH') {
        return $schema_source;
    }
    
    # Prüfe ob es sich um einen Dateipfad handelt
    if (-f $schema_source) {
        open my $fh, '<:encoding(UTF-8)', $schema_source or do {
            die SchemaValidationError->new("Cannot read schema file '$schema_source': $!");
        };
        my $content = do { local $/; <$fh> };
        close $fh;
        
        eval {
            return decode_json($content);
        } or do {
            die SchemaValidationError->new("Invalid JSON in schema file: $@");
        };
    }
    
    # Versuche als JSON String zu parsen
    eval {
        return decode_json($schema_source);
    } or do {
        die SchemaValidationError->new("Schema not found or invalid: $schema_source");
    };
}

sub validate_with_jsonschema {
    my ($data, $schema, $draft) = @_;
    $draft //= 'auto';
    
    unless ($HAS_JSONSCHEMA) {
        die SchemaValidationError->new("JSON::Schema not available. Install via CPAN.");
    }
    
    my $schema_dict = load_schema($schema);
    
    my $js = JSON::Schema->new($schema_dict);
    my $result = $js->validate($data);
    
    if (!$result) {
        my $errors = join ', ', map { $_->{message} . " at " . ($_->{path} || '/') } @{$result->errors};
        die SchemaValidationError->new("Schema validation failed: $errors");
    }
    
    return 1;
}

sub parse_json {
    my ($raw_input, $repair) = @_;
    $repair //= 1;
    
    eval {
        return decode_json($raw_input);
    } or do {
        my $error = $@;
        if ($repair) {
            # Versuche einfache Reparaturen
            my $repaired = $raw_input;
            $repaired =~ s/,\s*}/}/g;  # Entferne trailing commas
            $repaired =~ s/,\s*\]/\]/g;
            
            eval {
                return decode_json($repaired);
            } or do {
                die JSONProcessingError->new("Failed to parse JSON even after repairs: $error");
            };
        } else {
            die JSONProcessingError->new("Failed to parse JSON: $error");
        }
    };
}

sub validate_and_convert {
    my ($raw_input, $schema, $repair) = @_;
    $repair //= 1;
    
    my $data = parse_json($raw_input, $repair);
    validate_with_jsonschema($data, $schema);
    return $data;
}

package SchemaBuilder;

sub object {
    my ($class, $properties, $required) = @_;
    my %schema = (
        type => 'object',
        properties => $properties
    );
    if (defined $required && @$required) {
        $schema{required} = $required;
    }
    return \%schema;
}

sub string {
    my ($class, $enum, $pattern, $min_length) = @_;
    my %schema = (type => 'string');
    if (defined $enum && @$enum) {
        $schema{enum} = $enum;
    }
    if (defined $pattern) {
        $schema{pattern} = $pattern;
    }
    if (defined $min_length) {
        $schema{minLength} = $min_length;
    }
    return \%schema;
}

sub integer {
    my ($class, $minimum, $maximum) = @_;
    my %schema = (type => 'integer');
    if (defined $minimum) {
        $schema{minimum} = $minimum;
    }
    if (defined $maximum) {
        $schema{maximum} = $maximum;
    }
    return \%schema;
}

sub array {
    my ($class, $items, $min_items) = @_;
    my %schema = (
        type => 'array',
        items => $items
    );
    if (defined $min_items) {
        $schema{minItems} = $min_items;
    }
    return \%schema;
}

package main;

sub main {
    my $input;
    my $schema_file;
    my $is_file = 0;
    my $repair = 1;
    my $help = 0;
    
    GetOptions(
        'input=s'   => \$input,
        'schema|s=s' => \$schema_file,
        'file|f'    => \$is_file,
        'repair|r!' => \$repair,
        'help|h'    => \$help,
    ) or pod2usage(2);
    
    pod2usage(1) if $help;
    
    unless (defined $input && defined $schema_file) {
        pod2usage(2);
    }
    
    # Lade Input (Auto-detect file vs string)
    my $raw_input;
    if ($is_file || (-f $input)) {
        open my $fh, '<:encoding(UTF-8)', $input or do {
            print STDERR "✗ Cannot read input file '$input': $!\n";
            exit 1;
        };
        $raw_input = do { local $/; <$fh> };
        close $fh;
    } else {
        $raw_input = $input;
    }
    
    eval {
        my $result = validate_and_convert($raw_input, $schema_file, $repair);
        print encode_json($result) . "\n";
        print STDERR "\n✓ Validation passed\n";
    } or do {
        my $error = $@;
        if ($error->isa('JSONProcessingError') || $error->isa('SchemaValidationError')) {
            print STDERR "✗ Validation failed: " . $error->message . "\n";
        } else {
            print STDERR "✗ Unexpected error: $error\n";
        }
        exit 1;
    };
}

main() unless caller;

__END__

=head1 NAME

json_schema_validator.pl - JSON Schema Validator

=head1 SYNOPSIS

json_schema_validator.pl [options] <input>

 Options:
   --schema,-s    Schema file (required)
   --file,-f      Treat input as file path
   --repair,-r    Attempt to repair JSON (default: on)
   --help,-h      Show this help

 Arguments:
   input          JSON file or string

=cut

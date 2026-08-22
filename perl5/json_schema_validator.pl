#!/usr/bin/perl
# json_schema_validator.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_schema_validator.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_schema_validator.py
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use JSON::PP qw(decode_json encode_json);
use File::Slurp qw(read_file);
use Getopt::Long qw(GetOptions);
use Pod::Usage qw(pod2usage);

# JSON Schema Validator - Validiert JSON gegen JSON Schema Draft 7/2020-12.
# Erweitert Pydantic mit externen Schema-Dateien.

# Globale Variablen für Abhängigkeiten
my $HAS_JSONSCHEMA = eval {
    require JSON::Validator;
    JSON::Validator->import();
    1;
};

# JSONValidationError simulieren
package JSONValidationError {
    sub new {
        my ($class, $message) = @_;
        return bless { message => $message }, $class;
    }
    sub message {
        my $self = shift;
        return $self->{message};
    }
}

# SchemaValidationError
package SchemaValidationError {
    use parent 'JSONValidationError';
}

# JSONProcessingError simulieren
package JSONProcessingError {
    sub new {
        my ($class, $message) = @_;
        return bless { message => $message }, $class;
    }
    sub message {
        my $self = shift;
        return $self->{message};
    }
}

# parse_json Funktion (simuliert)
sub parse_json {
    my ($raw_input, $repair) = @_;
    eval {
        return decode_json($raw_input);
    };
    if ($@) {
        die JSONProcessingError->new("Invalid JSON: $@");
    }
}

# Lädt ein JSON Schema aus verschiedenen Quellen.
sub load_schema {
    my ($schema_source) = @_;
    
    if (ref($schema_source) eq 'HASH') {
        return $schema_source;
    }
    
    if (-f $schema_source) {
        eval {
            my $content = read_file($schema_source);
            return decode_json($content);
        };
        if ($@) {
            die SchemaValidationError->new("Invalid JSON in schema file: $@");
        }
    }
    
    # Versuche als JSON String zu parsen
    eval {
        return decode_json($schema_source);
    };
    if ($@) {
        die SchemaValidationError->new("Schema not found or invalid: $schema_source");
    }
}

# Validiert Daten gegen ein JSON Schema.
sub validate_with_jsonschema {
    my ($data, $schema, $draft) = @_;
    $draft //= "auto";
    
    if (!$HAS_JSONSCHEMA) {
        die SchemaValidationError->new("JSON::Validator not available");
    }
    
    my $schema_dict = load_schema($schema);
    
    my $validator = JSON::Validator->new;
    my @errors = $validator->validate($data, $schema_dict);
    
    if (@errors) {
        my $error_msg = join(", ", map { $_->{message} } @errors);
        die SchemaValidationError->new("Schema validation failed: $error_msg");
    }
    
    return 1;
}

# Parst, repariert und validiert JSON gegen Schema.
sub validate_and_convert {
    my ($raw_input, $schema, $repair) = @_;
    $repair //= 1;
    
    my $data = parse_json($raw_input, $repair);
    validate_with_jsonschema($data, $schema);
    return $data;
}

# SchemaBuilder Klasse
package SchemaBuilder {
    sub object {
        my ($class, $properties, $required) = @_;
        my $schema = {
            type => "object",
            properties => $properties
        };
        if ($required) {
            $schema->{required} = $required;
        }
        return $schema;
    }
    
    sub string {
        my ($class, $enum, $pattern, $min_length) = @_;
        my $schema = { type => "string" };
        if ($enum) {
            $schema->{enum} = $enum;
        }
        if ($pattern) {
            $schema->{pattern} = $pattern;
        }
        if (defined $min_length) {
            $schema->{minLength} = $min_length;
        }
        return $schema;
    }
    
    sub integer {
        my ($class, $minimum, $maximum) = @_;
        my $schema = { type => "integer" };
        if (defined $minimum) {
            $schema->{minimum} = $minimum;
        }
        if (defined $maximum) {
            $schema->{maximum} = $maximum;
        }
        return $schema;
    }
    
    sub array {
        my ($class, $items, $min_items) = @_;
        my $schema = { 
            type => "array", 
            items => $items 
        };
        if (defined $min_items) {
            $schema->{minItems} = $min_items;
        }
        return $schema;
    }
}

# Hauptprogramm
sub main {
    my $input;
    my $schema;
    my $file = 0;
    my $repair = 1;
    my $help = 0;
    
    GetOptions(
        "input=s"    => \$input,
        "schema|s=s" => \$schema,
        "file|f"     => \$file,
        "repair|r"   => \$repair,
        "help|h"     => \$help,
    ) or pod2usage(2);
    
    pod2usage(1) if $help;
    
    unless ($input && $schema) {
        pod2usage(2);
    }
    
    # Lade Input (Auto-detect file vs string)
    my $raw_input;
    if ($file || (-f $input)) {
        $raw_input = read_file($input);
    } else {
        $raw_input = $input;
    }
    
    eval {
        my $result = validate_and_convert($raw_input, $schema, $repair);
        print encode_json($result, { pretty => 1, canonical => 1 });
        print "\n✓ Validation passed\n";
    };
    if ($@) {
        if ($@->isa('JSONProcessingError') || $@->isa('SchemaValidationError')) {
            print STDERR "✗ Validation failed: " . $@->message . "\n";
        } else {
            print STDERR "✗ Validation failed: $@\n";
        }
        exit 1;
    }
}

main() if !caller;

__END__

=head1 NAME

json_schema_validator.pl - JSON Schema Validator

=head1 SYNOPSIS

json_schema_validator.pl [options] input

 Options:
   --schema|-s    Schema file (required)
   --file|-f      Input is file
   --repair|-r    Repair JSON (default: true)
   --help|-h      Show this help

=head1 DESCRIPTION

Validiert JSON gegen JSON Schema Draft 7/2020-12.

=cut

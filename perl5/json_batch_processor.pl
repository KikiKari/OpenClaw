#!/usr/bin/perl
# json_batch_processor.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_batch_processor.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_batch_processor.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use JSON;
use File::Basename;
use Getopt::Long;
use Pod::Usage;

# Prüfe ob JSON::XS oder Cpanel::JSON::XS verfügbar ist
my $json_parser;
eval {
    require Cpanel::JSON::XS;
    $json_parser = Cpanel::JSON::XS->new->utf8;
};
if ($@) {
    eval {
        require JSON::XS;
        $json_parser = JSON::XS->new->utf8;
    };
    if ($@) {
        $json_parser = JSON->new->utf8;
    }
}

# Globale Variablen
my $HAS_JSON_PROCESSOR = 0;
my %JSON_PROCESSOR_FUNCS;

# Versuche json_processor.pm zu laden
eval {
    require json_processor;
    json_processor->import();
    $HAS_JSON_PROCESSOR = 1;
    # Dummy-Funktionen falls json_processor nicht geladen werden kann
    *parse_json = sub {
        my ($content, $repair) = @_;
        eval {
            return $json_parser->decode($content);
        } or do {
            die "JSON decode error: $@";
        };
    };
    *parse_and_validate = sub {
        my ($content, $model, $repair) = @_;
        return parse_json($content, $repair);
    };
    *JSONProcessingError = sub {
        my $msg = shift // "";
        return "JSONProcessingError: $msg";
    };
};

# BatchResult Klasse
package BatchResult {
    sub new {
        my ($class, %args) = @_;
        my $self = {
            index => $args{index},
            source => $args{source},
            success => $args{success},
            data => $args{data},
            error => $args{error}
        };
        bless $self, $class;
        return $self;
    }

    sub to_dict {
        my ($self) = @_;
        return {
            index => $self->{index},
            source => $self->{source},
            success => $self->{success},
            data => $self->{data},
            error => $self->{error}
        };
    }
}

# Hauptpaket
package main;

# Liest JSON-Lines (NDJSON) Datei Zeile für Zeile
sub read_jsonl {
    my ($file_path) = @_;
    my @results;
    open my $fh, '<:encoding(UTF-8)', $file_path or die "Cannot open $file_path: $!";
    my $line_num = 0;
    while (my $line = <$fh>) {
        $line_num++;
        chomp $line;
        $line =~ s/^\s+|\s+$//g; # strip
        next if !$line;
        eval {
            my $data = $json_parser->decode($line);
            push @results, { data => $data, line_num => $line_num };
        } or do {
            my $err = $@;
            my $result = BatchResult->new(
                index => $line_num,
                source => "$file_path:$line_num",
                success => 0,
                error => "JSON decode error: $err"
            );
            push @results, $result;
        };
    }
    close $fh;
    return @results;
}

# Verarbeitet eine Liste von Inputs parallel (simuliert durch sequentielle Verarbeitung in Perl)
sub process_batch {
    my ($inputs_ref, $processor_ref, $max_workers) = @_;
    my @results;
    for my $idx (0 .. $#{$inputs_ref}) {
        my $inp = $inputs_ref->[$idx];
        eval {
            my $result = $processor_ref->($inp, $idx);
            push @results, $result;
        } or do {
            my $err = $@;
            my $result = BatchResult->new(
                index => $idx,
                source => "$inp",
                success => 0,
                error => "Unexpected error: $err"
            );
            push @results, $result;
        };
    }
    @results = sort { $a->{index} <=> $b->{index} } @results;
    return @results;
}

# Verarbeitet mehrere JSON-Dateien im Batch
sub process_file_batch {
    my ($file_paths_ref, $repair, $validate_model, $max_workers) = @_;
    
    my $processor = sub {
        my ($path, $idx) = @_;
        eval {
            open my $fh, '<:encoding(UTF-8)', $path or die "Cannot open $path: $!";
            my $content = do { local $/; <$fh> };
            close $fh;
            
            my $data;
            if ($validate_model && $HAS_JSON_PROCESSOR) {
                $data = parse_and_validate($content, $validate_model, $repair);
            } else {
                $data = parse_json($content, $repair);
            }
            
            return BatchResult->new(
                index => $idx,
                source => "$path",
                success => 1,
                data => $data
            );
        } or do {
            my $err = $@;
            return BatchResult->new(
                index => $idx,
                source => "$path",
                success => 0,
                error => "$err"
            );
        };
    };
    
    return process_batch($file_paths_ref, $processor, $max_workers);
}

# Verarbeitet eine JSON-Lines Datei
sub process_jsonl_file {
    my ($file_path, $repair, $validate_model) = @_;
    my @results;
    open my $fh, '<:encoding(UTF-8)', $file_path or die "Cannot open $file_path: $!";
    my $line_num = 0;
    while (my $line = <$fh>) {
        $line_num++;
        chomp $line;
        $line =~ s/^\s+|\s+$//g; # strip
        next if !$line;
        
        eval {
            my $data;
            if ($validate_model && $HAS_JSON_PROCESSOR) {
                $data = parse_and_validate($line, $validate_model, $repair);
            } else {
                $data = parse_json($line, $repair);
            }
            
            push @results, BatchResult->new(
                index => $line_num,
                source => "$file_path:$line_num",
                success => 1,
                data => $data
            );
        } or do {
            my $err = $@;
            push @results, BatchResult->new(
                index => $line_num,
                source => "$file_path:$line_num",
                success => 0,
                error => "$err"
            );
        };
    }
    close $fh;
    return @results;
}

# Schreibt BatchResult-Liste als JSON-Lines
sub write_jsonl {
    my ($results_ref, $output_path, $only_successful) = @_;
    open my $fh, '>:encoding(UTF-8)', $output_path or die "Cannot write to $output_path: $!";
    for my $result (@$results_ref) {
        if ($only_successful && !$result->{success}) {
            next;
        }
        my $dict = $result->to_dict();
        print $fh $json_parser->encode($dict) . "\n";
    }
    close $fh;
}

# Hauptfunktion
sub main {
    my @inputs = @ARGV;
    my $jsonl = 0;
    my $repair = 1;
    my $workers = 4;
    my $output = '';
    my $summary = 0;
    my $help = 0;

    GetOptions(
        'jsonl|l' => \$jsonl,
        'repair|r' => \$repair,
        'workers|w=i' => \$workers,
        'output|o=s' => \$output,
        'summary|s' => \$summary,
        'help|h' => \$help
    ) or pod2usage(2);

    pod2usage(1) if $help;
    pod2usage(2) if !@inputs;

    my @all_results;

    if ($jsonl) {
        # JSON-Lines Modus
        for my $input_path (@inputs) {
            my @results = process_jsonl_file($input_path, $repair);
            push @all_results, @results;
        }
    } else {
        # Standard JSON Batch
        my @file_paths = @inputs;
        @all_results = process_file_batch(\@file_paths, $repair, undef, $workers);
    }

    # Ausgabe
    my $successful = grep { $_->{success} } @all_results;
    my $failed = scalar(@all_results) - $successful;

    if ($summary) {
        print "Processed: " . scalar(@all_results) . "\n";
        print "Successful: $successful\n";
        print "Failed: $failed\n";
    } else {
        for my $result (@all_results) {
            if ($result->{success}) {
                print $json_parser->encode($result->{data}) . "\n";
            } else {
                print STDERR "ERROR [$result->{source}]: $result->{error}\n";
            }
        }
    }

    # Optional: JSONL Output
    if ($output) {
        write_jsonl(\@all_results, $output, 0);
        print STDERR "\nResults written to: $output\n";
    }

    exit($failed == 0 ? 0 : 1);
}

main() unless caller;

__END__

=head1 NAME

json_batch_processor - Batch JSON Processor - Verarbeitet mehrere JSON-Dateien oder JSON-Lines (NDJSON)

=head1 SYNOPSIS

json_batch_processor [options] file1.json [file2.json ...]

 Options:
   --jsonl, -l           Treat inputs as JSON-Lines files
   --repair, -r          Enable JSON repair (default)
   --workers, -w N       Parallel workers (default: 4)
   --output, -o FILE     Output JSON-Lines file
   --summary, -s         Show summary only
   --help, -h            Show this help message

=head1 DESCRIPTION

Dieses Skript verarbeitet mehrere JSON-Dateien oder JSON-Lines-Dateien (NDJSON) und gibt die Ergebnisse aus.

=cut

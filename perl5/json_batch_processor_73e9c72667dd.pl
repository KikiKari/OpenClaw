#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "58d2696c34d0cda0e847824f0258328e7818e46175bf64695f7136547257a3fd", "source_sha256": "40b902ee3739509c4b2ef72ed57b4d983e5b509f6e446d20ab14d630d9773322", "target_language": "perl5"}
# json_batch_processor.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_batch_processor.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_batch_processor.py
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use Getopt::Long;
use Pod::Usage;
use File::Spec;
use JSON::PP;
use threads;
use Thread::Queue;

# Globale Variablen
my $HAS_JSON_PROCESSOR = eval {
    require JSON::Parse;
    JSON::Parse->import();
    1;
};

# JSON Processing Error simulieren
package JSONProcessingError {
    sub new {
        my ($class, $message) = @_;
        return bless { message => $message }, $class;
    }
    sub message { return $_[0]->{message}; }
}

# BatchResult Klasse
package BatchResult {
    sub new {
        my ($class, %args) = @_;
        return bless {
            index   => $args{index},
            source  => $args{source},
            success => $args{success},
            data    => $args{data},
            error   => $args{error},
        }, $class;
    }

    sub to_hash {
        my ($self) = @_;
        return {
            index   => $self->{index},
            source  => $self->{source},
            success => $self->{success},
            data    => $self->{data},
            error   => $self->{error},
        };
    }
}

# Hauptpaket
package main;

# parse_json Funktion (vereinfacht)
sub parse_json {
    my ($content, $repair) = @_;
    my $json = JSON::PP->new->utf8;
    eval {
        return $json->decode($content);
    };
    if ($@) {
        if ($repair) {
            # Versuche einfache Reparaturen
            $content =~ s/(\w+):/ "$1": /g; # Schlüssel ohne Anführungszeichen
            $content =~ s/'/"/g;             # Einfache Anführungszeichen durch doppelte ersetzen
            return $json->decode($content);
        } else {
            die JSONProcessingError->new($@);
        }
    }
}

# read_jsonl Funktion
sub read_jsonl {
    my ($file_path) = @_;
    open my $fh, '<:encoding(UTF-8)', $file_path or die "Cannot open $file_path: $!";
    my @results;
    my $line_num = 0;
    while (my $line = <$fh>) {
        chomp $line;
        $line_num++;
        next unless $line =~ /\S/;
        eval {
            my $data = parse_json($line, 0);
            push @results, BatchResult->new(
                index   => $line_num,
                source  => "$file_path:$line_num",
                success => 1,
                data    => $data,
            );
        };
        if ($@) {
            push @results, BatchResult->new(
                index   => $line_num,
                source  => "$file_path:$line_num",
                success => 0,
                error   => "JSON decode error: " . ($@->isa('JSONProcessingError') ? $@->message : $@),
            );
        }
    }
    close $fh;
    return @results;
}

# process_batch Funktion
sub process_batch {
    my ($inputs_ref, $processor_ref, $max_workers) = @_;
    my @inputs = @$inputs_ref;
    my @results;
    my $q = Thread::Queue->new();
    my $result_q = Thread::Queue->new();

    # Producer: Füge alle Inputs zur Queue hinzu
    for my $idx (0 .. $#inputs) {
        $q->enqueue([$idx, $inputs[$idx]]);
    }
    $q->end();

    # Consumer: Starte Worker Threads
    my @threads;
    for my $i (1 .. $max_workers) {
        push @threads, threads->create(sub {
            while (defined(my $item = $q->dequeue())) {
                my ($idx, $inp) = @{$item};
                eval {
                    my $result = $processor_ref->($inp, $idx);
                    $result_q->enqueue($result);
                };
                if ($@) {
                    my $error_result = BatchResult->new(
                        index   => $idx,
                        source  => "$inp",
                        success => 0,
                        error   => "Unexpected error: $@",
                    );
                    $result_q->enqueue($error_result);
                }
            }
        });
    }

    # Sammle Ergebnisse
    for my $thread (@threads) {
        $thread->join();
    }

    # Hole alle Ergebnisse aus der Queue
    while (my $res = $result_q->dequeue_nb()) {
        push @results, $res;
    }

    # Sortiere nach Index
    @results = sort { $a->{index} <=> $b->{index} } @results;
    return @results;
}

# process_file_batch Funktion
sub process_file_batch {
    my ($file_paths_ref, $repair, $validate_model, $max_workers) = @_;
    my @file_paths = @$file_paths_ref;

    my $processor = sub {
        my ($path, $idx) = @_;
        eval {
            open my $fh, '<:encoding(UTF-8)', $path or die "Cannot open $path: $!";
            my $content = do { local $/; <$fh> };
            close $fh;

            my $data;
            if ($validate_model && $HAS_JSON_PROCESSOR) {
                # In Perl gibt es kein direktes Äquivalent zu Pydantic
                # Daher verwenden wir einfach parse_json
                $data = parse_json($content, $repair);
            } else {
                $data = parse_json($content, $repair);
            }

            return BatchResult->new(
                index   => $idx,
                source  => "$path",
                success => 1,
                data    => $data,
            );
        };
        if ($@) {
            my $error_msg = $@->isa('JSONProcessingError') ? $@->message : "$@";
            return BatchResult->new(
                index   => $idx,
                source  => "$path",
                success => 0,
                error   => $error_msg,
            );
        }
    };

    return process_batch(\@file_paths, $processor, $max_workers);
}

# process_jsonl_file Funktion
sub process_jsonl_file {
    my ($file_path, $repair, $validate_model) = @_;
    my @results;
    open my $fh, '<:encoding(UTF-8)', $file_path or die "Cannot open $file_path: $!";
    my $line_num = 0;
    while (my $line = <$fh>) {
        chomp $line;
        $line_num++;
        next unless $line =~ /\S/;

        eval {
            my $data;
            if ($validate_model && $HAS_JSON_PROCESSOR) {
                # In Perl gibt es kein direktes Äquivalent zu Pydantic
                # Daher verwenden wir einfach parse_json
                $data = parse_json($line, $repair);
            } else {
                $data = parse_json($line, $repair);
            }

            push @results, BatchResult->new(
                index   => $line_num,
                source  => "$file_path:$line_num",
                success => 1,
                data    => $data,
            );
        };
        if ($@) {
            my $error_msg = $@->isa('JSONProcessingError') ? $@->message : "$@";
            push @results, BatchResult->new(
                index   => $line_num,
                source  => "$file_path:$line_num",
                success => 0,
                error   => $error_msg,
            );
        }
    }
    close $fh;
    return @results;
}

# write_jsonl Funktion
sub write_jsonl {
    my ($results_ref, $output_path, $only_successful) = @_;
    my @results = @$results_ref;
    open my $fh, '>:encoding(UTF-8)', $output_path or die "Cannot write to $output_path: $!";
    my $json = JSON::PP->new->utf8->pretty;
    for my $result (@results) {
        if ($only_successful && !$result->{success}) {
            next;
        }
        print $fh $json->encode($result->to_hash()) . "\n";
    }
    close $fh;
}

# main Funktion
sub main {
    my $jsonl = 0;
    my $repair = 1;
    my $workers = 4;
    my $output = '';
    my $summary = 0;
    my $help = 0;

    GetOptions(
        'jsonl|l'     => \$jsonl,
        'repair|r!'   => \$repair,
        'workers|w=i' => \$workers,
        'output|o=s'  => \$output,
        'summary|s'   => \$summary,
        'help|h'      => \$help,
    ) or pod2usage(2);

    pod2usage(1) if $help;

    my @inputs = @ARGV;
    if (!@inputs) {
        pod2usage("No input files provided.");
    }

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
    my $failed = @all_results - $successful;

    if ($summary) {
        print "Processed: " . scalar(@all_results) . "\n";
        print "Successful: $successful\n";
        print "Failed: $failed\n";
    } else {
        my $json = JSON::PP->new->utf8->pretty;
        for my $result (@all_results) {
            if ($result->{success}) {
                print $json->encode($result->{data}) . "\n";
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

    # Exit code
    exit($failed == 0 ? 0 : 1);
}

main() unless caller;

__END__

=head1 NAME

json_batch_processor.pl - Batch JSON Processor - Verarbeitet mehrere JSON-Dateien oder JSON-Lines (NDJSON).

=head1 SYNOPSIS

json_batch_processor.pl [options] file1.json [file2.json ...]

 Options:
   -l --jsonl           Treat inputs as JSON-Lines files
   -r --repair          Enable JSON repair (default)
      --no-repair       Disable JSON repair
   -w --workers INT     Parallel workers (default: 4)
   -o --output FILE     Output JSON-Lines file
   -s --summary         Show summary only
   -h --help            Show this help message

=head1 DESCRIPTION

Dieses Skript verarbeitet mehrere JSON-Dateien oder JSON-Lines-Dateien (NDJSON) und gibt die Ergebnisse aus.

=cut

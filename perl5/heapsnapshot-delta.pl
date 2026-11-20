#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "9141bd89ecbd9282ffbda58b183cb3d3d9855fd26b041b2f41b00b81d1d659ca", "source_sha256": "d38a1b483644fdcb8d1b3d4826eb7c89f54ac769bf87debab3ab554e0544844f", "target_language": "perl5"}
# heapsnapshot-delta.mjs — portiert nach perl5
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/.agents/skills/openclaw-test-heap-leaks/scripts/heapsnapshot-delta.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use JSON::PP;
use File::Find;
use File::Spec;
use Getopt::Long;

sub print_usage {
    warn "Usage: perl heapsnapshot-delta.pl <before.heapsnapshot> <after.heapsnapshot> [--top N] [--min-kb N]\n";
    warn "   or: perl heapsnapshot-delta.pl --lane-dir <dir> [--pid PID] [--top N] [--min-kb N]\n";
}

sub fail {
    my ($message) = @_;
    warn $message . "\n";
    exit 1;
}

sub parse_args {
    my (@argv) = @_;
    my %options = (
        top => 30,
        min_kb => 64,
        lane_dir => undef,
        pid => undef,
        files => []
    );

    my $index = 0;
    while ($index < @argv) {
        my $arg = $argv[$index];
        if ($arg eq "--top") {
            $options{top} = int($argv[$index + 1] // "");
            $index += 2;
            next;
        }
        if ($arg eq "--min-kb") {
            $options{min_kb} = int($argv[$index + 1] // "");
            $index += 2;
            next;
        }
        if ($arg eq "--lane-dir") {
            $options{lane_dir} = $argv[$index + 1] // undef;
            $index += 2;
            next;
        }
        if ($arg eq "--pid") {
            $options{pid} = int($argv[$index + 1] // "");
            $index += 2;
            next;
        }
        push @{$options{files}}, $arg;
        $index += 1;
    }

    if (!defined $options{top} || $options{top} <= 0) {
        fail("--top must be a positive integer");
    }
    if (!defined $options{min_kb} || $options{min_kb} < 0) {
        fail("--min-kb must be a non-negative integer");
    }
    if (defined $options{pid} && ($options{pid} <= 0)) {
        fail("--pid must be a positive integer");
    }

    return \%options;
}

package JsonStreamScanner {
    sub new {
        my ($class, $file_path) = @_;
        my $self = {
            file_path => $file_path,
            buffer => "",
            offset => 0,
            done => 0,
            fh => undef
        };
        open($self->{fh}, "<:encoding(UTF-8)", $file_path) or die "Cannot open $file_path: $!";
        return bless $self, $class;
    }

    sub compact_buffer {
        my ($self) = @_;
        if ($self->{offset} > 65536) {
            $self->{buffer} = substr($self->{buffer}, $self->{offset});
            $self->{offset} = 0;
        }
    }

    sub ensure_available {
        my ($self, $count) = @_;
        $count //= 1;
        while (!$self->{done} && length($self->{buffer}) - $self->{offset} < $count) {
            my $chunk;
            my $bytes_read = read($self->{fh}, $chunk, 1024*1024);
            if (!defined $bytes_read || $bytes_read == 0) {
                $self->{done} = 1;
                last;
            }
            $self->{buffer} .= $chunk;
        }
    }

    sub peek {
        my ($self) = @_;
        $self->ensure_available(1);
        return substr($self->{buffer}, $self->{offset}, 1) if $self->{offset} < length($self->{buffer});
        return undef;
    }

    sub next_char {
        my ($self) = @_;
        $self->ensure_available(1);
        if ($self->{offset} >= length($self->{buffer})) {
            return undef;
        }
        my $char = substr($self->{buffer}, $self->{offset}, 1);
        $self->{offset} += 1;
        $self->compact_buffer();
        return $char;
    }

    sub skip_whitespace {
        my ($self) = @_;
        while (1) {
            my $char = $self->peek();
            last if !defined($char) || $char !~ /^\s$/;
            $self->next_char();
        }
    }

    sub expect_char {
        my ($self, $expected) = @_;
        my $char = $self->next_char();
        if (!defined($char) || $char ne $expected) {
            fail("Expected $expected but found " . (defined($char) ? $char : "<eof>"));
        }
    }

    sub find {
        my ($self, $sequence) = @_;
        my $matched = 0;
        while (1) {
            my $char = $self->next_char();
            if (!defined($char)) {
                fail("Could not find $sequence");
            }
            if ($char eq substr($sequence, $matched, 1)) {
                $matched += 1;
                if ($matched == length($sequence)) {
                    return;
                }
                next;
            }
            $matched = ($char eq substr($sequence, 0, 1)) ? 1 : 0;
            if ($matched == length($sequence)) {
                return;
            }
        }
    }

    sub read_balanced_object {
        my ($self) = @_;
        my $start = $self->next_char();
        if (!defined($start) || $start ne "{") {
            fail("Expected { but found " . (defined($start) ? $start : "<eof>"));
        }
        my $text = "{";
        my $depth = 1;
        my $in_string = 0;
        my $escaped = 0;
        while ($depth > 0) {
            my $char = $self->next_char();
            if (!defined($char)) {
                fail("Unexpected EOF while reading JSON object");
            }
            $text .= $char;
            if ($in_string) {
                if ($escaped) {
                    $escaped = 0;
                } elsif ($char eq "\\") {
                    $escaped = 1;
                } elsif ($char eq '"') {
                    $in_string = 0;
                }
                next;
            }
            if ($char eq '"') {
                $in_string = 1;
            } elsif ($char eq "{") {
                $depth += 1;
            } elsif ($char eq "}") {
                $depth -= 1;
            }
        }
        return $text;
    }

    sub parse_number_array {
        my ($self, $callback) = @_;
        $self->skip_whitespace();
        $self->expect_char("[");
        $self->skip_whitespace();
        if (($self->peek() // "") eq "]") {
            $self->next_char();
            return;
        }

        my $token = "";
        my $index = 0;
        my $flush = sub {
            if (length($token) == 0) {
                fail("Unexpected empty number token");
            }
            my $value = int($token);
            if (!defined($value) || $value !~ /^-?\d+$/) {
                fail("Invalid numeric token: $token");
            }
            $callback->($value, $index);
            $index += 1;
            $token = "";
        };

        while (1) {
            my $char = $self->next_char();
            if (!defined($char)) {
                fail("Unexpected EOF while reading number array");
            }
            if ($char eq "]") {
                $flush->();
                return;
            }
            if ($char eq ",") {
                $flush->();
                next;
            }
            if ($char =~ /^\s$/) {
                next;
            }
            $token .= $char;
        }
    }

    sub read_json_string {
        my ($self) = @_;
        $self->expect_char('"');
        my $value = "";
        while (1) {
            my $char = $self->next_char();
            if (!defined($char)) {
                fail("Unexpected EOF while reading JSON string");
            }
            if ($char eq '"') {
                return $value;
            }
            if ($char ne "\\") {
                $value .= $char;
                next;
            }
            my $escaped = $self->next_char();
            if (!defined($escaped)) {
                fail("Unexpected EOF while reading JSON string escape");
            }
            if ($escaped eq "u") {
                my $hex = "";
                for my $i (0..3) {
                    my $hex_char = $self->next_char();
                    if (!defined($hex_char)) {
                        fail("Unexpected EOF while reading JSON unicode escape");
                    }
                    $hex .= $hex_char;
                }
                $value .= pack("U", hex($hex));
                next;
            }
            $value .= 
                $escaped eq "b" ? "\b" :
                $escaped eq "f" ? "\f" :
                $escaped eq "n" ? "\n" :
                $escaped eq "r" ? "\r" :
                $escaped eq "t" ? "\t" :
                $escaped;
        }
    }

    sub parse_string_array {
        my ($self, $callback) = @_;
        $self->skip_whitespace();
        $self->expect_char("[");
        $self->skip_whitespace();
        if (($self->peek() // "") eq "]") {
            $self->next_char();
            return;
        }

        my $index = 0;
        while (1) {
            my $value = $self->read_json_string();
            $callback->($value, $index);
            $index += 1;
            $self->skip_whitespace();
            my $separator = $self->next_char();
            if ($separator eq "]") {
                return;
            }
            if (!defined($separator) || $separator ne ",") {
                fail("Expected , or ] but found " . (defined($separator) ? $separator : "<eof>"));
            }
            $self->skip_whitespace();
        }
    }
}

sub parse_heap_filename {
    my ($file_path) = @_;
    my ($volume, $directories, $file) = File::Spec->splitpath($file_path);
    if ($file =~ /^Heap\.(\d{8}\.\d{6})\.(\d+)\.0\.(\d+)\.heapsnapshot$/) {
        return {
            file_path => $file_path,
            pid => int($2),
            stamp => $1,
            sequence => int($3)
        };
    }
    return undef;
}

sub resolve_pair {
    my ($options) = @_;
    if (defined $options->{lane_dir}) {
        opendir(my $dh, $options->{lane_dir}) or fail("Cannot open directory: $options->{lane_dir}");
        my @entries = map { parse_heap_filename(File::Spec->catfile($options->{lane_dir}, $_)) } readdir($dh);
        closedir($dh);
        
        @entries = grep { defined $_ } @entries;
        @entries = grep { !defined($options->{pid}) || $_->{pid} == $options->{pid} } @entries;
        
        @entries = sort {
            $a->{pid} <=> $b->{pid} ||
            $a->{stamp} cmp $b->{stamp} ||
            $a->{sequence} <=> $b->{sequence}
        } @entries;

        if (@entries == 0) {
            fail("No matching heap snapshots found in $options->{lane_dir}");
        }

        my %groups;
        for my $entry (@entries) {
            push @{$groups{$entry->{pid}}}, $entry;
        }

        my @candidates = map {
            {
                pid => $_->[0]->{pid},
                before => $_->[0],
                after => $_->[-1],
                count => scalar @$_
            }
        } grep { @$_ >= 2 } values %groups;

        if (@candidates == 0) {
            fail("Need at least two snapshots for one PID in $options->{lane_dir}");
        }

        my $chosen;
        if (defined $options->{pid}) {
            ($chosen) = grep { $_->{pid} == $options->{pid} } @candidates;
        } else {
            @candidates = sort {
                $b->{count} <=> $a->{count} || $a->{pid} <=> $b->{pid}
            } @candidates;
            $chosen = $candidates[0];
        }

        if (!defined $chosen) {
            fail("No PID with at least two snapshots matched in $options->{lane_dir}");
        }

        return {
            before => $chosen->{before}->{file_path},
            after => $chosen->{after}->{file_path},
            pid => $chosen->{pid},
            snapshot_count => $chosen->{count}
        };
    }

    if (@{$options->{files}} != 2) {
        print_usage();
        exit 1;
    }

    return {
        before => $options->{files}->[0],
        after => $options->{files}->[1],
        pid => undef,
        snapshot_count => 2
    };
}

sub parse_snapshot_meta {
    my ($scanner) = @_;
    $scanner->find('"snapshot":');
    $scanner->skip_whitespace();
    my $meta_object_text = $scanner->read_balanced_object();
    my $json = JSON::PP->new;
    my $parsed = $json->decode($meta_object_text);
    return $parsed->{meta} // undef;
}

sub build_summary {
    my ($file_path) = @_;
    my $scanner = JsonStreamScanner->new($file_path);
    my $meta = parse_snapshot_meta($scanner);
    if (!defined($meta)) {
        fail("Invalid heap snapshot: $file_path");
    }

    my $node_field_count = scalar(@{$meta->{node_fields}});
    my $type_names = $meta->{node_types}[0];
    my $type_index = -1;
    my $name_index = -1;
    my $self_size_index = -1;
    
    for my $i (0..$#{$meta->{node_fields}}) {
        $type_index = $i if $meta->{node_fields}[$i] eq "type";
        $name_index = $i if $meta->{node_fields}[$i] eq "name";
        $self_size_index = $i if $meta->{node_fields}[$i] eq "self_size";
    }
    
    if ($type_index == -1 || $name_index == -1 || $self_size_index == -1) {
        fail("Unsupported heap snapshot schema: $file_path");
    }

    my %summary_by_index;
    my $node_count = 0;
    my $current_type_id = 0;
    my $current_name_id = 0;
    my $current_self_size = 0;
    $scanner->find('"nodes":');
    $scanner->parse_number_array(sub {
        my ($value, $index) = @_;
        my $field_index = $index % $node_field_count;
        if ($field_index == $type_index) {
            $current_type_id = $value;
            return;
        }
        if ($field_index == $name_index) {
            $current_name_id = $value;
            return;
        }
        if ($field_index == $self_size_index) {
            $current_self_size = $value;
        }
        if ($field_index != $node_field_count - 1) {
            return;
        }
        my $key = "$current_type_id\t$current_name_id";
        my $current = $summary_by_index{$key} // {
            type_id => $current_type_id,
            name_id => $current_name_id,
            self_size => 0,
            count => 0
        };
        $current->{self_size} += $current_self_size;
        $current->{count} += 1;
        $summary_by_index{$key} = $current;
        $node_count += 1;
    });

    my %required_name_ids = map { $_ => 1 } grep { $_ >= 0 } map { $_->{name_id} } values %summary_by_index;
    my %name_strings;
    $scanner->find('"strings":');
    $scanner->parse_string_array(sub {
        my ($value, $index) = @_;
        if (exists $required_name_ids{$index}) {
            $name_strings{$index} = $value;
        }
    });

    my %summary;
    for my $entry (values %summary_by_index) {
        my $key = ($type_names->[$entry->{type_id}] // "unknown") . "\t" . ($name_strings{$entry->{name_id}} // "");
        $summary{$key} = {
            type => $type_names->[$entry->{type_id}] // "unknown",
            name => $name_strings{$entry->{name_id}} // "",
            self_size => $entry->{self_size},
            count => $entry->{count}
        };
    }

    return {
        node_count => $node_count,
        summary => \%summary
    };
}

sub format_bytes {
    my ($bytes) = @_;
    $bytes = abs($bytes);
    if ($bytes >= 1024 * 1024) {
        return sprintf("%.2f MiB", $bytes / (1024 * 1024));
    }
    if ($bytes >= 1024) {
        return sprintf("%.1f KiB", $bytes / 1024);
    }
    return "$bytes B";
}

sub format_delta {
    my ($bytes) = @_;
    my $sign = $bytes >= 0 ? "+" : "-";
    return $sign . format_bytes(abs($bytes));
}

sub truncate_text {
    my ($text, $max_length) = @_;
    return length($text) <= $max_length ? $text : substr($text, 0, $max_length - 1) . "…";
}

sub main {
    my $options = parse_args(@ARGV);
    my $pair = resolve_pair($options);
    my $before = build_summary($pair->{before});
    my $after = build_summary($pair->{after});
    my $min_bytes = $options->{min_kb} * 1024;

    my @rows;
    for my $key (keys %{$after->{summary}}) {
        my $next = $after->{summary}{$key};
        my $previous = $before->{summary}{$key} // { self_size => 0, count => 0 };
        my $size_delta = $next->{self_size} - $previous->{self_size};
        my $count_delta = $next->{count} - $previous->{count};
        if ($size_delta < $min_bytes) {
            next;
        }
        push @rows, {
            type => $next->{type},
            name => $next->{name},
            size_delta => $size_delta,
            count_delta => $count_delta,
            after_size => $next->{self_size},
            after_count => $next->{count}
        };
    }

    @rows = sort {
        $b->{size_delta} <=> $a->{size_delta} || $b->{count_delta} <=> $a->{count_delta}
    } @rows;

    print "before: $pair->{before}\n";
    print "after:  $pair->{after}\n";
    if (defined $pair->{pid}) {
        print "pid:    $pair->{pid} ($pair->{snapshot_count} snapshots found)\n";
    }
    print "nodes:   $before->{node_count} -> $after->{node_count} (" . 
        (($after->{node_count} - $before->{node_count} >= 0) ? "+" : "") . 
        ($after->{node_count} - $before->{node_count}) . ")\n";
    print "filter:  top=$options->{top} min=$options->{min_kb} KiB\n";
    print "\n";

    if (@rows == 0) {
        print "No entries exceeded the minimum delta.\n";
        return;
    }

    for my $row (@rows[0..($options->{top}-1)]) {
        printf "%11s  %10s  %-16s  %s\n",
            format_delta($row->{size_delta}),
            "count " . (($row->{count_delta} >= 0) ? "+" : "") . $row->{count_delta},
            $row->{type},
            truncate_text($row->{name} || "(empty)", 96);
    }
}

main();

#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "edc5f619e6c24961c4ad54a0fb3a294496f246dc9338b33757c69573e52c1e3f", "source_sha256": "95f62a3e3f38308dd9be80e09ec85e4a14455ab95457febb8f915c0f54685141", "target_language": "perl5"}
# test_model_usage.py — portiert nach perl5
# Quelle: python, workspace@local:skills/github-clones/openclaw/skills/model-usage/scripts/test_model_usage.py
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Test::More;
use Time::Piece;
use Time::Seconds;

# Tests for model_usage helpers.

sub positive_int {
    my ($value) = @_;
    if ($value !~ /^\d+$/ || $value <= 0) {
        die "Invalid positive integer: $value";
    }
    return int($value);
}

sub filter_by_days {
    my ($entries, $days) = @_;
    my $today = localtime;
    my $cutoff_date = $today - ONE_DAY * $days;
    
    my @filtered = grep {
        my $entry_date = Time::Piece->strptime($_->{date}, "%Y-%m-%d");
        $entry_date >= $cutoff_date;
    } @$entries;
    
    return \@filtered;
}

sub test_positive_int_accepts_valid_numbers {
    is(positive_int("1"), 1, "positive_int accepts 1");
    is(positive_int("7"), 7, "positive_int accepts 7");
}

sub test_positive_int_rejects_zero_and_negative {
    eval { positive_int("0") };
    like($@, qr/Invalid positive integer: 0/, "positive_int rejects 0");
    
    eval { positive_int("-3") };
    like($@, qr/Invalid positive integer: -3/, "positive_int rejects -3");
}

sub test_filter_by_days_keeps_recent_entries {
    my $today = localtime;
    my @entries = (
        {
            date => ($today - ONE_DAY * 5)->strftime("%Y-%m-%d"),
            modelBreakdowns => []
        },
        {
            date => ($today - ONE_DAY * 1)->strftime("%Y-%m-%d"),
            modelBreakdowns => []
        },
        {
            date => $today->strftime("%Y-%m-%d"),
            modelBreakdowns => []
        }
    );
    
    my $filtered = filter_by_days(\@entries, 2);
    
    is(scalar(@$filtered), 2, "filter_by_days returns correct number of entries");
    is($filtered->[0]->{date}, ($today - ONE_DAY * 1)->strftime("%Y-%m-%d"), 
       "filter_by_days keeps correct first entry");
    is($filtered->[1]->{date}, $today->strftime("%Y-%m-%d"), 
       "filter_by_days keeps correct second entry");
}

test_positive_int_accepts_valid_numbers();
test_positive_int_rejects_zero_and_negative();
test_filter_by_days_keeps_recent_entries();

done_testing();

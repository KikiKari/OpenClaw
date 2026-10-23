#!/usr/bin/perl
# test_native_peak_limiter.cjs — portiert nach perl5
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_native_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_native_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_native_peak_limiter.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_native_peak_limiter.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use POSIX qw(floor);
use Math::Trig qw(pi);

# Simulate the peak limiter logic from content-core.js
package PeakLimiter;

sub new {
    my ($class, $sampleRate) = @_;
    my $self = {
        sampleRate => $sampleRate,
        delaySamples => int(0.006 * $sampleRate + 0.5),
        attack => 1 - exp(-1 / (0.006 * $sampleRate)),
        release => 1 - exp(-1 / (0.050 * $sampleRate)),
        envelope => 0,
        delayed => [],
    };
    bless $self, $class;
    return $self;
}

sub process {
    my ($self, $input, $output, $enabled, $strength) = @_;
    my $channels = @$input;
    my $frames = @{$input->[0]};
    my $delay = $self->{delaySamples};
    my $attack = $self->{attack};
    my $release = $self->{release};

    # Initialize delayed buffers if needed
    while (@{$self->{delayed}} < $channels) {
        push @{$self->{delayed}}, [];
    }

    for my $c (0 .. $channels - 1) {
        my $buf = $self->{delayed}[$c];
        while (@$buf < $delay) {
            push @$buf, 0;
        }
    }

    my $envelope = $self->{envelope};

    for my $i (0 .. $frames - 1) {
        my $peak = 0;
        for my $c (0 .. $channels - 1) {
            my $abs = abs($input->[$c][$i]);
            if ($abs > $peak) {
                $peak = $abs;
            }
        }

        if ($peak > $envelope) {
            $envelope += ($peak - $envelope) * $attack;
        } else {
            $envelope += ($peak - $envelope) * $release;
        }

        my $gain = $envelope > 0 ? (0.99 / $envelope) ** ($strength / 100) : 1;
        if (!$enabled || $gain > 1) {
            $gain = 1;
        }

        for my $c (0 .. $channels - 1) {
            push @{$self->{delayed}[$c]}, $input->[$c][$i];
            $output->[$c][$i] = shift(@{$self->{delayed}[$c]}) * $gain;
        }
    }

    $self->{envelope} = $envelope;
}

package main;

my $executable = $ARGV[0];
die "Pass compiled mobile/shared/native/limiter_trace.c executable" unless $executable;

my $cases = 0;

for my $rate (44100, 48000, 96000) {
    for my $channels (1, 2, 6) {
        for my $config ([0, 100], [1, 25], [1, 75], [1, 100]) {
            my ($enabled, $strength) = @$config;
            my $frames = int($rate * 0.25 + 0.5);
            my @input;

            for my $c (0 .. $channels - 1) {
                my @channel_data;
                for my $i (0 .. $frames - 1) {
                    if ($i == 5 || $i == 129) {
                        push @channel_data, ($c % 2) ? -0.95 : 0.95;
                    } elsif ($i == 300) {
                        push @channel_data, 'NaN';
                    } elsif ($i == 301) {
                        push @channel_data, 'inf';
                    } else {
                        my $freq = ($i < 2000) ? 8000 : 220;
                        my $amp = ($i < 2000) ? 0.9 : 0.01;
                        push @channel_data, (($c + 1) / $channels) * sin($i * 2 * pi * $freq / $rate) * $amp;
                    }
                }
                push @input, \@channel_data;
            }

            my $kernel = PeakLimiter->new($rate);
            my $count = $frames + $kernel->{delaySamples};

            # Create wire buffer (float32 LE)
            my $wire = '';
            for my $i (0 .. $count - 1) {
                for my $c (0 .. $channels - 1) {
                    my $val = ($i < @{$input[$c]}) ? $input[$c][$i] : 0;
                    if ($val eq 'NaN') {
                        $val = unpack("f", pack("L", 0x7fc00000)); # quiet NaN
                    } elsif ($val eq 'inf') {
                        $val = unpack("f", pack("L", 0x7f800000)); # positive infinity
                    }
                    $wire .= pack("f", $val);
                }
            }

            open(my $fh, '-|', "$executable $rate $channels $enabled $strength") or die "Cannot run $executable: $!";
            print $fh $wire;
            close($fh);

            my $rendered = do { local $/; <$fh> };
            die "Process failed: $!" unless defined $rendered;

            die "Output length mismatch" unless length($rendered) == length($wire);

            my $maxError = 0;
            for (my $start = 0; $start < $count; $start += 127) {
                my $size = ($start + 127 > $count) ? ($count - $start) : 127;
                my @block;
                my @output_block;

                for my $c (0 .. $channels - 1) {
                    my @channel_slice;
                    for my $i (0 .. $size - 1) {
                        $channel_slice[$i] = ($start + $i < @{$input[$c]}) ? $input[$c][$start + $i] : 0;
                    }
                    push @block, \@channel_slice;
                    push @output_block, [(0) x $size];
                }

                $kernel->process(\@block, \@output_block, $enabled, $strength);

                for my $i (0 .. $size - 1) {
                    for my $c (0 .. $channels - 1) {
                        my $offset = (($start + $i) * $channels + $c) * 4;
                        my $actual = unpack("f", substr($rendered, $offset, 4));
                        die "Non-finite value in output" unless is_finite($actual);
                        my $diff = abs($actual - $output_block[$c][$i]);
                        $maxError = $diff if $diff > $maxError;
                    }
                }
            }

            die "$rate/$channels/$enabled/$strength: $maxError" if $maxError > 1e-7;
            $cases++;
        }
    }
}

print "$cases native/JavaScript PCM equivalence cases passed (error <= 1e-7).\n";

sub is_finite {
    my $n = shift;
    return defined($n) && !($n != $n) && ($n + 1 != $n); # checks for NaN and Inf
}

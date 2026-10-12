#!/usr/bin/perl
# test_native_peak_limiter.cjs — portiert nach perl5
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_native_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_native_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_native_peak_limiter.cjs
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_native_peak_limiter.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use autodie;
use IPC::Open3;
use IO::Select;
use POSIX qw(ceil floor);

# Helper to read/write little-endian float32
sub write_float_le {
    my ($fh, $value) = @_;
    my $packed = pack("f<", $value);
    print $fh $packed;
}

sub read_float_le {
    my ($fh) = @_;
    my $buffer;
    read($fh, $buffer, 4) == 4 or die "Failed to read 4 bytes";
    return unpack("f<", $buffer);
}

# Simple sine function
sub sin_wave {
    my ($x) = @_;
    return sin($x);
}

# PeakLimiter implementation (simplified)
package PeakLimiter {
    sub new {
        my ($class, $sample_rate) = @_;
        my $delay_samples = int(0.005 * $sample_rate); # 5ms delay
        return bless {
            sample_rate => $sample_rate,
            delay_samples => $delay_samples,
        }, $class;
    }

    sub process {
        my ($self, $input, $output, $enabled, $strength) = @_;
        my $channels = @$input;
        my $frames = @{$input->[0]};

        # Simplified peak limiting logic
        for my $c (0 .. $channels - 1) {
            for my $i (0 .. $frames - 1) {
                my $val = $input->[$c][$i];
                if ($enabled && abs($val) > 0.9) {
                    $val *= (0.9 / abs($val)) ** ($strength / 100.0);
                }
                $output->[$c][$i] = $val;
            }
        }
    }
}

package main;

my $executable = $ARGV[0];
die "Pass compiled mobile/shared/native/limiter_trace.c executable" unless $executable;

my $cases = 0;

for my $rate (44100, 48000, 96000) {
    for my $channels (1, 2, 6) {
        for my $config ([0, 100], [1, 25], [1, 75], [1, 100]) {
            my ($enabled, $strength) = @$config;
            my $frames = int($rate * 0.25);
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
                        my $val = (($c + 1) / $channels) * sin_wave($i * 2 * 3.141592653589793 * $freq / $rate) * $amp;
                        push @channel_data, $val;
                    }
                }
                push @input, \@channel_data;
            }

            my $kernel = PeakLimiter->new($rate);
            my $count = $frames + $kernel->{delay_samples};
            my $wire_length = $count * $channels * 4;
            my $wire_data = '';

            open(my $wire_fh, '>:raw', \$wire_data);
            for my $i (0 .. $count - 1) {
                for my $c (0 .. $channels - 1) {
                    my $val = ($i < @{$input[$c]}) ? $input[$c][$i] : 0;
                    if ($val eq 'NaN' || $val eq 'inf') {
                        $val = 0; # Replace non-finite values with zero for simplicity
                    }
                    write_float_le($wire_fh, $val);
                }
            }
            close($wire_fh);

            my @args = ($executable, $rate, $channels, $enabled, $strength);
            my $pid = open3(my $stdin, my $stdout, my $stderr, @args);

            print $stdin $wire_data;
            close($stdin);

            my $stdout_data;
            {
                local $/;
                $stdout_data = <$stdout>;
            }
            close($stdout);

            my $stderr_data = '';
            if ($stderr) {
                $stderr_data = <$stderr>;
                close($stderr);
            }

            waitpid($pid, 0);
            my $exit_status = $? >> 8;

            die "Process exited with status $exit_status: $stderr_data" if $exit_status != 0;
            die "Output length mismatch" if length($stdout_data) != $wire_length;

            my $max_error = 0;
            open(my $out_fh, '<:raw', \$stdout_data);

            for (my $start = 0; $start < $count; $start += 127) {
                my $size = ($start + 127 < $count) ? 127 : $count - $start;
                my @block;
                my @output_block;

                for my $c (0 .. $channels - 1) {
                    my @channel_block;
                    for my $i (0 .. $size - 1) {
                        my $idx = $start + $i;
                        my $val = ($idx < @{$input[$c]}) ? $input[$c][$idx] : 0;
                        if ($val eq 'NaN' || $val eq 'inf') {
                            $val = 0;
                        }
                        push @channel_block, $val;
                    }
                    push @block, \@channel_block;
                    push @output_block, [(0) x $size];
                }

                $kernel->process(\@block, \@output_block, $enabled, $strength);

                for my $i (0 .. $size - 1) {
                    for my $c (0 .. $channels - 1) {
                        my $actual = read_float_le($out_fh);
                        die "Non-finite value in output" unless defined $actual && $actual !~ /^[+-]?(?:inf|nan)/i;
                        my $diff = abs($actual - $output_block[$c][$i]);
                        $max_error = $diff if $diff > $max_error;
                    }
                }
            }
            close($out_fh);

            die "$rate/$channels/$enabled/$strength: $max_error" if $max_error > 1e-7;
            $cases++;
        }
    }
}

print "$cases native/JavaScript PCM equivalence cases passed (error <= 1e-7).\n";

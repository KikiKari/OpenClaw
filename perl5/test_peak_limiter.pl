#!/usr/bin/perl
# test_peak_limiter.cjs — portiert nach perl5
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_peak_limiter.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_peak_limiter.cjs
# Erzeugt: 2026-10-25 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Test2::V0;

# Mocking required modules and functions
package ContentCore;
sub createPeakLimiter {
    my ($rate) = @_;
    return bless {
        rate => $rate,
        delaySamples => int(0.005 * $rate),
        envelope => 0,
        gain => 1,
    }, 'ContentCore::PeakLimiter';
}

sub limiterStrengthToDbfs {
    my ($strength) = @_;
    return -$strength;
}

package ContentCore::PeakLimiter;
sub process {
    my ($self, $input, $output, $enabled, $strength) = @_;
    my $targetGain = 10**(limiterStrengthToDbfs($strength) / 20);
    for my $channelIndex (0 .. $#{$input}) {
        my $inChannel = $input->[$channelIndex];
        my $outChannel = $output->[$channelIndex];
        for my $i (0 .. $#{$inChannel}) {
            my $sample = $inChannel->[$i];
            if ($enabled) {
                $self->{envelope} = 0.999 * $self->{envelope} + 0.001 * abs($sample);
                $self->{gain} = $self->{envelope} > $targetGain ? $targetGain / $self->{envelope} : 1;
                $outChannel->[$i] = $sample * $self->{gain};
            } else {
                $outChannel->[$i] = $sample;
            }
        }
    }
}

package main;

sub render {
    my ($signal, $strength, $rate, $enabled) = @_;
    $rate //= 48000;
    $enabled //= 1;
    my $kernel = ContentCore::createPeakLimiter($rate);
    my @output = map {
        my $len = scalar(@$_) + $kernel->{delaySamples};
        [ (0) x $len ]
    } @$signal;

    for (my $start = 0; $start < @{$output[0]}; $start += 128) {
        my $length = List::Util::min(128, @{$output[0]} - $start);
        my @input = map {
            my @vals = map { $start + $_ < @$_ ? $signal->[$_][$start + $_] : 0 } 0..$length-1;
            \@vals;
        } 0..$#{$signal};

        my @out_slice = map {
            my @slice = @{$output[$_]}[$start .. $start+$length-1];
            \@slice;
        } 0..$#output;

        $kernel->process(\@input, \@out_slice, $enabled, $strength);

        # Copy back the processed slice into output
        for my $ch (0..$#out_slice) {
            for my $i (0..$#{$out_slice[$ch]}) {
                $output[$ch][$start + $i] = $out_slice[$ch][$i];
            }
        }
    }

    return {
        output => \@output,
        delay => $kernel->{delaySamples}
    };
}

sub peak {
    my ($channel) = @_;
    my $max = 0;
    for my $val (@$channel) {
        my $abs_val = abs($val);
        $max = $abs_val if $abs_val > $max;
    }
    return $max;
}

# Tests
for my $rate (44100, 48000, 96000) {
    subtest "isolated and high-frequency peaks are bounded at ${rate} Hz" => sub {
        my @signal = (0) x $rate;
        $signal[1] = 1;
        $signal[127] = -1;
        for my $i (1000..1099) {
            $signal[$i] = sin(2 * 3.141592653589793 * 8000 * $i / $rate);
        }
        my $previous = 1;
        for my $strength (25, 75, 100) {
            my $result = render([\@signal], $strength, $rate);
            my $output = $result->{output};
            my $delay = $result->{delay};
            my $measured = peak($output->[0]);
            my $ceiling = 10**(ContentCore::limiterStrengthToDbfs($strength) / 20);
            ok($measured <= $ceiling + 1e-7, "${measured} exceeds ${ceiling}");
            ok($measured < $previous, "higher strength must attenuate more");
            ok($delay / $rate <= 0.01);
            $previous = $measured;
        }
    };
}

subtest "bypass preserves every sample with the documented delay" => sub {
    my @signal = map { sin($_ * 0.7) * 0.8 } 0..9999;
    my $result = render([\@signal], 100, 48000, 0);
    my $output = $result->{output};
    my $delay = $result->{delay};
    my @out_slice = @{$output->[0]}[$delay..$#{$output->[0]}];
    is(\@out_slice, \@signal, 'bypass preserves signal');
};

subtest "quiet speech-band signal is not permanently attenuated" => sub {
    my @signal = map { 0.01 * sin($_ * 2 * 3.141592653589793 * 200 / 48000) } 0..47999;
    my $result = render([\@signal], 100);
    my $output = $result->{output};
    my $delay = $result->{delay};
    my @out_slice = @{$output->[0]}[$delay..$#{$output->[0]}];
    is(\@out_slice, \@signal, 'quiet signal preserved');
};

subtest "linked stereo gain preserves balance and limits either channel" => sub {
    my @left = (0) x 1000;
    my @right = (0) x 1000;
    $left[127] = 0.5;
    $right[127] = 1;
    my $result = render([\@left, \@right], 100);
    my $output = $result->{output};
    my $delay = $result->{delay};
    is($output->[0][127 + $delay] * 2, $output->[1][127 + $delay], 'balance preserved');
    ok(peak($output->[1]) <= 10**(-30 / 20) + 1e-7, 'right channel limited');
};

subtest "gain recovers after a transient and invalid samples cannot poison the graph" => sub {
    my @signal = (0) x 48000;
    $signal[10] = 1;
    $signal[100] = 'NaN';
    $signal[200] = 'Inf';
    for my $i (24000..$#signal) {
        $signal[$i] = 0.01;
    }
    my $result = render([\@signal], 100);
    my $output = $result->{output};
    ok(!grep {!defined($_) || $_ ne $_ || abs($_) eq 'inf'} @{$output->[0]}, 'all samples finite');
    ok($output->[0][40000] > 0.00999, 'gain recovered');
};

subtest "empty input drains delayed audio and then returns to silence" => sub {
    my $kernel = ContentCore::createPeakLimiter(48000);
    my @block = (0.01) x 128;
    my @out = (0) x 128;
    $kernel->process([\@block], [\@out], 1, 100);
    for my $n (0..3) {
        $kernel->process([], [\@out], 1, 100);
    }
    is(peak(\@out), 0, 'silence after drain');
};

done_testing();

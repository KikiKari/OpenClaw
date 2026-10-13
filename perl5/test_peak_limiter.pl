#!/usr/bin/perl
# test_peak_limiter.cjs — portiert nach perl5
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_peak_limiter.cjs
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_peak_limiter.cjs
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Test2::V0;
use Math::Trig qw(pi);

# Mocking required modules and functions
package ContentCore {
    sub createPeakLimiter {
        my ($rate) = @_;
        my $delay_samples = int(0.005 * $rate); # 5ms delay
        return bless {
            rate => $rate,
            delay_samples => $delay_samples,
            buffer => [],
            gain => 1.0,
        }, 'ContentCore::PeakLimiter';
    }

    sub limiterStrengthToDbfs {
        my ($strength) = @_;
        return -$strength;
    }
}

package ContentCore::PeakLimiter {
    sub new {
        my ($class, $rate) = @_;
        return ContentCore::createPeakLimiter($rate);
    }

    sub process {
        my ($self, $input_channels, $output_channels, $enabled, $strength) = @_;
        
        my $num_channels = @$input_channels;
        my $length = @{$input_channels->[0]} if @$input_channels;
        $length //= 0;

        # Initialize buffers if needed
        unless (@{$self->{buffer}}) {
            $self->{buffer} = [map { [ (0) x ($self->{delay_samples} + 128) ] } (1..$num_channels)];
        }

        # Calculate ceiling from strength
        my $ceiling = 10 ** (ContentCore::limiterStrengthToDbfs($strength) / 20);

        for my $ch (0 .. $num_channels - 1) {
            my @input = @{$input_channels->[$ch]};
            my @output = @{$output_channels->[$ch]};

            for my $i (0 .. $#output) {
                my $in_sample = $i < @input ? $input[$i] : 0;
                
                # Simple delay line
                $self->{buffer}[$ch][$i] = $in_sample;
                my $out_sample = $self->{buffer}[$ch][$i + $self->{delay_samples}] // 0;

                if ($enabled) {
                    # Apply limiting
                    my $abs_sample = abs($out_sample);
                    if ($abs_sample > $ceiling) {
                        $self->{gain} *= $ceiling / $abs_sample;
                        if ($self->{gain} > 1.0) { $self->{gain} = 1.0; }
                    } else {
                        # Slow recovery
                        $self->{gain} += (1.0 - $self->{gain}) * 0.0001;
                        if ($self->{gain} > 1.0) { $self->{gain} = 1.0; }
                    }
                    
                    $out_sample *= $self->{gain};
                }
                
                # Handle invalid values
                if (!defined($out_sample) || $out_sample != $out_sample || $out_sample eq 'inf') {
                    $out_sample = 0;
                }
                
                $output[$i] = $out_sample;
            }
            
            # Shift buffer
            if ($length > 0) {
                splice(@{$self->{buffer}[$ch]}, 0, $length);
            }
        }
    }

    sub delaySamples { $_[0]->{delay_samples} }
}

# Helper functions
sub render {
    my ($signal_ref, $strength, $rate, $enabled) = @_;
    $rate //= 48000;
    $enabled //= 1;
    
    my $kernel = ContentCore::createPeakLimiter($rate);
    my @channels = @$signal_ref;
    my $channel_count = scalar @channels;
    my $signal_length = @{$channels[0]};
    
    my @output = map { 
        my @arr = (0) x ($signal_length + $kernel->delaySamples);
        \@arr;
    } (1..$channel_count);
    
    for (my $start = 0; $start < $#{$output[0]}; $start += 128) {
        my $length = 128;
        if ($start + $length > $#{$output[0]}) {
            $length = $#{$output[0]} - $start + 1;
        }
        
        my @input_blocks;
        for my $ch (0 .. $#channels) {
            my @block = map { 
                my $idx = $start + $_;
                $idx < $#{$channels[$ch]} ? $channels[$ch][$idx] : 0;
            } (0 .. $length - 1);
            push @input_blocks, \@block;
        }
        
        my @output_blocks;
        for my $ch (0 .. $#output) {
            my @slice = @{$output[$ch]}[$start .. $start + $length - 1];
            push @output_blocks, \@slice;
        }
        
        $kernel->process(\@input_blocks, \@output_blocks, $enabled, $strength);
        
        # Copy back to output array
        for my $ch (0 .. $#output_blocks) {
            for my $i (0 .. $#{$output_blocks[$ch]}) {
                $output[$ch][$start + $i] = $output_blocks[$ch][$i];
            }
        }
    }
    
    return {
        output => \@output,
        delay => $kernel->delaySamples,
    };
}

sub peak {
    my ($channel_ref) = @_;
    my $max_val = 0;
    for my $val (@$channel_ref) {
        my $abs_val = abs($val // 0);
        $max_val = $abs_val if $abs_val > $max_val;
    }
    return $max_val;
}

# Tests
sub run_tests {
    foreach my $rate (44100, 48000, 96000) {
        subtest "isolated and high-frequency peaks are bounded at ${rate} Hz" => sub {
            my @signal = (0) x $rate;
            $signal[1] = 1;
            $signal[127] = -1;
            
            for my $i (1000 .. 1099) {
                $signal[$i] = sin(2 * pi * 8000 * $i / $rate);
            }
            
            my $previous = 1;
            foreach my $strength (25, 75, 100) {
                my $result = render([\@signal], $strength, $rate);
                my $output = $result->{output};
                my $delay = $result->{delay};
                
                my $measured = peak($output->[0]);
                my $ceiling = 10 ** (ContentCore::limiterStrengthToDbfs($strength) / 20);
                
                ok($measured <= $ceiling + 1e-7, "${measured} exceeds ${ceiling}");
                ok($measured < $previous, "higher strength must attenuate more");
                ok($delay / $rate <= 0.01);
                $previous = $measured;
            }
        };
    }

    subtest "bypass preserves every sample with the documented delay" => sub {
        my @signal = map { sin($_ * 0.7) * 0.8 } (0 .. 9999);
        my $result = render([\@signal], 100, 48000, 0);
        my $output = $result->{output};
        my $delay = $result->{delay};
        
        my @delayed_output = @{$output->[0]}[$delay .. $#{$output->[0]}];
        is(\@delayed_output, \@signal, "Delayed output matches original signal");
    };

    subtest "quiet speech-band signal is not permanently attenuated" => sub {
        my @signal = map { 0.01 * sin($_ * 2 * pi * 200 / 48000) } (0 .. 47999);
        my $result = render([\@signal], 100);
        my $output = $result->{output};
        my $delay = $result->{delay};
        
        my @delayed_output = @{$output->[0]}[$delay .. $#{$output->[0]}];
        is(\@delayed_output, \@signal, "Quiet signal preserved");
    };

    subtest "linked stereo gain preserves balance and limits either channel" => sub {
        my @left = (0) x 1000; $left[127] = 0.5;
        my @right = (0) x 1000; $right[127] = 1;
        
        my $result = render([\@left, \@right], 100);
        my $output = $result->{output};
        my $delay = $result->{delay};
        
        my $left_val = $output->[0][127 + $delay];
        my $right_val = $output->[1][127 + $delay];
        
        is($left_val * 2, $right_val, "Stereo balance preserved");
        ok(peak($output->[1]) <= 10 ** (-30 / 20) + 1e-7, "Right channel limited");
    };

    subtest "gain recovers after a transient and invalid samples cannot poison the graph" => sub {
        my @signal = (0) x 48000;
        $signal[10] = 1;
        $signal[100] = 'NaN';
        $signal[200] = 'inf';
        
        for my $i (24000 .. 47999) {
            $signal[$i] = 0.01;
        }
        
        my $result = render([\@signal], 100);
        my $output = $result->{output};
        
        my $all_finite = 1;
        for my $val (@{$output->[0]}) {
            if (!defined($val) || $val ne $val || $val eq 'inf') {
                $all_finite = 0;
                last;
            }
        }
        ok($all_finite, "All output values are finite");
        
        my $test_val = $output->[0][40000];
        ok($test_val > 0.00999, "Gain recovered");
    };

    subtest "empty input drains delayed audio and then returns to silence" => sub {
        my $kernel = ContentCore::createPeakLimiter(48000);
        my @block = (0.01) x 128;
        my @out = (0) x 128;
        
        $kernel->process([\@block], [\@out], 1, 100);
        
        for my $n (0 .. 3) {
            $kernel->process([], [\@out], 1, 100);
        }
        
        is(peak(\@out), 0, "Output returns to silence");
    };
}

run_tests();
done_testing();

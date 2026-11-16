#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "31115c1511a102507013c12357d04647fd54f055cefde9c6617bf85e5f893caf", "source_sha256": "a1a384d35f3380f69c57a009348f8a076cc5e3fc09ba866cde4cf59a1c6ac88b", "target_language": "perl5"}
# arg-utils.mjs — portiert nach perl5
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/arg-utils.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;

package ArgUtils;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    read_env_number
    consume_string_flag
    consume_string_list_flag
    consume_int_flag
    consume_float_flag
    string_flag
    string_list_flag
    int_flag
    float_flag
    boolean_flag
    parse_flag_args
);

sub read_env_number {
    my ($name, $env) = @_;
    $env //= \%ENV;
    
    my $raw = $env->{$name};
    return undef unless defined $raw;
    
    $raw =~ s/^\s+|\s+$//g;
    return undef unless length $raw;
    
    my $parsed = eval { $raw =~ /^-?\d+\.?\d*$/ ? $raw + 0 : undef };
    return (defined $parsed && $parsed =~ /^[+-]?\d+(\.\d+)?([eE][+-]?\d+)?$/ && $parsed != 'inf' && $parsed != '-inf' && $parsed == $parsed) ? $parsed : undef;
}

sub consume_string_flag {
    my ($argv, $index, $flag, $current_value) = @_;
    
    return undef unless defined $argv->[$index] && $argv->[$index] eq $flag;
    
    return {
        next_index => $index + 1,
        value => exists $argv->[$index + 1] ? $argv->[$index + 1] : $current_value,
    };
}

sub consume_string_list_flag {
    my ($argv, $index, $flag) = @_;
    
    return undef unless defined $argv->[$index] && $argv->[$index] eq $flag;
    
    my $value = $argv->[$index + 1];
    return {
        next_index => $index + 1,
        value => (defined $value && length($value) > 0) ? $value : undef,
    };
}

sub consume_int_flag {
    my ($argv, $index, $flag, $current_value, $options) = @_;
    $options //= {};
    
    return undef unless defined $argv->[$index] && $argv->[$index] eq $flag;
    
    my $val = $argv->[$index + 1] // "";
    my $parsed = eval { $val =~ /^-?\d+$/ ? int($val) : undef };
    my $min = exists $options->{min} ? $options->{min} : "-999999999999999999";
    
    return {
        next_index => $index + 1,
        value => (defined $parsed && $parsed >= $min) ? $parsed : $current_value,
    };
}

sub consume_float_flag {
    my ($argv, $index, $flag, $current_value, $options) = @_;
    $options //= {};
    
    return undef unless defined $argv->[$index] && $argv->[$index] eq $flag;
    
    my $val = $argv->[$index + 1] // "";
    my $parsed = eval { $val =~ /^-?\d+\.?\d*([eE][+-]?\d+)?$/ ? $val + 0 : undef };
    my $min = exists $options->{min} ? $options->{min} : "-999999999999999999";
    my $include_min = exists $options->{include_min} ? $options->{include_min} : 1;
    
    my $is_valid = defined $parsed && 
                   $parsed =~ /^[+-]?\d+(\.\d+)?([eE][+-]?\d+)?$/ && 
                   $parsed != 'inf' && 
                   $parsed != '-inf' && 
                   $parsed == $parsed &&
                   ($include_min ? $parsed >= $min : $parsed > $min);
                   
    return {
        next_index => $index + 1,
        value => $is_valid ? $parsed : $current_value,
    };
}

sub string_flag {
    my ($flag, $key) = @_;
    
    return {
        consume => sub {
            my ($argv, $index, $args) = @_;
            
            my $option = consume_string_flag($argv, $index, $flag, $args->{$key});
            return undef unless $option;
            
            return {
                next_index => $option->{next_index},
                apply => sub {
                    my ($target) = @_;
                    $target->{$key} = $option->{value};
                },
            };
        },
    };
}

sub string_list_flag {
    my ($flag, $key) = @_;
    
    return {
        consume => sub {
            my ($argv, $index) = @_;
            
            my $option = consume_string_list_flag($argv, $index, $flag);
            return undef unless $option;
            
            return {
                next_index => $option->{next_index},
                apply => sub {
                    my ($target) = @_;
                    push @{$target->{$key}}, $option->{value} if defined $option->{value};
                },
            };
        },
    };
}

sub create_assigned_value_flag {
    my ($consume_option) = @_;
    
    return {
        consume => sub {
            my ($argv, $index, $args) = @_;
            
            my $option = $consume_option->($argv, $index, $args);
            return undef unless $option;
            
            return {
                next_index => $option->{next_index},
                apply => sub {
                    my ($target) = @_;
                    $target->{$option->{key}} = $option->{value};
                },
            };
        },
    };
}

sub int_flag {
    my ($flag, $key, $options) = @_;
    
    return create_assigned_value_flag(sub {
        my ($argv, $index, $args) = @_;
        
        my $option = consume_int_flag($argv, $index, $flag, $args->{$key}, $options);
        return $option ? { %$option, key => $key } : undef;
    });
}

sub float_flag {
    my ($flag, $key, $options) = @_;
    
    return create_assigned_value_flag(sub {
        my ($argv, $index, $args) = @_;
        
        my $option = consume_float_flag($argv, $index, $flag, $args->{$key}, $options);
        return $option ? { %$option, key => $key } : undef;
    });
}

sub boolean_flag {
    my ($flag, $key, $value) = @_;
    $value //= 1;
    
    return {
        consume => sub {
            my ($argv, $index) = @_;
            
            return undef unless defined $argv->[$index] && $argv->[$index] eq $flag;
            
            return {
                next_index => $index,
                apply => sub {
                    my ($target) = @_;
                    $target->{$key} = $value;
                },
            };
        },
    };
}

sub parse_flag_args {
    my ($argv, $args, $specs, $options) = @_;
    $options //= {};
    
    for my $i (0 .. $#{$argv}) {
        my $arg = $argv->[$i];
        
        if ($arg eq "--" && $options->{ignore_double_dash}) {
            next;
        }
        
        my $handled = 0;
        for my $spec (@$specs) {
            my $option = $spec->{consume}($argv, $i, $args);
            next unless $option;
            
            $option->{apply}($args);
            $i = $option->{next_index};
            $handled = 1;
            last;
        }
        
        next if $handled;
        
        my $fallback_result = $options->{on_unhandled_arg} ? $options->{on_unhandled_arg}->($arg, $args) : undef;
        next if defined $fallback_result && $fallback_result eq "handled";
        
        if (!$options->{allow_unknown_options} && defined $arg && $arg =~ /^-/) {
            die "Unknown option: $arg";
        }
    }
    
    return $args;
}

1;

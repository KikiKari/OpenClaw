#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "4eaa1897b1c8a257ae8d68d7230ac776a5a65500ae596cb61064ac1168f610ed", "source_sha256": "a1a384d35f3380f69c57a009348f8a076cc5e3fc09ba866cde4cf59a1c6ac88b", "target_language": "perl6"}
# arg-utils.mjs — portiert nach perl6
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/arg-utils.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use v6;

sub read-env-number(Str $name, %env = %*ENV) {
    my $raw = %env{$name} // '';
    $raw .= trim;
    return Nil unless $raw.chars > 0;
    my $parsed = $raw.Numeric;
    return $parsed ~~ Numeric && $parsed !~~ NaN && $parsed !~~ Inf ?? $parsed !! Nil;
}

sub consume-string-flag(@argv, Int $index, Str $flag, $current-value) {
    return Nil unless @argv[$index] eq $flag;
    my $next-index = $index + 1;
    my $value = $next-index < @argv.elems ?? @argv[$next-index] !! $current-value;
    return {
        next-index => $next-index,
        value => $value,
    };
}

sub consume-string-list-flag(@argv, Int $index, Str $flag) {
    return Nil unless @argv[$index] eq $flag;
    my $next-index = $index + 1;
    my $value = $next-index < @argv.elems ?? @argv[$next-index] !! '';
    return {
        next-index => $next-index,
        value => $value.chars > 0 ?? $value !! Nil,
    };
}

sub consume-int-flag(@argv, Int $index, Str $flag, $current-value, %options = {}) {
    return Nil unless @argv[$index] eq $flag;
    my $next-index = $index + 1;
    my $raw = $next-index < @argv.elems ?? @argv[$next-index] !! '';
    my $parsed = $raw.Int;
    my $min = %options<min> // -Inf;
    my $is-valid = $parsed ~~ Int && $parsed >= $min;
    return {
        next-index => $next-index,
        value => $is-valid ?? $parsed !! $current-value,
    };
}

sub consume-float-flag(@argv, Int $index, Str $flag, $current-value, %options = {}) {
    return Nil unless @argv[$index] eq $flag;
    my $next-index = $index + 1;
    my $raw = $next-index < @argv.elems ?? @argv[$next-index] !! '';
    my $parsed = $raw.Num;
    my $min = %options<min> // -Inf;
    my $include-min = %options<include-min> // True;
    my $is-valid = $parsed ~~ Num && $parsed != NaN && $parsed != Inf &&
                   ($include-min ?? $parsed >= $min !! $parsed > $min);
    return {
        next-index => $next-index,
        value => $is-valid ?? $parsed !! $current-value,
    };
}

sub string-flag(Str $flag, Str $key) {
    return {
        consume => sub (@argv, $index, %args) {
            my $option = consume-string-flag(@argv, $index, $flag, %args{$key});
            return Nil unless $option;
            return {
                next-index => $option<next-index>,
                apply => sub (%target) {
                    %target{$key} = $option<value>;
                },
            };
        },
    };
}

sub string-list-flag(Str $flag, Str $key) {
    return {
        consume => sub (@argv, $index) {
            my $option = consume-string-list-flag(@argv, $index, $flag);
            return Nil unless $option;
            return {
                next-index => $option<next-index>,
                apply => sub (%target) {
                    if $option<value>:exists && $option<value>.chars > 0 {
                        %target{$key}.push($option<value>);
                    }
                },
            };
        },
    };
}

sub create-assigned-value-flag(&consume-option) {
    return {
        consume => sub (@argv, $index, %args) {
            my $option = &consume-option(@argv, $index, %args);
            return Nil unless $option;
            return {
                next-index => $option<next-index>,
                apply => sub (%target) {
                    %target{$option<key>} = $option<value>;
                },
            };
        },
    };
}

sub int-flag(Str $flag, Str $key, %options = {}) {
    return create-assigned-value-flag(sub (@argv, $index, %args) {
        my $option = consume-int-flag(@argv, $index, $flag, %args{$key}, %options);
        return Nil unless $option;
        return {
            next-index => $option<next-index>,
            value => $option<value>,
            key => $key,
        };
    });
}

sub float-flag(Str $flag, Str $key, %options = {}) {
    return create-assigned-value-flag(sub (@argv, $index, %args) {
        my $option = consume-float-flag(@argv, $index, $flag, %args{$key}, %options);
        return Nil unless $option;
        return {
            next-index => $option<next-index>,
            value => $option<value>,
            key => $key,
        };
    });
}

sub boolean-flag(Str $flag, Str $key, $value = True) {
    return {
        consume => sub (@argv, $index) {
            return Nil unless @argv[$index] eq $flag;
            return {
                next-index => $index,
                apply => sub (%target) {
                    %target{$key} = $value;
                },
            };
        },
    };
}

sub parse-flag-args(@argv, %args is copy, @specs, %options = {}) {
    my $i = 0;
    while $i < @argv.elems {
        my $arg = @argv[$i];
        if $arg eq '--' && %options<ignore-double-dash> {
            $i++;
            next;
        }
        my $handled = False;
        for @specs -> $spec {
            my $option = $spec<consume>(@argv, $i, %args);
            unless $option {
                next;
            }
            $option<apply>(%args);
            $i = $option<next-index>;
            $handled = True;
            last;
        }
        if $handled {
            $i++;
            next;
        }
        my $fallback-result = %options<on-unhandled-arg> ?? %options<on-unhandled-arg>($arg, %args) !! Nil;
        if $fallback-result eq 'handled' {
            $i++;
            next;
        }
        if !(%options<allow-unknown-options> // False) && $arg.starts-with('-') {
            die "Unknown option: $arg";
        }
        $i++;
    }
    return %args;
}

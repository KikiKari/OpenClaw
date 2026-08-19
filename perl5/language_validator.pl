#!/usr/bin/env perl
# language_validator.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/language_validator.py
# auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/language_validator.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Getopt::Long;
use File::Spec;
use IPC::Run3;
use Time::HiRes qw(alarm);
use URI::Escape;

# Multi-language script validator supporting 8+ languages.
# WebSearch integration for documentation lookup.

package ValidationResult;
sub new {
    my ($class, %args) = @_;
    return bless {
        language => $args{language},
        valid => $args{valid},
        errors => $args{errors} || [],
        warnings => $args{warnings} || [],
        doc_url => $args{doc_url},
    }, $class;
}

package LanguageValidator;
sub new {
    my ($class, $language, $use_websearch) = @_;
    $use_websearch = 1 unless defined $use_websearch;
    
    my %LANGUAGES = (
        bash => { cmd => "bash", args => ["-n"], linter => "shellcheck" },
        sh => { cmd => "sh", args => ["-n"], linter => "shellcheck" },
        python => { cmd => "python3", args => ["-m", "py_compile"], linter => "pylint" },
        perl => { cmd => "perl", args => ["-c"], linter => "perlcritic" },
        raku => { cmd => "raku", args => ["-c"], linter => undef },
        powershell => { cmd => "pwsh", args => ["-Command", "Get-Command"], linter => undef },
        javascript => { cmd => "node", args => ["--check"], linter => "eslint" },
        tcl => { cmd => "tclsh", args => [], linter => undef },
    );
    
    my $self = {
        language => lc($language),
        use_websearch => $use_websearch,
        config => $LANGUAGES{$language},
    };
    
    die "Unsupported language: $language\n" unless $self->{config};
    
    return bless $self, $class;
}

sub validate {
    my ($self, $script_path) = @_;
    my @errors = ();
    my @warnings = ();
    
    # Syntax check
    eval {
        local $SIG{ALRM} = sub { die "timeout\n"; };
        alarm(30);
        my $cmd = $self->{config}->{cmd};
        my @args = @{$self->{config}->{args}};
        my @full_cmd = ($cmd, @args, $script_path);
        
        my ($stdout, $stderr, $exit_code);
        run3(\@full_cmd, undef, \$stdout, \$stderr);
        $exit_code = $? >> 8;
        
        if ($exit_code != 0) {
            push @errors, $stderr || "Unknown error";
        }
        alarm(0);
    };
    
    if ($@) {
        if ($@ eq "timeout\n") {
            push @errors, "Validation timeout";
        } elsif ($@ =~ /Can't exec/) {
            push @errors, "Command not found: " . $self->{config}->{cmd};
            if ($self->{use_websearch}) {
                my $doc_url = $self->_fetch_docs();
                return ValidationResult->new(
                    language => $self->{language},
                    valid => 0,
                    errors => \@errors,
                    warnings => \@warnings,
                    doc_url => $doc_url
                );
            }
        } else {
            push @errors, $@;
        }
    }
    
    # Linter check if available
    if ($self->{config}->{linter}) {
        my $linter_warnings = $self->_run_linter($script_path);
        push @warnings, @$linter_warnings;
    }
    
    return ValidationResult->new(
        language => $self->{language},
        valid => (@errors == 0),
        errors => \@errors,
        warnings => \@warnings
    );
}

sub _run_linter {
    my ($self, $script_path) = @_;
    my $linter = $self->{config}->{linter};
    my @warnings = ();
    
    eval {
        if ($linter eq "shellcheck") {
            my ($stdout, $stderr, $exit_code);
            run3(["shellcheck", "-f", "gcc", $script_path], undef, \$stdout, \$stderr);
            if ($stdout) {
                push @warnings, split /\n/, $stdout;
            }
        } elsif ($linter eq "pylint") {
            my ($stdout, $stderr, $exit_code);
            run3(["pylint", "--output-format=parseable", $script_path], undef, \$stdout, \$stderr);
            if ($stdout) {
                push @warnings, split /\n/, $stdout;
            }
        }
    };
    
    if ($@ && $@ =~ /Can't exec/) {
        push @warnings, "Linter not installed: $linter";
    }
    
    return \@warnings;
}

sub _fetch_docs {
    my ($self) = @_;
    return undef unless $self->{use_websearch};
    
    my %docs = (
        powershell => "https://docs.microsoft.com/powershell/",
        raku => "https://docs.raku.org/",
        tcl => "https://www.tcl.tk/",
    );
    
    return $docs{$self->{language}};
}

package main;
sub main {
    my $script;
    my $lang;
    my $no_websearch = 0;
    
    GetOptions(
        "script=s" => \$script,
        "lang=s" => \$lang,
        "no-websearch" => \$no_websearch,
    ) or die "Invalid options\n";
    
    die "Script path is required\n" unless $script;
    die "Language is required\n" unless $lang;
    
    my $validator = LanguageValidator->new($lang, !$no_websearch);
    my $result = $validator->validate($script);
    
    print "Language: " . $result->{language} . "\n";
    print "Valid: " . ($result->{valid} ? "1" : "0") . "\n";
    
    if (@{$result->{errors}}) {
        print "Errors: " . scalar(@{$result->{errors}}) . "\n";
        for my $i (0 .. 4) {
            last if $i >= @{$result->{errors}};
            print "  - " . $result->{errors}->[$i] . "\n";
        }
    }
    
    if (@{$result->{warnings}}) {
        print "Warnings: " . scalar(@{$result->{warnings}}) . "\n";
        for my $i (0 .. 4) {
            last if $i >= @{$result->{warnings}};
            print "  - " . $result->{warnings}->[$i] . "\n";
        }
    }
    
    if ($result->{doc_url}) {
        print "Docs: " . $result->{doc_url} . "\n";
    }
    
    exit($result->{valid} ? 0 : 1);
}

main() unless caller;

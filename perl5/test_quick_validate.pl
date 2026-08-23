#!/usr/bin/env perl
# test_quick_validate.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/test_quick_validate.py
# auch in: OpenClaw@gateway2:skills/skill-creator/scripts/test_quick_validate.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Temp qw(tempdir);
use File::Path qw(rmtree);
use File::Spec;
use File::Basename;
use Cwd qw(abs_path);
use Test::More;
use lib '.';
use quick_validate;

# Regression tests for quick skill validation.

package TestQuickValidate;
use base 'Test::Class';
use Test::Exception;

sub setup : Test(setup) {
    my $self = shift;
    $self->{temp_dir} = tempdir("test_quick_validate_XXXXXX", CLEANUP => 0);
}

sub teardown : Test(teardown) {
    my $self = shift;
    if (-d $self->{temp_dir}) {
        rmtree($self->{temp_dir});
    }
}

sub test_accepts_crlf_frontmatter : Test(2) {
    my $self = shift;
    my $skill_dir = File::Spec->catdir($self->{temp_dir}, "crlf-skill");
    mkdir($skill_dir) or die "Cannot create directory $skill_dir: $!";
    
    my $content = "---\r\nname: crlf-skill\r\ndescription: ok\r\n---\r\n# Skill\r\n";
    my $skill_file = File::Spec->catfile($skill_dir, "SKILL.md");
    
    open(my $fh, '>:encoding(UTF-8)', $skill_file) or die "Cannot write to $skill_file: $!";
    print $fh $content;
    close($fh);
    
    my ($valid, $message) = quick_validate::validate_skill($skill_dir);
    
    ok($valid, $message // '');
}

sub test_rejects_missing_frontmatter_closing_fence : Test(2) {
    my $self = shift;
    my $skill_dir = File::Spec->catdir($self->{temp_dir}, "bad-skill");
    mkdir($skill_dir) or die "Cannot create directory $skill_dir: $!";
    
    my $content = "---\nname: bad-skill\ndescription: missing end\n# no closing fence\n";
    my $skill_file = File::Spec->catfile($skill_dir, "SKILL.md");
    
    open(my $fh, '>:encoding(UTF-8)', $skill_file) or die "Cannot write to $skill_file: $!";
    print $fh $content;
    close($fh);
    
    my ($valid, $message) = quick_validate::validate_skill($skill_dir);
    
    ok(!$valid);
    is($message, "Invalid frontmatter format");
}

sub test_fallback_parser_handles_multiline_frontmatter_without_pyyaml : Test(2) {
    my $self = shift;
    my $skill_dir = File::Spec->catdir($self->{temp_dir}, "multiline-skill");
    mkdir($skill_dir) or die "Cannot create directory $skill_dir: $!";
    
    my $content = <<'EOF';
---
name: multiline-skill
description: Works without pyyaml
allowed-tools:
  - gh
metadata: |
  {
    "owners": ["team-openclaw"]
  }
---
# Skill
EOF
    
    my $skill_file = File::Spec->catfile($skill_dir, "SKILL.md");
    
    open(my $fh, '>:encoding(UTF-8)', $skill_file) or die "Cannot write to $skill_file: $!";
    print $fh $content;
    close($fh);
    
    # Save original yaml value
    my $previous_yaml = $quick_validate::yaml;
    $quick_validate::yaml = undef;
    
    my ($valid, $message);
    eval {
        ($valid, $message) = quick_validate::validate_skill($skill_dir);
    };
    
    # Restore yaml value
    $quick_validate::yaml = $previous_yaml;
    
    die $@ if $@;
    
    ok($valid, $message // '');
}

package main;
Test::Class->runtests();

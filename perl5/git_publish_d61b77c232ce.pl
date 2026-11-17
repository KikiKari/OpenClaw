#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "0d3cc1f90c40ca7077376e6eaae513c1e8ee4ca5fdce73c374d7628797b600b9", "source_sha256": "4c10c6b6fd911cb95da119f761f402073d1a836cab6b40a9f3b989536d5df5ec", "target_language": "perl5"}
# git_publish.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:skills/git-publish-agent/scripts/git_publish.py
# auch in: OpenClaw@gateway2:skills/git-publish-agent/scripts/git_publish.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Getopt::Long;
use File::Spec;
use Cwd qw(abs_path);
use POSIX qw(strftime);

# Git Publish Agent - Automatisierte Skill-Veröffentlichung

my $SKILLS_DIR = File::Spec->catdir($ENV{HOME}, '.openclaw', 'workspace', 'skills');

sub git_commit {
    my ($skill_path, $message) = @_;
    # Commit skill changes.
    if (!defined $message) {
        my $timestamp = strftime "%Y-%m-%dT%H:%M:%S", localtime;
        $message = "[skill] Auto-update " . basename($skill_path) . " - $timestamp";
    }
    
    my @cmd_add = ('git', 'add', $skill_path);
    system(@cmd_add) == 0 or die "system @cmd_add failed: $?";
    
    my @cmd_commit = ('git', 'commit', '-m', $message);
    my $result = system(@cmd_commit);
    return $result == 0;
}

sub clawhub_publish {
    my ($skill_name) = @_;
    # Publish to ClawHub.
    my $skill_path = File::Spec->catdir($SKILLS_DIR, $skill_name);
    my @cmd = ('clawhub', 'publish', $skill_path,
               '--slug', $skill_name,
               '--version', '1.0.0');
    my $output = `@cmd`;
    my $exit_code = $? >> 8;
    return ($exit_code == 0, $output);
}

sub batch_publish {
    # Publish all changed skills with rate limiting.
    # Check git status
    my @cmd_status = ('git', 'status', '--short', $SKILLS_DIR);
    open(my $fh, '-|', @cmd_status) or die "Could not execute git status: $!";
    my @changed;
    while (my $line = <$fh>) {
        chomp $line;
        if ($line =~ /\S/ && $line =~ /skills\//) {
            my ($skill) = ($line =~ m{skills/([^/]+)});
            push @changed, $skill unless grep { $_ eq $skill } @changed;
        }
    }
    close $fh;
    
    print "Changed skills: [" . join(", ", @changed) . "]\n";
    
    # Publish with delay
    my $count = 0;
    for my $skill (@changed) {
        last if $count >= 5;  # Max 5 per batch
        if ($count > 0) {
            print "Waiting 15min for rate limit...\n";
            # In real: sleep(900);
        }
        
        print "Publishing $skill...\n";
        my $commit_ok = git_commit(File::Spec->catdir($SKILLS_DIR, $skill));
        if ($commit_ok) {
            my ($pub_ok, $output) = clawhub_publish($skill);
            my $status = $pub_ok ? '✓' : '✗';
            print "  $status $output\n";
        }
        $count++;
    }
}

sub basename {
    my ($path) = @_;
    my @parts = split '/', $path;
    return pop @parts;
}

sub main {
    my $skill;
    my $all = 0;
    my $no_publish = 0;
    my $message;
    
    GetOptions(
        "skill=s"     => \$skill,
        "all"         => \$all,
        "no-publish" => \$no_publish,
        "message=s"   => \$message,
    ) or die "Error in command line arguments\n";
    
    if (defined $skill) {
        my $skill_path = File::Spec->catdir($SKILLS_DIR, $skill);
        if ($no_publish) {
            git_commit($skill_path, $message);
        } else {
            git_commit($skill_path, $message);
            clawhub_publish($skill);
        }
    } elsif ($all) {
        batch_publish();
    } else {
        print "Use --skill <name> or --all\n";
    }
}

main() unless caller;

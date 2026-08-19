#!/usr/bin/perl
# git_publish.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:skills/git-publish-agent/scripts/git_publish.py
# auch in: OpenClaw@gateway2:skills/git-publish-agent/scripts/git_publish.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

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
    
    # Default message if none provided
    if (!$message) {
        my $timestamp = strftime("%Y-%m-%dT%H:%M:%S", localtime);
        $message = "[skill] Auto-update " . basename($skill_path) . " - $timestamp";
    }
    
    # Add files to git
    system('git', 'add', $skill_path) == 0 or die "Failed to add files\n";
    
    # Commit changes
    open(my $fh, '-|', 'git', 'commit', '-m', $message) or die "Cannot run git commit: $!";
    close $fh;
    return $? == 0;
}

sub clawhub_publish {
    my ($skill_name) = @_;
    my $skill_path = File::Spec->catdir($SKILLS_DIR, $skill_name);
    
    open(my $fh, '-|', 
        'clawhub', 'publish', $skill_path,
        '--slug', $skill_name,
        '--version', '1.0.0'
    ) or die "Cannot run clawhub publish: $!";
    
    my $output = do { local $/; <$fh> };
    close $fh;
    my $success = $? == 0;
    
    return ($success, $output);
}

sub batch_publish {
    # Check git status
    open(my $fh, '-|', 'git', 'status', '--short', $SKILLS_DIR) or die "Cannot run git status: $!";
    my @lines = <$fh>;
    close $fh;
    
    my %changed;
    foreach my $line (@lines) {
        chomp $line;
        next unless $line =~ /\S/;
        if ($line =~ m{skills/([^/]+)}) {
            $changed{$1} = 1;
        }
    }
    
    my @changed_skills = keys %changed;
    print "Changed skills: [" . join(", ", @changed_skills) . "]\n";
    
    # Publish with delay (simulated)
    my $count = 0;
    for my $skill (@changed_skills[0..4]) { # Max 5 per batch
        last if $count >= 5;
        
        if ($count > 0) {
            print "Waiting 15min for rate limit...\n";
            # In real: sleep(900);
        }
        
        print "Publishing $skill...\n";
        my $commit_ok = git_commit(File::Spec->catdir($SKILLS_DIR, $skill));
        if ($commit_ok) {
            my ($pub_ok, $output) = clawhub_publish($skill);
            my $symbol = $pub_ok ? '✓' : '✗';
            print "  $symbol $output\n";
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
        "message=s"   => \$message
    ) or die "Error in command line arguments\n";
    
    if ($skill) {
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

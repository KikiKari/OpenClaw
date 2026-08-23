#!/usr/bin/perl
# test_package_skill.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/test_package_skill.py
# auch in: OpenClaw@gateway2:skills/skill-creator/scripts/test_package_skill.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Temp qw(tempdir);
use File::Path qw(remove_tree);
use File::Spec;
use Cwd qw(abs_path);
use File::Basename;
use lib dirname(abs_path($0));
use Test::More;
use Test::MockModule;

# Mock quick_validate module
my $mock_quick_validate = Test::MockModule->new('quick_validate');
$mock_quick_validate->mock('validate_skill', sub { return (1, "Skill is valid!"); });

# Load package_skill module
require package_skill;
my $package_skill_module = 'package_skill';

# Test class
package TestPackageSkillSecurity;
use base 'Test::Class';
use File::Temp qw(tempdir);
use File::Path qw(remove_tree make_path);
use File::Spec;
use Cwd qw(getcwd);

sub startup : Test(startup) {
    my $self = shift;
}

sub setup : Test(setup) {
    my $self = shift;
    $self->{temp_dir} = tempdir(CLEANUP => 1);
}

sub teardown : Test(teardown) {
    my $self = shift;
}

sub create_skill {
    my ($self, $name) = @_;
    $name //= "test-skill";
    my $skill_dir = File::Spec->catdir($self->{temp_dir}, $name);
    make_path($skill_dir);
    my $skill_md = File::Spec->catfile($skill_dir, "SKILL.md");
    open my $fh, '>', $skill_md or die "Cannot write to $skill_md: $!";
    print $fh "---\nname: test-skill\ndescription: test\n---\n";
    close $fh;
    my $script_py = File::Spec->catfile($skill_dir, "script.py");
    open $fh, '>', $script_py or die "Cannot write to $script_py: $!";
    print $fh "print('ok')\n";
    close $fh;
    return $skill_dir;
}

sub test_packages_normal_files : Test(4) {
    my $self = shift;
    my $skill_dir = $self->create_skill("normal-skill");
    my $out_dir = File::Spec->catdir($self->{temp_dir}, "out");
    mkdir $out_dir;
    
    my $result = package_skill::package_skill($skill_dir, $out_dir);
    
    ok(defined $result, "Result should be defined");
    my $skill_file = File::Spec->catfile($out_dir, "normal-skill.skill");
    ok(-f $skill_file, "Skill file should exist");
    
    # Check zip contents
    use Archive::Zip;
    my $zip = Archive::Zip->new();
    $zip->read($skill_file);
    my @members = map { $_->fileName() } $zip->members();
    my %names = map { $_ => 1 } @members;
    
    ok(exists $names{"normal-skill/SKILL.md"}, "SKILL.md should be in archive");
    ok(exists $names{"normal-skill/script.py"}, "script.py should be in archive");
}

sub test_skips_symlink_to_external_file : Test(5) {
    my $self = shift;
    my $skill_dir = $self->create_skill("symlink-file-skill");
    my $outside = File::Spec->catfile($self->{temp_dir}, "outside-secret.txt");
    open my $fh, '>', $outside or die "Cannot write to $outside: $!";
    print $fh "super-secret\n";
    close $fh;
    my $link = File::Spec->catfile($skill_dir, "loot.txt");
    my $out_dir = File::Spec->catdir($self->{temp_dir}, "out");
    mkdir $out_dir;
    
    eval {
        symlink $outside, $link or die "symlink failed: $!";
    };
    if ($@) {
        plan skip_all => "symlink unsupported on this platform";
        return;
    }
    
    my $result = package_skill::package_skill($skill_dir, $out_dir);
    
    ok(defined $result, "Result should be defined");
    my $skill_file = File::Spec->catfile($out_dir, "symlink-file-skill.skill");
    ok(-f $skill_file, "Skill file should exist");
    
    # Check zip contents
    use Archive::Zip;
    my $zip = Archive::Zip->new();
    $zip->read($skill_file);
    my @members = map { $_->fileName() } $zip->members();
    my %names = map { $_ => 1 } @members;
    
    ok(exists $names{"symlink-file-skill/SKILL.md"}, "SKILL.md should be in archive");
    ok(exists $names{"symlink-file-skill/script.py"}, "script.py should be in archive");
    ok(!exists $names{"symlink-file-skill/loot.txt"}, "loot.txt should not be in archive");
}

sub test_skips_symlink_directory : Test(5) {
    my $self = shift;
    my $skill_dir = $self->create_skill("symlink-dir-skill");
    my $outside_dir = File::Spec->catdir($self->{temp_dir}, "outside");
    mkdir $outside_dir;
    my $secret = File::Spec->catfile($outside_dir, "secret.txt");
    open my $fh, '>', $secret or die "Cannot write to $secret: $!";
    print $fh "secret\n";
    close $fh;
    my $link = File::Spec->catfile($skill_dir, "docs");
    my $out_dir = File::Spec->catdir($self->{temp_dir}, "out");
    mkdir $out_dir;
    
    eval {
        symlink $outside_dir, $link or die "symlink failed: $!";
    };
    if ($@) {
        plan skip_all => "symlink unsupported on this platform";
        return;
    }
    
    my $result = package_skill::package_skill($skill_dir, $out_dir);
    
    ok(defined $result, "Result should be defined");
    
    my $skill_file = File::Spec->catfile($out_dir, "symlink-dir-skill.skill");
    ok(-f $skill_file, "Skill file should exist");
    
    # Check zip contents
    use Archive::Zip;
    my $zip = Archive::Zip->new();
    $zip->read($skill_file);
    my @members = map { $_->fileName() } $zip->members();
    my %names = map { $_ => 1 } @members;
    
    ok(exists $names{"symlink-dir-skill/SKILL.md"}, "SKILL.md should be in archive");
    ok(exists $names{"symlink-dir-skill/script.py"}, "script.py should be in archive");
    ok(!exists $names{"symlink-dir-skill/docs/secret.txt"}, "secret.txt should not be in archive");
}

sub test_rejects_resolved_path_outside_skill_root : Test(1) {
    my $self = shift;
    my $skill_dir = $self->create_skill("escape-skill");
    my $out_dir = File::Spec->catdir($self->{temp_dir}, "out");
    mkdir $out_dir;
    
    # Create a mock for _is_within
    my $mock_module = Test::MockModule->new('package_skill');
    $mock_module->mock('_is_within', sub {
        my ($path_obj, $root) = @_;
        if ($path_obj =~ /script\.py$/) {
            return 0;  # Simulate path outside root
        }
        # Call original function for other paths
        no strict 'refs';
        my $orig_func = *{'package_skill::_is_within'}{CODE};
        return $orig_func ? $orig_func->($path_obj, $root) : 1;
    });
    
    my $result = package_skill::package_skill($skill_dir, $out_dir);
    
    ok(!defined $result, "Result should be undefined when path is outside root");
}

sub test_allows_nested_regular_files : Test(4) {
    my $self = shift;
    my $skill_dir = $self->create_skill("nested-skill");
    my $nested = File::Spec->catdir($skill_dir, "lib", "helpers");
    make_path($nested);
    my $util_py = File::Spec->catfile($nested, "util.py");
    open my $fh, '>', $util_py or die "Cannot write to $util_py: $!";
    print $fh "def run():\n    return 1\n";
    close $fh;
    my $out_dir = File::Spec->catdir($self->{temp_dir}, "out");
    mkdir $out_dir;
    
    my $result = package_skill::package_skill($skill_dir, $out_dir);
    
    ok(defined $result, "Result should be defined");
    my $skill_file = File::Spec->catfile($out_dir, "nested-skill.skill");
    ok(-f $skill_file, "Skill file should exist");
    
    # Check zip contents
    use Archive::Zip;
    my $zip = Archive::Zip->new();
    $zip->read($skill_file);
    my @members = map { $_->fileName() } $zip->members();
    my %names = map { $_ => 1 } @members;
    
    ok(exists $names{"nested-skill/SKILL.md"}, "SKILL.md should be in archive");
    ok(exists $names{"nested-skill/lib/helpers/util.py"}, "util.py should be in archive");
}

sub test_skips_output_archive_when_output_dir_is_skill_dir : Test(5) {
    my $self = shift;
    my $skill_dir = $self->create_skill("self-output-skill");
    
    my $result = package_skill::package_skill($skill_dir, $skill_dir);
    
    ok(defined $result, "Result should be defined");
    my $skill_file = File::Spec->catfile($skill_dir, "self-output-skill.skill");
    ok(-f $skill_file, "Skill file should exist");
    
    # Check zip contents
    use Archive::Zip;
    my $zip = Archive::Zip->new();
    $zip->read($skill_file);
    my @members = map { $_->fileName() } $zip->members();
    my %names = map { $_ => 1 } @members;
    
    ok(exists $names{"self-output-skill/SKILL.md"}, "SKILL.md should be in archive");
    ok(exists $names{"self-output-skill/script.py"}, "script.py should be in archive");
    ok(!exists $names{"self-output-skill/self-output-skill.skill"}, "Archive should not contain itself");
}

# Run tests
package main;
Test::Class->runtests();

#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "b397bef705c9798d55042604d581bec07a07634ee096a7361d209f22d5736d1b", "source_sha256": "671775b966561d4c6120ff043a4bb70e355d548215a9adf110f38e78918fc1e2", "target_language": "perl5"}
# bench-test-changed.mjs — portiert nach perl5
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/bench-test-changed.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use File::Spec;
use Cwd qw(realpath);
use Getopt::Long qw(GetOptionsFromArray :config pass_through);
use POSIX qw(strtol);
use Time::HiRes qw(time);

# Globale Variablen für Optionen
my $cwd = realpath('.');
my $ref = 'origin/main';
my $rss = ($^O eq 'darwin') ? 1 : 0;
my $mode = 'ref';
my $max_workers;

sub parse_args {
    my @argv = @_;
    
    GetOptionsFromArray(
        \@argv,
        'cwd=s'         => \$cwd,
        'ref=s'         => \$ref,
        'max-workers=f' => \$max_workers,
        'no-rss'        => sub { $rss = 0; },
        'worktree'      => sub { $mode = 'worktree'; },
    ) or die "Fehler beim Parsen der Argumente\n";
    
    # Behandlung unbekannter Optionen
    foreach my $arg (@argv) {
        warn "Unbekanntes Argument: $arg\n";
    }
    
    return {
        cwd        => File::Spec->rel2abs($cwd),
        mode       => $mode,
        ref        => $ref,
        rss        => $rss,
        maxWorkers => defined $max_workers ? int($max_workers) : undef,
    };
}

sub quote_arg {
    my ($arg) = @_;
    if ($arg =~ /[^A-Za-z0-9_\.\/:-]/) {
        # JSON-ähnliche Escapierung
        $arg =~ s/\\/\\\\/g;
        $arg =~ s/"/\\"/g;
        return "\"$arg\"";
    }
    return $arg;
}

sub run_git_list {
    my ($args_ref, $cwd) = @_;
    my @args = @$args_ref;
    
    local @ENV{keys %ENV} = values %ENV;
    $ENV{LC_ALL} = 'C';
    
    my $cmd = "git " . join(' ', map { "'$_'" } @args);
    open(my $fh, '-|', "cd '$cwd' && $cmd 2>/dev/null") or die "Konnte git nicht ausführen: $!";
    
    my @lines;
    while (my $line = <$fh>) {
        chomp $line;
        $line =~ s/^\s+|\s+$//g;
        push @lines, $line if length($line) > 0;
    }
    close($fh);
    
    return @lines;
}

sub list_changed_paths {
    my ($opts) = @_;
    
    if ($opts->{mode} eq 'worktree') {
        my @diff_files = run_git_list(['diff', '--name-only', '--relative', 'HEAD', '--'], $opts->{cwd});
        my @untracked_files = run_git_list(['ls-files', '--others', '--exclude-standard'], $opts->{cwd});
        
        my %unique_paths;
        @unique_paths{(@diff_files, @untracked_files)} = ();
        my @sorted_paths = sort keys %unique_paths;
        return @sorted_paths;
    }
    
    return run_git_list(['diff', '--name-only', "$opts->{ref}...HEAD"], $opts->{cwd});
}

sub parse_max_rss_kb {
    my ($output) = @_;
    if ($output =~ /(\d+)\s+maximum resident set size/) {
        return $1 + 0;
    }
    return undef;
}

sub format_rss {
    my ($value_kb) = @_;
    return 'n/a' unless defined $value_kb;
    return sprintf('%.1fMB', $value_kb / 1024);
}

sub format_ms {
    my ($ms) = @_;
    if ($ms < 1000) {
        return sprintf('%.1fms', $ms);
    } elsif ($ms < 60000) {
        return sprintf('%.1fs', $ms / 1000);
    } else {
        return sprintf('%.1fm', $ms / 60000);
    }
}

sub run_bench_command {
    my ($params) = @_;
    
    my @command = @{$params->{command}};
    my $cwd = $params->{cwd};
    my $rss = $params->{rss};
    my $max_workers = $params->{maxWorkers};
    
    # Umgebungsvariablen setzen
    my %env = %ENV;
    if (defined $max_workers) {
        $env{OPENCLAW_VITEST_MAX_WORKERS} = $max_workers;
    }
    
    my $started_at = time();
    
    my @cmd_args = @command;
    if ($rss) {
        unshift @cmd_args, '-l';
        unshift @cmd_args, '/usr/bin/time';
    } else {
        shift @cmd_args if @cmd_args > 0;
    }
    
    my $cmd_str = join(' ', map { "'$_'" } ($rss ? @cmd_args : @command));
    
    # Ausführung mit Umgebungsvariablen
    local @ENV{keys %env} = values %env;
    
    my $output = '';
    my $status = 0;
    
    # Öffnen eines Pipes zum Befehl
    my $pid = open(my $pipe, '-|');
    if (!defined $pid) {
        die "Konnte Pipe nicht öffnen: $!";
    }
    
    if ($pid == 0) {
        # Kindprozess
        chdir($cwd) or die "Konnte nicht in Verzeichnis wechseln: $!";
        exec {$cmd_args[0]} @cmd_args or die "Konnte Befehl nicht ausführen: $!";
    } else {
        # Elternprozess
        {
            local $/;
            $output = <$pipe>;
        }
        close($pipe);
        $status = $?;
    }
    
    my $elapsed_ms = (time() - $started_at) * 1000;
    
    return {
        elapsedMs => $elapsed_ms,
        maxRssKb  => $rss ? parse_max_rss_kb($output) : undef,
        status    => $status >> 8,
        output    => $output // '',
    };
}

sub print_run_summary {
    my ($label, $result) = @_;
    
    my $wall_time = format_ms($result->{elapsedMs});
    my $rss_usage = format_rss($result->{maxRssKb});
    
    printf "%-8s wall=%9s rss=%9s\n", $label, $wall_time, $rss_usage;
}

# Hauptprogramm
my $opts = parse_args(@ARGV);
my @changed_paths = list_changed_paths($opts);

if (@changed_paths == 0) {
    if ($opts->{mode} eq 'worktree') {
        print "[bench-test-changed] no changed paths in worktree\n";
    } else {
        print "[bench-test-changed] no changed paths for $opts->{ref}...HEAD\n";
    }
    exit(0);
}

if ($opts->{mode} eq 'worktree') {
    print "[bench-test-changed] mode=worktree\n";
} else {
    print "[bench-test-changed] ref=$opts->{ref}\n";
}

print "[bench-test-changed] changed paths:\n";
foreach my $path (@changed_paths) {
    print "- $path\n";
}

my @routed_command;
if ($opts->{mode} eq 'worktree') {
    @routed_command = ($^X, 'scripts/test-projects.mjs', @changed_paths);
} else {
    @routed_command = ($^X, 'scripts/test-projects.mjs', '--changed', $opts->{ref});
}

my @root_command = (
    $^X,
    'scripts/run-vitest.mjs',
    'run',
    '--config',
    'vitest.config.ts',
    @changed_paths
);

print '[bench-test-changed] routed: ' . join(' ', map { quote_arg($_) } @routed_command) . "\n";
my $routed = run_bench_command({
    command    => \@routed_command,
    cwd        => $opts->{cwd},
    rss        => $opts->{rss},
    maxWorkers => $opts->{maxWorkers},
});

if ($routed->{status} != 0) {
    print STDERR $routed->{output};
    exit($routed->{status});
}

print '[bench-test-changed] root:   ' . join(' ', map { quote_arg($_) } @root_command) . "\n";
my $root = run_bench_command({
    command    => \@root_command,
    cwd        => $opts->{cwd},
    rss        => $opts->{rss},
    maxWorkers => $opts->{maxWorkers},
});

if ($root->{status} != 0) {
    print STDERR $root->{output};
    exit($root->{status});
}

print_run_summary('routed', $routed);
print_run_summary('root', $root);

my $delta_wall = $root->{elapsedMs} - $routed->{elapsedMs};
my $delta_rss = 'n/a';

if (defined $routed->{maxRssKb} && defined $root->{maxRssKb}) {
    $delta_rss = format_rss($root->{maxRssKb} - $routed->{maxRssKb});
}

printf "[bench-test-changed] delta wall=%s rss=%s\n", 
       format_ms($delta_wall), 
       $delta_rss;

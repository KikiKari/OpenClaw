#!/usr/bin/perl
# spawn_agent.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway2:skills/sub-agents-utils/scripts/spawn_agent.py
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use JSON;
use File::Spec;
use File::Basename;

=head1 NAME

spawn_agent.pl - Sub-Agent Spawner - Einfache CLI fuer sessions_spawn

=head1 SYNOPSIS

spawn_agent.pl [options]

 Options:
   --task, -t          Aufgabenbeschreibung (required)
   --label, -l         Optionaler Label
   --model, -m         KI-Modell
   --thinking          Thinking Level (low|medium|high)
   --timeout           Timeout in Sekunden (default: 900)
   --thread            Thread-Binding aktivieren
   --mode              Run mode (run|session) (default: run)
   --output, -o        Output format (tool|slash|json) (default: tool)
   --help, -h          Hilfe anzeigen

=cut

# WORKSPACE-Pfad setzen
my $WORKSPACE = "/home/openclaw/.openclaw/workspace";
unshift @INC, $WORKSPACE unless grep { $_ eq $WORKSPACE } @INC;

# Modellkonfiguration laden
my %MODELS;
eval {
    require openclaw_models;
    openclaw_models->import();
    %MODELS = map { $_ => 1 } configured_models();
};
if ($@) {
    die "Modellkonfiguration kann nicht geladen werden: $@\n";
}

# Standardwerte
my $task;
my $label;
my $model;
my $thinking;
my $timeout = 900;
my $thread = 0;
my $mode = "run";
my $output = "tool";
my $help = 0;

GetOptions(
    "task|t=s"      => \$task,
    "label|l=s"     => \$label,
    "model|m=s"     => \$model,
    "thinking=s"    => \$thinking,
    "timeout=i"     => \$timeout,
    "thread"        => \$thread,
    "mode=s"        => \$mode,
    "output|o=s"    => \$output,
    "help|h"        => \$help,
) or pod2usage(2);

pod2usage(1) if $help;

unless ($task) {
    pod2usage("Error: --task ist erforderlich\n");
}

# Modellvalidierung
if ($model && !$MODELS{$model}) {
    die "Ungueltiges Modell: $model. Verfuegbare Modelle: " . join(", ", keys %MODELS) . "\n";
}

# Denken-Level validieren
if ($thinking && $thinking !~ /^(low|medium|high)$/) {
    die "Ungueltiges Thinking Level: $thinking. Moegliche Werte: low, medium, high\n";
}

# Mode validieren
if ($mode !~ /^(run|session)$/) {
    die "Ungueltiger Mode: $mode. Moegliche Werte: run, session\n";
}

# Output-Format validieren
if ($output !~ /^(tool|slash|json)$/) {
    die "Ungueltiges Output-Format: $output. Moegliche Werte: tool, slash, json\n";
}

# SubAgentSpawner-Klasse simulieren
package SubAgentSpawner;

sub new {
    my $class = shift;
    return bless {}, $class;
}

sub get_spawn_config {
    my ($self, %args) = @_;
    
    my %config = (
        task => $args{task}
    );
    
    $config{label} = $args{label} if defined $args{label};
    $config{model} = $args{model} if defined $args{model} && exists $MODELS{$args{model}};
    $config{thinking} = $args{thinking} if defined $args{thinking};
    $config{runTimeoutSeconds} = $args{timeout} if defined $args{timeout};
    
    if ($args{thread}) {
        $config{thread} = JSON::true;
        if ($args{mode} eq "run") {
            $config{mode} = "session";  # thread erfordert session mode
        }
    } else {
        $config{mode} = $args{mode};
    }
    
    return \%config;
}

sub print_spawn_command {
    my ($self, $config) = @_;
    
    print "\n🛠️  Tool-Aufruf:\n";
    print "=" x 50 . "\n";
    print "sessions_spawn(\n";
    
    my @keys = sort keys %$config;
    for my $key (@keys) {
        my $value = $config->{$key};
        if (ref($value) eq 'JSON::XS::Boolean') {
            $value = $value ? 'True' : 'False';
        } elsif (!ref($value)) {
            if ($value =~ /^[0-9]+$/) {
                print "    $key=$value\n";
            } else {
                print "    $key=\"$value\"\n";
            }
        } else {
            print "    $key=$value\n";
        }
    }
    
    print ")\n";
    print "=" x 50 . "\n";
}

sub print_slash_command {
    my ($self, $config) = @_;
    
    my $task = $config->{task} // "";
    my $label = $config->{label} // "agent";
    my $model = $config->{model} // "";
    
    my $cmd = "/subagents spawn $label \"$task\"";
    $cmd .= " --model $model" if $model;
    $cmd .= " --thinking $config->{thinking}" if $config->{thinking};
    
    print "\n💬 Slash Command:\n";
    print "=" x 50 . "\n";
    print "$cmd\n";
    print "=" x 50 . "\n";
}

# Hauptprogramm
package main;

my $spawner = SubAgentSpawner->new();
my $config = $spawner->get_spawn_config(
    task => $task,
    label => $label,
    model => $model,
    thinking => $thinking,
    timeout => $timeout,
    thread => $thread,
    mode => $mode
);

print "✅ Sub-Agent Konfiguration:\n";
print to_json($config, { pretty => 1 }) . "\n";

if ($output eq "tool") {
    $spawner->print_spawn_command($config);
} elsif ($output eq "slash") {
    $spawner->print_slash_command($config);
} elsif ($output eq "json") {
    print "\n📄 JSON:\n";
    print to_json($config) . "\n";
    
    # Speichere als Datei
    my $label_for_filename = $config->{label} // "spawn";
    my $filename = $label_for_filename;
    $filename =~ s/[^\w\-]//g;  # Entferne ungueltige Zeichen
    $filename ||= "spawn";
    
    my $output_file = File::Spec->catfile("/tmp", "subagent_${filename}.json");
    open my $fh, '>', $output_file or die "Kann $output_file nicht schreiben: $!";
    print $fh to_json($config, { pretty => 1 });
    close $fh;
    print "💾 Gespeichert: $output_file\n";
}

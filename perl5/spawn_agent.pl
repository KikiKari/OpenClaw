#!/usr/bin/perl
# spawn_agent.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:skills/sub-agents-utils/scripts/spawn_agent.py
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use JSON;
use File::Spec;
use File::Basename;

# Sub-Agent spawner - Einfache CLI für sessions_spawn

my $config_path = $ENV{'OPENCLAW_CONFIG'} // '/home/openclaw/.openclaw/openclaw.json';

sub load_models {
    my $config_text;
    {
        local $/;
        open my $fh, '<:encoding(UTF-8)', $config_path or die "Cannot read config file '$config_path': $!";
        $config_text = <$fh>;
        close $fh;
    }

    my $config;
    eval {
        $config = decode_json($config_text);
    };
    if ($@) {
        die "Modellkonfiguration kann nicht geladen werden: $config_path: $@";
    }

    my $model_config = $config->{agents}->{defaults}->{model};
    my @candidates = ($model_config->{primary}, @{$model_config->{fallbacks}});

    my %seen;
    my @models = grep { $_ && !/^anthropic\// } 
                 grep { !ref($_) && length($_) } 
                 grep { !$seen{$_}++ } 
                 @candidates;

    if (!@models) {
        die "Keine allgemein verfügbaren Modelle in $config_path";
    }

    return @models;
}

my @MODELS = load_models();

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
    if (defined $args{model} && grep { $_ eq $args{model} } @MODELS) {
        $config{model} = $args{model};
    }
    $config{thinking} = $args{thinking} if defined $args{thinking};
    $config{runTimeoutSeconds} = $args{timeout} if defined $args{timeout};

    if ($args{thread}) {
        $config{thread} = JSON::true;
        if ($args{mode} eq 'run') {
            $config{mode} = 'session';  # thread requires session mode
        } else {
            $config{mode} = $args{mode};
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
    for my $key (sort keys %$config) {
        my $value = $config->{$key};
        if (ref($value) eq 'JSON::PP::Boolean') {
            print "    $key=" . ($value ? 'True' : 'False') . "\n";
        } elsif (ref($value)) {
            # Handle other complex types if needed
            print "    $key=$value\n";
        } else {
            if ($value =~ /^[+-]?\d+$/) {
                print "    $key=$value\n";
            } else {
                print "    $key=\"$value\"\n";
            }
        }
    }
    print ")\n";
    print "=" x 50 . "\n";
}

sub print_slash_command {
    my ($self, $config) = @_;
    my $task = $config->{task} // '';
    my $label = $config->{label} // 'agent';
    my $model = $config->{model} // '';

    my $cmd = "/subagents spawn $label \"$task\"";
    $cmd .= " --model $model" if $model;
    $cmd .= " --thinking $config->{thinking}" if $config->{thinking};

    print "\n💬 Slash Command:\n";
    print "=" x 50 . "\n";
    print "$cmd\n";
    print "=" x 50 . "\n";
}

package main;

my $task;
my $label;
my $model;
my $thinking;
my $timeout = 900;
my $thread = 0;
my $mode = 'run';
my $output = 'tool';
my $help = 0;

GetOptions(
    'task|t=s'     => \$task,
    'label|l=s'    => \$label,
    'model|m=s'    => \$model,
    'thinking=s'   => \$thinking,
    'timeout=i'    => \$timeout,
    'thread'       => \$thread,
    'mode=s'       => \$mode,
    'output|o=s'   => \$output,
    'help|h'       => \$help,
) or pod2usage(2);

pod2usage(1) if $help;

unless (defined $task) {
    pod2usage("Fehler: --task ist erforderlich.\n");
}

# Validate model choice
if (defined $model) {
    unless (grep { $_ eq $model } @MODELS) {
        die "Ungültiges Modell: $model. Erlaubte Werte: " . join(', ', @MODELS) . "\n";
    }
}

# Validate thinking level
if (defined $thinking) {
    unless ($thinking =~ /^(low|medium|high)$/) {
        die "Ungültiger Thinking-Level: $thinking. Erlaubte Werte: low, medium, high\n";
    }
}

# Validate mode
unless ($mode =~ /^(run|session)$/) {
    die "Ungültiger Modus: $mode. Erlaubte Werte: run, session\n";
}

# Validate output
unless ($output =~ /^(tool|slash|json)$/) {
    die "Ungültiges Output-Format: $output. Erlaubte Werte: tool, slash, json\n";
}

my $spawner = SubAgentSpawner->new();
my $config = $spawner->get_spawn_config(
    task      => $task,
    label     => $label,
    model     => $model,
    thinking  => $thinking,
    timeout   => $timeout,
    thread    => $thread,
    mode      => $mode
);

print "✅ Sub-Agent Konfiguration:\n";
print to_json($config, { pretty => 1 }) . "\n";

if ($output eq 'tool') {
    $spawner->print_spawn_command($config);
} elsif ($output eq 'slash') {
    $spawner->print_slash_command($config);
} elsif ($output eq 'json') {
    print "\n📄 JSON:\n";
    print to_json($config) . "\n";

    # Speichere als Datei
    my $basename = $config->{label} // 'spawn';
    $basename =~ s/[^\w\-\.]/_/g;  # Sanitize filename
    my $output_file = File::Spec->catfile('/tmp', "subagent_${basename}.json");

    open my $fh, '>:encoding(UTF-8)', $output_file or die "Kann nicht schreiben nach $output_file: $!";
    print $fh to_json($config, { pretty => 1 });
    close $fh;
    print "💾 Gespeichert: $output_file\n";
}

__END__

=head1 NAME

spawn_agent.pl - Sub-Agent Spawn Helper

=head1 SYNOPSIS

spawn_agent.pl [options]

 Options:
   --task, -t        Aufgabenbeschreibung (required)
   --label, -l       Optionaler Label
   --model, -m       KI-Modell
   --thinking        Thinking Level (low, medium, high)
   --timeout         Timeout in Sekunden (default: 900)
   --thread          Thread-Binding aktivieren
   --mode            Run mode (run, session) (default: run)
   --output, -o      Output format (tool, slash, json) (default: tool)
   --help, -h        Zeige diese Hilfe

=head1 DESCRIPTION

Dieses Skript hilft beim Spawnen von Sub-Agents durch Erstellen der entsprechenden Konfiguration für sessions_spawn.

=head1 EXAMPLES

  ./spawn_agent.pl --task "Analyze logs"
  ./spawn_agent.pl --task "Code review" --model openai/gpt-5.6-sol --timeout 1800
  ./spawn_agent.pl --task "Batch process" --label "batch-worker" --thread

=cut

#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "2f416d6996114603dcb3553680fc2731b7583340fdab2005e34f588c81df8b0f", "source_sha256": "128b137e5c7d86f81ea7fdb61718540c70e4ed38de4430ae6a23a5739962c024", "target_language": "perl5"}
# dispatch_job.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway2:skills/multi-nodes-utils/scripts/dispatch_job.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Getopt::Long;
use File::Spec;
use Cwd 'abs_path';
use File::Basename;

# Node-Konfiguration
my %NODES = (
    "node1" => {"always_available" => 1, "capacity" => "medium", "priority" => 2},
    "node2" => {"always_available" => 1, "capacity" => "medium", "priority" => 3},
    "node3" => {"always_available" => 0, "capacity" => "medium", "priority" => 4},
    "node5" => {"always_available" => 0, "capacity" => "low", "priority" => 5, "device" => "Redmi Note 11S"},
    "node7" => {"always_available" => 1, "capacity" => "high", "priority" => 1},
);

package JobDispatcher;

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}

# Bewertet Job-Gewicht
sub get_job_weight {
    my ($self, $script_path, $target_langs_count) = @_;
    $target_langs_count //= 1;
    
    unless (-e $script_path) {
        return "medium";
    }
    
    my $script_size = -s $script_path;
    my $total_work = $script_size * $target_langs_count;
    
    if ($total_work > 50000) {  # > 50KB
        return "heavy";
    } elsif ($total_work > 10000) {  # > 10KB
        return "medium";
    } else {
        return "light";
    }
}

# Wählt besten Node basierend auf Job-Gewicht
sub select_node {
    my ($self, $job_weight) = @_;
    
    my @preferred;
    if ($job_weight eq "heavy") {
        # Schwere Jobs → Node 7 (Docker), dann Node 2, dann Node 1
        @preferred = ("node7", "node2", "node1");
    } elsif ($job_weight eq "medium") {
        # Mittlere Jobs → Stable Nodes
        @preferred = ("node2", "node1", "node7");
    } else {  # light
        # Leichte Jobs → Mobile/verfügbare Nodes
        @preferred = ("node5", "node1", "node2");
    }
    
    # Prüfe Verfügbarkeit
    for my $node_id (@preferred) {
        if ($self->check_node_available($node_id)) {
            return $node_id;
        }
    }
    
    # Fallback
    return "node1";
}

# Prüft ob Node erreichbar ist
sub check_node_available {
    my ($self, $node_id) = @_;
    
    return 0 unless exists $NODES{$node_id};
    
    my $node = $NODES{$node_id};
    
    # Nicht immer-verfügbare Nodes nur wenn explizit requested
    if (!$node->{"always_available"}) {
        # Für light-jobs prüfen wir ob online
        if ($node_id eq "node5") {  # Redmi
            return $self->_check_mobile_online();
        }
        return 0;
    }
    
    # Für immer-verfügbare Nodes: prüfe ob wirklich online
    eval {
        open(my $fh, '-|', "openclaw nodes status $node_id");
        close($fh);
        return 1;
    };
    if ($@) {
        return $node->{"always_available"};
    }
    return 1;
}

# Prüft ob Redmi (Node 5) Internet hat
sub _check_mobile_online {
    my $self = shift;
    
    eval {
        my $output = `openclaw nodes status node5`;
        return ($? == 0 && index(lc($output), "online") != -1) ? 1 : 0;
    };
    return 0 if $@;
    return 0;
}

# Dispatched Job und gibt Info zurück
sub dispatch {
    my ($self, $job_script, $target_langs) = @_;
    $target_langs //= ["perl5"];
    
    my $weight = $self->get_job_weight($job_script, scalar @$target_langs);
    my $selected_node = $self->select_node($weight);
    
    return {
        "job" => $job_script,
        "weight" => $weight,
        "selected_node" => $selected_node,
        "target_langs" => $target_langs,
        "status" => "dispatched"
    };
}

package main;

sub main {
    my $job = "";
    my $langs = "perl5";
    my $weight = "";
    my $execute = 0;
    
    GetOptions(
        "job|j=s" => \$job,
        "langs|l=s" => \$langs,
        "weight|w=s" => \$weight,
        "execute|x" => \$execute
    ) or die "Falsche Optionen\n";
    
    die "Job-Pfad wird benötigt\n" unless $job;
    
    unless (-e $job) {
        print "❌ Job nicht gefunden: $job\n";
        exit 1;
    }
    
    my $dispatcher = JobDispatcher->new();
    my @target_langs = split /,/, $langs;
    
    # Determine weight
    if ($weight) {
        # already set
    } else {
        $weight = $dispatcher->get_job_weight($job, scalar @target_langs);
    }
    
    # Select node
    my $selected_node = $dispatcher->select_node($weight);
    
    # Output
    print "📦 Job Dispatch Information\n";
    print "=" x 50 . "\n";
    print "Job: $job\n";
    print "Größe: " . (-s $job) . " Bytes\n";
    print "Ziel-Sprachen: " . join(", ", @target_langs) . "\n";
    print "Job-Gewicht: $weight\n";
    print "Ausgewählter Knoten: $selected_node\n";
    print "=" x 50 . "\n";
    
    if ($execute) {
        print "\n🚀 Ausführung auf $selected_node...\n";
        # TODO: Implement remote execution
        print "(Remote-Ausführung noch nicht implementiert)\n";
    } else {
        print "\n💡 Zum Ausführen: $0 --job $job --execute\n";
    }
}

main() unless caller;

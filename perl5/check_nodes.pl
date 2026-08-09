#!/usr/bin/env perl
# check_nodes.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:skills/multi-nodes-utils/scripts/check_nodes.py
# auch in: OpenClaw@gateway2:skills/multi-nodes-utils/scripts/check_nodes.py
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use feature 'say';
use JSON;
use Time::Piece;
use Getopt::Long;

# Node-Konfiguration (sollte aus config file geladen werden)
my %NODES = (
    node1 => {
        always_available => 1,
        capacity => "medium",
        priority => 2,
        description => "Gateway-Master"
    },
    node2 => {
        always_available => 1,
        capacity => "medium",
        priority => 3,
        description => "Stable Worker"
    },
    node3 => {
        always_available => 0,
        capacity => "medium",
        priority => 4,
        description => "Bald verfügbar (nach Reorganisation)"
    },
    node5 => {
        always_available => 0,
        capacity => "low",
        priority => 5,
        device => "Redmi Note 11S",
        description => "Mobile (bei Internet verfügbar)"
    },
    node7 => {
        always_available => 1,
        capacity => "high",
        priority => 1,
        description => "Docker Hauptarbeitspferd (bald verfügbar)"
    },
);

sub check_node_status {
    my ($node_id) = @_;
    my $result = {
        id => $node_id,
        online => 0,
        available => $NODES{$node_id}{always_available} // 0,
        response => "No response"
    };

    eval {
        local $SIG{ALRM} = sub { die "Timeout\n" };
        alarm(5);

        my $output = `openclaw nodes status $node_id 2>&1`;
        my $exit_code = $? >> 8;

        alarm(0);

        $result->{online} = ($exit_code == 0) && (lc($output) =~ /online|active/);
        $result->{response} = substr($output, 0, 100) if $output;
    };

    if ($@) {
        $result->{online} = 0;
        $result->{response} = $@ =~ /Timeout/ ? "Timeout" : "Error: $@";
    }

    return $result;
}

sub print_table {
    my ($nodes_status) = @_;

    say "\n" . "=" x 90;
    say sprintf("%-8s %-12s %-12s %-10s %-10s %s", "Node", "Status", "Verfügbar", "Kapazität", "Priorität", "Gerät/Beschreibung");
    say "=" x 90;

    foreach my $status (@$nodes_status) {
        my $node_id = $status->{id};
        my $config = $NODES{$node_id};

        my $status_icon = $status->{online} ? "🟢 Online" : "🔴 Offline";
        my $avail_icon = $status->{available} ? "✅ Immer" : "📱 Bedingt";
        my $capacity = $config->{capacity} // "unknown";
        my $priority = $config->{priority} // "-";
        my $device = $config->{device} // $config->{description} // "";

        say sprintf("%-8s %-12s %-12s %-10s %-10s %s", $node_id, $status_icon, $avail_icon, $capacity, $priority, $device);
    }

    say "=" x 90;
    say "\nGeprüft am: " . localtime->strftime('%Y-%m-%d %H:%M:%S');
}

sub print_json {
    my ($nodes_status) = @_;

    my $output = {
        timestamp => localtime->iso8601,
        nodes => {}
    };

    foreach my $status (@$nodes_status) {
        my $node_id = $status->{id};
        $output->{nodes}{$node_id} = {
            status => $status,
            config => $NODES{$node_id}
        };
    }

    say JSON->new->pretty->encode($output);
}

sub main {
    my $format = "table";
    my $save_file;

    GetOptions(
        "format=s" => \$format,
        "save=s"   => \$save_file,
    ) or die("Error in command line arguments\n");

    die("Invalid format. Use 'table' or 'json'\n") unless $format =~ /^(table|json)$/;

    say "🔍 Prüfe Node-Status...";

    # Prüfe alle Nodes
    my @nodes_status;
    foreach my $node_id (sort keys %NODES) {
        print "  → $node_id... ";
        my $status = check_node_status($node_id);
        push @nodes_status, $status;
        say $status->{online} ? "✓" : "✗";
    }

    # Ausgabe
    if ($format eq "table") {
        print_table(\@nodes_status);
    } else {
        print_json(\@nodes_status);
    }

    # Speichern
    if ($save_file) {
        my $output = {
            timestamp => localtime->iso8601,
            nodes => { map { $_->{id} => $_ } @nodes_status }
        };

        open(my $fh, '>', $save_file) or die "Could not open file '$save_file' $!";
        print $fh JSON->new->pretty->encode($output);
        close $fh;

        say "\n💾 Gespeichert: $save_file";
    }

    # Zusammenfassung
    my $online_count = grep { $_->{online} } @nodes_status;
    say "\n📊 Zusammenfassung: $online_count/" . scalar(@nodes_status) . " Nodes online";
}

main();

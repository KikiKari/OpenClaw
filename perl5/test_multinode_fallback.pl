#!/usr/bin/perl
# test_multinode_fallback.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:scripts/test_multinode_fallback.py
# auch in: OpenClaw@gateway2:scripts/test_multinode_fallback.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use File::Spec;
use File::Basename;
use Cwd 'abs_path';

=head1 NAME

test_multinode_fallback.pl - Testet Multi-Node Fallback-Logik des db-maintainer

=head1 DESCRIPTION

Simuliert: Worker-Node nicht erreichbar → Fallback auf lokal

=cut

my $WORKSPACE = "/home/openclaw/.openclaw/workspace";

sub check_node_reachable {
    my ($node_id) = @_;
    
    # Prüft ob Node erreichbar ist
    eval {
        # Versuche Node-Status abzufragen
        my @cmd = ('openclaw', 'nodes', 'status');
        my $output = `@cmd`;
        my $exit_code = $? >> 8;
        
        if ($exit_code == 0 && $output =~ /\Q$node_id\E/ && $output =~ /connected/) {
            return 1;
        }
    };
    
    return 0;
}

sub spawn_on_node {
    my ($node_id, $task) = @_;
    
    # Versucht Task auf Node auszuführen
    print "Versuche Task auf Node $node_id zu starten...\n";
    
    eval {
        # Simuliert: openclaw agent spawn --node {node_id}
        my @cmd = ('echo', "Spawned on $node_id: $task");
        my $output = `@cmd`;
        my $exit_code = $? >> 8;
        
        if ($exit_code == 0) {
            print "✅ Erfolgreich delegiert an $node_id\n";
            return 1;
        } else {
            die "Exit code $exit_code";
        }
    };
    
    if ($@) {
        my $error = $@;
        chomp $error;
        print "❌ Node $node_id nicht erreichbar: $error\n";
        return 0;
    }
}

sub execute_locally {
    my ($task) = @_;
    
    # Führt Task lokal aus (Fallback)
    print "🔄 Fallback: Führe Task lokal aus...\n";
    
    eval {
        if ($task eq 'db_maintainer') {
            my $script_path = File::Spec->catfile($WORKSPACE, 'skills', 'db-maintainer', 'scripts', 'db_maintainer.py');
            my @cmd = ('python3', $script_path);
            my $output = `@cmd 2>&1`;
            my $exit_code = $? >> 8;
            
            if ($exit_code == 0) {
                print "✅ Lokale Ausführung erfolgreich\n";
                return 1;
            } else {
                my $stderr_short = substr($output, 0, 200);
                print "❌ Fehler: $stderr_short\n";
                return 0;
            }
        }
    };
    
    if ($@) {
        my $error = $@;
        chomp $error;
        print "❌ Lokale Ausführung fehlgeschlagen: $error\n";
        return 0;
    }
}

sub main {
    print "=" x 60 . "\n";
    print "MULTI-NODE FALLBACK TEST\n";
    print "=" x 60 . "\n";
    print "\n";
    
    # Konfiguration
    my $primary_node = 'v2202603104722445775';  # Node 2
    my $task = 'db_maintainer';
    
    print "Primärer Node: $primary_node\n";
    print "Task: $task\n";
    print "\n";
    
    # 1. Prüfe Node-Erreichbarkeit
    print "--- 1. Prüfe Node-Erreichbarkeit ---\n";
    if (check_node_reachable($primary_node)) {
        print "✅ Node $primary_node ist erreichbar\n";
        
        # 2. Versuche Delegation
        print "\n--- 2. Versuche Delegation ---\n";
        if (spawn_on_node($primary_node, $task)) {
            print "\n✅ MULTI-NODE: Task erfolgreich delegiert\n";
            return 0;
        } else {
            print "\n⚠️ Delegation fehlgeschlagen, aktiviere Fallback...\n";
        }
    } else {
        print "❌ Node $primary_node nicht erreichbar\n";
        print "🔄 Fallback wird aktiviert...\n";
    }
    
    # 3. Lokale Ausführung (Fallback)
    print "\n--- 3. Lokale Ausführung (Fallback) ---\n";
    if (execute_locally($task)) {
        print "\n✅ FALLBACK: Task lokal erfolgreich ausgeführt\n";
        return 0;
    } else {
        print "\n❌ FEHLER: Weder Delegation noch Fallback erfolgreich\n";
        return 1;
    }
}

exit(main());

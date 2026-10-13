#!/usr/bin/perl
# tree_indexer_v2.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:scripts/tree_indexer_v2.py
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use DBI;
use File::Find;
use File::Spec;
use Digest::MD5 qw(md5_hex);
use POSIX qw(strftime);
use JSON;

# Konfiguration
my $WORKSPACE = "/home/openclaw/.openclaw/workspace";
my $DB_DIR = "$WORKSPACE/db";

# Erstelle DB Verzeichnis falls nicht vorhanden
mkdir $DB_DIR unless -d $DB_DIR;

package TreeIndexerV2;

sub new {
    my $class = shift;
    my $self = {
        db_path => "$DB_DIR/tree.db",
        dbh     => undef,
    };
    bless $self, $class;
    return $self;
}

sub connect {
    my $self = shift;
    $self->{dbh} = DBI->connect("dbi:SQLite:dbname=$self->{db_path}", "", "", {
        RaiseError => 1,
        AutoCommit => 0,
    }) or die "Kann keine Verbindung zur Datenbank herstellen: $DBI::errstr";
    return $self->{dbh};
}

sub init_schema_v2 {
    my $self = shift;
    my $dbh = $self->connect();
    
    # Haupttabelle mit erweiterten Metadaten
    $dbh->do(qq{
        CREATE TABLE IF NOT EXISTS tree_entries_v2 (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_id TEXT UNIQUE,
            root_path TEXT NOT NULL,
            relative_path TEXT NOT NULL,
            name TEXT NOT NULL,
            type TEXT CHECK(type IN ('file', 'directory', 'symlink')),
            depth INTEGER,
            parent_path TEXT,
            
            size_bytes INTEGER,
            previous_size_bytes INTEGER,
            size_change_bytes INTEGER,
            
            mtime_timestamp REAL,
            mtime_iso TEXT,
            first_seen_timestamp REAL,
            last_seen_timestamp REAL,
            
            change_type TEXT CHECK(change_type IN ('NEW', 'MODIFIED', 'MOVED', 'RENAMED', 'UNCHANGED', 'DELETED')),
            
            original_name TEXT,
            original_path TEXT,
            previous_path TEXT,
            
            content_hash TEXT,
            
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    });
    
    # Historie-Tabelle für alle Änderungen
    $dbh->do(qq{
        CREATE TABLE IF NOT EXISTS file_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_id TEXT NOT NULL,
            timestamp REAL NOT NULL,
            change_type TEXT NOT NULL,
            old_path TEXT,
            new_path TEXT,
            old_size INTEGER,
            new_size INTEGER,
            FOREIGN KEY (file_id) REFERENCES tree_entries_v2(file_id)
        )
    });
    
    # Index für schnelle Suchen
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_file_id ON tree_entries_v2(file_id)");
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_path ON tree_entries_v2(relative_path)");
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_mtime ON tree_entries_v2(mtime_timestamp)");
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_change_type ON tree_entries_v2(change_type)");
    
    $dbh->commit();
    print "✅ tree.db Schema v2 erstellt/aktualisiert\n";
    return $self;
}

sub get_file_metadata {
    my ($self, $full_path) = @_;
    if (-e $full_path) {
        my @stat = stat($full_path);
        my $mtime_iso = strftime("%Y-%m-%dT%H:%M:%S", localtime($stat[9]));
        return {
            size       => $stat[7],
            mtime      => $stat[9],
            mtime_iso  => $mtime_iso,
        };
    } else {
        return { size => 0, mtime => 0, mtime_iso => undef };
    }
}

sub generate_file_id {
    my ($self, $relative_path) = @_;
    my $digest = md5_hex($relative_path);
    return substr($digest, 0, 16);
}

sub scan_directory_detailed {
    my ($self, $root_path, $max_depth) = @_;
    $max_depth //= 8;
    
    my @entries;
    my %seen;
    
    find(sub {
        # Verhindere Endlosschleifen und doppeltes Scannen
        return if $seen{$File::Find::name}++;
        
        my $rel_path = File::Spec->abs2rel($File::Find::name, $root_path);
        my @parts = split('/', $rel_path);
        
        # Max depth prüfen
        return if scalar(@parts) > $max_depth;
        
        my $file_id = $self->generate_file_id($rel_path);
        my $metadata = $self->get_file_metadata($File::Find::name);
        
        my $entry = {
            file_id              => $file_id,
            root_path            => $root_path,
            relative_path        => $rel_path,
            name                 => $_,
            type                 => (-d $_) ? 'directory' : ((-l $_) ? 'symlink' : 'file'),
            depth                => scalar(@parts),
            parent_path          => ($rel_path =~ m|/|) ? $` : '',
            size_bytes           => $metadata->{size},
            mtime_timestamp      => $metadata->{mtime},
            mtime_iso            => $metadata->{mtime_iso},
        };
        push @entries, $entry;
    }, $root_path);
    
    return \@entries;
}

sub update_database {
    my ($self, $entries) = @_;
    my $dbh = $self->connect();
    
    # Aktuelle Zeit
    my $now = time();
    
    # Alle bestehenden Einträge als "potentiell gelöscht" markieren
    $dbh->do("UPDATE tree_entries_v2 SET change_type = NULL");
    
    my %stats = ( new => 0, modified => 0, unchanged => 0, moved => 0 );
    
    foreach my $entry (@$entries) {
        # Prüfe ob Datei bereits bekannt
        my $sth_select = $dbh->prepare("SELECT * FROM tree_entries_v2 WHERE file_id = ?");
        $sth_select->execute($entry->{file_id});
        my $existing = $sth_select->fetchrow_hashref();
        
        if ($existing) {
            # Vergleiche Metadaten
            my $old_mtime = $existing->{mtime_timestamp} || 0;
            my $old_size = $existing->{size_bytes} || 0;
            my $old_path = $existing->{relative_path};
            
            # Größenänderung berechnen
            my $size_change = $entry->{size_bytes} - $old_size;
            
            # Änderungstyp bestimmen
            my $change_type;
            if ($old_path ne $entry->{relative_path}) {
                $change_type = 'MOVED';
                $stats{moved}++;
            } elsif ($old_mtime != $entry->{mtime_timestamp} || $old_size != $entry->{size_bytes}) {
                $change_type = 'MODIFIED';
                $stats{modified}++;
            } else {
                $change_type = 'UNCHANGED';
                $stats{unchanged}++;
            }
            
            # Update
            my $sth_update = $dbh->prepare(qq{
                UPDATE tree_entries_v2 SET
                    size_bytes = ?,
                    previous_size_bytes = ?,
                    size_change_bytes = ?,
                    mtime_timestamp = ?,
                    mtime_iso = ?,
                    last_seen_timestamp = ?,
                    change_type = ?,
                    previous_path = ?,
                    original_path = COALESCE(original_path, ?),
                    updated_at = CURRENT_TIMESTAMP
                WHERE file_id = ?
            });
            $sth_update->execute(
                $entry->{size_bytes},
                $old_size,
                $size_change,
                $entry->{mtime_timestamp},
                $entry->{mtime_iso},
                $now,
                $change_type,
                ($change_type eq 'MOVED') ? $old_path : undef,
                ($change_type eq 'MOVED') ? $old_path : $existing->{original_path},
                $entry->{file_id}
            );
            
            # Änderung in Historie loggen
            if ($change_type eq 'MODIFIED' || $change_type eq 'MOVED') {
                my $sth_hist = $dbh->prepare(qq{
                    INSERT INTO file_history
                    (file_id, timestamp, change_type, old_path, new_path, old_size, new_size)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                });
                $sth_hist->execute(
                    $entry->{file_id},
                    $now,
                    $change_type,
                    $old_path,
                    $entry->{relative_path},
                    $old_size,
                    $entry->{size_bytes}
                );
            }
        } else {
            # Neue Datei
            $stats{new}++;
            my $sth_insert = $dbh->prepare(qq{
                INSERT INTO tree_entries_v2
                (file_id, root_path, relative_path, name, type, depth, parent_path,
                 size_bytes, previous_size_bytes, size_change_bytes,
                 mtime_timestamp, mtime_iso, first_seen_timestamp, last_seen_timestamp,
                 change_type, content_hash)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            });
            $sth_insert->execute(
                $entry->{file_id},
                $entry->{root_path},
                $entry->{relative_path},
                $entry->{name},
                $entry->{type},
                $entry->{depth},
                $entry->{parent_path},
                $entry->{size_bytes},
                $entry->{size_bytes},
                0,
                $entry->{mtime_timestamp},
                $entry->{mtime_iso},
                $now,
                $now,
                'NEW',
                undef  # content_hash
            );
        }
    }
    
    # Markiere nicht aktualisierte Einträge als DELETED
    my $sth_deleted = $dbh->prepare(qq{
        SELECT * FROM tree_entries_v2 
        WHERE change_type IS NULL OR last_seen_timestamp < ?
    });
    $sth_deleted->execute($now - 3600); # Älter als 1 Stunde
    
    my $deleted_count = 0;
    while (my $item = $sth_deleted->fetchrow_hashref()) {
        my $sth_upd = $dbh->prepare(qq{
            UPDATE tree_entries_v2 
            SET change_type = 'DELETED', updated_at = CURRENT_TIMESTAMP
            WHERE file_id = ?
        });
        $sth_upd->execute($item->{file_id});
        $deleted_count++;
    }
    $stats{deleted} = $deleted_count;
    
    $dbh->commit();
    return \%stats;
}

sub export_changes {
    my ($self, $since_hours) = @_;
    $since_hours //= 24;
    
    my $dbh = $self->connect();
    my $since = time() - ($since_hours * 3600);
    
    my $sth = $dbh->prepare(qq{
        SELECT * FROM tree_entries_v2 
        WHERE change_type IN ('NEW', 'MODIFIED', 'MOVED', 'DELETED')
        AND last_seen_timestamp > ?
        ORDER BY last_seen_timestamp DESC
    });
    $sth->execute($since);
    
    my @changes;
    while (my $row = $sth->fetchrow_hashref()) {
        push @changes, $row;
    }
    
    # Export als JSON
    my $export_file = "$WORKSPACE/tree_changes_last_${since_hours}h.json";
    open(my $fh, '>', $export_file) or die "Kann Datei $export_file nicht öffnen: $!";
    print $fh to_json(\@changes, { pretty => 1 });
    close $fh;
    
    print "✅ Änderungen exportiert: $export_file (" . scalar(@changes) . " Einträge)\n";
    return $export_file;
}

package main;

print "=" x 60 . "\n";
print "TREE INDEXER v2 - Erweitertes Tracking\n";
print "=" x 60 . "\n";

my $indexer = TreeIndexerV2->new();
$indexer->init_schema_v2();

print "\n--- Scanning Workspace ---\n";
my $entries = $indexer->scan_directory_detailed('/home/openclaw/.openclaw/workspace/', 8);
print "Gefunden: " . scalar(@$entries) . " Einträge\n";

print "\n--- Aktualisiere Datenbank ---\n";
my $stats = $indexer->update_database($entries);
print "Statistiken:\n";
print "  NEU:        " . ($stats->{new} // 0) . "\n";
print "  MODIFIED:   " . ($stats->{modified} // 0) . "\n";
print "  MOVED:      " . ($stats->{moved} // 0) . "\n";
print "  UNCHANGED:  " . ($stats->{unchanged} // 0) . "\n";
print "  DELETED:    " . ($stats->{deleted} // 0) . "\n";

print "\n--- Exportiere Änderungen (24h) ---\n";
$indexer->export_changes(24);

print "\n" . "=" x 60 . "\n";
print "TREE INDEXING ABGESCHLOSSEN\n";
print "=" x 60 . "\n";

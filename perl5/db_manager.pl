#!/usr/bin/perl
# db_manager.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:scripts/db_manager.py
# auch in: OpenClaw@gateway1:abstraction-manager/db_manager.py
# auch in: OpenClaw@gateway2:scripts/db_manager.py
# auch in: OpenClaw@gateway2:abstraction-manager/db_manager.py
# auch in: 1 weiteren Fundstellen
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use File::Path qw(make_path);
use DBI;
use Text::CSV;
use JSON;
use Time::Piece;

# ---------------------------------------------------------------------------
# Konfiguration
# ---------------------------------------------------------------------------

my $WORKSPACE = $ENV{'OPENCLAW_WORKSPACE'} // '/home/openclaw/.openclaw/workspace';
my $DB_DIR = "$WORKSPACE/db";

# Erlaubte Tabellennamen für Export-Methoden (verhindert SQL-Injection)
my @_DOCS_EXPORT_TABLES = qw(documents categories symlinks skills);
my %_DOCS_EXPORT_TABLES = map { $_ => 1 } @_DOCS_EXPORT_TABLES;
my @_TREE_EXPORT_TABLES = qw(tree_entries tree_scans);
my %_TREE_EXPORT_TABLES = map { $_ => 1 } @_TREE_EXPORT_TABLES;

# ---------------------------------------------------------------------------
# Logger
# ---------------------------------------------------------------------------

sub log_message {
    my ($level, $msg) = @_;
    my $timestamp = localtime->strftime('%Y-%m-%d %H:%M:%S');
    printf "%s | %-8s | %s | %s\n", $timestamp, uc($level), 'db_manager', $msg;
}

sub info { log_message('info', @_); }
sub error { log_message('error', @_); }

# ---------------------------------------------------------------------------
# DocsDatabase
# ---------------------------------------------------------------------------

package DocsDatabase {
    sub new {
        my $class = shift;
        my $self = {
            db_path => "$DB_DIR/docs.db"
        };
        bless $self, $class;
        return $self;
    }

    sub _get_connection {
        my $self = shift;
        my $dbh = DBI->connect("dbi:SQLite:dbname=$self->{db_path}", "", "", { RaiseError => 1, AutoCommit => 0 });
        $dbh->{sqlite_allow_multiple_statements} = 1;
        return $dbh;
    }

    sub init_schema {
        my $self = shift;
        my $dbh = $self->_get_connection();
        
        eval {
            $dbh->do(<<'SQL');
CREATE TABLE IF NOT EXISTS documents (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT    NOT NULL,
    path        TEXT    NOT NULL,
    category    TEXT,
    description TEXT,
    type        TEXT    CHECK(type IN ('config', 'doc', 'guide', 'script', 'symlink')),
    has_symlink BOOLEAN DEFAULT FALSE,
    symlink_path TEXT,
    last_update TEXT,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
SQL
            
            $dbh->do(<<'SQL');
CREATE TABLE IF NOT EXISTS categories (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT    UNIQUE NOT NULL,
    description TEXT,
    priority    INTEGER DEFAULT 0
)
SQL
            
            $dbh->do(<<'SQL');
CREATE TABLE IF NOT EXISTS symlinks (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT    NOT NULL,
    target      TEXT    NOT NULL,
    source_path TEXT    NOT NULL,
    description TEXT,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
SQL
            
            $dbh->do(<<'SQL');
CREATE TABLE IF NOT EXISTS skills (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT    NOT NULL,
    version     TEXT,
    status      TEXT    CHECK(status IN ('installed', 'local', 'published')),
    description TEXT,
    path        TEXT
)
SQL
            
            $dbh->commit();
        };
        if ($@) {
            $dbh->rollback();
            die "Fehler bei Schema-Erstellung: $@";
        }
        $dbh->disconnect();
        
        info("docs.db Schema initialisiert: $self->{db_path}");
        return $self;
    }

    sub populate_from_workspace {
        my $self = shift;
        
        my @categories = (
            ['main',      'Hauptverzeichnis Dateien',        1],
            ['memory',    'Memory und Protokolle',           2],
            ['reports',   'Berichte und Analysen',           3],
            ['cluster',   'Cluster und Infrastruktur',       4],
            ['skills',    'Installierte Skills',             5],
            ['websearch', 'WebSearch Dokumentationen',       6],
            ['mcp',       'MCP Integration',                 7],
            ['links',     'Symbolische Links',               8],
        );
        
        my @docs = (
            ['AGENTS.md',             '/', 'main', 'Agent-Konfiguration, Memory-Regeln',      'config',  0, undef,                          '2026-04-11'],
            ['SOUL.md',               '/', 'main', 'Agent-Persönlichkeit und Kernwahrheiten', 'config',  0, undef,                          '2026-04-11'],
            ['IDENTITY.md',           '/', 'main', 'Agent-Name und Eigenschaften',            'config',  0, undef,                          '2026-04-11'],
            ['USER.md',               '/', 'main', 'Benutzerinformationen',                   'config',  0, undef,                          '2026-04-11'],
            ['TOOLS.md',              '/', 'main', 'Tool-spezifische Konfigurationen',        'config',  0, undef,                          '2026-04-18'],
            ['MEMORY.md',             '/', 'main', 'Langzeitspeicher, System-Konfiguration',  'config',  0, undef,                          '2026-04-11'],
            ['DOCUMENTATION-INDEX.md','/', 'main', 'Übersicht aller Dokumentationen',         'doc',     0, undef,                          '2026-04-18'],
            ['WORKSPACE-INDEX.md',    '/', 'main', 'Symlink zu DOCUMENTATION-INDEX.md',       'symlink', 1,  'DOCUMENTATION-INDEX.md',      '2026-04-18'],
            ['WEBSEARCH_README.md',        'websearch/', 'websearch', 'Schnellstart Guide',                    'guide',  1, 'websearch/WEBSEARCH_README.md',          '2026-04-18'],
            ['WEBSEARCH_MCP_GUIDE.md',     'websearch/', 'websearch', 'Vollständige technische Dokumentation', 'guide',  1, 'websearch/WEBSEARCH_MCP_GUIDE.md',       '2026-04-18'],
            ['WEBSEARCH_CONFIG.md',        'websearch/', 'websearch', 'Konfigurations-Referenz',               'config', 1, 'websearch/WEBSEARCH_CONFIG.md',          '2026-04-18'],
            ['WEBSEARCH_PRIORITY_CONFIG.md','websearch/','websearch', 'Provider-Priorität',                    'config', 1, 'websearch/WEBSEARCH_PRIORITY_CONFIG.md', '2026-04-18'],
            ['WEBSEARCH_SCRIPTS.md',       'websearch/', 'websearch', 'Automation & Scripting',                'script', 1, 'websearch/WEBSEARCH_SCRIPTS.md',         '2026-04-18'],
            ['WEBSEARCH_OPS.md',           'websearch/', 'websearch', 'IT-Operations',                         'guide',  1, 'websearch/WEBSEARCH_OPS.md',             '2026-04-18'],
            ['MCP_GUIDE.md',               'mcp/',       'mcp',       'Symlink zu websearch/WEBSEARCH_MCP_GUIDE.md','symlink',0,'websearch/WEBSEARCH_MCP_GUIDE.md',  '2026-04-18'],
        );
        
        my @skills = (
            ['json-utils',          '1.0.0', 'installed', 'JSON parsing and validation',      'skills/json-utils/'],
            ['scripting-utils',     '1.0.0', 'installed', 'Multi-language scripting support', 'skills/scripting-utils/'],
            ['tiktok-live-mon',     '1.0.0', 'installed', 'TikTok stream monitoring',         'skills/tiktok-live-mon/'],
            ['cluster-management',  '1.0.0', 'installed', 'Cluster topology management',      'skills/cluster-management/'],
            ['worker-node',         '-',     'local',     'Worker node configuration',        'skills/worker-node/'],
            ['resource-manager',    '-',     'local',     'Resource management',              'skills/resource-manager/'],
            ['git-publish-agent',   '1.0.0', 'local',     'Git publishing automation',        'skills/git-publish-agent/'],
        );
        
        my @symlinks = (
            ['openclaw.env',               '/home/openclaw/.config/openclaw/env',  '/',             'API-Keys Shortcut'],
            ['openclaw.json',              '/home/openclaw/.openclaw/openclaw.json','/',             'Konfig Shortcut'],
            ['links/config/openclaw-env',  '/home/openclaw/.config/openclaw/env',  'links/config/', 'API-Keys'],
            ['links/dotfiles/.tavily',     '/home/openclaw/.tavily/',              'links/dotfiles/','Tavily Config'],
            ['links/dotfiles/.claude',     '/home/openclaw/.claude/',              'links/dotfiles/','Claude Config'],
            ['links/dotfiles/.mcporter',   '/home/openclaw/.mcporter/',            'links/dotfiles/','MCPorter Config'],
            ['links/dotfiles/.ssh',        '/home/openclaw/.ssh/',                 'links/dotfiles/','SSH Keys'],
        );
        
        my $dbh = $self->_get_connection();
        eval {
            my $sth = $dbh->prepare("INSERT OR IGNORE INTO categories (name, description, priority) VALUES (?,?,?)");
            for my $cat (@categories) {
                $sth->execute(@$cat);
            }
            
            $sth = $dbh->prepare(<<'SQL');
INSERT OR REPLACE INTO documents
(name, path, category, description, type, has_symlink, symlink_path, last_update)
VALUES (?,?,?,?,?,?,?,?)
SQL
            for my $doc (@docs) {
                $sth->execute(@$doc);
            }
            
            $sth = $dbh->prepare("INSERT OR REPLACE INTO skills (name, version, status, description, path) VALUES (?,?,?,?,?)");
            for my $skill (@skills) {
                $sth->execute(@$skill);
            }
            
            $sth = $dbh->prepare("INSERT OR REPLACE INTO symlinks (name, target, source_path, description) VALUES (?,?,?,?)");
            for my $link (@symlinks) {
                $sth->execute(@$link);
            }
            
            $dbh->commit();
        };
        if ($@) {
            $dbh->rollback();
            die "Fehler beim Befüllen der Datenbank: $@";
        }
        $dbh->disconnect();
        
        info(sprintf("docs.db befüllt: %d Dokumente, %d Skills, %d Symlinks", scalar(@docs), scalar(@skills), scalar(@symlinks)));
        return $self;
    }

    sub _validate_table_name {
        my ($self, $table, $allowed_ref) = @_;
        my %allowed = %$allowed_ref;
        if (!exists $allowed{$table}) {
            die "Ungültiger Tabellenname: '$table'. Erlaubt: " . join(', ', sort keys %allowed);
        }
    }

    sub export_csv {
        my ($self, $table) = @_;
        $self->_validate_table_name($table, \%_DOCS_EXPORT_TABLES);
        
        my $dbh = $self->_get_connection();
        my $sth = $dbh->prepare("SELECT * FROM $table");
        $sth->execute();
        my $rows = $sth->fetchall_arrayref({});
        $dbh->disconnect();
        
        if (!@$rows) {
            info("Tabelle '$table' ist leer — kein CSV erzeugt");
            return undef;
        }
        
        my @column_names = @{$sth->{NAME}};
        my $csv_path = "$WORKSPACE/export_${table}.csv";
        
        open(my $fh, '>:encoding(utf8)', $csv_path) or die "Kann $csv_path nicht öffnen: $!";
        my $csv = Text::CSV->new({ binary => 1 });
        $csv->say($fh, \@column_names);
        for my $row (@$rows) {
            my @values = map { $row->{$_} } @column_names;
            $csv->say($fh, \@values);
        }
        close($fh);
        
        info("CSV exportiert: $csv_path (" . scalar(@$rows) . " Zeilen)");
        return $csv_path;
    }

    sub export_json {
        my ($self, $table) = @_;
        $self->_validate_table_name($table, \%_DOCS_EXPORT_TABLES);
        
        my $dbh = $self->_get_connection();
        my $sth = $dbh->prepare("SELECT * FROM $table");
        $sth->execute();
        my $rows = $sth->fetchall_arrayref({});
        $dbh->disconnect();
        
        if (!@$rows) {
            info("Tabelle '$table' ist leer — kein JSON erzeugt");
            return undef;
        }
        
        my $json_path = "$WORKSPACE/export_${table}.json";
        open(my $fh, '>:encoding(utf8)', $json_path) or die "Kann $json_path nicht öffnen: $!";
        print $fh to_json($rows, { pretty => 1, utf8 => 1 });
        close($fh);
        
        info("JSON exportiert: $json_path (" . scalar(@$rows) . " Einträge)");
        return $json_path;
    }
}

# ---------------------------------------------------------------------------
# TreeDatabase
# ---------------------------------------------------------------------------

package TreeDatabase {
    sub new {
        my $class = shift;
        my $self = {
            db_path => "$DB_DIR/tree.db"
        };
        bless $self, $class;
        return $self;
    }

    sub _get_connection {
        my $self = shift;
        my $dbh = DBI->connect("dbi:SQLite:dbname=$self->{db_path}", "", "", { RaiseError => 1, AutoCommit => 0 });
        $dbh->{sqlite_allow_multiple_statements} = 1;
        return $dbh;
    }

    sub init_schema {
        my $self = shift;
        my $dbh = $self->_get_connection();
        
        eval {
            $dbh->do(<<'SQL');
CREATE TABLE IF NOT EXISTS tree_entries (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    root_path     TEXT    NOT NULL,
    relative_path TEXT    NOT NULL,
    name          TEXT    NOT NULL,
    type          TEXT    CHECK(type IN ('file', 'directory', 'symlink')),
    depth         INTEGER,
    parent_path   TEXT,
    size          INTEGER,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
SQL
            
            $dbh->do(<<'SQL');
CREATE TABLE IF NOT EXISTS tree_scans (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    root_path      TEXT    NOT NULL,
    max_depth      INTEGER,
    total_files    INTEGER,
    total_dirs     INTEGER,
    total_symlinks INTEGER,
    scanned_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
SQL
            
            $dbh->commit();
        };
        if ($@) {
            $dbh->rollback();
            die "Fehler bei Schema-Erstellung: $@";
        }
        $dbh->disconnect();
        
        info("tree.db Schema initialisiert: $self->{db_path}");
        return $self;
    }

    sub add_entry {
        my ($self, $root_path, $relative_path, $name, $entry_type, $depth, $parent_path, $size) = @_;
        $size //= 0;
        
        my $dbh = $self->_get_connection();
        eval {
            my $sth = $dbh->prepare(<<'SQL');
INSERT INTO tree_entries
(root_path, relative_path, name, type, depth, parent_path, size)
VALUES (?,?,?,?,?,?,?)
SQL
            $sth->execute($root_path, $relative_path, $name, $entry_type, $depth, $parent_path, $size);
            $dbh->commit();
        };
        if ($@) {
            $dbh->rollback();
            die "Fehler beim Hinzufügen des Eintrags: $@";
        }
        $dbh->disconnect();
    }

    sub export_csv {
        my ($self, $root_path_filter) = @_;
        
        my $dbh = $self->_get_connection();
        my ($sth, $rows);
        if (defined $root_path_filter) {
            $sth = $dbh->prepare("SELECT * FROM tree_entries WHERE root_path = ?");
            $sth->execute($root_path_filter);
        } else {
            $sth = $dbh->prepare("SELECT * FROM tree_entries");
            $sth->execute();
        }
        $rows = $sth->fetchall_arrayref({});
        $dbh->disconnect();
        
        if (!@$rows) {
            info("Keine Tree-Einträge vorhanden — kein CSV erzeugt");
            return undef;
        }
        
        my @column_names = @{$sth->{NAME}};
        my $suffix = defined $root_path_filter ? "_" . ($root_path_filter =~ s|/|_|gr) : "_all";
        my $csv_path = "$WORKSPACE/export_tree${suffix}.csv";
        
        open(my $fh, '>:encoding(utf8)', $csv_path) or die "Kann $csv_path nicht öffnen: $!";
        my $csv = Text::CSV->new({ binary => 1 });
        $csv->say($fh, \@column_names);
        for my $row (@$rows) {
            my @values = map { $row->{$_} } @column_names;
            $csv->say($fh, \@values);
        }
        close($fh);
        
        info("Tree-CSV exportiert: $csv_path (" . scalar(@$rows) . " Einträge)");
        return $csv_path;
    }
}

# ---------------------------------------------------------------------------
# Einstiegspunkt
# ---------------------------------------------------------------------------

sub main {
    print "=" x 60 . "\n";
    print "WORKSPACE DATABASE MANAGER\n";
    print "=" x 60 . "\n";
    
    # DB-Verzeichnis hier (nicht auf Modulebene) anlegen
    eval {
        make_path($DB_DIR, { verbose => 0 });
        info("DB-Verzeichnis: $DB_DIR");
    };
    if ($@) {
        error("DB-Verzeichnis konnte nicht erstellt werden: $@");
        exit 1;
    }
    
    # docs.db aufbauen
    my $docs_db = DocsDatabase->new();
    $docs_db->init_schema();
    $docs_db->populate_from_workspace();
    
    # Exporte
    print "\n--- Exporte docs.db ---\n";
    for my $table (qw(documents skills symlinks)) {
        $docs_db->export_csv($table);
    }
    $docs_db->export_json('documents');
    
    # tree.db aufbauen (Daten kommen via tree.py)
    print "\n--- tree.db Initialisierung ---\n";
    my $tree_db = TreeDatabase->new();
    $tree_db->init_schema();
    info("Tree-Daten werden via tree.py Script befüllt");
    
    print "\n" . "=" x 60 . "\n";
    print "DATENBANKEN BEREIT\n";
    print "=" x 60 . "\n";
    print "\nDatenbanken: $DB_DIR/\n";
    print "Exporte:     $WORKSPACE/\n";
}

main() unless caller;

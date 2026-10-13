#!/usr/bin/perl
# update_docs_db.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:scripts/update_docs_db.py
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use DBI;
use File::Find;
use File::Spec;
use JSON;
use Text::CSV;
use POSIX qw(strftime);

=head1 NAME

update_docs_db.pl - Scannt alle vorhandenen Dokumentationen und aktualisiert docs.db

=cut

my $WORKSPACE = "/home/openclaw/.openclaw/workspace";
my $DB_PATH = "$WORKSPACE/db/docs.db";

sub scan_documentations {
    my @docs = ();

    # Hauptverzeichnis
    opendir(my $dh, $WORKSPACE) or die "Kann $WORKSPACE nicht öffnen: $!";
    while (readdir $dh) {
        my $file = $_;
        next unless $file =~ /\.md$/;
        my $full_path = "$WORKSPACE/$file";
        if (-f $full_path && !-l $full_path) {
            push @docs, {
                name => $file,
                path => '/',
                category => 'main',
                description => get_description($full_path),
                type => 'doc',
                has_symlink => 0,
                symlink_path => undef,
                last_update => get_mtime($full_path)
            };
        }
    }
    closedir $dh;

    # WebSearch Verzeichnis
    my $websearch_dir = "$WORKSPACE/websearch";
    if (-d $websearch_dir) {
        opendir(my $dh, $websearch_dir) or die "Kann $websearch_dir nicht öffnen: $!";
        while (readdir $dh) {
            my $file = $_;
            next unless $file =~ /\.md$/;
            my $full_path = "$websearch_dir/$file";
            push @docs, {
                name => $file,
                path => 'websearch/',
                category => 'websearch',
                description => get_description($full_path),
                type => ($file =~ /GUIDE/) ? 'guide' : 'config',
                has_symlink => 1,
                symlink_path => "websearch/$file",
                last_update => get_mtime($full_path)
            };
        }
        closedir $dh;
    }

    # MCP Verzeichnis
    my $mcp_dir = "$WORKSPACE/mcp";
    if (-d $mcp_dir) {
        opendir(my $dh, $mcp_dir) or die "Kann $mcp_dir nicht öffnen: $!";
        while (readdir $dh) {
            my $file = $_;
            next unless $file =~ /\.md$/;
            my $full_path = "$mcp_dir/$file";
            my $is_symlink = -l $full_path;
            my $symlink_path = $is_symlink ? readlink($full_path) : undef;
            push @docs, {
                name => $file,
                path => 'mcp/',
                category => 'mcp',
                description => get_description($full_path),
                type => $is_symlink ? 'symlink' : 'guide',
                has_symlink => $is_symlink,
                symlink_path => $symlink_path,
                last_update => get_mtime($full_path)
            };
        }
        closedir $dh;
    }

    # Docs-Unterverzeichnisse
    my $docs_dir = "$WORKSPACE/docs";
    if (-d $docs_dir) {
        opendir(my $dh, $docs_dir) or die "Kann $docs_dir nicht öffnen: $!";
        while (readdir $dh) {
            my $subdir = $_;
            next if $subdir =~ /^\.\.?$/;
            my $subdir_path = "$docs_dir/$subdir";
            if (-d $subdir_path) {
                opendir(my $sdh, $subdir_path) or die "Kann $subdir_path nicht öffnen: $!";
                while (readdir $sdh) {
                    my $file = $_;
                    next unless $file =~ /\.md$/;
                    my $full_path = "$subdir_path/$file";
                    push @docs, {
                        name => $file,
                        path => "docs/$subdir/",
                        category => $subdir,
                        description => get_description($full_path),
                        type => 'doc',
                        has_symlink => 0,
                        symlink_path => undef,
                        last_update => get_mtime($full_path)
                    };
                }
                closedir $sdh;
            }
        }
        closedir $dh;
    }

    # Cluster, Memory, Reports, Skills
    foreach my $category (qw(cluster memory reports skills)) {
        my $cat_dir = "$WORKSPACE/$category";
        if (-d $cat_dir) {
            opendir(my $dh, $cat_dir) or die "Kann $cat_dir nicht öffnen: $!";
            while (readdir $dh) {
                my $file = $_;
                next unless $file =~ /\.md$/;
                my $full_path = "$cat_dir/$file";
                push @docs, {
                    name => $file,
                    path => "$category/",
                    category => $category,
                    description => get_description($full_path),
                    type => 'doc',
                    has_symlink => 0,
                    symlink_path => undef,
                    last_update => get_mtime($full_path)
                };
            }
            closedir $dh;
        }
    }

    return \@docs;
}

sub get_description {
    my ($md_file) = @_;
    open(my $fh, '<', $md_file) or return 'Dokumentation';
    my $first_line = <$fh>;
    close($fh);
    chomp($first_line);
    $first_line =~ s/^\s+|\s+$//g;
    if ($first_line =~ /^#(.*)/) {
        my $desc = $1;
        $desc =~ s/^\s+|\s+$//g;
        return $desc;
    }
    if (length($first_line) > 50) {
        return substr($first_line, 0, 50) . '...';
    }
    return $first_line;
}

sub get_mtime {
    my ($file) = @_;
    my @stat = stat($file);
    if (@stat) {
        my $mtime = $stat[9];
        return strftime('%Y-%m-%d', localtime($mtime));
    }
    return '2026-04-18';
}

sub update_database {
    my ($docs) = @_;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$DB_PATH", "", "",
                           { RaiseError => 1, AutoCommit => 0 }) or die $DBI::errstr;

    # Lösche alte Einträge (außer config)
    $dbh->do("DELETE FROM documents WHERE category != 'config'");

    # Füge neue ein
    my $inserted = 0;
    my $sth = $dbh->prepare(qq{
        INSERT INTO documents 
        (name, path, category, description, type, has_symlink, symlink_path, last_update)
        VALUES (?,?,?,?,?,?,?,?)
    });

    foreach my $doc (@$docs) {
        $sth->execute(
            $doc->{name}, $doc->{path}, $doc->{category},
            $doc->{description}, $doc->{type}, $doc->{has_symlink} ? 1 : 0,
            $doc->{symlink_path}, $doc->{last_update}
        );
        $inserted++;
    }

    $dbh->commit();
    $dbh->disconnect();

    return $inserted;
}

sub export_all {
    my $dbh = DBI->connect("dbi:SQLite:dbname=$DB_PATH", "", "",
                           { RaiseError => 1, AutoCommit => 1 }) or die $DBI::errstr;

    # JSON & CSV Export
    my @tables = qw(documents skills symlinks);
    foreach my $table (@tables) {
        my $sth = $dbh->prepare("SELECT * FROM $table");
        $sth->execute();

        my $rows = $sth->fetchall_arrayref({});
        my @column_names = @{$sth->{NAME_lc}};

        # JSON Export
        my $json_text = encode_json($rows);
        my $json_path = "$WORKSPACE/db_${table}.json";
        open(my $json_fh, '>', $json_path) or die "Kann $json_path nicht schreiben: $!";
        print $json_fh $json_text;
        close($json_fh);
        print "✅ $json_path\n";

        # CSV Export
        my $csv_path = "$WORKSPACE/db_${table}.csv";
        open(my $csv_fh, '>:encoding(utf8)', $csv_path) or die "Kann $csv_path nicht schreiben: $!";
        my $csv = Text::CSV->new({ binary => 1 });
        $csv->print($csv_fh, \@column_names);
        print $csv_fh "\n";
        foreach my $row (@$rows) {
            my @values = map { $row->{$_} } @column_names;
            $csv->print($csv_fh, \@values);
            print $csv_fh "\n";
        }
        close($csv_fh);
        print "✅ $csv_path\n";
    }

    $dbh->disconnect();
}

sub main {
    print "=" x 60 . "\n";
    print "DOCS.DB UPDATER\n";
    print "=" x 60 . "\n";

    print "\n--- Scanne Dokumentationen ---\n";
    my $docs = scan_documentations();
    print "Gefunden: " . scalar(@$docs) . " Dokumente\n";

    print "\n--- Aktualisiere docs.db ---\n";
    my $inserted = update_database($docs);
    print "✅ $inserted Dokumente in docs.db aktualisiert\n";

    print "\n--- Erstelle Exporte ---\n";
    export_all();

    print "\n" . "=" x 60 . "\n";
    print "DOCS.DB AKTUALISIERT\n";
    print "=" x 60 . "\n";
}

main() if __FILE__ eq $0;

#!/usr/bin/perl
# update_docs_db.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway2:scripts/update_docs_db.py
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);
use JSON qw(encode_json);
use Text::CSV;

my $WORKSPACE = '/workspace';
my $DB_PATH = "$WORKSPACE/db/docs.db";

sub iter_docs {
    my @docs;
    find(\&wanted, $WORKSPACE);

    sub wanted {
        my $file = $_;
        return unless -f $file && $file =~ /\.md$/;
        my $rel_path = $File::Find::name;
        $rel_path =~ s/^$WORKSPACE\/?//;
        return if $rel_path =~ m{(?:^|/)(?:node_modules|\.git|backups)(?:/|$)};
        push @docs, $File::Find::name;
    }

    return @docs;
}

sub file_hash {
    my ($path) = @_;
    open my $fh, '<:raw', $path or die "Cannot open $path: $!";
    my $ctx = Digest::MD5->new;
    while (read($fh, my $buffer, 8192)) {
        $ctx->add($buffer);
    }
    close $fh;
    return $ctx->hexdigest;
}

sub word_count {
    my ($path) = @_;
    open my $fh, '<:encoding(UTF-8)', $path or return 0;
    local $/;
    my $text = <$fh>;
    close $fh;
    my @words = split /\s+/, $text;
    return scalar @words;
}

sub build_rows {
    my @rows;
    my $indexed = time();
    for my $md_file (iter_docs()) {
        my $rel_path = $md_file;
        $rel_path =~ s/^$WORKSPACE\/?//;
        push @rows, {
            path         => $rel_path,
            content_hash => file_hash($md_file),
            last_indexed => $indexed,
            word_count   => word_count($md_file),
        };
    }
    return \@rows;
}

sub ensure_schema {
    my ($dbh) = @_;
    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS documents (
            path TEXT PRIMARY KEY,
            content_hash TEXT,
            last_indexed REAL,
            word_count INTEGER
        )
    });
    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            path TEXT,
            tag TEXT
        )
    });
}

sub update_database {
    my ($rows) = @_;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$DB_PATH", "", "", { RaiseError => 1 });
    ensure_schema($dbh);
    $dbh->do('DELETE FROM documents');
    my $sth = $dbh->prepare('INSERT INTO documents (path, content_hash, last_indexed, word_count) VALUES (?, ?, ?, ?)');
    for my $row (@$rows) {
        $sth->execute($row->{path}, $row->{content_hash}, $row->{last_indexed}, $row->{word_count});
    }
    $dbh->commit;
    $dbh->disconnect;
}

sub export_table {
    my ($table) = @_;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$DB_PATH", "", "", { RaiseError => 1, sqlite_unicode => 1 });
    $dbh->{sqlite_allow_multiple_statements} = 1;
    $dbh->{AutoCommit} = 1;
    my $rows = $dbh->selectall_arrayref("SELECT * FROM $table", { Slice => {} });
    my $json_data = encode_json($rows);
    open my $json_fh, '>:encoding(UTF-8)', "$WORKSPACE/db_${table}.json" or die "Cannot write to db_${table}.json: $!";
    print $json_fh $json_data;
    close $json_fh;

    open my $csv_fh, '>:encoding(UTF-8)', "$WORKSPACE/db_${table}.csv" or die "Cannot write to db_${table}.csv: $!";
    my $csv = Text::CSV->new({ binary => 1 });
    if (@$rows > 0) {
        my @headers = keys %{$rows->[0]};
        $csv->print($csv_fh, \@headers);
        print $csv_fh "\n";
        for my $row (@$rows) {
            my @values = map { $row->{$_} } @headers;
            $csv->print($csv_fh, \@values);
            print $csv_fh "\n";
        }
    } else {
        $csv->print($csv_fh, []);
        print $csv_fh "\n";
    }
    close $csv_fh;
    $dbh->disconnect;
}

sub main {
    print '=' x 60 . "\n";
    print "DOCS.DB UPDATER\n";
    print '=' x 60 . "\n";
    my $rows = build_rows();
    print "Gefunden: " . scalar(@$rows) . " Dokumente\n";
    update_database($rows);
    print "✅ " . scalar(@$rows) . " Dokumente in docs.db aktualisiert\n";
    export_table('documents');
    export_table('tags');
    print "✅ Exporte aktualisiert\n";
    print "\n" . '=' x 60 . "\n";
    print "DOCS.DB AKTUALISIERT\n";
    print '=' x 60 . "\n";
}

use File::Find;
use DBI;
main() unless caller;

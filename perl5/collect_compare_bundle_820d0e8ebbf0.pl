#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "02af53facfc3931e9546cb819d56b5792460d2172a8db4614858067cf7476820", "source_sha256": "5aa602a80e57cbc63f54485d4cd66e205c54bd9f32bc03434218ff9bd388b3ab", "target_language": "perl5"}
# collect_compare_bundle.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway1:scripts/collect_compare_bundle.sh
# auch in: OpenClaw@gateway2:scripts/collect_compare_bundle.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Path qw(make_path);
use File::Find;
use POSIX qw(strftime);

my $ROOT = "/home/openclaw/.openclaw";
my $OUT_DIR = "$ROOT/workspace/vscode/compare";
my $TRANSFER_DIR = "$OUT_DIR/transfer";
my $MD_FILE = "$OUT_DIR/local-gateway-config.md";
my $TREE_FILE = "$OUT_DIR/tree.txt";
my $BACKUP_FILE = "/home/openclaw/openclaw-backup.tar.gz";

my $NOW_LOCAL = strftime('%Y-%m-%d %H:%M:%S %Z', localtime);
my $NOW_UTC = strftime('%Y-%m-%dT%H:%M:%SZ', gmtime);
my $HOST = `hostname -f 2>/dev/null || hostname`;
chomp $HOST;

my $OPENCLAW_JSON = "$ROOT/openclaw.json";
my $EXEC_APPROVALS_JSON = "$ROOT/exec-approvals.json";
my $GATEWAY_SYSTEMD_ENV = "$ROOT/gateway.systemd.env";
my $DOT_ENV = "$ROOT/.env";
my $CONFIG_DIR = "$ROOT/.config";
my $AGENTS_DIR = "$ROOT/agents";

make_path($OUT_DIR);
make_path($TRANSFER_DIR);

unless (`which tree`) {
    die "Fehler: 'tree' ist nicht installiert.\n";
}

sub append_file_verbatim {
    my ($label, $path, $lang) = @_;
    $lang //= "text";

    open(my $fh, '>>', $MD_FILE) or die "Konnte $MD_FILE nicht öffnen: $!";
    print $fh "\n## $label\n\n";
    print $fh "Pfad: `$path`\n\n";
    print $fh "```$lang\n";
    if (-f $path) {
        open(my $file_fh, '<', $path) or die "Konnte $path nicht öffnen: $!";
        while (my $line = <$file_fh>) {
            print $fh $line;
        }
        close($file_fh);
    } else {
        print $fh "[FEHLT] $path\n";
    }
    print $fh "\n```\n";
    close($fh);
}

sub append_env_verbatim {
    open(my $fh, '>>', $MD_FILE) or die "Konnte $MD_FILE nicht öffnen: $!";
    print $fh "\n## Umgebungsvariablen (env)\n\n";
    print $fh "```\n";
    foreach my $key (sort keys %ENV) {
        print $fh "$key=$ENV{$key}\n";
    }
    print $fh "```\n";
    close($fh);
}

sub append_dir_files_verbatim {
    my ($section, $dir) = @_;

    open(my $fh, '>>', $MD_FILE) or die "Konnte $MD_FILE nicht öffnen: $!";
    print $fh "\n## $section\n\n";
    unless (-d $dir) {
        print $fh "[FEHLT] $dir\n";
        close($fh);
        return;
    }
    print $fh "Basisverzeichnis: `$dir`\n";
    close($fh);

    my @files;
    find(sub {
        push @files, $File::Find::name if -f $_;
    }, $dir);

    for my $f (sort @files) {
        open(my $fh_append, '>>', $MD_FILE) or die "Konnte $MD_FILE nicht öffnen: $!";
        print $fh_append "\n### Datei: `$f`\n\n";
        print $fh_append "```\n";
        open(my $file_fh, '<', $f) or warn "Konnte $f nicht öffnen: $!";
        while (my $line = <$file_fh>) {
            print $fh_append $line;
        }
        close($file_fh) if $file_fh;
        print $fh_append "\n```\n";
        close($fh_append);
    }
}

open(my $md_fh, '>', $MD_FILE) or die "Konnte $MD_FILE nicht öffnen: $!";
print $md_fh "# Lokaler Gateway-Konfigurationsstand\n\n";
print $md_fh "Generiert: $NOW_LOCAL\n";
print $md_fh "UTC: $NOW_UTC\n";
print $md_fh "Host: $HOST\n\n";
print $md_fh "Diese Datei enthaelt den lokalen Stand mit unveraenderten Inhalten.\n";
close($md_fh);

append_file_verbatim("openclaw.json", $OPENCLAW_JSON, "json");
append_file_verbatim("exec-approvals.json", $EXEC_APPROVALS_JSON, "json");
append_file_verbatim("gateway.systemd.env", $GATEWAY_SYSTEMD_ENV, "dotenv");
append_file_verbatim(".env", $DOT_ENV, "dotenv");
append_env_verbatim();
append_dir_files_verbatim(".config (alle Dateien rekursiv)", $CONFIG_DIR);
append_dir_files_verbatim("agents (alle Dateien rekursiv)", $AGENTS_DIR);

system("tree -a -L 6 '$ROOT' > '$TREE_FILE'");

system("openclaw backup create --output '$BACKUP_FILE' --verify") == 0
    or die "Backup-Befehl fehlgeschlagen: $?";

system("cp '$BACKUP_FILE' '$OUT_DIR'") == 0
    or die "Kopieren des Backups fehlgeschlagen: $?";

print "OK\n";
print "Erzeugt:\n";
print "- $MD_FILE\n";
print "- $TREE_FILE\n";
print "- $BACKUP_FILE\n";
print "- $TRANSFER_DIR (leer)\n";

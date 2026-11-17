#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "e3aab2310f18b353f74c5534a2a3d444ac46d093f289afe24308aa8785d02a99", "source_sha256": "5aa602a80e57cbc63f54485d4cd66e205c54bd9f32bc03434218ff9bd388b3ab", "target_language": "perl6"}
# collect_compare_bundle.sh — portiert nach perl6
# Quelle: shell, OpenClaw@gateway1:scripts/collect_compare_bundle.sh
# auch in: OpenClaw@gateway2:scripts/collect_compare_bundle.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

use v6;

my $ROOT = "/home/openclaw/.openclaw";
my $OUT_DIR = "$ROOT/workspace/vscode/compare";
my $TRANSFER_DIR = "$OUT_DIR/transfer";
my $MD_FILE = "$OUT_DIR/local-gateway-config.md";
my $TREE_FILE = "$OUT_DIR/tree.txt";
my $BACKUP_FILE = "/home/openclaw/openclaw-backup.tar.gz";

my $NOW_LOCAL = DateTime.now.Str ~~ s/\.\d+$//;
my $NOW_UTC = DateTime.now.utc.Str ~~ s/\.\d+Z$/Z/;
my $HOST = run(<hostname -f>, :out).out.slurp.chomp // run(<hostname>, :out).out.slurp.chomp;

my $OPENCLAW_JSON = "$ROOT/openclaw.json";
my $EXEC_APPROVALS_JSON = "$ROOT/exec-approvals.json";
my $GATEWAY_SYSTEMD_ENV = "$ROOT/gateway.systemd.env";
my $DOT_ENV = "$ROOT/.env";
my $CONFIG_DIR = "$ROOT/.config";
my $AGENTS_DIR = "$ROOT/agents";

mkdir $OUT_DIR unless $OUT_DIR.IO.d;
mkdir $TRANSFER_DIR unless $TRANSFER_DIR.IO.d;

unless run(<which tree>, :out).exitcode == 0 {
    note "Fehler: 'tree' ist nicht installiert.";
    exit 1;
}

sub append-file-verbatim($label, $path, $lang = "text") {
    my $fh = open($MD_FILE, :append);
    $fh.say("");
    $fh.say("## $label");
    $fh.say("");
    $fh.say("Pfad: `$path`");
    $fh.say("");
    $fh.say("```$lang");
    if $path.IO.f {
        $fh.say($path.IO.slurp.chomp);
    } else {
        $fh.say("[FEHLT] $path");
    }
    $fh.say("");
    $fh.say("```");
    $fh.close;
}

sub append-env-verbatim() {
    my $fh = open($MD_FILE, :append);
    $fh.say("");
    $fh.say("## Umgebungsvariablen (env)");
    $fh.say("");
    $fh.say("```text");
    for %*ENV.kv -> $key, $value {
        $fh.say("$key=$value");
    }
    $fh.say("```");
    $fh.close;
}

sub append-dir-files-verbatim($section, $dir) {
    my $fh = open($MD_FILE, :append);
    $fh.say("");
    $fh.say("## $section");
    $fh.say("");
    unless $dir.IO.d {
        $fh.say("[FEHLT] $dir");
        $fh.close;
        return;
    }
    $fh.say("Basisverzeichnis: `$dir`");
    $fh.close;

    for $dir.IO.dir(:test(*.f), :!hidden, :recursive).sort {
        my $file-fh = open($MD_FILE, :append);
        $file-fh.say("");
        $file-fh.say("### Datei: `$_`");
        $file-fh.say("");
        $file-fh.say("```text");
        $file-fh.say($_.IO.slurp.chomp);
        $file-fh.say("");
        $file-fh.say("```");
        $file-fh.close;
    }
}

spurt $MD_FILE, qq:to/EOF2/;
# Lokaler Gateway-Konfigurationsstand

Generiert: $NOW_LOCAL
UTC: $NOW_UTC
Host: $HOST

Diese Datei enthaelt den lokalen Stand mit unveraenderten Inhalten.
EOF2

append-file-verbatim("openclaw.json", $OPENCLAW_JSON, "json");
append-file-verbatim("exec-approvals.json", $EXEC_APPROVALS_JSON, "json");
append-file-verbatim("gateway.systemd.env", $GATEWAY_SYSTEMD_ENV, "dotenv");
append-file-verbatim(".env", $DOT_ENV, "dotenv");
append-env-verbatim();
append-dir-files-verbatim(".config (alle Dateien rekursiv)", $CONFIG_DIR);
append-dir-files-verbatim("agents (alle Dateien rekursiv)", $AGENTS_DIR);

run("tree", "-a", "-L", "6", $ROOT, :out[$TREE_FILE]);
run("openclaw", "backup", "create", "--output", $BACKUP_FILE, "--verify");
run("cp", $BACKUP_FILE, $OUT_DIR);

say "OK";
say "Erzeugt:";
say "- $MD_FILE";
say "- $TREE_FILE";
say "- $BACKUP_FILE";
say "- $TRANSFER_DIR (leer)";

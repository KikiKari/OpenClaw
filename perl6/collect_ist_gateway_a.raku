#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "2052333e2780860927d980513f6d84763dd30acb6fdb5dacb06f63af7513934f", "source_sha256": "47064dbc7b32c01d57d42222f8cc3ac7caf9c8d82b98029dc5fc6ecb0d32f2c9", "target_language": "perl6"}
# collect_ist_gateway_a.sh — portiert nach perl6
# Quelle: shell, OpenClaw@gateway1:scripts/collect_ist_gateway_a.sh
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

use v6;

my $BASE_DIR = "%*ENV<HOME>/.openclaw";
my $OUT_DIR = "$BASE_DIR/workspace/vscode";
my $NOW_UTC = DateTime.now.utc.Str.subst(/\.\d+/, '');
my $NOW_LOCAL = DateTime.now.Str.subst(/\.\d+/, '');
my $TS = DateTime.now.Str.subst(/<-[\d]>*/, '', :g);

mkdir $OUT_DIR unless $OUT_DIR.IO.d;

my $IST_FILE = "$OUT_DIR/IST-ZUSTAND_GATEWAY-A_NODE1.md";
my $INV_FILE = "$OUT_DIR/ARTEFAKT-INVENTAR_GATEWAY-A_NODE1.md";
my $CFG_FILE = "$OUT_DIR/OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-A_NODE1.md";
my $ENV_FILE = "$OUT_DIR/ENV-STATUS_GATEWAY-A_NODE1.md";
my $RUN_FILE = "$OUT_DIR/RUN-$TS.md";

my $OPENCLAW_JSON = "$BASE_DIR/openclaw.json";
my $ENV_DOT = "$BASE_DIR/.env";
my $ENV_SYSTEMD = "$BASE_DIR/gateway.systemd.env";
my $VSCODE_DIR = "$BASE_DIR/.vscode";

my $HOSTNAME_FQDN = run('hostname', '-f'), :out;
$HOSTNAME_FQDN = $HOSTNAME_FQDN.out.slurp.chomp // run('hostname').out.slurp.chomp;

my $HOSTNAME_SHORT = run('hostname').out.slurp.chomp;
my $ARCH = run('uname', '-m').out.slurp.chomp;
my $KERNEL = run('uname', '-r').out.slurp.chomp;

my $OS_PRETTY = '';
if "/etc/os-release".IO.f {
    for "/etc/os-release".IO.lines -> $line {
        if $line ~~ /^'PRETTY_NAME='(.*)$/ {
            $OS_PRETTY = ~$0;
            $OS_PRETTY ~~ s:g/\"//;
            last;
        }
    }
}

my $IPV4_ALL = '';
try {
    my $proc = run('hostname', '-I'), :out;
    $IPV4_ALL = $proc.out.slurp.chomp.words.join(' ');
}

my $PUBLIC_IP = '';
try {
    my $proc = run('curl', '-4', '-s', '--max-time', '4', 'ifconfig.me'), :out;
    $PUBLIC_IP = $proc.out.slurp.chomp;
}

my $TAILSCALE_IP = '';
try {
    my $proc = run('tailscale', 'ip', '-4'), :out;
    $TAILSCALE_IP = $proc.out.slurp.lines[0].chomp // '';
}

my $OPENCLAW_VER = '';
try {
    my $proc = run('openclaw', '--version'), :out;
    $OPENCLAW_VER = $proc.out.slurp.chomp;
}

my $NODE_VER = '';
try {
    my $proc = run('node', '-v'), :out;
    $NODE_VER = $proc.out.slurp.chomp;
}

$PUBLIC_IP = "(nicht ermittelt)" if !$PUBLIC_IP.defined || $PUBLIC_IP eq '';
$TAILSCALE_IP = "(nicht ermittelt)" if !$TAILSCALE_IP.defined || $TAILSCALE_IP eq '';
$OPENCLAW_VER = "(nicht ermittelt)" if !$OPENCLAW_VER.defined || $OPENCLAW_VER eq '';
$NODE_VER = "(nicht ermittelt)" if !$NODE_VER.defined || $NODE_VER eq '';

spurt $IST_FILE, qq:to/EOM/;
# IST-Zustand: Gateway A / Node 1

Stand (lokal): $NOW_LOCAL  
Stand (UTC): $NOW_UTC

## 1) Identitaet & System

- Gateway: **A**
- Node: **1**
- Hostname (short): `$HOSTNAME_SHORT`
- Hostname (FQDN): `$HOSTNAME_FQDN`
- Architektur: `$ARCH`
- Kernel: `$KERNEL`
- OS: `$OS_PRETTY`
- IPv4 (lokal): `$IPV4_ALL`
- Public IPv4: `$PUBLIC_IP`
- Tailscale IPv4: `$TAILSCALE_IP`
- OpenClaw Version: `$OPENCLAW_VER`
- Node.js Version: `$NODE_VER`

## 2) Arbeitsverzeichnisse

- Basis: `$BASE_DIR`
- Funktionell VSCode: `$VSCODE_DIR`
- Workspace Doku: `$OUT_DIR`

## 3) Kernartefakte (Existenz)

- `$OPENCLAW_JSON`: { $OPENCLAW_JSON.IO.f ?? 'vorhanden' !! 'fehlt' }
- `$ENV_DOT`: { $ENV_DOT.IO.f ?? 'vorhanden' !! 'fehlt' }
- `$ENV_SYSTEMD`: { $ENV_SYSTEMD.IO.f ?? 'vorhanden' !! 'fehlt' }
- `$BASE_DIR/plugins/installs.json`: { "$BASE_DIR/plugins/installs.json".IO.f ?? 'vorhanden' !! 'fehlt' }
- `$BASE_DIR/plugin-skills`: { "$BASE_DIR/plugin-skills".IO.d ?? 'vorhanden' !! 'fehlt' }
EOM

my $inv_content = q:to/END_INV/;
# Artefakt-Inventar: Gateway A / Node 1

Stand: $NOW_LOCAL

## Top-Level in ~/.openclaw

```text
END_INV

if $BASE_DIR.IO.d {
    $inv_content ~= $BASE_DIR.IO.dir.map(*.basename).join("\n") ~ "\n";
} else {
    $inv_content ~= "(nicht vorhanden)\n";
}

$inv_content ~= q:to/END_VSCODE/;

## ~/.openclaw/.vscode

```text
END_VSCODE

if $VSCODE_DIR.IO.d {
    $inv_content ~= $VSCODE_DIR.IO.dir.map({ .Str.IO ~~ :f ?? .basename !! .basename ~ '/' }).sort.join("\n") ~ "\n";
} else {
    $inv_content ~= "(nicht vorhanden)\n";
}

$inv_content ~= q:to/END_PLUGIN_SKILLS/;

## plugin-skills/

```text
END_PLUGIN_SKILLS

if "$BASE_DIR/plugin-skills".IO.d {
    $inv_content ~= "$BASE_DIR/plugin-skills".IO.dir.map(*.basename).join("\n") ~ "\n";
} else {
    $inv_content ~= "(nicht vorhanden)\n";
}

$inv_content ~= q:to/END_BACKUPS/;

## openclaw.json Backups

```text
END_BACKUPS

my @backups = $BASE_DIR.IO.dir.grep(*.basename ~~ /^'openclaw.json.bak'/);
if @backups.elems > 0 {
    $inv_content ~= @backups.map(*.basename).join("\n") ~ "\n";
} else {
    $inv_content ~= "(keine gefunden)\n";
}

$inv_content ~= "```\n";

spurt $INV_FILE, $inv_content;

my $cfg_content = q:to/END_CFG/;
# OpenClaw Config Snapshot: Gateway A / Node 1

Stand: $NOW_LOCAL

## Schluesselpositionen (grep)

```text
END_CFG

if $OPENCLAW_JSON.IO.f {
    try {
        my $fh = open $OPENCLAW_JSON, :r;
        for $fh.lines -> $line {
            if $line ~~ /'"gateway"'|\"session\"|\"dmScope\"|\"auth\"|\"secrets\"|\"tools\"|\"plugins\"|\"profile\"|\"alsoAllow\"|\"denyCommands\"/ {
                $cfg_content ~= $line ~ "\n";
            }
        }
        $fh.close;
    }
} else {
    $cfg_content ~= "openclaw.json fehlt\n";
}

$cfg_content ~= q:to/END_SNIPPET/;

## Ausschnitt gateway/session/auth

```json
END_SNIPPET

if $OPENCLAW_JSON.IO.f {
    try {
        my $fh = open $OPENCLAW_JSON, :r;
        my $lines = $fh.lines;
        $fh.close;
        my $start = 579 < $lines.elems ?? 579 !! 0;
        my $end = 779 < $lines.elems ?? 779 !! $lines.elems - 1;
        for $start..$end -> $i {
            $cfg_content ~= $lines[$i] ~ "\n" if $i < $lines.elems;
        }
    }
} else {
    $cfg_content ~= '{ "error": "openclaw.json fehlt" }';
}

$cfg_content ~= "```\n";

spurt $CFG_FILE, $cfg_content;

my $env_content = q:to/END_ENV/;
# ENV-Status: Gateway A / Node 1

Stand: $NOW_LOCAL

## Dateien

```text
END_ENV

try {
    my $dot_stat = $ENV_DOT.IO.e ?? $ENV_DOT.IO ~~ :f ?? 'f' !! 'd' !! '-';
    my $systemd_stat = $ENV_SYSTEMD.IO.e ?? $ENV_SYSTEMD.IO ~~ :f ?? 'f' !! 'd' !! '-';
    $env_content ~= "$dot_stat $ENV_DOT\n" if $ENV_DOT.IO.e;
    $env_content ~= "$systemd_stat $ENV_SYSTEMD\n" if $ENV_SYSTEMD.IO.e;
}

$env_content ~= q:to/END_DOTENV/;

## .env (vollstaendig)

```dotenv
END_DOTENV

if $ENV_DOT.IO.f {
    $env_content ~= $ENV_DOT.IO.slurp;
} else {
    $env_content ~= "# .env fehlt\n";
}

$env_content ~= q:to/END_SYSTEMD/;

## gateway.systemd.env (vollstaendig)

```dotenv
END_SYSTEMD

if $ENV_SYSTEMD.IO.f {
    $env_content ~= $ENV_SYSTEMD.IO.slurp;
} else {
    $env_content ~= "# gateway.systemd.env fehlt\n";
}

$env_content ~= "```\n";

spurt $ENV_FILE, $env_content;

spurt $RUN_FILE, qq:to/EOM/;
# Laufprotokoll Gateway A / Node 1

- Zeit (lokal): $NOW_LOCAL
- Zeit (UTC): $NOW_UTC
- Script: {$*PROGRAM}

## Erzeugte Dateien

- { $IST_FILE.split('/').tail }
- { $INV_FILE.split('/').tail }
- { $CFG_FILE.split('/').tail }
- { $ENV_FILE.split('/').tail }
EOM

say "OK: IST-Zustand erfasst.";

if $OUT_DIR.IO.d {
    for $OUT_DIR.IO.dir -> $file {
        say "- " ~ $file.basename;
    }
}

#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "207c01ec5c74fe92e7d5d054bcfe0374e90885fc35f07672551d2fbb86152ffd", "source_sha256": "47064dbc7b32c01d57d42222f8cc3ac7caf9c8d82b98029dc5fc6ecb0d32f2c9", "target_language": "perl6"}
# collect_ist_gateway_a.sh — portiert nach perl6
# Quelle: shell, OpenClaw@gateway1:scripts/collect_ist_gateway_a.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

use v6;

my $BASE_DIR = "%*ENV<HOME>/.openclaw";
my $OUT_DIR = "$BASE_DIR/workspace/vscode";
my $NOW_UTC = run('date', '-u', '+%Y-%m-%dT%H:%M:%SZ', :out).out.slurp.chomp;
my $NOW_LOCAL = run('date', '+%Y-%m-%d %H:%M:%S %Z', :out).out.slurp.chomp;
my $TS = run('date', '+%Y%m%d-%H%M%S', :out).out.slurp.chomp;

run('mkdir', '-p', $OUT_DIR);

my $IST_FILE = "$OUT_DIR/IST-ZUSTAND_GATEWAY-A_NODE1.md";
my $INV_FILE = "$OUT_DIR/ARTEFAKT-INVENTAR_GATEWAY-A_NODE1.md";
my $CFG_FILE = "$OUT_DIR/OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-A_NODE1.md";
my $ENV_FILE = "$OUT_DIR/ENV-STATUS_GATEWAY-A_NODE1.md";
my $RUN_FILE = "$OUT_DIR/RUN-$TS.md";

my $OPENCLAW_JSON = "$BASE_DIR/openclaw.json";
my $ENV_DOT = "$BASE_DIR/.env";
my $ENV_SYSTEMD = "$BASE_DIR/gateway.systemd.env";
my $VSCODE_DIR = "$BASE_DIR/.vscode";

my $HOSTNAME_FQDN = try { run('hostname', '-f', :out).out.slurp.chomp } // run('hostname', :out).out.slurp.chomp;
my $HOSTNAME_SHORT = run('hostname', :out).out.slurp.chomp;
my $ARCH = run('uname', '-m', :out).out.slurp.chomp;
my $KERNEL = run('uname', '-r', :out).out.slurp.chomp;
my $OS_PRETTY = try { run('grep', '^PRETTY_NAME=', '/etc/os-release', :out).out.slurp.chomp.split('=', 2)[1].subst('"', '', :g) } // '';
my $IPV4_ALL = try { run('hostname', '-I', :out).out.slurp.chomp.words.join(' ') } // '';
my $PUBLIC_IP = try { run('curl', '-4', '-s', '--max-time', '4', 'ifconfig.me', :out).out.slurp.chomp } // '';
my $TAILSCALE_IP = try { run('tailscale', 'ip', '-4', :out).out.slurp.lines[0] } // '';
my $OPENCLAW_VER = try { run('openclaw', '--version', :out).out.slurp.chomp } // '';
my $NODE_VER = try { run('node', '-v', :out).out.slurp.chomp } // '';

$PUBLIC_IP = "(nicht ermittelt)" if $PUBLIC_IP eq '';
$TAILSCALE_IP = "(nicht ermittelt)" if $TAILSCALE_IP eq '';
$OPENCLAW_VER = "(nicht ermittelt)" if $OPENCLAW_VER eq '';
$NODE_VER = "(nicht ermittelt)" if $NODE_VER eq '';

spurt($IST_FILE, qq:to/EOM/);
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

spurt($INV_FILE, qq:to/EOM/);
# Artefakt-Inventar: Gateway A / Node 1

Stand: $NOW_LOCAL

## Top-Level in ~/.openclaw

```text
{try { run('ls', '-1', $BASE_DIR, :out).out.slurp } // ''}
```

## ~/.openclaw/.vscode

```text
{ $VSCODE_DIR.IO.d ?? run('ls', '-la', $VSCODE_DIR, :out).out.slurp !! "(nicht vorhanden)" }
```

## plugin-skills/

```text
{ "$BASE_DIR/plugin-skills".IO.d ?? try { run('ls', '-1', "$BASE_DIR/plugin-skills", :out).out.slurp } !! "(nicht vorhanden)" }
```

## openclaw.json Backups

```text
{try { run('ls', '-1', "$BASE_DIR/openclaw.json.bak*", :out).out.slurp } // "(keine gefunden)"}
```
EOM

spurt($CFG_FILE, qq:to/EOM/);
# OpenClaw Config Snapshot: Gateway A / Node 1

Stand: $NOW_LOCAL

## Schluesselpositionen (grep)

```text
{ $OPENCLAW_JSON.IO.f ?? try { run('grep', '-nE', '"gateway"|\"session\"|\"dmScope\"|\"auth\"|\"secrets\"|\"tools\"|\"plugins\"|\"profile\"|\"alsoAllow\"|\"denyCommands\"', $OPENCLAW_JSON, :out).out.slurp } !! "openclaw.json fehlt" }
```

## Ausschnitt gateway/session/auth

```json
{ $OPENCLAW_JSON.IO.f ?? try { $OPENCLAW_JSON.IO.slurp.lines[579..779].join("\n") } !! '{ "error": "openclaw.json fehlt" }' }
```
EOM

spurt($ENV_FILE, qq:to/EOM/);
# ENV-Status: Gateway A / Node 1

Stand: $NOW_LOCAL

## Dateien

```text
{try { run('ls', '-la', $ENV_DOT, $ENV_SYSTEMD, :out).out.slurp } // ''}
```

## .env (vollstaendig)

```dotenv
{ $ENV_DOT.IO.f ?? $ENV_DOT.IO.slurp !! "# .env fehlt" }
```

## gateway.systemd.env (vollstaendig)

```dotenv
{ $ENV_SYSTEMD.IO.f ?? $ENV_SYSTEMD.IO.slurp !! "# gateway.systemd.env fehlt" }
```
EOM

spurt($RUN_FILE, qq:to/EOM/);
# Laufprotokoll Gateway A / Node 1

- Zeit (lokal): $NOW_LOCAL
- Zeit (UTC): $NOW_UTC
- Script: {run('realpath', $*PROGRAM-NAME, :out).out.slurp.chomp}

## Erzeugte Dateien

- { $IST_FILE.IO.basename }
- { $INV_FILE.IO.basename }
- { $CFG_FILE.IO.basename }
- { $ENV_FILE.IO.basename }
EOM

say "OK: IST-Zustand erfasst.";
run('ls', '-1', $OUT_DIR).out.lines.map({ "- $_" }).join("\n").say;

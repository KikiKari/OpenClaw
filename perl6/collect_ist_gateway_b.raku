#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "5ff2cd12d4175ed9f4da3df9916695b057bddf4a71160ee074f2456f3ccc27f0", "source_sha256": "da890cc26fb848b78b6a85373d6cfa4e08f6e7c2002921e1c0247960b8b361d7", "target_language": "perl6"}
# collect_ist_gateway_b.sh — portiert nach perl6
# Quelle: shell, OpenClaw@gateway2:scripts/collect_ist_gateway_b.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

use v6;

my $BASE-DIR = "{$*HOME}/.openclaw";
my $OUT-DIR = "{$BASE-DIR}/workspace/vscode";

# Ensure output directory exists
run 'mkdir', '-p', $OUT-DIR;

my $NOW-UTC = DateTime.now.utc.Str.subst(' ', 'T') ~ 'Z';
my $NOW-LOCAL = DateTime.now.Str;
my $TS = DateTime.now.Str.subst(/<[ T:-]>/, { when 'T'|'-' { '-' }; when ':' { '' } }, :g);

my $IST-FILE = "{$OUT-DIR}/IST-ZUSTAND_GATEWAY-B_NODE7.md";
my $INV-FILE = "{$OUT-DIR}/ARTEFAKT-INVENTAR_GATEWAY-B_NODE7.md";
my $CFG-FILE = "{$OUT-DIR}/OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-B_NODE7.md";
my $ENV-FILE = "{$OUT-DIR}/ENV-STATUS_GATEWAY-B_NODE7.md";
my $RUN-FILE = "{$OUT-DIR}/RUN-{$TS}.md";

my $OPENCLAW-JSON = "{$BASE-DIR}/openclaw.json";
my $ENV-DOT = "{$BASE-DIR}/.env";
my $ENV-SYSTEMD = "{$BASE-DIR}/gateway.systemd.env";
my $VSCODE-DIR = "{$BASE-DIR}/.vscode";

sub get-hostname-info() {
    my $fqdn = run(<hostname -f>, :out).out.slurp-rest.chomp // run(<hostname>, :out).out.slurp-rest.chomp;
    my $short = run(<hostname>, :out).out.slurp-rest.chomp;
    return ($fqdn, $short);
}

sub get-os-info() {
    my $os-name = '';
    if "/etc/os-release".IO.e {
        for "/etc/os-release".IO.lines -> $line {
            if $line ~~ /^'PRETTY_NAME='(.*)/ {
                $os-name = ~$0.trim('"');
                last;
            }
        }
    }
    return $os-name;
}

sub get-ip-info() {
    my $ipv4-all = '';
    try {
        $ipv4-all = run(<hostname -I>, :out).out.slurp-rest.chomp.words.join(' ');
    }

    my $public-ip = '';
    try {
        $public-ip = run(<curl -4 -s --max-time 4 ifconfig.me>, :out).out.slurp-rest.chomp;
    }

    my $tailscale-ip = '';
    try {
        $tailscale-ip = run(<tailscale ip -4>, :out).out.slurp-rest.lines[0].chomp;
    }

    return ($ipv4-all, $public-ip || '(nicht ermittelt)', $tailscale-ip || '(nicht ermittelt)');
}

sub get-version-info() {
    my $openclaw-ver = '';
    try {
        $openclaw-ver = run(<openclaw --version>, :out).out.slurp-rest.chomp;
    }

    my $node-ver = '';
    try {
        $node-ver = run(<node -v>, :out).out.slurp-rest.chomp;
    }

    return ($openclaw-ver || '(nicht ermittelt)', $node-ver || '(nicht ermittelt)');
}

my ($HOSTNAME-FQDN, $HOSTNAME-SHORT) = get-hostname-info();
my $ARCH = run(<uname -m>, :out).out.slurp-rest.chomp;
my $KERNEL = run(<uname -r>, :out).out.slurp-rest.chomp;
my $OS-PRETTY = get-os-info();
my ($IPV4-ALL, $PUBLIC-IP, $TAILSCALE-IP) = get-ip-info();
my ($OPENCLAW-VER, $NODE-VER) = get-version-info();

spurt $IST-FILE, qq:to/END/;
# IST-Zustand: Gateway B / Node 7

Stand (lokal): {$NOW-LOCAL}  
Stand (UTC): {$NOW-UTC}

## 1) Identität & System

- Gateway: **B**
- Node: **7**
- Hostname (short): `{$HOSTNAME-SHORT}`
- Hostname (FQDN): `{$HOSTNAME-FQDN}`
- Architektur: `{$ARCH}`
- Kernel: `{$KERNEL}`
- OS: `{$OS-PRETTY}`
- IPv4 (lokal): `{$IPV4-ALL}`
- Public IPv4: `{$PUBLIC-IP}`
- Tailscale IPv4: `{$TAILSCALE-IP}`
- OpenClaw Version: `{$OPENCLAW-VER}`
- Node.js Version: `{$NODE-VER}`

## 2) Arbeitsverzeichnisse

- Basis: `{$BASE-DIR}`
- Funktionell VSCode: `{$VSCODE-DIR}`
- Workspace Doku: `{$OUT-DIR}`

## 3) Kernartefakte (Existenz)

- `{$OPENCLAW-JSON}`: { $OPENCLAW-JSON.IO.e ?? 'vorhanden' !! 'fehlt' }
- `{$ENV-DOT}`: { $ENV-DOT.IO.e ?? 'vorhanden' !! 'fehlt' }
- `{$ENV-SYSTEMD}`: { $ENV-SYSTEMD.IO.e ?? 'vorhanden' !! 'fehlt' }
- `{$BASE-DIR}/plugins/installs.json`: { "{$BASE-DIR}/plugins/installs.json".IO.e ?? 'vorhanden' !! 'fehlt' }
- `{$BASE-DIR}/plugin-skills`: { "{$BASE-DIR}/plugin-skills".IO.d ?? 'vorhanden' !! 'fehlt' }

## 4) Hinweis

Diese Datei wird bei jedem Lauf neu geschrieben.
Zusätzlich wird ein Laufprotokoll als `RUN-*.md` erzeugt.
END

spurt $INV-FILE, join("\n", 
    "# Artefakt-Inventar: Gateway B / Node 7",
    "",
    "Stand: {$NOW-LOCAL}",
    "",
    "## Top-Level in ~/.openclaw",
    "",
    '```text',
    ($BASE-DIR.IO.d ?? $BASE-DIR.IO.dir.map(*.basename).sort !! []),
    '```',
    "",
    "## ~/.openclaw/.vscode",
    "",
    '```text',
    ($VSCODE-DIR.IO.d ?? run(<ls -la>, $VSCODE-DIR, :out).out.slurp-rest !! "(nicht vorhanden)"),
    '```',
    "",
    "## plugin-skills/",
    "",
    '```text',
    ("{$BASE-DIR}/plugin-skills".IO.d ?? "{$BASE-DIR}/plugin-skills".IO.dir.map(*.basename).sort !! ["(nicht vorhanden)"]),
    '```',
    "",
    "## openclaw.json Backups",
    "",
    '```text',
    (gather for $BASE-DIR.IO.dir -> $file {
        take $file.basename if $file.basename ~~ /^'openclaw.json.bak'/;
    }).sort || ["(keine gefunden)"],
    '```'
);

spurt $CFG-FILE, join("\n",
    "# OpenClaw Config Snapshot: Gateway B / Node 7",
    "",
    "Stand: {$NOW-LOCAL}",
    "",
    "## Schlüsselpositionen (grep)",
    "",
    '```text',
    ($OPENCLAW-JSON.IO.f ?? run(<grep -nE '"gateway"|\"session\"|\"dmScope\"|\"auth\"|\"secrets\"|\"tools\"|\"plugins\"|\"profile\"|\"alsoAllow\"|\"denyCommands\"'>, $OPENCLAW-JSON, :out).out.slurp-rest !! "openclaw.json fehlt"),
    '```',
    "",
    "## Ausschnitt gateway/session/auth (ungefiltert, betriebsnah)",
    "",
    '```json',
    ($OPENCLAW-JSON.IO.f ?? try {
        my @lines = $OPENCLAW-JSON.IO.lines;
        @lines[579..779].join("\n");
    } !! '{ "error": "openclaw.json fehlt" }'),
    '```'
);

spurt $ENV-FILE, join("\n",
    "# ENV-Status: Gateway B / Node 7",
    "",
    "Stand: {$NOW-LOCAL}",
    "",
    "## Dateien",
    "",
    '```text',
    (try {
        run(<ls -la>, $ENV-DOT, $ENV-SYSTEMD, :out).out.slurp-rest;
    } // ''),
    '```',
    "",
    "## .env (vollständig, ungefiltert)",
    "",
    '```dotenv',
    ($ENV-DOT.IO.f ?? $ENV-DOT.IO.slurp !! "# .env fehlt"),
    '```',
    "",
    "## gateway.systemd.env (vollständig, ungefiltert)",
    "",
    '```dotenv',
    ($ENV-SYSTEMD.IO.f ?? $ENV-SYSTEMD.IO.slurp !! "# gateway.systemd.env fehlt"),
    '```'
);

spurt $RUN-FILE, qq:to/END/;
# Laufprotokoll Gateway B / Node 7

- Zeit (lokal): {$NOW-LOCAL}
- Zeit (UTC): {$NOW-UTC}
- Script: {$?FILE}

## Erzeugte Dateien

- { $IST-FILE.split('/').tail }
- { $INV-FILE.split('/').tail }
- { $CFG-FILE.split('/').tail }
- { $ENV-FILE.split('/').tail }

END

say "OK: IST-Zustand erfasst.";
say "Ausgabeordner: {$OUT-DIR}";
say "Dateien:";
for $OUT-DIR.IO.dir -> $file {
    say "- ", $file.basename;
}

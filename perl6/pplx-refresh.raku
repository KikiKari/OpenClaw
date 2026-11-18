#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "8cbd10bc275d339079217f8424140a1b4929033b3b5c8ad35c15b16dbea5e0cd", "source_sha256": "47740d82dac30833751ad7e0c569c7c084b01b1468243a6aebaf3f4a526f0a93", "target_language": "perl6"}
# pplx-refresh.sh — portiert nach perl6
# Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-refresh.sh
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

# Refresh the codespace Perplexity session from a locally-exported cookie.
#
# Usage:
#   ./pplx-refresh.raku [cookie-file]
#
# cookie-file defaults to ~/pplx-cookies.txt. Put your local browser's
# __Secure-next-auth.session-token value (raw), or the whole Cookie header,
# or a JSON cookie export, into that file first.
#
# Steps: ensure daemon browser -> read daemon passphrase -> inject into vault
#        -> trigger reinit -> verify authenticated.

use v6.d;

sub MAIN($cookie-file? = "$*HOME/pplx-cookies.txt") {
    my $HERE = $*PROGRAM.dirname.IO.resolve.absolute;
    my $CFG = %*ENV<PERPLEXITY_CONFIG_DIR> // "$*HOME/.perplexity-mcp";
    my $PROFILE = %*ENV<PERPLEXITY_PROFILE> // "codespace";
    my $COOKIE_FILE = $cookie-file;

    if !$COOKIE_FILE.IO.e || $COOKIE_FILE.IO.s == 0 {
        note "✗ Cookie file empty/missing: $COOKIE_FILE";
        note "  Export __Secure-next-auth.session-token from your local browser";
        note "  (DevTools → Application → Cookies → www.perplexity.ai) into that file.";
        exit 1;
    }

    # 1. ensure the extension daemon has a usable browser (idempotent)
    run($*EXECUTABLE, "$HERE/pplx-setup.raku");

    # 2. daemon pid + vault passphrase (never guessed — read from the live daemon)
    my $LOCK = "$CFG/daemon.lock";
    if !$LOCK.IO.e {
        note "✗ no daemon.lock at $LOCK — is the extension running?";
        exit 1;
    }
    
    my $lock-content = $LOCK.IO.slurp;
    my $json;
    try {
        $json = from-json($lock-content);
        CATCH {
            note "✗ invalid JSON in daemon.lock";
            exit 1;
        }
    }
    
    my $PID = $json<pid>;
    try {
        run("ps", "-p", $PID, "-o", "pid=", :out, :err);
        CATCH {
            note "✗ daemon pid $PID not running";
            exit 1;
        }
    }
    
    my $PASS;
    if $*KERNEL.name eq 'linux' {
        my $environ = "/proc/$PID/environ".IO.slurp(:bin);
        my $env-str = $environ.decode: :latin-1;
        for $env-str.split("\0") -> $var {
            if $var.starts-with('PERPLEXITY_VAULT_PASSPHRASE=') {
                $PASS = $var.substr(27);
                last;
            }
        }
    } else {
        # Fallback for non-Linux systems
        my $proc = run("ps", "eww", "-p", $PID, "-o", "command", :out);
        my $output = $proc.out.slurp(:close);
        if $output ~~ /PERPLEXITY_VAULT_PASSPHRASE\=(\S+)/ {
            $PASS = ~$0;
        }
    }
    
    if !$PASS {
        note "✗ no PERPLEXITY_VAULT_PASSPHRASE in daemon env";
        exit 1;
    }

    # 3. locate the perplexity-user-mcp dist (populate npx cache if needed)
    my $DIST;
    my @npx-dirs = "$*HOME/.npm/_npx".IO.dir.grep(*.d);
    for @npx-dirs -> $dir {
        my @dist-dirs = find($dir, :dir, :name('dist'));
        for @dist-dirs -> $dist-dir {
            if $dist-dir.absolute.contains('perplexity-user-mcp') {
                $DIST = $dist-dir.absolute;
                last;
            }
        }
        last if $DIST;
    }
    
    if !$DIST {
        try {
            run("npx", "-y", "perplexity-user-mcp", "--version", :out, :err);
            @npx-dirs = "$*HOME/.npm/_npx".IO.dir.grep(*.d);
            for @npx-dirs -> $dir {
                my @dist-dirs = find($dir, :dir, :name('dist'));
                for @dist-dirs -> $dist-dir {
                    if $dist-dir.absolute.contains('perplexity-user-mcp') {
                        $DIST = $dist-dir.absolute;
                        last;
                    }
                }
                last if $DIST;
            }
        }
    }

    # 4. inject
    my %env = %*ENV;
    %env<PERPLEXITY_VAULT_PASSPHRASE> = $PASS;
    %env<PERPLEXITY_CONFIG_DIR> = $CFG;
    %env<PERPLEXITY_PROFILE> = $PROFILE;
    %env<PPLX_DIST> = $DIST // '';
    
    run(%env, "node", "$HERE/pplx-inject.mjs", $COOKIE_FILE);

    # 5. trigger daemon reinit
    spurt("$CFG/profiles/$PROFILE/.reinit", DateTime.now.posix.Int);
    note "→ reinit triggered, waiting for daemon...";

    # 6. verify
    my $STAT = "$CFG/profiles/$PROFILE/daemon-status.json";
    for 1..20 {
        sleep 1.5;
        my $AUTH;
        my $TIER;
        try {
            if $STAT.IO.e {
                my $stat-content = $STAT.IO.slurp;
                my $stat-json = from-json($stat-content);
                $AUTH = $stat-json<authenticated> // '';
                $TIER = $stat-json<tier> // '';
            }
        }
        if $AUTH.defined && $AUTH eq 'True' {
            note "✅ authenticated — tier: $TIER";
            exit 0;
        }
    }
    note "⚠️  not authenticated yet. Check: tail -20 $CFG/daemon.log";
    exit 1;
}

sub find(IO::Path $dir, :$name, :$dir-only = False) {
    my @results;
    for $dir.dir -> $entry {
        if $dir-only && !$entry.d { next; }
        if $entry.basename eq $name {
            @results.push($entry);
        }
        if $entry.d {
            @results.append(find($entry, :$name, :$dir-only));
        }
    }
    return @results;
}

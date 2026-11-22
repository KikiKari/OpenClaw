#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "e6eea6c09b74937109459af63cabdf1421b4b6e5b7f79c8c7c8405e5c6761240", "source_sha256": "9bab70cc20775da1defcfadbbbef9ceb0f983a51d1a3988a76a20843d64c8471", "target_language": "tcl"}
# run.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/install-sh-nonroot/run.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

package require http
package require tls

proc main {} {
    set INSTALL_URL [expr {[info exists ::env(OPENCLAW_INSTALL_URL)] ? $::env(OPENCLAW_INSTALL_URL) : "https://openclaw.bot/install.sh"}]
    set DEFAULT_PACKAGE "openclaw"
    set PACKAGE_NAME [expr {[info exists ::env(OPENCLAW_INSTALL_PACKAGE)] ? $::env(OPENCLAW_INSTALL_PACKAGE) : $DEFAULT_PACKAGE}]

    # Source cli-verify.sh equivalent
    source_cli_verify

    puts "==> Pre-flight: ensure git absent"
    if {[catch {exec which git}]} {
        puts stderr "git is present unexpectedly"
        exit 1
    }

    puts "==> Pre-flight: ensure supported Node is already present"
    if {[catch {exec node -e {
        const version = process.versions.node.split(".").map(Number);
        const ok =
            version.length >= 2 &&
            (version[0] > 22 || (version[0] === 22 && version[1] >= 16));
        if (!ok) {
            process.stderr.write(`unsupported node ${process.versions.node}\n`);
            process.exit(1);
        }
    }} result]} {
        puts stderr $result
        exit 1
    }

    if {[catch {exec which npm}]} {
        puts stderr "npm not found"
        exit 1
    }

    puts "==> Run installer (non-root user)"
    if {[catch {exec curl -fsSL $INSTALL_URL} script_content]} {
        puts stderr "Failed to download install script"
        exit 1
    }

    if {[catch {exec bash << $script_content} result]} {
        puts stderr "Install script failed: $result"
        exit 1
    }

    # Ensure PATH picks up user npm prefix
    set ::env(PATH) "$::env(HOME)/.npm-global/bin:$::env(PATH)"

    puts "==> Verify git installed"
    if {[catch {exec which git}]} {
        puts stderr "git not installed by script"
        exit 1
    }

    set EXPECTED_VERSION [expr {[info exists ::env(OPENCLAW_INSTALL_EXPECT_VERSION)] ? $::env(OPENCLAW_INSTALL_EXPECT_VERSION) : ""}]
    if {$EXPECTED_VERSION ne ""} {
        set LATEST_VERSION $EXPECTED_VERSION
    } else {
        if {[catch {exec npm view $PACKAGE_NAME version} LATEST_VERSION]} {
            puts stderr "Failed to get package version"
            exit 1
        }
        set LATEST_VERSION [string trim $LATEST_VERSION]
    }

    puts "==> Verify CLI installed"
    verify_installed_cli $PACKAGE_NAME $LATEST_VERSION

    puts "OK"
}

proc source_cli_verify {} {
    # Implementation of cli-verify.sh functionality in Tcl
    proc verify_installed_cli {package_name expected_version} {
        if {[catch {exec npm list -g $package_name --depth=0} output]} {
            puts stderr "CLI $package_name not installed"
            exit 1
        }
        
        if {$expected_version ne ""} {
            if {![string match "*@$expected_version*" $output]} {
                puts stderr "CLI version mismatch. Expected: $expected_version"
                exit 1
            }
        }
    }
}

main

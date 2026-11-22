#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "f5d0526e7c4e72b9ac80c7b8f5669d53de9a5f5a8fc5f7886f3725b72ea3ae17", "source_sha256": "8f102a03732002cacc77d2ffc6fb4210aabf44652bfa80af3f96aab371d0679c", "target_language": "tcl"}
# run.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/install-sh-smoke/run.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

package require http
package require json
package require fileutil

# Set environment variables with defaults
set INSTALL_URL [expr {[info exists ::env(OPENCLAW_INSTALL_URL)] ? $::env(OPENCLAW_INSTALL_URL) : "https://openclaw.bot/install.sh"}]
set SMOKE_MODE [expr {[info exists ::env(OPENCLAW_INSTALL_SMOKE_MODE)] ? $::env(OPENCLAW_INSTALL_SMOKE_MODE) : "install"}]
set SMOKE_PREVIOUS_VERSION [expr {[info exists ::env(OPENCLAW_INSTALL_SMOKE_PREVIOUS)] ? $::env(OPENCLAW_INSTALL_SMOKE_PREVIOUS) : ""}]
set SKIP_PREVIOUS [expr {[info exists ::env(OPENCLAW_INSTALL_SMOKE_SKIP_PREVIOUS)] ? $::env(OPENCLAW_INSTALL_SMOKE_SKIP_PREVIOUS) : "0"}]
set DEFAULT_PACKAGE "openclaw"
set PACKAGE_NAME [expr {[info exists ::env(OPENCLAW_INSTALL_PACKAGE)] ? $::env(OPENCLAW_INSTALL_PACKAGE) : $DEFAULT_PACKAGE}]
set FRESH_VERSION [expr {[info exists ::env(OPENCLAW_INSTALL_FRESH_VERSION)] ? $::env(OPENCLAW_INSTALL_FRESH_VERSION) : ""}]
set FRESH_TAG_URL [expr {[info exists ::env(OPENCLAW_INSTALL_FRESH_TAG_URL)] ? $::env(OPENCLAW_INSTALL_FRESH_TAG_URL) : ""}]
set UPDATE_BASELINE_VERSION [expr {[info exists ::env(OPENCLAW_INSTALL_UPDATE_BASELINE)] ? $::env(OPENCLAW_INSTALL_UPDATE_BASELINE) : "2026.4.10"}]
set UPDATE_BASELINE_TAG_URL [expr {[info exists ::env(OPENCLAW_INSTALL_UPDATE_BASELINE_TAG_URL)] ? $::env(OPENCLAW_INSTALL_UPDATE_BASELINE_TAG_URL) : ""}]
set UPDATE_EXPECT_VERSION [expr {[info exists ::env(OPENCLAW_INSTALL_UPDATE_EXPECT_VERSION)] ? $::env(OPENCLAW_INSTALL_UPDATE_EXPECT_VERSION) : ""}]
set UPDATE_TAG_URL [expr {[info exists ::env(OPENCLAW_INSTALL_UPDATE_TAG_URL)] ? $::env(OPENCLAW_INSTALL_UPDATE_TAG_URL) : ""}]

# Get script directory
set SCRIPT_DIR [file dirname [file normalize [info script]]]

# Source cli-verify.sh equivalent
if {[file exists "$SCRIPT_DIR/../install-sh-common/cli-verify.sh"]} {
    # In Tcl we'll implement the verification inline
}

proc quiet_npm {args} {
    set cmd "npm {*}$args"
    if {[catch {exec {*}$cmd} result]} {
        return ""
    }
    return $result
}

proc verify_installed_cli {package_name expected_version} {
    set cmd [list npm list -g --depth=0 $package_name]
    if {[catch {exec {*}$cmd} output]} {
        puts stderr "ERROR: Failed to verify installed CLI"
        exit 1
    }
    
    # Parse the output to check version
    if {![regexp "$package_name@$expected_version" $output]} {
        puts stderr "ERROR: Expected version $expected_version not found"
        exit 1
    }
}

proc run_install_smoke {} {
    global FRESH_VERSION FRESH_TAG_URL PACKAGE_NAME SKIP_PREVIOUS SMOKE_PREVIOUS_VERSION
    
    if {$FRESH_VERSION ne "" && $FRESH_TAG_URL ne ""} {
        puts "package=$PACKAGE_NAME latest=$FRESH_VERSION source=$FRESH_TAG_URL"
        puts "==> Install latest release tarball"
        if {[catch {exec npm install -g --omit=optional $FRESH_TAG_URL} result]} {
            puts stderr "ERROR: npm install failed: $result"
            exit 1
        }
        
        puts "==> Verify installed version"
        if {[info exists ::env(OPENCLAW_INSTALL_LATEST_OUT)] && $::env(OPENCLAW_INSTALL_LATEST_OUT) ne ""} {
            set fp [open $::env(OPENCLAW_INSTALL_LATEST_OUT) w]
            puts -nonewline $fp $FRESH_VERSION
            close $fp
        }
        verify_installed_cli $PACKAGE_NAME $FRESH_VERSION
        
        puts "OK"
        return
    }
    
    puts "==> Resolve npm versions"
    if {$SKIP_PREVIOUS eq "1"} {
        set LATEST_VERSION [quiet_npm view $PACKAGE_NAME version]
        set PREVIOUS_VERSION $LATEST_VERSION
    } elseif {$SMOKE_PREVIOUS_VERSION ne ""} {
        set LATEST_VERSION [quiet_npm view $PACKAGE_NAME version]
        set PREVIOUS_VERSION $SMOKE_PREVIOUS_VERSION
    } else {
        set LATEST_VERSION [quiet_npm view $PACKAGE_NAME dist-tags.latest]
        set VERSIONS_JSON [quiet_npm view $PACKAGE_NAME versions --json]
        
        # Use a temporary file for Node.js script
        set temp_script [fileutil::tempfile]
        set fp [open $temp_script w]
        puts $fp {const latest = String(process.env.LATEST_VERSION || "");
const raw = process.env.VERSIONS_JSON || "[]";
let versions;
try {
  versions = JSON.parse(raw);
} catch {
  versions = raw ? [raw] : [];
}
if (!Array.isArray(versions)) {
  versions = [versions];
}
if (versions.length === 0 || latest.length === 0) {
  process.exit(1);
}
const latestIndex = versions.lastIndexOf(latest);
if (latestIndex <= 0) {
  process.stdout.write(latest);
  process.exit(0);
}
process.stdout.write(String(versions[latestIndex - 1] ?? latest));}
        close $fp
        
        set env(LATEST_VERSION) $LATEST_VERSION
        set env(VERSIONS_JSON) $VERSIONS_JSON
        if {[catch {exec node $temp_script} PREVIOUS_VERSION]} {
            file delete $temp_script
            error "Failed to determine previous version"
        }
        file delete $temp_script
    }
    
    puts "package=$PACKAGE_NAME latest=$LATEST_VERSION previous=$PREVIOUS_VERSION"
    
    if {$SKIP_PREVIOUS eq "1"} {
        puts "==> Skip preinstall previous (OPENCLAW_INSTALL_SMOKE_SKIP_PREVIOUS=1)"
    } else {
        puts "==> Preinstall previous (forces installer upgrade path)"
        if {[catch {exec npm install -g ${PACKAGE_NAME}@${PREVIOUS_VERSION}} result]} {
            puts stderr "ERROR: npm install failed: $result"
            exit 1
        }
    }
    
    puts "==> Run official installer one-liner"
    if {[catch {exec curl -fsSL $::INSTALL_URL | exec bash -s -- --no-prompt} result]} {
        puts stderr "ERROR: Installer failed: $result"
        exit 1
    }
    
    puts "==> Verify installed version"
    if {[info exists ::env(OPENCLAW_INSTALL_LATEST_OUT)] && $::env(OPENCLAW_INSTALL_LATEST_OUT) ne ""} {
        set fp [open $::env(OPENCLAW_INSTALL_LATEST_OUT) w]
        puts -nonewline $fp $LATEST_VERSION
        close $fp
    }
    verify_installed_cli $PACKAGE_NAME $LATEST_VERSION
    
    puts "OK"
}

proc run_update_smoke {} {
    global PACKAGE_NAME UPDATE_BASELINE_VERSION UPDATE_BASELINE_TAG_URL UPDATE_EXPECT_VERSION UPDATE_TAG_URL
    
    if {$UPDATE_EXPECT_VERSION eq ""} {
        puts stderr "ERROR: OPENCLAW_INSTALL_UPDATE_EXPECT_VERSION is required for update mode"
        exit 1
    }
    if {$UPDATE_TAG_URL eq ""} {
        puts stderr "ERROR: OPENCLAW_INSTALL_UPDATE_TAG_URL is required for update mode"
        exit 1
    }
    
    puts "package=$PACKAGE_NAME baseline=$UPDATE_BASELINE_VERSION target=$UPDATE_EXPECT_VERSION"
    puts "==> Install baseline release"
    if {$UPDATE_BASELINE_TAG_URL ne ""} {
        if {[catch {exec npm install -g --omit=optional $UPDATE_BASELINE_TAG_URL} result]} {
            puts stderr "ERROR: npm install failed: $result"
            exit 1
        }
    } else {
        if {[catch {exec npm install -g --omit=optional ${PACKAGE_NAME}@${UPDATE_BASELINE_VERSION}} result]} {
            puts stderr "ERROR: npm install failed: $result"
            exit 1
        }
    }
    verify_installed_cli $PACKAGE_NAME $UPDATE_BASELINE_VERSION
    
    puts "==> Run openclaw update from host-served tgz"
    set update_stderr_file [fileutil::tempfile]
    set env(npm_config_omit) "optional"
    set env(NPM_CONFIG_OMIT) "optional"
    
    if {[catch {exec openclaw update --tag $UPDATE_TAG_URL --yes --json 2>@stderr} UPDATE_JSON]} {
        set update_status 1
    } else {
        set update_status 0
    }
    
    # Read stderr content
    set update_stderr ""
    if {[file exists $update_stderr_file]} {
        set fp [open $update_stderr_file r]
        set update_stderr [read $fp]
        close $fp
        file delete $update_stderr_file
    }
    
    puts $UPDATE_JSON
    if {$update_stderr ne ""} {
        puts stderr $update_stderr
    }
    if {$update_status != 0} {
        puts stderr "ERROR: openclaw update failed with exit code $update_status"
        exit $update_status
    }
    
    # Create and run validation script
    set temp_script [fileutil::tempfile]
    set fp [open $temp_script w]
    puts $fp {const payload = JSON.parse(process.env.UPDATE_JSON || "{}");
const expectedVersion = String(process.env.UPDATE_EXPECT_VERSION || "");
const baselineVersion = String(process.env.UPDATE_BASELINE_VERSION || "");
const expectedUrl = String(process.env.UPDATE_TAG_URL || "");
if (payload.status !== "ok") {
  throw new Error(`expected update status ok, got ${JSON.stringify(payload.status)}`);
}
if ((payload.before?.version ?? null) !== baselineVersion) {
  throw new Error(
    `expected before.version ${baselineVersion}, got ${JSON.stringify(payload.before?.version)}`,
  );
}
if ((payload.after?.version ?? null) !== expectedVersion) {
  throw new Error(
    `expected after.version ${expectedVersion}, got ${JSON.stringify(payload.after?.version)}`,
  );
}
if (payload.reason != null) {
  throw new Error(`expected no failure reason, got ${JSON.stringify(payload.reason)}`);
}
const steps = Array.isArray(payload.steps) ? payload.steps : [];
const updateStep = steps.find((step) => step?.name === "global update");
if (!updateStep) {
  throw new Error("missing global update step in update JSON");
}
if (Number(updateStep.exitCode ?? 1) !== 0) {
  throw new Error(`global update step failed: ${JSON.stringify(updateStep)}`);
}
if (typeof updateStep.command !== "string" || !updateStep.command.includes(expectedUrl)) {
  throw new Error(`global update step missing expected tgz URL: ${JSON.stringify(updateStep)}`);
}}
    close $fp
    
    set env(UPDATE_JSON) $UPDATE_JSON
    set env(UPDATE_EXPECT_VERSION) $UPDATE_EXPECT_VERSION
    set env(UPDATE_BASELINE_VERSION) $UPDATE_BASELINE_VERSION
    set env(UPDATE_TAG_URL) $UPDATE_TAG_URL
    
    if {[catch {exec node $temp_script} result]} {
        file delete $temp_script
        puts stderr "ERROR: Validation failed: $result"
        exit 1
    }
    file delete $temp_script
    
    puts "==> Verify updated version"
    verify_installed_cli $PACKAGE_NAME $UPDATE_EXPECT_VERSION
    
    puts "OK"
}

# Main execution
switch $SMOKE_MODE {
    "install" {
        run_install_smoke
    }
    "update" {
        run_update_smoke
    }
    default {
        puts stderr "ERROR: unsupported OPENCLAW_INSTALL_SMOKE_MODE=$SMOKE_MODE"
        exit 1
    }
}

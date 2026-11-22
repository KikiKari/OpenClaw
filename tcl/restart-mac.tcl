#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "7f72915e6bddfeff1899ba40746de2abeba9030a5490f0c0e816f2087fdf5067", "source_sha256": "fbf046d1988d19407db864ee85d468151b410a1dc1cab4374f1f8119c6fb9897", "target_language": "tcl"}
# restart-mac.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/restart-mac.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

# Reset OpenClaw like Trimmy: kill running instances, rebuild, repackage, relaunch, verify.

# Global variables
set ROOT_DIR [file normalize [file join [file dirname [info script]] ..]]
set APP_BUNDLE [expr {[info exists ::env(OPENCLAW_APP_BUNDLE)] ? $::env(OPENCLAW_APP_BUNDLE) : ""}]
set APP_PROCESS_PATTERN "OpenClaw.app/Contents/MacOS/OpenClaw"
set DEBUG_PROCESS_PATTERN [file join $ROOT_DIR apps macos .build debug OpenClaw]
set LOCAL_PROCESS_PATTERN [file join $ROOT_DIR apps macos .build-local debug OpenClaw]
set RELEASE_PROCESS_PATTERN [file join $ROOT_DIR apps macos .build release OpenClaw]
set LAUNCH_AGENT [file join $::env(HOME) Library LaunchAgents ai.openclaw.mac.plist]
set LOCK_KEY [string range [exec printf %s $ROOT_DIR | exec shasum -a 256] 0 7]
set LOCK_DIR [file join [expr {[info exists ::env(TMPDIR)] ? $::env(TMPDIR) : "/tmp"}] openclaw-restart-$LOCK_KEY]
set LOCK_PID_FILE [file join $LOCK_DIR pid]
set WAIT_FOR_LOCK 0
set LOG_PATH [expr {[info exists ::env(OPENCLAW_RESTART_LOG)] ? $::env(OPENCLAW_RESTART_LOG) : "/tmp/openclaw-restart.log"}]
set NO_SIGN 0
set SIGN 0
set AUTO_DETECT_SIGNING 1
set GATEWAY_WAIT_SECONDS [expr {[info exists ::env(OPENCLAW_GATEWAY_WAIT_SECONDS)] ? $::env(OPENCLAW_GATEWAY_WAIT_SECONDS) : 0}]
set LAUNCHAGENT_DISABLE_MARKER [file join $::env(HOME) .openclaw disable-launchagent]
set ATTACH_ONLY 1

proc log {msg} {
    puts $msg
    flush stdout
}

proc fail {msg} {
    puts stderr "ERROR: $msg"
    flush stderr
    exit 1
}

# Ensure local node binaries (rolldown, pnpm) are discoverable for the steps below.
set ::env(PATH) [file join $::ROOT_DIR node_modules .bin]:$::env(PATH)

proc run_step {label args} {
    log "==> $label"
    if {[catch {exec {*}$args} result]} {
        fail "$label failed: $result"
    }
}

proc cleanup {} {
    global LOCK_DIR
    if {[file exists $LOCK_DIR] && [file isdirectory $LOCK_DIR]} {
        file delete -force $LOCK_DIR
    }
}

proc acquire_lock {} {
    global LOCK_DIR LOCK_PID_FILE WAIT_FOR_LOCK
    while {true} {
        if {[catch {file mkdir $LOCK_DIR}]} {
            set existing_pid ""
            if {[file exists $LOCK_PID_FILE]} {
                if {[catch {set existing_pid [exec cat $LOCK_PID_FILE]}]} {
                    # Ignore error
                }
            }
            
            if {$existing_pid ne ""} {
                if {![catch {exec kill -0 $existing_pid}]} {
                    if {$::WAIT_FOR_LOCK == 1} {
                        log "==> Another restart is running (pid $existing_pid); waiting..."
                        while {![catch {exec kill -0 $existing_pid}] && ![catch {exec sleep 1}]} {}
                        continue
                    }
                    log "==> Another restart is running (pid $existing_pid); re-run with --wait."
                    exit 0
                }
            }
            
            file delete -force $LOCK_DIR
        } else {
            set fp [open $LOCK_PID_FILE w]
            puts $fp [pid]
            close $fp
            return 0
        }
    }
}

proc check_signing_keys {} {
    if {[catch {exec security find-identity -p codesigning -v} result]} {
        return 0
    }
    if {[regexp {(Developer ID Application|Apple Distribution|Apple Development)} $result]} {
        return 1
    }
    return 0
}

# Register cleanup handler
proc handle_exit {} {
    cleanup
}
proc handle_signal {sig} {
    cleanup
    exit 1
}

# Parse command line arguments
foreach arg $argv {
    switch -- $arg {
        "--wait" - "-w" {
            set WAIT_FOR_LOCK 1
        }
        "--no-sign" {
            set NO_SIGN 1
            set AUTO_DETECT_SIGNING 0
        }
        "--sign" {
            set SIGN 1
            set AUTO_DETECT_SIGNING 0
        }
        "--attach-only" {
            set ATTACH_ONLY 1
        }
        "--no-attach-only" {
            set ATTACH_ONLY 0
        }
        "--help" - "-h" {
            set script_name [file tail $argv0]
            log "Usage: $script_name \[--wait\] \[--no-sign\] \[--sign\] \[--attach-only|--no-attach-only\]"
            log "  --wait    Wait for other restart to complete instead of exiting"
            log "  --no-sign Force no code signing (fastest for development)"
            log "  --sign    Force code signing (will fail if no signing key available)"
            log "  --attach-only    Launch app with --attach-only (skip launchd install)"
            log "  --no-attach-only Launch app without attach-only override"
            log ""
            log "Env:"
            log "  OPENCLAW_GATEWAY_WAIT_SECONDS=0  Wait time before gateway port check (unsigned only)"
            log ""
            log "Unsigned recovery:"
            log "  node openclaw.mjs daemon install --force --runtime node"
            log "  node openclaw.mjs daemon restart"
            log ""
            log "Reset unsigned overrides:"
            log "  rm ~/.openclaw/disable-launchagent"
            log ""
            log "Default behavior: Auto-detect signing keys, fallback to --no-sign if none found"
            exit 0
        }
    }
}

if {$NO_SIGN == 1 && $SIGN == 1} {
    fail "Cannot use --sign and --no-sign together"
}

# Setup logging
file mkdir [file dirname $LOG_PATH]
file delete -force $LOG_PATH

# Redirect output to log file and stdout
if {[catch {open "| tee $LOG_PATH" w} log_pipe]} {
    set log_pipe stdout
}
set stdout_copy $log_pipe
set stderr_copy $log_pipe

log "==> Log: $LOG_PATH"
if {$NO_SIGN == 1} {
    log "==> Using --no-sign (unsigned flow enabled)"
}
if {$ATTACH_ONLY == 1} {
    log "==> Using --attach-only (skip launchd install)"
}

acquire_lock

proc kill_all_openclaw {} {
    global APP_PROCESS_PATTERN DEBUG_PROCESS_PATTERN LOCAL_PROCESS_PATTERN RELEASE_PROCESS_PATTERN
    
    for {set i 0} {$i < 10} {incr i} {
        catch {exec pkill -f $APP_PROCESS_PATTERN}
        catch {exec pkill -f $DEBUG_PROCESS_PATTERN}
        catch {exec pkill -f $LOCAL_PROCESS_PATTERN}
        catch {exec pkill -f $RELEASE_PROCESS_PATTERN}
        catch {exec pkill -x "OpenClaw"}
        
        set found_processes 0
        if {![catch {exec pgrep -f $APP_PROCESS_PATTERN}]} {set found_processes 1}
        if {![catch {exec pgrep -f $DEBUG_PROCESS_PATTERN}]} {set found_processes 1}
        if {![catch {exec pgrep -f $LOCAL_PROCESS_PATTERN}]} {set found_processes 1}
        if {![catch {exec pgrep -f $RELEASE_PROCESS_PATTERN}]} {set found_processes 1}
        if {![catch {exec pgrep -x "OpenClaw"}]} {set found_processes 1}
        
        if {!$found_processes} {
            return 0
        }
        exec sleep 0.3
    }
    return 1
}

proc stop_launch_agent {} {
    global ::env(UID)
    catch {exec launchctl bootout gui/$::env(UID)/ai.openclaw.mac}
}

# 1) Kill all running instances first.
log "==> Killing existing OpenClaw instances"
kill_all_openclaw
stop_launch_agent

# Bundle Gateway-hosted Canvas A2UI assets.
run_step "bundle canvas a2ui" {*}[auto_execok bash] -lc "cd '$ROOT_DIR' && pnpm canvas:a2ui:bundle"

# 2) Rebuild into the same path the packager consumes (.build).
run_step "clean build cache" {*}[auto_execok bash] -lc "cd '$ROOT_DIR/apps/macos' && rm -rf .build .build-swift .swiftpm 2>/dev/null || true"
run_step "swift build" {*}[auto_execok bash] -lc "cd '$ROOT_DIR/apps/macos' && swift build -q --product OpenClaw"

if {$AUTO_DETECT_SIGNING == 1} {
    if {[check_signing_keys]} {
        log "==> Signing keys detected, will code sign"
        set SIGN 1
    } else {
        log "==> No signing keys found, will skip code signing (--no-sign)"
        set NO_SIGN 1
    }
}

if {$NO_SIGN == 1} {
    set ::env(ALLOW_ADHOC_SIGNING) 1
    set ::env(SIGN_IDENTITY) "-"
    file mkdir [file join $::env(HOME) .openclaw]
    run_step "disable launchagent writes" {*}[auto_execok touch] $LAUNCHAGENT_DISABLE_MARKER
} elseif {$SIGN == 1} {
    if {![check_signing_keys]} {
        fail "No signing identity found. Use --no-sign or install a signing key."
    }
    unset -nocomplain ::env(ALLOW_ADHOC_SIGNING)
    unset -nocomplain ::env(SIGN_IDENTITY)
}

# 3) Package app (no embedded gateway).
set skip_tsc [expr {[info exists ::env(SKIP_TSC)] ? $::env(SKIP_TSC) : 1}]
run_step "package app" {*}[auto_execok bash] -lc "cd '$ROOT_DIR' && SKIP_TSC=$skip_tsc '$ROOT_DIR/scripts/package-mac-app.sh'"

proc choose_app_bundle {} {
    global APP_BUNDLE ROOT_DIR
    
    if {$APP_BUNDLE ne "" && [file isdirectory $APP_BUNDLE]} {
        return 0
    }
    
    if {[file isdirectory "/Applications/OpenClaw.app"]} {
        set ::APP_BUNDLE "/Applications/OpenClaw.app"
        return 0
    }
    
    set dist_bundle [file join $ROOT_DIR dist OpenClaw.app]
    if {[file isdirectory $dist_bundle]} {
        set ::APP_BUNDLE $dist_bundle
        if {![file isdirectory [file join $dist_bundle Contents Frameworks Sparkle.framework]]} {
            fail "dist/OpenClaw.app missing Sparkle after packaging"
        }
        return 0
    }
    
    fail "App bundle not found. Set OPENCLAW_APP_BUNDLE to your installed OpenClaw.app"
}

choose_app_bundle

# When signed, clear any previous launchagent override marker.
if {$NO_SIGN != 1 && $ATTACH_ONLY != 1 && [file exists $LAUNCHAGENT_DISABLE_MARKER]} {
    run_step "clear launchagent disable marker" {*}[auto_execok rm] -f $LAUNCHAGENT_DISABLE_MARKER
}

# When unsigned, ensure the gateway LaunchAgent targets the repo CLI (before the app launches).
# This reduces noisy "could not connect" errors during app startup.
if {$NO_SIGN == 1 && $ATTACH_ONLY != 1} {
    run_step "install gateway launch agent (unsigned)" {*}[auto_execok bash] -lc "cd '$ROOT_DIR' && node openclaw.mjs daemon install --force --runtime node"
    run_step "restart gateway daemon (unsigned)" {*}[auto_execok bash] -lc "cd '$ROOT_DIR' && node openclaw.mjs daemon restart"
    if {$GATEWAY_WAIT_SECONDS > 0} {
        run_step "wait for gateway (unsigned)" {*}[auto_execok sleep] $GATEWAY_WAIT_SECONDS
    }
    
    set gateway_port_script {
        const fs = require("node:fs");
        const path = require("node:path");
        try {
            const raw = fs.readFileSync(path.join(process.env.HOME, ".openclaw", "openclaw.json"), "utf8");
            const cfg = JSON.parse(raw);
            const port = cfg && cfg.gateway && typeof cfg.gateway.port === "number" ? cfg.gateway.port : 18789;
            process.stdout.write(String(port));
        } catch {
            process.stdout.write("18789");
        }
    }
    
    set GATEWAY_PORT [exec node -e $gateway_port_script]
    run_step "verify gateway port $GATEWAY_PORT (unsigned)" {*}[auto_execok bash] -lc "lsof -iTCP:$GATEWAY_PORT -sTCP:LISTEN | head -n 5 || true"
}

set ATTACH_ONLY_ARGS {}
if {$ATTACH_ONLY == 1} {
    lappend ATTACH_ONLY_ARGS --args --attach-only
}

# 4) Launch the installed app in the foreground so the menu bar extra appears.
# LaunchServices can inherit a huge environment from this shell (secrets, prompt vars, etc.).
# That can cause launchd spawn failures and is undesirable for a GUI app anyway.
set clean_env [dict create \
    HOME $::env(HOME) \
    USER [expr {[info exists ::env(USER)] ? $::env(USER) : [exec id -un]}] \
    LOGNAME [expr {[info exists ::env(LOGNAME)] ? $::env(LOGNAME) : [exec id -un]}] \
    TMPDIR [expr {[info exists ::env(TMPDIR)] ? $::env(TMPDIR) : "/tmp"}] \
    PATH "/usr/bin:/bin:/usr/sbin:/sbin" \
    LANG [expr {[info exists ::env(LANG)] ? $::env(LANG) : "en_US.UTF-8"}]]

set cmd_args [concat [auto_execok env] -i]
foreach {key val} $clean_env {
    lappend cmd_args $key=$val
}
lappend cmd_args {*}[auto_execok open] $APP_BUNDLE {*}$ATTACH_ONLY_ARGS

run_step "launch app" {*}$cmd_args

# 5) Verify the app is alive.
exec sleep 1.5
if {![catch {exec pgrep -f $APP_PROCESS_PATTERN}]} {
    log "OK: OpenClaw is running."
} else {
    fail "App exited immediately. Check $LOG_PATH or Console.app (User Reports)."
}

if {$NO_SIGN == 1 && $ATTACH_ONLY != 1} {
    run_step "show gateway launch agent args (unsigned)" {*}[auto_execok bash] -lc "/usr/bin/plutil -p '$::env(HOME)/Library/LaunchAgents/ai.openclaw.gateway.plist' | head -n 40 || true"
}

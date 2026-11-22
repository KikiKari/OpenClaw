#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "dcf0c71a3a52ce8682ebac6c08c51feabcd65923b4fedf4b12cec53119408325", "source_sha256": "29aab8d3e497ddaa7ec77edf107b153fe17970d064df8a91d7cfcedb7e30a7fd", "target_language": "tcl"}
# sandbox-browser-entrypoint.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/sandbox-browser-entrypoint.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

# Environment setup
set env(DBUS_SESSION_BUS_ADDRESS) "/dev/null"
set env(DISPLAY) ":1"
set env(HOME) "/tmp/openclaw-home"
set env(XDG_CONFIG_HOME) "$env(HOME)/.config"
set env(XDG_CACHE_HOME) "$env(HOME)/.cache"

# Configuration variables with defaults
set CDP_PORT [expr {[info exists env(OPENCLAW_BROWSER_CDP_PORT)] ? $env(OPENCLAW_BROWSER_CDP_PORT) : 9222}]
set CDP_SOURCE_RANGE [expr {[info exists env(OPENCLAW_BROWSER_CDP_SOURCE_RANGE)] ? $env(OPENCLAW_BROWSER_CDP_SOURCE_RANGE) : ""}]
set VNC_PORT [expr {[info exists env(OPENCLAW_BROWSER_VNC_PORT)] ? $env(OPENCLAW_BROWSER_VNC_PORT) : 5900}]
set NOVNC_PORT [expr {[info exists env(OPENCLAW_BROWSER_NOVNC_PORT)] ? $env(OPENCLAW_BROWSER_NOVNC_PORT) : 6080}]
set ENABLE_NOVNC [expr {[info exists env(OPENCLAW_BROWSER_ENABLE_NOVNC)] ? $env(OPENCLAW_BROWSER_ENABLE_NOVNC) : 1}]
set HEADLESS [expr {[info exists env(OPENCLAW_BROWSER_HEADLESS)] ? $env(OPENCLAW_BROWSER_HEADLESS) : 0}]
set ALLOW_NO_SANDBOX [expr {[info exists env(OPENCLAW_BROWSER_NO_SANDBOX)] ? $env(OPENCLAW_BROWSER_NO_SANDBOX) : 0}]
set NOVNC_PASSWORD [expr {[info exists env(OPENCLAW_BROWSER_NOVNC_PASSWORD)] ? $env(OPENCLAW_BROWSER_NOVNC_PASSWORD) : ""}]

set DISABLE_GRAPHICS_FLAGS [expr {[info exists env(OPENCLAW_BROWSER_DISABLE_GRAPHICS_FLAGS)] ? $env(OPENCLAW_BROWSER_DISABLE_GRAPHICS_FLAGS) : 1}]
set DISABLE_EXTENSIONS [expr {[info exists env(OPENCLAW_BROWSER_DISABLE_EXTENSIONS)] ? $env(OPENCLAW_BROWSER_DISABLE_EXTENSIONS) : 1}]
set RENDERER_PROCESS_LIMIT [expr {[info exists env(OPENCLAW_BROWSER_RENDERER_PROCESS_LIMIT)] ? $env(OPENCLAW_BROWSER_RENDERER_PROCESS_LIMIT) : 2}]
set AUTO_START_TIMEOUT_MS [expr {[info exists env(OPENCLAW_BROWSER_AUTO_START_TIMEOUT_MS)] ? $env(OPENCLAW_BROWSER_AUTO_START_TIMEOUT_MS) : 12000}]

# Validate unsigned integers
proc validate_uint {name value {min 0} {max 4294967295}} {
    if {![string is integer -strict $value] || $value < $min || $value > $max} {
        puts stderr "\[sandbox\] ERROR: $name must be an integer between $min and $max, got: $value"
        exit 1
    }
}

# Validation calls
validate_uint "CDP_PORT" $CDP_PORT 1 65535
validate_uint "VNC_PORT" $VNC_PORT 1 65535
validate_uint "NOVNC_PORT" $NOVNC_PORT 1 65535
validate_uint "AUTO_START_TIMEOUT_MS" $AUTO_START_TIMEOUT_MS 1 2147483647
if {$RENDERER_PROCESS_LIMIT ne ""} {
    validate_uint "RENDERER_PROCESS_LIMIT" $RENDERER_PROCESS_LIMIT 0 2147483647
}

# Global process tracking variables
array set PIDS {}

# Cleanup procedure
proc cleanup {code} {
    global PIDS
    
    # Remove signal handlers
    catch {exec kill -TERM [array get PIDS]}
    
    # Kill processes
    set pids_list [array names PIDS]
    if {[llength $pids_list] > 0} {
        foreach pid $pids_list {
            if {[catch {exec kill -0 $pid}]} {
                continue
            }
            
            # Try TERM first
            catch {exec kill -TERM $pid}
        }
        
        # Wait for termination with timeout
        for {set i 0} {$i < 10} {incr i} {
            set alive 0
            foreach pid $pids_list {
                if {![catch {exec kill -0 $pid}]} {
                    set alive 1
                    break
                }
            }
            if {!$alive} {
                break
            }
            after 200
        }
        
        # Force kill remaining processes
        foreach pid $pids_list {
            catch {exec kill -KILL $pid}
        }
        
        # Wait for processes to finish
        catch {exec wait}
    }
    
    exit $code
}

# Signal handling
proc handle_exit {} { cleanup [exit] }
proc handle_int {} { cleanup 130 }
proc handle_term {} { cleanup 143 }

# Create directories
file mkdir $env(HOME) $env(HOME)/.chrome $env(XDG_CONFIG_HOME) $env(XDG_CACHE_HOME)

# Start Xvfb
if {[catch {exec Xvfb :1 -screen 0 1280x800x24 -ac -nolisten tcp &} result]} {
    puts stderr "Failed to start Xvfb: $result"
    exit 1
}
set XVFB_PID [lindex [split $result] end]
set PIDS($XVFB_PID) "Xvfb"
puts "\[sandbox\] Xvfb started (PID: $XVFB_PID)"

# Calculate Chrome CDP port
if {$CDP_PORT >= 65535} {
    set CHROME_CDP_PORT [expr {$CDP_PORT - 1}]
} else {
    set CHROME_CDP_PORT [expr {$CDP_PORT + 1}]
}

# Build Chrome arguments
set CHROME_ARGS [list \
    "--remote-debugging-address=127.0.0.1" \
    "--remote-debugging-port=$CHROME_CDP_PORT" \
    "--user-data-dir=$env(HOME)/.chrome" \
    "--no-first-run" \
    "--no-default-browser-check" \
    "--disable-dev-shm-usage" \
    "--disable-background-networking" \
    "--disable-breakpad" \
    "--disable-crash-reporter" \
    "--no-zygote" \
    "--metrics-recording-only" \
    "--password-store=basic" \
    "--use-mock-keychain"]

if {$HEADLESS eq "1"} {
    lappend CHROME_ARGS "--headless=new"
}

if {$ALLOW_NO_SANDBOX eq "1"} {
    lappend CHROME_ARGS "--no-sandbox" "--disable-setuid-sandbox"
}

# Convert to lowercase for comparison
set DISABLE_GRAPHICS_FLAGS_LOWER [string tolower $DISABLE_GRAPHICS_FLAGS]
if {$DISABLE_GRAPHICS_FLAGS_LOWER in {1 true yes on}} {
    lappend CHROME_ARGS "--disable-3d-apis" "--disable-gpu" "--disable-software-rasterizer"
}

set DISABLE_EXTENSIONS_LOWER [string tolower $DISABLE_EXTENSIONS]
if {$DISABLE_EXTENSIONS_LOWER in {1 true yes on}} {
    lappend CHROME_ARGS "--disable-extensions"
}

if {[string is integer -strict $RENDERER_PROCESS_LIMIT] && $RENDERER_PROCESS_LIMIT > 0} {
    lappend CHROME_ARGS "--renderer-process-limit=$RENDERER_PROCESS_LIMIT"
}

# Start Chromium
puts "\[sandbox\] Starting Chromium..."
if {[catch {exec chromium {*}$CHROME_ARGS about:blank &} result]} {
    puts stderr "Failed to start Chromium: $result"
    exit 1
}
set CHROME_PID [lindex [split $result] end]
set PIDS($CHROME_PID) "Chromium"
puts "\[sandbox\] Chromium started (PID: $CHROME_PID)"

# Wait for CDP to become ready
set start_ms [clock milliseconds]
set deadline_ms [expr {$start_ms + $AUTO_START_TIMEOUT_MS}]
set CDP_READY 0
set probe_url "http://127.0.0.1:$CHROME_CDP_PORT/json/version"

puts "\[sandbox\] Waiting up to $AUTO_START_TIMEOUT_MS ms for CDP on port $CHROME_CDP_PORT..."

while {[clock milliseconds] < $deadline_ms} {
    # Check if Chrome is still running
    if {[catch {exec kill -0 $CHROME_PID}]} {
        puts "\[sandbox\] ERROR: Chromium exited before CDP became ready."
        exit 1
    }
    
    # Try to connect to CDP endpoint
    if {![catch {exec curl -fsS --max-time 0.5 $probe_url}]} {
        set CDP_READY 1
        break
    }
    
    after 200
}

if {!$CDP_READY} {
    puts "\[sandbox\] ERROR: CDP failed to start within $AUTO_START_TIMEOUT_MS ms."
    exit 1
}

puts "\[sandbox\] CDP ready. Starting socat..."

# Start socat if source range is specified
if {$CDP_SOURCE_RANGE eq ""} {
    puts stderr "\[sandbox-browser\] WARNING: CDP_SOURCE_RANGE unset; socat CDP relay will not start."
    puts stderr "\[sandbox-browser\] Set OPENCLAW_BROWSER_CDP_SOURCE_RANGE to an explicit CIDR to enable CDP access."
} else {
    set SOCAT_LISTEN_ADDR "TCP-LISTEN:$CDP_PORT,fork,reuseaddr,bind=0.0.0.0,range=$CDP_SOURCE_RANGE"
    if {[catch {exec socat $SOCAT_LISTEN_ADDR "TCP:127.0.0.1:$CHROME_CDP_PORT" &} result]} {
        puts stderr "Failed to start socat: $result"
    } else {
        set SOCAT_PID [lindex [split $result] end]
        set PIDS($SOCAT_PID) "socat"
        puts "\[sandbox\] socat started (PID: $SOCAT_PID)"
    }
}

# Start noVNC if enabled and not headless
if {$ENABLE_NOVNC eq "1" && $HEADLESS ne "1"} {
    # Generate password if not provided
    if {$NOVNC_PASSWORD eq ""} {
        if {[catch {exec cat /proc/sys/kernel/random/uuid} uuid]} {
            set uuid [clock microseconds]
        }
        regsub -all {-} $uuid "" NOVNC_PASSWORD
        set NOVNC_PASSWORD [string range $NOVNC_PASSWORD 0 7]
    }
    
    # Store VNC password
    file mkdir $env(HOME)/.vnc
    if {[catch {exec x11vnc -storepasswd $NOVNC_PASSWORD $env(HOME)/.vnc/passwd}]} {
        puts stderr "Failed to store VNC password"
    } else {
        file attributes $env(HOME)/.vnc/passwd -permissions 0600
        
        # Start x11vnc
        if {[catch {exec x11vnc -display :1 -rfbport $VNC_PORT -shared -forever -rfbauth $env(HOME)/.vnc/passwd -localhost &} result]} {
            puts stderr "Failed to start x11vnc: $result"
        } else {
            set X11VNC_PID [lindex [split $result] end]
            set PIDS($X11VNC_PID) "x11vnc"
            puts "\[sandbox\] x11vnc started (PID: $X11VNC_PID)"
        }
        
        # Start websockify
        if {[catch {exec websockify --web /usr/share/novnc/ $NOVNC_PORT localhost:$VNC_PORT &} result]} {
            puts stderr "Failed to start websockify: $result"
        } else {
            set WEBSOCKIFY_PID [lindex [split $result] end]
            set PIDS($WEBSOCKIFY_PID) "websockify"
            puts "\[sandbox\] websockify started (PID: $WEBSOCKIFY_PID)"
        }
    }
}

puts "\[sandbox\] Container running. Monitoring all sub-processes..."

# Monitor processes
while {1} {
    set any_running 0
    foreach pid [array names PIDS] {
        if {![catch {exec kill -0 $pid}]} {
            set any_running 1
            break
        } else {
            unset PIDS($pid)
        }
    }
    
    if {!$any_running} {
        break
    }
    
    after 1000
}

# Exit when all processes terminate
exit 0

#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "a0f7ed469ae50188f83b4a78031515a2402a55329f7a5422e9036bf7055154fd", "source_sha256": "fe4cfd779f66ea7706f9bdfe3744e5d0a5b102609de3aca3ad086e40c76e8a2f", "target_language": "tcl"}
# build-and-run-mac.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/build-and-run-mac.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Get the directory of this script and navigate to the correct path
set scriptDir [file dirname [info script]]
set basePath [file normalize "$scriptDir/../apps/macos"]
cd $basePath

set BUILD_PATH ".build-local"
set PRODUCT "OpenClaw"
set BIN "$BUILD_PATH/debug/$PRODUCT"

puts "\n▶️  Building $PRODUCT (debug, build path: $BUILD_PATH)"

# Build the product using swift
if {[catch {exec swift build -c debug --product $PRODUCT --build-path $BUILD_PATH} result]} {
    puts stderr "Build failed: $result"
    exit 1
} else {
    puts $result
}

puts "\n⏹  Stopping existing $PRODUCT..."
# Kill existing processes (ignore errors)
catch {exec killall -q $PRODUCT}

puts "\n🚀 Launching $BIN ..."
# Launch the binary in background
if {[catch {exec $BIN >& /tmp/openclaw.log &} pid]} {
    puts stderr "Failed to start $PRODUCT: $pid"
    exit 1
} else {
    # Extract PID from the result
    set PID [lindex $pid 0]
    puts "Started $PRODUCT (PID $PID). Logs: /tmp/openclaw.log"
}

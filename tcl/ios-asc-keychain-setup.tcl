#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "895e37dced9a8c15dd76ea74ea01db7fff6660fd845b331721d6aeda68d039c7", "source_sha256": "3c82de39b963e31592918456342c499f4e6477d2ee7404f215a5685c6d02674c", "target_language": "tcl"}
# ios-asc-keychain-setup.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-asc-keychain-setup.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

proc usage {} {
    puts {
Usage:
  scripts/ios-asc-keychain-setup.sh --key-path /path/to/AuthKey_XXXXXX.p8 --issuer-id <issuer-uuid> [options]

Required:
  --key-path <path>      Path to App Store Connect API key (.p8)
  --issuer-id <uuid>     App Store Connect issuer ID

Optional:
  --key-id <id>          API key ID (auto-detected from AuthKey_<id>.p8 if omitted)
  --service <name>       Keychain service name (default: openclaw-asc-key)
  --account <name>       Keychain account name (default: $USER or $LOGNAME)
  --write-env            Upsert non-secret env vars into apps/ios/fastlane/.env
  --env-file <path>      Override env file path used with --write-env
  -h, --help             Show this help

Example:
  scripts/ios-asc-keychain-setup.sh \
    --key-path "$HOME/keys/AuthKey_ABC1234567.p8" \
    --issuer-id "00000000-1111-2222-3333-444444444444" \
    --write-env
}
}

proc upsert_env_line {file key value} {
    set tmp [exec mktemp]
    
    if {[file exists $file]} {
        set fp [open $file r]
        set lines [split [read $fp] "\n"]
        close $fp
        
        set fp [open $tmp w]
        set updated 0
        foreach line $lines {
            if {[regexp "^${key}=" $line]} {
                puts $fp "${key}=${value}"
                set updated 1
            } else {
                puts $fp $line
            }
        }
        if {!$updated} {
            puts $fp "${key}=${value}"
        }
        close $fp
    } else {
        set fp [open $tmp w]
        puts $fp "${key}=${value}"
        close $fp
    }
    
    file rename -force $tmp $file
}

proc delete_env_line {file key} {
    if {![file exists $file]} {
        return
    }
    
    set tmp [exec mktemp]
    set fp [open $file r]
    set lines [split [read $fp] "\n"]
    close $fp
    
    set fp [open $tmp w]
    foreach line $lines {
        if {![regexp "^${key}=" $line]} {
            puts $fp $line
        }
    }
    close $fp
    
    file rename -force $tmp $file
}

# Initialize variables
set KEY_PATH ""
set KEY_ID ""
set ISSUER_ID ""
set SERVICE "openclaw-asc-key"
set ACCOUNT [expr {[info exists ::env(USER)] ? $::env(USER) : [expr {[info exists ::env(LOGNAME)] ? $::env(LOGNAME) : ""}] }]
set WRITE_ENV 0
set ENV_FILE ""

# Get repository root
set script_dir [file dirname [file normalize $::argv0]]
set REPO_ROOT [file normalize "$script_dir/.."]
set DEFAULT_ENV_FILE [file join $REPO_ROOT "apps" "ios" "fastlane" ".env"]

# Parse command line arguments
set i 0
while {$i < [llength $::argv]} {
    set arg [lindex $::argv $i]
    switch $arg {
        "--key-path" {
            incr i
            set KEY_PATH [lindex $::argv $i]
            incr i
        }
        "--key-id" {
            incr i
            set KEY_ID [lindex $::argv $i]
            incr i
        }
        "--issuer-id" {
            incr i
            set ISSUER_ID [lindex $::argv $i]
            incr i
        }
        "--service" {
            incr i
            set SERVICE [lindex $::argv $i]
            incr i
        }
        "--account" {
            incr i
            set ACCOUNT [lindex $::argv $i]
            incr i
        }
        "--write-env" {
            set WRITE_ENV 1
            incr i
        }
        "--env-file" {
            incr i
            set ENV_FILE [lindex $::argv $i]
            incr i
        }
        "-h" -
        "--help" {
            usage
            exit 0
        }
        default {
            puts stderr "Unknown argument: $arg"
            usage
            exit 1
        }
    }
}

# Validate required arguments
if {$KEY_PATH eq "" || $ISSUER_ID eq ""} {
    puts stderr "Missing required arguments."
    usage
    exit 1
}

# Check if key file exists
if {![file exists $KEY_PATH]} {
    puts stderr "Key file not found: $KEY_PATH"
    exit 1
}

# Auto-detect key ID if not provided
if {$KEY_ID eq ""} {
    set key_filename [file tail $KEY_PATH]
    if {[regexp {^AuthKey_([A-Za-z0-9]+)\.p8$} $key_filename match id]} {
        set KEY_ID $id
    } else {
        puts stderr "Could not infer --key-id from filename '$key_filename'. Pass --key-id explicitly."
        exit 1
    }
}

# Validate account
if {$ACCOUNT eq ""} {
    puts stderr "Could not determine Keychain account. Pass --account explicitly."
    exit 1
}

# Read key content
set fp [open $KEY_PATH r]
set KEY_CONTENT [read $fp]
close $fp

if {$KEY_CONTENT eq ""} {
    puts stderr "Key file is empty: $KEY_PATH"
    exit 1
}

# Store key in keychain using security command
if {[catch {exec security add-generic-password -a $ACCOUNT -s $SERVICE -w $KEY_CONTENT -U} result]} {
    puts stderr "Failed to store key in keychain: $result"
    exit 1
}

puts "Stored ASC API private key in macOS Keychain (service='$SERVICE', account='$ACCOUNT')."
puts ""
puts "Export these vars for Fastlane:"
puts "ASC_KEY_ID=$KEY_ID"
puts "ASC_ISSUER_ID=$ISSUER_ID"
puts "ASC_KEYCHAIN_SERVICE=$SERVICE"
puts "ASC_KEYCHAIN_ACCOUNT=$ACCOUNT"

# Write environment variables if requested
if {$WRITE_ENV == 1} {
    if {$ENV_FILE eq ""} {
        set ENV_FILE $DEFAULT_ENV_FILE
    }
    
    file mkdir [file dirname $ENV_FILE]
    close [open $ENV_FILE a]
    
    upsert_env_line $ENV_FILE "ASC_KEY_ID" $KEY_ID
    upsert_env_line $ENV_FILE "ASC_ISSUER_ID" $ISSUER_ID
    upsert_env_line $ENV_FILE "ASC_KEYCHAIN_SERVICE" $SERVICE
    upsert_env_line $ENV_FILE "ASC_KEYCHAIN_ACCOUNT" $ACCOUNT
    # Remove file/path based keys so Keychain is used by default.
    delete_env_line $ENV_FILE "ASC_KEY_PATH"
    delete_env_line $ENV_FILE "ASC_KEY_CONTENT"
    delete_env_line $ENV_FILE "APP_STORE_CONNECT_API_KEY_PATH"
    
    puts ""
    puts "Updated env file: $ENV_FILE"
}

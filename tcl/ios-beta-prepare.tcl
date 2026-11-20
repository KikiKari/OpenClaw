#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "f224135bff870d555f5d32c79b80b361f0d374c5d6f90d1a3f8b3e42edb31c20", "source_sha256": "2ca708f3e5a694b78eb83d1e37cf5eefe3e601ebec3e31d771a7ebd4246aa33c", "target_language": "tcl"}
# ios-beta-prepare.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-beta-prepare.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

proc usage {} {
    puts stderr {Usage:
  OPENCLAW_PUSH_RELAY_BASE_URL=https://relay.example.com \
    scripts/ios-beta-prepare.sh --build-number 7 [--team-id TEAMID]

Prepares local beta-release inputs without touching local signing overrides:
- reads apps/ios/version.json and writes apps/ios/build/Version.xcconfig
- writes apps/ios/build/BetaRelease.xcconfig with canonical bundle IDs
- configures the beta build for relay-backed APNs registration
- regenerates apps/ios/OpenClaw.xcodeproj via xcodegen}
}

proc get_root_dir {} {
    set script_path [file normalize [info script]]
    return [file dirname [file dirname $script_path]]
}

proc write_generated_file {output_path content} {
    if {[file exists $output_path] && [file type $output_path] eq "link"} {
        puts stderr "Refusing to overwrite symlinked file: $output_path"
        exit 1
    }
    
    set tmp_file [exec mktemp "${output_path}.XXXXXX"]
    set fh [open $tmp_file w]
    puts -nonewline $fh $content
    close $fh
    file rename -force $tmp_file $output_path
}

proc validate_push_relay_base_url {value} {
    if {[regexp {\s} $value]} {
        puts stderr "Invalid OPENCLAW_PUSH_RELAY_BASE_URL: whitespace is not allowed."
        exit 1
    }
    
    if {[regexp {[\$\(\)=]} $value]} {
        puts stderr "Invalid OPENCLAW_PUSH_RELAY_BASE_URL: contains forbidden xcconfig characters."
        exit 1
    }
    
    if {![regexp {^https://([A-Za-z0-9.-]+)(:([0-9]{1,5}))?(/[A-Za-z0-9._~!&*+,;:@%/-]*)?$} $value -> host port_part path]} {
        puts stderr "Invalid OPENCLAW_PUSH_RELAY_BASE_URL: expected https://host[:port][/path]."
        exit 1
    }
    
    if {$port_part ne "" && $port_part > 65535} {
        puts stderr "Invalid OPENCLAW_PUSH_RELAY_BASE_URL: port must be between 1 and 65535."
        exit 1
    }
}

proc prepare_build_dir {build_dir} {
    if {[file exists $build_dir] && [file type $build_dir] eq "link"} {
        puts stderr "Refusing to use symlinked build directory: $build_dir"
        exit 1
    }
    file mkdir $build_dir
}

proc main {argv} {
    set root_dir [get_root_dir]
    set ios_dir [file join $root_dir "apps" "ios"]
    set build_dir [file join $ios_dir "build"]
    set beta_xcconfig [file join $build_dir "BetaRelease.xcconfig"]
    set team_helper [file join $root_dir "scripts" "ios-team-id.sh"]
    set version_helper [file join $root_dir "scripts" "ios-write-version-xcconfig.sh"]
    set ios_version_helper [file join $root_dir "scripts" "ios-version.ts"]
    set version_sync_helper [file join $root_dir "scripts" "ios-sync-versioning.ts"]
    
    set build_number ""
    set team_id [expr {[info exists ::env(IOS_DEVELOPMENT_TEAM)] ? $::env(IOS_DEVELOPMENT_TEAM) : ""}]
    set push_relay_base_url [expr {[info exists ::env(OPENCLAW_PUSH_RELAY_BASE_URL)] ? $::env(OPENCLAW_PUSH_RELAY_BASE_URL) : [expr {[info exists ::env(IOS_PUSH_RELAY_BASE_URL)] ? $::env(IOS_PUSH_RELAY_BASE_URL) : ""}]}]
    set push_relay_base_url_xcconfig ""
    set ios_version ""
    
    for {set i 0} {$i < [llength $argv]} {incr i} {
        set arg [lindex $argv $i]
        switch -- $arg {
            "--build-number" {
                incr i
                set build_number [lindex $argv $i]
            }
            "--team-id" {
                incr i
                set team_id [lindex $argv $i]
            }
            "-h" - "--help" {
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
    
    if {$build_number eq ""} {
        puts stderr "Missing required --build-number."
        usage
        exit 1
    }
    
    if {$team_id eq ""} {
        set env(IOS_ALLOW_KEYCHAIN_TEAM_FALLBACK) 1
        if {[catch {exec bash $team_helper} result]} {
            puts stderr "Failed to execute team helper: $result"
            exit 1
        }
        set team_id [string trim $result]
    }
    
    if {$team_id eq ""} {
        puts stderr "Could not resolve Apple Team ID. Set IOS_DEVELOPMENT_TEAM or sign into Xcode."
        exit 1
    }
    
    if {$push_relay_base_url eq ""} {
        puts stderr "Missing OPENCLAW_PUSH_RELAY_BASE_URL (or IOS_PUSH_RELAY_BASE_URL) for beta relay registration."
        exit 1
    }
    
    validate_push_relay_base_url $push_relay_base_url
    
    # `.xcconfig` treats `//` as a comment opener. Break the URL with a helper setting
    # so Xcode still resolves it back to `https://...` at build time.
    regsub -all {//} $push_relay_base_url {\$(OPENCLAW_URL_SLASH)\$(OPENCLAW_URL_SLASH)} push_relay_base_url_xcconfig
    
    prepare_build_dir $build_dir
    
    if {[catch {exec node --import tsx $version_sync_helper --check} result]} {
        puts stderr "Version sync check failed: $result"
        exit 1
    }
    
    if {[catch {exec node --import tsx $ios_version_helper --field canonicalVersion} result]} {
        puts stderr "Unable to resolve iOS version from $root_dir/apps/ios/version.json."
        exit 1
    }
    set ios_version [string trim $result]
    
    if {[catch {exec bash $version_helper --build-number $build_number} result]} {
        puts stderr "Version helper failed: $result"
        exit 1
    }
    
    set content "// Auto-generated by scripts/ios-beta-prepare.sh.
// Local beta-release override; do not commit.
OPENCLAW_CODE_SIGN_STYLE = Automatic
OPENCLAW_DEVELOPMENT_TEAM = $team_id
OPENCLAW_IOS_SELECTED_TEAM = $team_id
OPENCLAW_APP_BUNDLE_ID = ai.openclaw.client
OPENCLAW_SHARE_BUNDLE_ID = ai.openclaw.client.share
OPENCLAW_ACTIVITY_WIDGET_BUNDLE_ID = ai.openclaw.client.activitywidget
OPENCLAW_WATCH_APP_BUNDLE_ID = ai.openclaw.client.watchkitapp
OPENCLAW_WATCH_EXTENSION_BUNDLE_ID = ai.openclaw.client.watchkitapp.extension
OPENCLAW_APP_PROFILE =
OPENCLAW_SHARE_PROFILE =
OPENCLAW_PUSH_TRANSPORT = relay
OPENCLAW_PUSH_DISTRIBUTION = official
OPENCLAW_URL_SLASH = /
OPENCLAW_PUSH_RELAY_BASE_URL = $push_relay_base_url_xcconfig
OPENCLAW_PUSH_APNS_ENVIRONMENT = production
"
    
    write_generated_file $beta_xcconfig $content
    
    if {[catch {exec xcodegen generate} result]} {
        puts stderr "xcodegen failed: $result"
        exit 1
    }
    
    puts "Prepared iOS beta release: version=$ios_version build=$build_number team=$team_id"
    puts "XCODE_XCCONFIG_FILE=$beta_xcconfig"
}

main $argv

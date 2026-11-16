#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "3301a0296c8f1604a055b1452ddc49a3ac09b8acfc5920818637c2acd1e317cf", "source_sha256": "cff712785adbfe2fa94661b7b8457fbc21ec0b21bc3bc77e5cfa7018f473e486", "target_language": "tcl"}
# build_icon.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/build_icon.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Render the macOS .icon bundle to a padded .icns like Trimmy's pipeline.
# Defaults target the OpenClaw assets so you can just run the script from repo root.

package require fileutil

set ROOT_DIR [file normalize [file join [file dirname $argv0] ..]]

set ICON_FILE [expr {[llength $argv] > 0 ? [lindex $argv 0] : "$ROOT_DIR/apps/macos/Icon.icon"}]
set BASENAME [expr {[llength $argv] > 1 ? [lindex $argv 1] : "OpenClaw"}]
set OUT_ROOT [expr {[llength $argv] > 2 ? [lindex $argv 2] : "$ROOT_DIR/apps/macos/build/icon"}]

set XCODE_APP [expr {[info exists env(XCODE_APP)] ? $env(XCODE_APP) : "/Applications/Xcode.app"}]
set DEST_ICNS [expr {[info exists env(DEST_ICNS)] ? $env(DEST_ICNS) : "$ROOT_DIR/apps/macos/Sources/OpenClaw/Resources/OpenClaw.icns"}]

set ICTOOL "$XCODE_APP/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
if {![file executable $ICTOOL]} {
    set ICTOOL "$XCODE_APP/Contents/Applications/Icon Composer.app/Contents/Executables/icontool"
}
if {![file executable $ICTOOL]} {
    puts stderr "ictool/icontool not found. Set XCODE_APP if Xcode is elsewhere."
    exit 1
}

set ICONSET_DIR "$OUT_ROOT/${BASENAME}.iconset"
set TMP_DIR "$OUT_ROOT/tmp"

file mkdir $ICONSET_DIR $TMP_DIR

set MASTER_ART "$TMP_DIR/icon_art_824.png"
set MASTER_1024 "$TMP_DIR/icon_1024.png"

# Render inner art (no margin) with macOS Default appearance
exec $ICTOOL $ICON_FILE \
    --export-preview {"macOS Default"} 824 824 1 -45 $MASTER_ART

# Pad to 1024x1024 with transparent border
exec sips --padToHeightWidth 1024 1024 $MASTER_ART --out $MASTER_1024 >@ stdout

# Generate required sizes
set sizes {16 32 64 128 256 512 1024}
foreach sz $sizes {
    set out "$ICONSET_DIR/icon_${sz}x${sz}.png"
    exec sips -z $sz $sz $MASTER_1024 --out $out >@ stdout
    if {$sz != 1024} {
        set dbl [expr {$sz * 2}]
        set out2 "$ICONSET_DIR/icon_${sz}x${sz}@2x.png"
        exec sips -z $dbl $dbl $MASTER_1024 --out $out2 >@ stdout
    }
}

# 512x512@2x already covered by 1024; ensure it exists
file copy -force $MASTER_1024 "$ICONSET_DIR/icon_512x512@2x.png"

exec iconutil -c icns $ICONSET_DIR -o "$OUT_ROOT/${BASENAME}.icns"

file mkdir [file dirname $DEST_ICNS]
file copy -force "$OUT_ROOT/${BASENAME}.icns" $DEST_ICNS

puts "Icon.icns generated at $DEST_ICNS"

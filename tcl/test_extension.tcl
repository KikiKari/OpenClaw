#!/usr/bin/env tclsh
# test_extension.cjs — portiert nach tcl
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_extension.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_extension.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_extension.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

package require json
package require sha256

# Helper functions
proc concat {args} {
    set result {}
    foreach chunk $args {
        append result $chunk
    }
    return $result
}

proc varint {value} {
    set bytes {}
    while {$value > 0} {
        set byte [expr {$value & 0x7f}]
        set value [expr {$value >> 7}]
        if {$value != 0} {
            set byte [expr {$byte | 0x80}]
        }
        lappend bytes $byte
    }
    return $bytes
}

proc bytesField {number value} {
    set body $value
    if {[string is integer $value]} {
        set body [binary format c* $value]
    }
    set header [varint [expr {($number << 3) | 2}]]
    set length [varint [string length $body]]
    return [concat $header $length $body]
}

proc intField {number value} {
    set header [varint [expr {$number << 3}]]
    set data [varint $value]
    return [concat $header $data]
}

# File operations
proc readFile {filename} {
    set fp [open $filename r]
    set data [read $fp]
    close $fp
    return $data
}

proc fileExists {filename} {
    return [file exists $filename]
}

proc listJsFiles {dir} {
    set files {}
    foreach file [glob -nocomplain -directory $dir *.js] {
        lappend files [file tail $file]
    }
    return $files
}

# Main test logic
set root [file dirname [pwd]]
set extension [file join $root browser-extension]
set manifest [json::json2dict [readFile [file join $extension manifest.json]]]

# Assertions
if {[dict get $manifest manifest_version] != 3} {
    error "Manifest version mismatch"
}
if {[dict get $manifest version] != "0.8.2"} {
    error "Version mismatch"
}

# Check permissions
set permissions [dict get $manifest permissions]
if {![info exists permissions] || ![string match "*sidePanel*" $permissions]} {
    error "Missing sidePanel permission"
}
if {![string match "*webRequest*" $permissions]} {
    error "Missing webRequest permission"
}
if {![string match "*tabCapture*" $permissions]} {
    error "Missing tabCapture permission"
}

# Check host permissions
set host_permissions [dict get $manifest host_permissions]
if {![info exists host_permissions] || ![string match "*http://127.0.0.1/*" $host_permissions]} {
    error "Missing http://127.0.0.1/* host permission"
}
if {![string match "*http://localhost/*" $host_permissions]} {
    error "Missing http://localhost/* host permission"
}

# Check excluded permissions
if {[string match "*cookies*" $permissions]} {
    error "cookies permission should not be present"
}
if {[string match "*webRequestBlocking*" $permissions]} {
    error "webRequestBlocking permission should not be present"
}
if {[string match "*nativeMessaging*" $permissions]} {
    error "nativeMessaging permission should not be present"
}

# Check content scripts
set content_scripts [dict get $manifest content_scripts]
if {[lindex [dict get [lindex $content_scripts 0] js] 0] != "vendor-mpegts.js"} {
    error "vendor-mpegts.js not found in content scripts"
}

# Check vendor files exist
set mpegtsVendorPath [file join $extension vendor-mpegts.js]
set mpegtsLicensePath [file join $extension vendor-mpegts.LICENSE.txt]
set mpegtsNoticePath [file join $extension vendor-mpegts.NOTICE.md]

if {![fileExists $mpegtsVendorPath]} {
    error "vendor-mpegts.js not found"
}
if {![fileExists $mpegtsLicensePath]} {
    error "vendor-mpegts.LICENSE.txt not found"
}
if {![fileExists $mpegtsNoticePath]} {
    error "vendor-mpegts.NOTICE.md not found"
}

# Check SHA256 hash
set vendorData [readFile $mpegtsVendorPath]
set sha256hash [string toupper [sha256::sha256 -hex $vendorData]]
if {$sha256hash != "0786F9AF6780822FF29240259A73B07ED7BC479BC44966E49418DD38213B8064"} {
    error "SHA256 hash mismatch"
}

# Check mobile bridge content
set mobileBridge [readFile [file join $root mobile-shared webview-bridge.js]]
if {![string match "*location.hostname !== \"www.tiktok.com\"*" $mobileBridge]} {
    error "location.hostname check not found"
}
if {[string match "*document.cookie*" $mobileBridge]} {
    error "document.cookie should not be present"
}
if {![string match "*QUICK_RECOVER_RELOAD_COOLDOWN_MS = 400*" $mobileBridge]} {
    error "QUICK_RECOVER_RELOAD_COOLDOWN_MS not found"
}
if {![string match "*\"set-auto-reconnect\"*" $mobileBridge]} {
    error "set-auto-reconnect not found"
}
if {![string match "*\"set-limiter\"*" $mobileBridge]} {
    error "set-limiter not found"
}

# Check all manifest files exist
foreach relative [list \
    [dict get $manifest background service_worker] \
    [dict get $manifest side_panel default_path] \
    {*}[dict get $manifest content_scripts 0 js]] {
    if {![fileExists [file join $extension $relative]]} {
        error "Missing manifest file: $relative"
    }
}

# Test JavaScript files
set scripts [listJsFiles $extension]
foreach name $scripts {
    set source [readFile [file join $extension $name]]
    # Basic syntax check would go here if we had a JS parser
    
    # Check for dangerous patterns
    if {[regexp {\beval\s*\(} $source]} {
        error "$name contains eval()"
    }
    if {[regexp {new\s+Function\s*\(} $source]} {
        error "$name contains new Function()"
    }
    if {[regexp {\.innerHTML\s*=} $source]} {
        error "$name assigns innerHTML"
    }
}

puts "PASS: manifest 0.8.2, [llength $scripts] scripts, basic checks passed"

#!/usr/bin/env tclsh
# status-overview-panel.css — portiert nach tcl
# Quelle: css, Projects@TikTok-Live-Companion:plugin-source/browser-extension/status-overview-panel.css
# Erzeugt: 2026-11-01 durch ABSTRACTIONS_MANAGER.py

# Tcl 8.6 script to generate CSS content and write it to a file
# This is a translation of the CSS file into Tcl code that generates the same CSS output

proc generate_css {} {
    set css_content ""
    
    append css_content ".overview-row { display:grid; grid-template-columns:24px minmax(0,1fr) 11px 22px auto; gap:7px; align-items:center; margin:6px 0; }\n"
    append css_content ".overview-row input { min-width:0; width:100%; }\n"
    append css_content ".overview-state { width:11px; height:11px; border-radius:50%; background:#888; }\n"
    append css_content ".overview-state.online { background:var(--good); box-shadow:0 0 0 3px color-mix(in srgb, var(--good) 15%, transparent); }\n"
    append css_content ".overview-state.offline { background:var(--bad); box-shadow:0 0 0 3px color-mix(in srgb, var(--bad) 15%, transparent); }\n"
    append css_content ".overview-state.checking, .overview-state.error { background:var(--warn); }\n"
    append css_content ".overview-count { font-size:11px; text-align:center; font-variant-numeric:tabular-nums; }\n"
    append css_content ".overview-actions { display:grid; grid-template-columns:44px repeat(2,minmax(0,1fr)); gap:6px; align-items:stretch; }\n"
    append css_content ".overview-actions button { min-width:0; padding:8px 2px; font-size:11px; white-space:nowrap; }\n\n"
    
    append css_content "#overview-rows { display:flex; flex-direction:column; }\n"
    append css_content ".monitor-settings > label:not(.option-row) { display:block; margin:12px 0; }\n"
    append css_content ".monitor-settings .option-row input { appearance:auto; width:13px; height:13px; min-width:13px; background:none; }\n"
    append css_content ".overview-link { padding:8px 0; border-bottom:1px solid #bbb; overflow-wrap:anywhere; }\n"
    append css_content ".overview-link p { margin:4px 0; }\n\n"
    
    append css_content ".overview-row .overview-retry { width:24px; min-width:24px; height:26px; min-height:26px; padding:0; background-image:var(--icon-reset); background-size:20px; background-position:center; background-repeat:no-repeat; }\n\n"
    
    append css_content ".top-setting input { appearance:auto; -webkit-appearance:checkbox; width:13px; height:13px; min-width:13px; background:none; }\n\n"
    
    append css_content ".overview-visually-hidden { position:absolute; width:1px; height:1px; padding:0; margin:-1px; overflow:hidden; clip:rect(0,0,0,0); white-space:nowrap; border:0; }\n"
    append css_content ".overview-row\[hidden\] { display:none; }\n"
    
    return $css_content
}

proc write_css_to_file {filename} {
    set css_content [generate_css]
    set fh [open $filename w]
    puts $fh $css_content
    close $fh
}

# Main execution
if {$argc != 1} {
    puts "Usage: $argv0 <output_filename>"
    exit 1
}

set output_file [lindex $argv 0]
write_css_to_file $output_file

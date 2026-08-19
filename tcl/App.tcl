#!/usr/bin/env tclsh
# App.css — portiert nach tcl
# Quelle: css, OpenClaw@main:src/App.css
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

proc generateCSS {} {
    set css ""

    # Root styles
    append css ":root {\n"
    append css "  color-scheme: dark;\n"
    append css "  font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif;\n"
    append css "  background: #0b1020;\n"
    append css "  color: #eef2ff;\n"
    append css "}\n\n"

    # Universal selector
    append css "* {\n"
    append css "  box-sizing: border-box;\n"
    append css "}\n\n"

    # Body styles
    append css "body {\n"
    append css "  margin: 0;\n"
    append css "  min-width: 320px;\n"
    append css "  min-height: 100vh;\n"
    append css "  background:\n"
    append css "    radial-gradient(circle at 20% 20%, rgba(56, 189, 248, 0.22), transparent 30rem),\n"
    append css "    radial-gradient(circle at 80% 10%, rgba(168, 85, 247, 0.2), transparent 28rem),\n"
    append css "    linear-gradient(135deg, #050816 0%, #111827 55%, #172033 100%);\n"
    append css "}\n\n"

    # Page shell
    append css ".page-shell {\n"
    append css "  min-height: 100vh;\n"
    append css "  display: grid;\n"
    append css "  place-items: center;\n"
    append css "  padding: 2rem;\n"
    append css "}\n\n"

    # Hero card
    append css ".hero-card {\n"
    append css "  width: min(100%, 56rem);\n"
    append css "  padding: clamp(2rem, 6vw, 4.5rem);\n"
    append css "  border: 1px solid rgba(148, 163, 184, 0.28);\n"
    append css "  border-radius: 2rem;\n"
    append css "  background: rgba(15, 23, 42, 0.72);\n"
    append css "  box-shadow: 0 2rem 6rem rgba(0, 0, 0, 0.35);\n"
    append css "  backdrop-filter: blur(18px);\n"
    append css "}\n\n"

    # Eyebrow
    append css ".eyebrow {\n"
    append css "  margin: 0 0 1rem;\n"
    append css "  color: #67e8f9;\n"
    append css "  font-size: 0.8rem;\n"
    append css "  font-weight: 700;\n"
    append css "  letter-spacing: 0.18em;\n"
    append css "  text-transform: uppercase;\n"
    append css "}\n\n"

    # Heading 1
    append css "h1 {\n"
    append css "  margin: 0;\n"
    append css "  max-width: 12ch;\n"
    append css "  font-size: clamp(2.75rem, 8vw, 6rem);\n"
    append css "  line-height: 0.95;\n"
    append css "  letter-spacing: -0.06em;\n"
    append css "}\n\n"

    # Lead paragraph
    append css ".lead {\n"
    append css "  margin: 1.5rem 0 0;\n"
    append css "  max-width: 42rem;\n"
    append css "  color: #cbd5e1;\n"
    append css "  font-size: clamp(1.05rem, 2vw, 1.35rem);\n"
    append css "  line-height: 1.65;\n"
    append css "}\n\n"

    # Link grid container
    append css ".link-grid {\n"
    append css "  display: grid;\n"
    append css "  gap: 0.85rem;\n"
    append css "  margin-top: 2rem;\n"
    append css "}\n\n"

    # Link grid items
    append css ".link-grid a {\n"
    append css "  display: flex;\n"
    append css "  align-items: center;\n"
    append css "  justify-content: space-between;\n"
    append css "  gap: 1rem;\n"
    append css "  padding: 1rem 1.15rem;\n"
    append css "  border: 1px solid rgba(148, 163, 184, 0.25);\n"
    append css "  border-radius: 1rem;\n"
    append css "  color: #f8fafc;\n"
    append css "  text-decoration: none;\n"
    append css "  background: rgba(255, 255, 255, 0.06);\n"
    append css "}\n\n"

    # Link hover and focus states
    append css ".link-grid a:hover,\n"
    append css ".link-grid a:focus-visible {\n"
    append css "  border-color: rgba(103, 232, 249, 0.75);\n"
    append css "  outline: none;\n"
    append css "  background: rgba(103, 232, 249, 0.12);\n"
    append css "}\n"

    return $css
}

# Main execution
if {$argc != 1} {
    puts stderr "Usage: $argv0 <output-file>"
    exit 1
}

set outputFile [lindex $argv 0]
set cssContent [generateCSS]

# Write to file
if {[catch {set fh [open $outputFile w]} errorMsg]} {
    puts stderr "Error: Could not open file '$outputFile' for writing: $errorMsg"
    exit 1
}

puts $fh $cssContent
close $fh

puts "CSS file generated successfully: $outputFile"

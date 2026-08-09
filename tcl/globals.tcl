#!/usr/bin/env tclsh
# globals.css — portiert nach tcl
# Quelle: css, Onboarding@main:app/globals.css
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

# Tcl script to generate globals.css file

proc writeGlobalsCss {filename} {
    set fh [open $filename w]
    
    puts $fh "@import \"tailwindcss\";"
    puts $fh ""
    puts $fh ":root {"
    
    # Color variables
    set colors [dict create \
        bg "#faf8f4" \
        surface "#ffffff" \
        surface-2 "#f1eee7" \
        ink "#1b1a17" \
        ink-2 "#3c3a34" \
        muted "#6e6a61" \
        line "#e5e1d8" \
        line-strong "#d4cfc3" \
        accent "#a8542f" \
        accent-press "#8e4526" \
        accent-tint "#f1e5dd" \
        on-accent "#ffffff" \
        accent-2 "#2e7d7b" \
        accent-2-press "#225e5b" \
        accent-3 "#c77d2e" \
        footer-bg "#191815" \
        footer-fg "#efeae0" \
        footer-muted "#9a958a" \
        success "#2e7d5b" \
        danger "#9e3f32"]
    
    foreach {name value} $colors {
        puts $fh "  --$name: $value;"
    }
    
    # Font variables
    puts $fh "  --font-display: \"Iowan Old Style\", \"Palatino Linotype\", Georgia, \"Times New Roman\", serif;"
    puts $fh "  --font-sans: \"Segoe UI\", Inter, system-ui, -apple-system, sans-serif;"
    puts $fh "  --font-mono: \"Cascadia Code\", \"SFMono-Regular\", Consolas, ui-monospace, monospace;"
    
    # Space variables
    set spaces [dict create \
        1 "0.25rem" \
        2 "0.5rem" \
        3 "0.75rem" \
        4 "1rem" \
        5 "1.25rem" \
        6 "1.5rem" \
        8 "2rem" \
        10 "2.5rem" \
        12 "3rem" \
        16 "4rem" \
        20 "5rem" \
        24 "6rem" \
        30 "7.5rem"]
    
    foreach {num value} $spaces {
        puts $fh "  --space-$num: $value;"
    }
    
    # Radius variables
    puts $fh "  --radius-sm: 0.375rem;"
    puts $fh "  --radius-md: 0.625rem;"
    puts $fh "  --radius-lg: 1.125rem;"
    puts $fh "  --radius-pill: 999px;"
    
    # Shadow variables
    puts $fh "  --shadow-sm: 0 1px 2px rgb(27 26 23 / 6%);"
    puts $fh "  --shadow-md: 0 10px 30px -16px rgb(27 26 23 / 22%);"
    puts $fh "  --shadow-lg: 0 34px 70px -34px rgb(27 26 23 / 32%);"
    
    # Other variables
    puts $fh "  --container: 75rem;"
    puts $fh "  --motion-fast: 180ms;"
    puts $fh "  --motion-base: 350ms;"
    puts $fh "  --motion-slow: 800ms;"
    puts $fh "  --ease-out: cubic-bezier(0.22, 0.61, 0.36, 1);"
    puts $fh "}"
    puts $fh ""
    
    # Theme inline section
    puts $fh "@theme inline {"
    set themeColors [list bg surface surface-2 ink ink-2 muted line line-strong accent accent-2 accent-3]
    foreach color $themeColors {
        puts $fh "  --color-$color: var(--$color);"
    }
    puts $fh "  --font-display: var(--font-display);"
    puts $fh "  --font-sans: var(--font-sans);"
    puts $fh "  --font-mono: var(--font-mono);"
    puts $fh "}"
    puts $fh ""
    
    # Base styles
    puts $fh "* { box-sizing: border-box; }"
    puts $fh "html { scroll-behavior: smooth; }"
    puts $fh "body {"
    puts $fh "  margin: 0;"
    puts $fh "  background: var(--bg);"
    puts $fh "  color: var(--ink);"
    puts $fh "  font-family: var(--font-sans);"
    puts $fh "  line-height: 1.5;"
    puts $fh "  -webkit-font-smoothing: antialiased;"
    puts $fh "}"
    puts $fh "a { color: inherit; }"
    puts $fh "button, input, textarea { font: inherit; }"
    puts $fh "::selection { background: var(--accent-tint); color: var(--ink); }"
    puts $fh ""
    
    # Utility classes
    puts $fh ".display {"
    puts $fh "  font-family: var(--font-display);"
    puts $fh "  font-weight: 400;"
    puts $fh "  letter-spacing: -0.022em;"
    puts $fh "}"
    puts $fh ".eyebrow {"
    puts $fh "  font-family: var(--font-mono);"
    puts $fh "  font-size: 0.75rem;"
    puts $fh "  letter-spacing: 0.16em;"
    puts $fh "  text-transform: uppercase;"
    puts $fh "}"
    puts $fh ".focus-ring:focus-visible {"
    puts $fh "  outline: 2px solid var(--accent);"
    puts $fh "  outline-offset: 4px;"
    puts $fh "}"
    puts $fh ".content-auto { content-visibility: auto; contain-intrinsic-size: 1px 800px; }"
    puts $fh ""
    
    # Media query for reduced motion
    puts $fh "@media (prefers-reduced-motion: reduce) {"
    puts $fh "  html { scroll-behavior: auto; }"
    puts $fh "  *, *::before, *::after {"
    puts $fh "    animation-duration: 0.01ms !important;"
    puts $fh "    animation-iteration-count: 1 !important;"
    puts $fh "    scroll-behavior: auto !important;"
    puts $fh "    transition-duration: 0.01ms !important;"
    puts $fh "  }"
    puts $fh "}"
    puts $fh ""
    
    # Header hiding comment and styles
    puts $fh "/* Header ausblenden solange PondExperience aktiv ist (data-hero-immersive) */"
    puts $fh "body[data-hero-immersive=\"true\"] > header,"
    puts $fh "body[data-hero-immersive=\"true\"] header[data-site-header] {"
    puts $fh "  opacity: 0;"
    puts $fh "  pointer-events: none;"
    puts $fh "  transition: opacity 0.4s ease-out;"
    puts $fh "}"
    puts $fh ""
    
    # Keyframes for dropfall animation
    puts $fh "/* Wassertropfen die frontal am Screen herunterlaufen (Splash-Overlay) */"
    puts $fh "@keyframes dropfall {"
    puts $fh "  0% {"
    puts $fh "    transform: translateY(0);"
    puts $fh "    opacity: 0;"
    puts $fh "  }"
    puts $fh "  10% {"
    puts $fh "    opacity: 0.9;"
    puts $fh "  }"
    puts $fh "  90% {"
    puts $fh "    opacity: 0.7;"
    puts $fh "  }"
    puts $fh "  100% {"
    puts $fh "    transform: translateY(110vh);"
    puts $fh "    opacity: 0;"
    puts $fh "  }"
    puts $fh "}"
    
    close $fh
}

# Main execution
if {$argc != 1} {
    puts "Usage: $argv0 <output-file>"
    exit 1
}

set outputFile [lindex $argv 0]
writeGlobalsCss $outputFile

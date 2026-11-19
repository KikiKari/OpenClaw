#!/usr/bin/env tcl
# abstraction-provenance: {"artifact_sha256": "3bf2dce4a856f9bd5069c2425bc279f8be2bb35b55cd52db80b94fc0d481e231", "source_sha256": "e3bab1624f203b949716145357872ec8001a11d44b45121002215386ca7164b3", "target_language": "tcl"}
# style.css — portiert nach tcl
# Quelle: css, workspace@local:skills/github-clones/openclaw/docs/style.css
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

proc writeCSS {filename} {
    set cssContent [getCSSContent]
    set fileHandle [open $filename w]
    puts $fileHandle $cssContent
    close $fileHandle
}

proc getCSSContent {} {
    return {
#content > h1:first-of-type {
  display: none !important;
}

.nav-tabs {
  position: relative;
}

.nav-tabs-item > div {
  opacity: 0;
}

.nav-tabs-underline {
  position: absolute;
  left: 0;
  bottom: 0;
  height: 1.5px;
  width: var(--nav-tab-underline-width, 0);
  transform: translateX(var(--nav-tab-underline-x, 0));
  background-color: rgb(var(--primary));
  border-radius: 999px;
  pointer-events: none;
  opacity: 0;
  transition:
    transform 260ms ease-in-out,
    width 260ms ease-in-out,
    opacity 160ms ease-in-out;
  will-change: transform, width;
}

html.dark .nav-tabs-underline {
  background-color: rgb(var(--primary-light));
}

.nav-tabs-underline-ready .nav-tabs-underline {
  opacity: 1;
}
    }
}

# Main execution
if {$argc != 1} {
    puts "Usage: [info script] <output-file>"
    exit 1
}

set outputFile [lindex $argv 0]
writeCSS $outputFile

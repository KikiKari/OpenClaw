#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "6571772627136efa54b97ad3813bbbffdcbb8ea43246b4b10f7986e9de4997df", "source_sha256": "a1805aea1655d2760f0aa6fe9d137718ec6b67c1eb8b7d25c2b93d461eea3215", "target_language": "tcl"}
# build-docs-list.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/build-docs-list.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

package require fileutil

# Bestimme das Wurzelverzeichnis relativ zum aktuellen Skript
set scriptDir [file dirname [file normalize $argv0]]
set root [file normalize [file join $scriptDir ".."]]
set binDir [file join $root "bin"]
set binPath [file join $binDir "docs-list"]

# Erstelle das bin-Verzeichnis rekursiv
file mkdir $binDir

# Wrapper-Inhalt für die docs-list-Datei
set wrapper {#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const script = path.join(here, "..", "scripts", "docs-list.js");

const result = spawnSync(process.execPath, [script], { stdio: "inherit" });
process.exit(result.status ?? 1);
}

# Schreibe den Wrapper in die Zieldatei mit Ausführungsrechten
set fd [open $binPath w]
puts -nonewline $fd $wrapper
close $fd

# Setze die Dateirechte auf 755 (rwxr-xr-x)
file attributes $binPath -permissions 0755

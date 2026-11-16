#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "946bf1bd9cbc97d6f87d1cf6329a953a280c73c226a031ee9ba862ee80e79a11", "source_sha256": "25e94789e3af346018b091c7c4d6d65632394c19fcf9eaaeac876efbe534149a", "target_language": "powershell"}
# bundle-a2ui.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/bundle-a2ui.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"
$ROOT_DIR = (Resolve-Path "$PSScriptRoot/..").Path
& node "$ROOT_DIR/scripts/bundle-a2ui.mjs" @args

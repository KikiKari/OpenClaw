#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "52a42a1097c4e6436d4ab299ee28017712be51777f50a1533c2ef10e3d8bc71a", "source_sha256": "25e94789e3af346018b091c7c4d6d65632394c19fcf9eaaeac876efbe534149a", "target_language": "ruby"}
# bundle-a2ui.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/bundle-a2ui.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

root_dir = File.expand_path('..', __dir__)
exec('node', "#{root_dir}/scripts/bundle-a2ui.mjs", *ARGV)

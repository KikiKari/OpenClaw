#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "530ef7d0c7865588c3831dd10e4ca58f031ae758191c531fbf4c20fca121ff4a", "source_sha256": "38f82799f0ca285828fb717a736b87169329e2393ab0778a9019dae9e817c6ec", "target_language": "ruby"}
# tiktok-common.js — portiert nach ruby
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/tiktok-common.js
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

# Reuse the basic skill's normalization, load, selector, URL, and result
# contract so both extractors classify identical inputs consistently.
require_relative '../../tiktok-live/scripts/tiktok-common'

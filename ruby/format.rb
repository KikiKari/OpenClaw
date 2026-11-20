#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "82466c694868388a2d92dab3d46dfb58a929c5cdace1ae74df3c72bbd0e4120f", "source_sha256": "ed82b1410f121f3b1436d54099143d7010035ba702c64f21d2669fce9dd3f2ae", "target_language": "ruby"}
# format.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/Swabble/scripts/format.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

require 'pathname'

root = Pathname.new(__FILE__).dirname.parent.realpath.to_s
config = "#{root}/.swiftformat"
sources = "#{root}/Sources"

system("swiftformat", "--config", config, sources) or exit($?.exitstatus)

#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "0133689ff1c841cf953c3bd280c6636398af26c286c64eeb74f6e68ec7f2e29a", "source_sha256": "5fc2c92995e4c87536b6317eba7c9959c9babc16a20ce4476804921089ee2e34", "target_language": "ruby"}
# copy-plugin-sdk-root-alias.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/copy-plugin-sdk-root-alias.mjs
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

require "fileutils"

# Import shared functionality
require_relative "runtime-postbuild-shared"

def copy_plugin_sdk_root_alias(params = {})
  cwd = params[:cwd] || Dir.pwd
  source = File.join(cwd, "src/plugin-sdk/root-alias.cjs")
  target = File.join(cwd, "dist/plugin-sdk/root-alias.cjs")

  # Read source file content
  content = File.read(source, encoding: "utf-8")
  
  # Write to target if changed
  write_text_file_if_changed(target, content)
end

# Execute if called directly
if __FILE__ == $0
  copy_plugin_sdk_root_alias
end

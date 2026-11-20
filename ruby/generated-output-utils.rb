#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "f72337aa6907a9b913bafcf9c3fd1d42a1db17e3bc4dbaa8579e65f1dd2f9cb4", "source_sha256": "3c225928c07272d97d9f90c9c2134a117467308ab5be4a60ac9e89701f38b3e9", "target_language": "ruby"}
# generated-output-utils.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/generated-output-utils.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

require "pathname"
require_relative "../runtime-postbuild-shared"
require_relative "./bundled-plugin-source-utils"

def write_generated_output(params)
  output_path = Pathname.new(params[:repo_root]).join(params[:output_path]).to_s
  current = read_if_exists(output_path)
  changed = current != params[:next]

  if params[:check]
    return {
      changed: changed,
      wrote: false,
      output_path: output_path,
    }
  end

  {
    changed: changed,
    wrote: write_text_file_if_changed(output_path, params[:next]),
    output_path: output_path,
  }
end

def report_generated_output_cli(params)
  # In Ruby gibt es kein direktes Äquivalent zu import.meta.url
  # Wir prüfen stattdessen, ob das aktuelle Skript der Einstiegspunkt ist
  return unless caller.empty? || caller.first.include?(File.basename($0))

  check = ARGV.include?("--check")
  result = params[:run].call(check: check)
  return unless result[:changed]

  relative_output_path = Pathname.new(result[:output_path]).relative_path_from(Pathname.pwd).to_s
  if check
    $stderr.puts "[#{params[:label]}] stale generated output at #{relative_output_path}"
    exit 1
  end

  puts "[#{params[:label]}] wrote #{relative_output_path}"
end

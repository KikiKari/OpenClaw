#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "7945fca4e04d8b3cc7df6b754399538daea724132e10da46968a3da8705d3333", "source_sha256": "bf11781342e249f3bb5e5746f94668968b3fed5b83b099b77d5a9bb8ec38b713", "target_language": "ruby"}
# filter-staged-files.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/pre-commit/filter-staged-files.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

# Prints selected files as NUL-delimited tokens to stdout.
#
# Usage:
#   ruby scripts/pre-commit/filter-staged-files.rb lint -- <files...>
#   ruby scripts/pre-commit/filter-staged-files.rb format -- <files...>
#
# Keep this dependency-free: the pre-commit hook runs in many environments.

mode = ARGV[0]
raw_args = ARGV[1..-1]
files = raw_args.first == "--" ? raw_args[1..-1] : raw_args

if mode != "lint" && mode != "format"
  STDERR.puts "usage: filter-staged-files.rb <lint|format> -- <files...>"
  exit 2
end

lint_exts = [".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs"].to_set
format_exts = [".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".json", ".md", ".mdx"].to_set
format_ignored_paths = ["src/canvas-host/a2ui/a2ui.bundle.js"].to_set

def should_select(file_path, mode, lint_exts, format_exts, format_ignored_paths)
  ext = File.extname(file_path).downcase
  if mode == "lint"
    return lint_exts.include?(ext)
  end
  if format_ignored_paths.include?(file_path)
    return false
  end
  return format_exts.include?(ext)
end

files.each do |file|
  if should_select(file, mode, lint_exts, format_exts, format_ignored_paths)
    print file
    print "\0"
  end
end

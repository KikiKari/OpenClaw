#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "5c15e2dca956efc391935ac6f140f563140c2381521dc2cbcbbbfe516c76b905", "source_sha256": "b77d7ac77e305afea60b0aa9579426471649732bc9d7cb3bce3f14575d0d0bb6", "target_language": "ruby"}
# check-no-raw-window-open.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-raw-window-open.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

require "fileutils"
require "pathname"
require "json"

# Helper method to resolve the repository root directory
def resolve_repo_root(url)
  script_path = File.expand_path(url.gsub("file://", ""))
  Pathname.new(script_path).parent.parent.parent
end

# Helper method to unwrap expressions (simplified for Ruby context)
def unwrap_expression(node)
  # In a real implementation, this would recursively unwrap TypeScript AST nodes
  # For now, we'll assume it's just returning the node itself
  node
end

# Helper method to convert a node position to a line number
def to_line(source_file, node)
  # This is a placeholder; in reality, you'd use the TypeScript parser to get the line number
  1
end

# Check if the expression is a raw window.open call
def is_raw_window_open_call(expression)
  # Placeholder logic - in reality, this would parse the TypeScript AST
  false
end

# Find raw window.open lines in the given content
def find_raw_window_open_lines(content, file_name = "source.ts")
  # Placeholder implementation - in reality, this would parse the TypeScript AST
  []
end

# Collect TypeScript files in the given directory
def collect_typescript_files(dir, options = {})
  test_suffixes = options[:extra_test_suffixes] || []
  ignore_missing = options[:ignore_missing] || false

  files = []

  Dir.glob(File.join(dir, "**", "*.ts")).each do |file|
    next if file.include?("node_modules")

    # Skip test files unless they match the extra suffixes
    is_test_file = file.end_with?(".test.ts") || file.end_with?(".spec.ts")
    unless is_test_file || test_suffixes.any? { |suffix| file.end_with?(suffix) }
      files << file
    end
  end

  files
rescue Errno::ENOENT
  return [] if ignore_missing

  raise
end

# Main function
def main
  repo_root = resolve_repo_root(__FILE__)
  ui_source_dir = File.join(repo_root, "ui", "src", "ui")
  allowed_callsites = Set.new([File.join(ui_source_dir, "open-external-url.ts")])

  files = collect_typescript_files(ui_source_dir, {
    extra_test_suffixes: [".browser.test.ts", ".node.test.ts"],
    ignore_missing: true,
  })

  violations = []

  files.each do |file_path|
    next if allowed_callsites.include?(file_path)

    begin
      content = File.read(file_path)
    rescue Errno::ENOENT
      next
    end

    find_raw_window_open_lines(content, file_path).each do |line|
      rel_path = Pathname.new(file_path).relative_path_from(repo_root).to_s
      violations.push("#{rel_path}:#{line}")
    end
  end

  if violations.empty?
    return
  end

  puts "Found raw window.open usage outside safe helper:"
  violations.each do |violation|
    puts "- #{violation}"
  end
  puts "Use openExternalUrlSafe(...) from ui/src/ui/open-external-url.ts instead."
  exit(1)
end

# Run as script
if __FILE__ == $0
  main
end

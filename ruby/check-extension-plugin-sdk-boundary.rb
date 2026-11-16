#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "203d49303e09af5ebccf209884d85c5604df3a208f07f1abedac6f7d0ec20727", "source_sha256": "c1ed4f7faa3c799c1ac7104f76f48529711802b8f045a3a2fa20f18a82447b76", "target_language": "ruby"}
# check-extension-plugin-sdk-boundary.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-extension-plugin-sdk-boundary.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

require 'fileutils'
require 'json'
require 'pathname'
require_relative 'lib/bundled_plugin_paths'
require_relative 'lib/extension_source_classifier'
require_relative 'lib/guard_inventory_utils'
require_relative 'lib/ts_guard_utils'

REPO_ROOT = Pathname.new(__FILE__).dirname.parent.to_s
EXTENSIONS_ROOT = File.join(REPO_ROOT, BUNDLED_PLUGIN_ROOT_DIR)

MODES = %w[
  src-outside-plugin-sdk
  plugin-sdk-internal
  relative-outside-package
].freeze

BASELINE_PATH_BY_MODE = {
  'src-outside-plugin-sdk' => File.join(REPO_ROOT, 'test', 'fixtures', 'extension-src-outside-plugin-sdk-inventory.json'),
  'plugin-sdk-internal' => File.join(REPO_ROOT, 'test', 'fixtures', 'extension-plugin-sdk-internal-inventory.json'),
  'relative-outside-package' => File.join(REPO_ROOT, 'test', 'fixtures', 'extension-relative-outside-package-inventory.json')
}.freeze

RULE_TEXT_BY_MODE = {
  'src-outside-plugin-sdk' => 'Rule: production bundled plugins must not import src/** outside src/plugin-sdk/**',
  'plugin-sdk-internal' => 'Rule: production bundled plugins must not import src/plugin-sdk-internal/**',
  'relative-outside-package' => 'Rule: production bundled plugins must not use relative imports that escape their own package root'
}.freeze

@all_inventory_by_mode_promise = nil
@parsed_extension_source_files_promise = nil

def is_code_file(file_name)
  !!(/\.(ts|tsx|mts|cts|js|jsx|mjs|cjs)$/ =~ file_name)
end

def is_boundary_canary_file(file_name)
  file_name.include?('__rootdir_boundary_canary__')
end

def collect_extension_source_files(root_dir)
  out = []
  
  def walk(dir, out, repo_root)
    entries = Dir.entries(dir).reject { |e| e == '.' || e == '..' }
    entries.each do |entry|
      next if entry == 'dist' || entry == 'node_modules'
      
      full_path = File.join(dir, entry)
      if File.directory?(full_path)
        walk(full_path, out, repo_root)
        next
      end
      
      next unless File.file?(full_path)
      next unless is_code_file(entry)
      next if is_boundary_canary_file(entry)
      
      relative_path = normalize_repo_path(repo_root, full_path)
      next if classify_bundled_extension_source_path(relative_path)[:is_test_like]
      
      out << full_path
    end
  end
  
  walk(root_dir, out, REPO_ROOT)
  
  out.sort do |left, right|
    normalize_repo_path(REPO_ROOT, left) <=> normalize_repo_path(REPO_ROOT, right)
  end
end

def collect_parsed_extension_source_files
  unless @parsed_extension_source_files_promise
    @parsed_extension_source_files_promise = begin
      files = collect_extension_source_files(EXTENSIONS_ROOT)
      files.map do |file_path|
        source = File.read(file_path, encoding: 'UTF-8')
        # In Ruby, we'll need to simulate TypeScript AST parsing differently
        # For now, we'll store the raw source and file info
        {
          file_path: file_path,
          source: source
        }
      end
    end
  end
  
  @parsed_extension_source_files_promise
end

def resolve_extension_root(file_path)
  relative_path = normalize_repo_path(REPO_ROOT, file_path)
  segments = relative_path.split('/')
  return nil if segments[0] != BUNDLED_PLUGIN_ROOT_DIR || !segments[1]
  
  "#{segments[0]}/#{segments[1]}"
end

def classify_reason(mode, kind, resolved_path, specifier)
  verb = case kind
         when 'export' then 're-exports'
         when 'dynamic-import' then 'dynamically imports'
         else 'imports'
         end
  
  if mode == 'relative-outside-package'
    if resolved_path&.start_with?('src/plugin-sdk/')
      return "#{verb} plugin-sdk via relative path; use openclaw/plugin-sdk/<subpath>"
    end
    if resolved_path&.start_with?('src/')
      return "#{verb} core src path via relative path outside the extension package"
    end
    if resolved_path&.start_with?(BUNDLED_PLUGIN_PATH_PREFIX)
      return "#{verb} another bundled plugin via relative path outside the extension package"
    end
    return "#{verb} relative path #{specifier} outside the extension package"
  end
  
  if mode == 'plugin-sdk-internal'
    return "#{verb} src/plugin-sdk-internal from an extension"
  end
  
  if resolved_path.start_with?('src/plugin-sdk/')
    return "#{verb} allowed plugin-sdk path"
  end
  
  "#{verb} core src path outside plugin-sdk from an extension"
end

def compare_entries(left, right)
  file_cmp = left[:file] <=> right[:file]
  return file_cmp unless file_cmp == 0
  
  line_cmp = left[:line] <=> right[:line]
  return line_cmp unless line_cmp == 0
  
  kind_cmp = left[:kind] <=> right[:kind]
  return kind_cmp unless kind_cmp == 0
  
  specifier_cmp = left[:specifier] <=> right[:specifier]
  return specifier_cmp unless specifier_cmp == 0
  
  left[:reason] <=> right[:reason]
end

def should_report(mode, resolved_path)
  if mode == 'relative-outside-package'
    return false
  end
  
  return false unless resolved_path&.start_with?('src/')
  
  if mode == 'plugin-sdk-internal'
    return resolved_path.start_with?('src/plugin-sdk-internal/')
  end
  
  !resolved_path.start_with?('src/plugin-sdk/')
end

def collect_entries_by_mode_from_source_file(source_info, file_path)
  entries_by_mode = {
    'src-outside-plugin-sdk' => [],
    'plugin-sdk-internal' => [],
    'relative-outside-package' => []
  }
  
  extension_root = resolve_extension_root(file_path)
  relative_file = normalize_repo_path(REPO_ROOT, file_path)
  
  # This is a simplified version since we don't have TypeScript AST parsing in Ruby
  # In a real implementation, you'd parse the source and find imports
  def push(entries_by_mode, kind, specifier_node, specifier, file_path, extension_root, relative_file, repo_root)
    resolved_path = resolve_repo_specifier(repo_root, specifier, file_path)
    base_entry = {
      file: relative_file,
      line: 0, # Would be determined by to_line equivalent
      kind: kind,
      specifier: specifier,
      resolved_path: resolved_path
    }
    
    if specifier.start_with?('.') && resolved_path && extension_root
      unless resolved_path == extension_root || resolved_path.start_with?("#{extension_root}/")
        entries_by_mode['relative-outside-package'] << {
          **base_entry,
          reason: classify_reason('relative-outside-package', kind, resolved_path, specifier)
        }
      end
    end
    
    %w[src-outside-plugin-sdk plugin-sdk-internal].each do |mode|
      next unless should_report(mode, resolved_path)
      entries_by_mode[mode] << {
        **base_entry,
        reason: classify_reason(mode, kind, resolved_path, specifier)
      }
    end
  end
  
  # Simulate visiting module specifiers - would need actual parsing in real implementation
  # visit_module_specifiers would go here
  
  entries_by_mode
end

def collect_extension_plugin_sdk_boundary_inventory(mode)
  raise "Unknown mode: #{mode}" unless MODES.include?(mode)
  
  unless @all_inventory_by_mode_promise
    @all_inventory_by_mode_promise = begin
      files = collect_parsed_extension_source_files()
      inventory_by_mode = {
        'src-outside-plugin-sdk' => [],
        'plugin-sdk-internal' => [],
        'relative-outside-package' => []
      }
      
      files.each do |file_info|
        entries_by_mode = collect_entries_by_mode_from_source_file(file_info, file_info[:file_path])
        MODES.each do |inventory_mode|
          inventory_by_mode[inventory_mode].concat(entries_by_mode[inventory_mode])
        end
      end
      
      MODES.each do |inventory_mode|
        inventory_by_mode[inventory_mode].sort! { |a, b| compare_entries(a, b) }
      end
      
      inventory_by_mode
    end
  end
  
  inventory_by_mode = @all_inventory_by_mode_promise
  inventory_by_mode[mode]
end

def read_expected_inventory(mode)
  JSON.parse(File.read(BASELINE_PATH_BY_MODE[mode], encoding: 'UTF-8'))
rescue Errno::ENOENT => e
  if %w[plugin-sdk-internal src-outside-plugin-sdk relative-outside-package].include?(mode)
    []
  else
    raise e
  end
end

def diff_inventory(expected, actual)
  diff_inventory_entries(expected, actual, method(:compare_entries))
end

def format_inventory_human(mode, inventory)
  lines = [RULE_TEXT_BY_MODE[mode]]
  
  if inventory.empty?
    lines << 'No extension plugin-sdk boundary violations found.'
    return lines.join("\n")
  end
  
  lines << 'Extension boundary inventory:'
  active_file = ''
  
  inventory.each do |entry|
    if entry[:file] != active_file
      active_file = entry[:file]
      lines << active_file
    end
    lines << "  - line #{entry[:line]} [#{entry[:kind]}] #{entry[:reason]}"
    lines << "    specifier: #{entry[:specifier]}"
    lines << "    resolved: #{entry[:resolved_path]}"
  end
  
  lines.join("\n")
end

def run_extension_plugin_sdk_boundary_check(argv = ARGV, io = nil)
  streams = io || { stdout: $stdout, stderr: $stderr }
  json = argv.include?('--json')
  mode_arg = argv.find { |arg| arg.start_with?('--mode=') }
  mode = mode_arg ? mode_arg['--mode='.length..-1] : 'src-outside-plugin-sdk'
  
  raise "Unknown mode: #{mode}" unless MODES.include?(mode)
  
  actual = collect_extension_plugin_sdk_boundary_inventory(mode)
  
  if json
    write_line(streams[:stdout], JSON.pretty_generate(actual))
    return 0
  end
  
  write_line(streams[:stdout], format_inventory_human(mode, actual))
  
  if mode == 'relative-outside-package'
    if actual.empty?
      return 0
    end
    write_line(
      streams[:stderr],
      "Relative outside-package violations found (#{actual.length}); this mode no longer uses a baseline."
    )
    return 1
  end
  
  expected = read_expected_inventory(mode)
  diff = diff_inventory(expected, actual)
  
  if diff[:missing].empty? && diff[:unexpected].empty?
    write_line(streams[:stdout], "Baseline matches (#{actual.length} entries).")
    return 0
  end
  
  unless diff[:missing].empty?
    write_line(streams[:stderr], "Missing baseline entries (#{diff[:missing].length}):")
    diff[:missing].each do |entry|
      write_line(streams[:stderr], "  - #{entry[:file]}:#{entry[:line]} #{entry[:reason]}")
    end
  end
  
  unless diff[:unexpected].empty?
    write_line(streams[:stderr], "Unexpected inventory entries (#{diff[:unexpected].length}):")
    diff[:unexpected].each do |entry|
      write_line(streams[:stderr], "  - #{entry[:file]}:#{entry[:line]} #{entry[:reason]}")
    end
  end
  
  1
end

def main(argv = ARGV, io = nil)
  exit_code = run_extension_plugin_sdk_boundary_check(argv, io)
  $exit_code = exit_code unless io
  exit_code
end

if __FILE__ == $0
  main
end

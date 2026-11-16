#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "941bda16ad9a7fa3dbc5b671704567fc6e50c5a07152b7f1adac75a0de5f6e38", "source_sha256": "913a32ef02a0f4e83bb9d65b279088c91abd5e717e9dbba62e17a4a50836e586", "target_language": "ruby"}
# check-architecture-smells.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-architecture-smells.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

require 'pathname'
require 'json'
require_relative 'lib/bundled_plugin_paths'
require_relative 'lib/guard_inventory_utils'
require_relative 'lib/ts_guard_utils'

REPO_ROOT = Pathname.new(__FILE__).dirname.parent.to_s.freeze
SCAN_ROOTS = resolve_source_roots(REPO_ROOT, ['src/plugin-sdk', 'src/plugins/runtime'])

def compare_entries(left, right)
  result = left[:category] <=> right[:category]
  return result unless result.zero?

  result = left[:file] <=> right[:file]
  return result unless result.zero?

  result = left[:line] <=> right[:line]
  return result unless result.zero?

  result = left[:kind] <=> right[:kind]
  return result unless result.zero?

  result = left[:specifier] <=> right[:specifier]
  return result unless result.zero?

  left[:reason] <=> right[:reason]
end

def push_entry(entries, entry)
  entries << entry
end

def scan_plugin_sdk_extension_facade_smells(source_file, file_path)
  relative_file = normalize_repo_path(REPO_ROOT, file_path)
  return [] unless relative_file.start_with?('src/plugin-sdk/')

  entries = []

  visit_module_specifiers(source_file) do |kind:, specifier:, specifier_node:|
    next unless kind == 'export'
    
    resolved_path = resolve_repo_specifier(REPO_ROOT, specifier, file_path)
    next unless resolved_path&.start_with?(BUNDLED_PLUGIN_PATH_PREFIX)

    push_entry(entries, {
      category: 'plugin-sdk-extension-facade',
      file: relative_file,
      line: to_line(source_file, specifier_node),
      kind: kind,
      specifier: specifier,
      resolvedPath: resolved_path,
      reason: 'plugin-sdk public surface re-exports extension-owned implementation'
    })
  end

  entries
end

def scan_runtime_type_implementation_smells(source_file, file_path)
  relative_file = normalize_repo_path(REPO_ROOT, file_path)
  return [] unless /^src\/plugins\/runtime\/types(?:-[^\/]+)?\.ts$/.match?(relative_file)

  entries = []

  visit_nodes(source_file) do |node|
    if node.type == 'ImportType' &&
       node.argument&.type == 'LiteralType' &&
       node.argument&.literal&.type == 'StringLiteral'
      
      specifier = node.argument.literal.text
      resolved_path = resolve_repo_specifier(REPO_ROOT, specifier, file_path)
      
      if resolved_path &&
         (/^src\/plugins\/runtime\/runtime-[^\/]+\.ts$/.match?(resolved_path) ||
          /^extensions\/[^\/]+\/runtime-api\.[^\/]+$/.match?(resolved_path))
        
        push_entry(entries, {
          category: 'runtime-type-implementation-edge',
          file: relative_file,
          line: to_line(source_file, node.argument.literal),
          kind: 'import-type',
          specifier: specifier,
          resolvedPath: resolved_path,
          reason: 'runtime type file references implementation shim directly'
        })
      end
    end
  end

  entries
end

def scan_runtime_service_locator_smells(source_file, file_path)
  relative_file = normalize_repo_path(REPO_ROOT, file_path)
  return [] unless relative_file.start_with?('src/plugin-sdk/') || 
                   relative_file.start_with?('src/plugins/runtime/')

  entries = []
  exported_names = Set.new
  runtime_store_calls = []
  mutable_state_nodes = []

  source_file.statements.each do |statement|
    if statement.type == 'FunctionDeclaration' && statement.name
      is_exported = statement.modifiers&.any? { |modifier| modifier.kind == 'ExportKeyword' }
      exported_names.add(statement.name.text) if is_exported
    elsif statement.type == 'VariableStatement'
      is_exported = statement.modifiers&.any? { |modifier| modifier.kind == 'ExportKeyword' }
      
      statement.declaration_list.declarations.each do |declaration|
        if declaration.name.type == 'Identifier' && is_exported
          exported_names.add(declaration.name.text)
        end
        
        if !is_exported && 
           (statement.declaration_list.flags & NODE_FLAGS_LET) != 0 &&
           declaration.name.type == 'Identifier'
          mutable_state_nodes.push(declaration.name)
        end
      end
    end
  end

  visit_nodes(source_file) do |node|
    if node.type == 'CallExpression' &&
       node.expression.type == 'Identifier' &&
       node.expression.text == 'createPluginRuntimeStore'
      runtime_store_calls.push(node.expression)
    end
  end

  getter_names = exported_names.select { |name| /^get[A-Z]/.match?(name) }.sort
  setter_names = exported_names.select { |name| /^set[A-Z]/.match?(name) }.sort

  if runtime_store_calls.length > 0 && getter_names.length > 0 && setter_names.length > 0
    runtime_store_calls.each do |call_node|
      push_entry(entries, {
        category: 'runtime-service-locator',
        file: relative_file,
        line: to_line(source_file, call_node),
        kind: 'runtime-store',
        specifier: 'createPluginRuntimeStore',
        resolvedPath: relative_file,
        reason: "exports paired runtime accessors (#{getter_names.join(', ')} / #{setter_names.join(', ')}) over module-global store state"
      })
    end
  end

  if mutable_state_nodes.length > 0 && getter_names.length > 0 && setter_names.length > 0
    mutable_state_nodes.each do |identifier|
      push_entry(entries, {
        category: 'runtime-service-locator',
        file: relative_file,
        line: to_line(source_file, identifier),
        kind: 'mutable-state',
        specifier: identifier.text,
        resolvedPath: relative_file,
        reason: "module-global mutable state backs exported runtime accessors (#{getter_names.join(', ')} / #{setter_names.join(', ')})"
      })
    end
  end

  entries
end

def collect_architecture_smells
  files = collect_typescript_files_from_roots(SCAN_ROOTS).sort do |left, right|
    normalize_repo_path(REPO_ROOT, left) <=> normalize_repo_path(REPO_ROOT, right)
  end

  collect_typescript_inventory({
    files: files,
    compare_entries: method(:compare_entries),
    collect_entries: ->(source_file, file_path) {
      scan_plugin_sdk_extension_facade_smells(source_file, file_path) +
      scan_runtime_type_implementation_smells(source_file, file_path) +
      scan_runtime_service_locator_smells(source_file, file_path)
    }
  })
end

def format_inventory_human(inventory)
  if inventory.empty?
    return 'No architecture smells found for the configured checks.'
  end

  lines = ['Architecture smell inventory:']
  active_category = ''
  active_file = ''

  inventory.each do |entry|
    if entry[:category] != active_category
      active_category = entry[:category]
      active_file = ''
      lines.push(entry[:category])
    end

    if entry[:file] != active_file
      active_file = entry[:file]
      lines.push("  #{active_file}")
    end

    lines.push("    - line #{entry[:line]} [#{entry[:kind]}] #{entry[:reason]}")
    lines.push("      specifier: #{entry[:specifier]}")
    lines.push("      resolved: #{entry[:resolvedPath]}")
  end

  lines.join("\n")
end

def run_architecture_smells_check(argv = ARGV, io = nil)
  streams = io || { stdout: $stdout, stderr: $stderr }
  json_flag = argv.include?('--json')
  inventory = collect_architecture_smells

  if json_flag
    write_line(streams[:stdout], JSON.pretty_generate(inventory))
    return 0
  end

  write_line(streams[:stdout], format_inventory_human(inventory))
  smell_count = inventory.length
  write_line(streams[:stdout], "#{smell_count} smell#{smell_count == 1 ? '' : 's'} found.")
  0
end

def main(argv = ARGV, io = nil)
  run_architecture_smells_check(argv, io)
end

if __FILE__ == $0
  exit(main)
end

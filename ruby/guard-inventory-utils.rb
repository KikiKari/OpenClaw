#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "ffdcb0c8bb9bbb563cfa1b74f6b20f53b5d69e43574a026afa0ff36a1d1f0670", "source_sha256": "f01a1a7ac46054c631b27d8f3e127238ed7417a0fe38ecb59857573bd355603f", "target_language": "ruby"}
# guard-inventory-utils.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/guard-inventory-utils.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'pathname'

$parsed_type_script_source_cache = {}

def normalize_repo_path(repo_root, file_path)
  Pathname.new(file_path).relative_path_from(Pathname.new(repo_root)).to_s.gsub(File::SEPARATOR, '/')
end

def resolve_repo_specifier(repo_root, specifier, importer_file)
  if specifier.start_with?('.')
    normalized_path = Pathname.new(importer_file).dirname.join(specifier).cleanpath
    return normalize_repo_path(repo_root, normalized_path.to_s)
  end
  if specifier.start_with?('/')
    return normalize_repo_path(repo_root, specifier)
  end
  nil
end

def visit_module_specifiers(ts, source_file, &visit)
  walk = lambda do |node|
    if ts.is_import_declaration?(node) && ts.is_string_literal?(node.module_specifier)
      visit.call({
        kind: 'import',
        node: node,
        specifier: node.module_specifier.text,
        specifier_node: node.module_specifier
      })
    elsif ts.is_export_declaration?(node) &&
          node.module_specifier &&
          ts.is_string_literal?(node.module_specifier)
      visit.call({
        kind: 'export',
        node: node,
        specifier: node.module_specifier.text,
        specifier_node: node.module_specifier
      })
    elsif ts.is_call_expression?(node) &&
          node.expression.kind == ts.syntax_kind.import_keyword &&
          node.arguments.length == 1 &&
          ts.is_string_literal?(node.arguments[0])
      visit.call({
        kind: 'dynamic-import',
        node: node,
        specifier: node.arguments[0].text,
        specifier_node: node.arguments[0]
      })
    end

    ts.for_each_child(node, &walk)
  end

  walk.call(source_file)
end

def diff_inventory_entries(expected, actual, compare_entries)
  expected_keys = expected.map { |entry| JSON.generate(entry) }.to_set
  actual_keys = actual.map { |entry| JSON.generate(entry) }.to_set
  
  {
    missing: expected.select { |entry| !actual_keys.include?(JSON.generate(entry)) }.sort(&compare_entries),
    unexpected: actual.select { |entry| !expected_keys.include?(JSON.generate(entry)) }.sort(&compare_entries)
  }
end

def write_line(stream, text)
  stream.puts(text)
end

async def collect_type_script_inventory(params)
  inventory = []
  script_kind = params[:script_kind] || params[:ts].script_kind.ts

  params[:files].each do |file_path|
    cache_key = "#{script_kind}:#{file_path}"
    source_file = $parsed_type_script_source_cache[cache_key]
    
    unless source_file
      source = File.read(file_path, encoding: 'UTF-8')
      next if params[:should_parse_source] && !params[:should_parse_source].call(source, file_path)
      
      source_file = params[:ts].create_source_file(
        file_path,
        source,
        params[:ts].script_target.latest,
        true,
        script_kind
      )
      $parsed_type_script_source_cache[cache_key] = source_file
    end
    
    inventory.concat(params[:collect_entries].call(source_file, file_path))
  end

  inventory.sort(&params[:compare_entries])
end

async def run_baseline_inventory_check(params)
  streams = params[:io] || { stdout: $stdout, stderr: $stderr }
  json = params[:argv].include?('--json')
  
  actual = await params[:collect_actual].call
  expected = await params[:read_expected].call
  diff_result = params[:diff_inventory].call(expected, actual)
  missing = diff_result[:missing]
  unexpected = diff_result[:unexpected]
  matches_baseline = missing.empty? && unexpected.empty?

  if json
    write_line(streams[:stdout], JSON.pretty_generate(actual))
  else
    write_line(streams[:stdout], params[:format_inventory_human].call(actual))
    message = if matches_baseline
                "Baseline matches (#{actual.length} entries)."
              else
                "Baseline mismatch (#{unexpected.length} unexpected, #{missing.length} missing)."
              end
    write_line(streams[:stdout], message)
    
    unless matches_baseline
      if unexpected.length > 0
        write_line(streams[:stderr], 'Unexpected entries:')
        unexpected.each do |entry|
          write_line(streams[:stderr], "- #{params[:format_entry].call(entry)}")
        end
      end
      
      if missing.length > 0
        write_line(streams[:stderr], 'Missing baseline entries:')
        missing.each do |entry|
          write_line(streams[:stderr], "- #{params[:format_entry].call(entry)}")
        end
      end
    end
  end

  matches_baseline ? 0 : 1
end

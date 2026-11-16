#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "12cb771d4bf451eb9adc79c8822e3067363874d3c302511cc141c0c3fc558254", "source_sha256": "290dec5062f0c8675bc7304f9c93475a3e9667ed53e93894c5bc66f40e5ae5df", "target_language": "ruby"}
# check-no-random-messaging-tmp.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-random-messaging-tmp.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

require 'pathname'
require_relative 'lib/bundled_plugin_paths'
require_relative 'lib/callsite_guard'
require_relative 'lib/ts_guard_utils'

MESSAGING_TMPDIR_GUARD_SOURCE_ROOTS = [
  "src/channels",
  "src/infra/outbound",
  "src/line",
  "src/media",
  "src/media-understanding",
  "extensions",
].freeze

ALLOWED_RELATIVE_PATHS = Set.new([bundled_plugin_file("feishu", "src/dedup.ts")]).freeze

def collect_os_tmpdir_imports(source_file)
  os_module_specifiers = Set.new(["node:os", "os"])
  os_namespace_or_default = Set.new
  named_tmpdir = Set.new
  
  source_file[:statements].each do |statement|
    next unless statement[:type] == 'ImportDeclaration'
    next unless statement[:importClause] && statement[:moduleSpecifier][:type] == 'StringLiteral'
    
    module_specifier_text = statement[:moduleSpecifier][:text]
    next unless os_module_specifiers.include?(module_specifier_text)
    
    clause = statement[:importClause]
    if clause[:name]
      os_namespace_or_default.add(clause[:name][:text])
    end
    
    next unless clause[:namedBindings]
    
    if clause[:namedBindings][:type] == 'NamespaceImport'
      os_namespace_or_default.add(clause[:namedBindings][:name][:text])
      next
    end
    
    clause[:namedBindings][:elements].each do |element|
      property_name_text = element[:propertyName] ? element[:propertyName][:text] : element[:name][:text]
      if property_name_text == "tmpdir"
        named_tmpdir.add(element[:name][:text])
      end
    end
  end
  
  { os_namespace_or_default: os_namespace_or_default, named_tmpdir: named_tmpdir }
end

def find_messaging_tmpdir_call_lines(content, file_name = "source.ts")
  source_file = TS.create_source_file(file_name, content, TS::ScriptTarget::Latest, true)
  imports_data = collect_os_tmpdir_imports(source_file)
  os_namespace_or_default = imports_data[:os_namespace_or_default]
  named_tmpdir = imports_data[:named_tmpdir]
  
  collect_call_expression_lines(TS, source_file) do |node|
    callee = unwrap_expression(node[:expression])
    
    if callee[:type] == 'PropertyAccessExpression' &&
       callee[:name][:text] == "tmpdir" &&
       callee[:expression][:type] == 'Identifier' &&
       os_namespace_or_default.include?(callee[:expression][:text])
      next callee
    end
    
    if callee[:type] == 'Identifier' && named_tmpdir.include?(callee[:text])
      next callee
    end
    
    nil
  end
end

def main
  run_callsite_guard(
    import_meta_url: __FILE__,
    source_roots: MESSAGING_TMPDIR_GUARD_SOURCE_ROOTS,
    find_call_lines: method(:find_messaging_tmpdir_call_lines),
    skip_relative_path: ->(relative_path) { ALLOWED_RELATIVE_PATHS.include?(relative_path) },
    header: "Found os.tmpdir()/tmpdir() usage in messaging/channel runtime sources:",
    footer: "Use resolvePreferredOpenClawTmpDir() or plugin-sdk temp helpers instead of host tmp defaults.",
    sort_violations: false
  )
end

run_as_script(__FILE__, method(:main))

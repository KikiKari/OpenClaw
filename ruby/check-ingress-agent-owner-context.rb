#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "5828854272b1b6e86c3b4706c4061918c492b93cb143c2c2091af892c26141b3", "source_sha256": "cfa6fdcce252a97fa8be4d621d55955657d2f6616d52330d880db2123e1db43b", "target_language": "ruby"}
# check-ingress-agent-owner-context.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-ingress-agent-owner-context.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

require 'pathname'
require_relative 'lib/bundled_plugin_paths'
require_relative 'lib/callsite_guard'
require_relative 'lib/ts_guard_utils'

SOURCE_ROOTS = [
  "src/gateway",
  bundled_plugin_file("discord", "src/voice")
]

ENFORCED_FILES = Set.new([
  bundled_plugin_file("discord", "src/voice/manager.ts"),
  "src/gateway/openai-http.ts",
  "src/gateway/openresponses-http.ts",
  "src/gateway/server-methods/agent.ts",
  "src/gateway/server-node-events.ts"
])

def find_legacy_agent_command_call_lines(content, file_name = "source.ts")
  source_file = TS::CreateSourceFile.call(file_name, content, TS::ScriptTarget::Latest, true)
  collect_call_expression_lines(TS, source_file) do |node|
    callee = unwrap_expression(node.expression)
    if callee.is_a?(TS::Identifier) && callee.text == "agentCommand"
      callee
    else
      nil
    end
  end
end

def main
  run_callsite_guard(
    import_meta_url: __FILE__,
    source_roots: SOURCE_ROOTS,
    find_call_lines: method(:find_legacy_agent_command_call_lines),
    skip_relative_path: ->(rel_path) { !ENFORCED_FILES.include?(rel_path.gsub(File::SEPARATOR, "/")) },
    header: "Found ingress callsites using local agentCommand() (must be explicit owner-aware):",
    footer: "Use agentCommandFromIngress(...) and pass senderIsOwner explicitly at ingress boundaries."
  )
end

run_as_script(__FILE__, method(:main))

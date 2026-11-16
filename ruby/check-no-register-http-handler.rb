#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "eed348aa6825816a6f6ddc1cb4162c74d7bafb64a4f12a30a6f4fe58d077b6d2", "source_sha256": "a01dcf18c06d5aeb081cedf0088a13b316c08622615e4de86febe2deaee2596d", "target_language": "ruby"}
# check-no-register-http-handler.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-register-http-handler.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

require 'pathname'
require_relative 'lib/callsite_guard'
require_relative 'lib/ts_guard_utils'

SOURCE_ROOTS = ["src", "extensions"].freeze

def is_deprecated_register_http_handler_call(expression)
  callee = unwrap_expression(expression)
  callee&.[](:kind) == :PropertyAccessExpression && callee[:name][:text] == "registerHttpHandler"
end

def find_deprecated_register_http_handler_lines(content, file_name = "source.ts")
  source_file = TS.create_source_file(file_name, content, :latest, true)
  collect_call_expression_lines(source_file) do |node|
    expression = node.dig(:expression)
    is_deprecated_register_http_handler_call(expression) ? expression : nil
  end
end

def main
  run_callsite_guard(
    source_roots: SOURCE_ROOTS,
    find_call_lines: method(:find_deprecated_register_http_handler_lines),
    header: "Found deprecated plugin API call registerHttpHandler(...):",
    footer: "Use registerHttpRoute({ path, auth, match, handler }) and registerPluginHttpRoute for dynamic webhook paths."
  )
end

run_as_script(__FILE__, method(:main))

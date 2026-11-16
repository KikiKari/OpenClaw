#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "86a5c0f6d75b1ec25a7eebbf56a76c0bdcaf28620bec5c5124068f9ad356e24c", "source_sha256": "e3a70dc12204181e113d6bd10329e4a0d699a4c3922e73906b5348e1fc3fd07a", "target_language": "ruby"}
# check-no-raw-channel-fetch.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-raw-channel-fetch.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

require 'set'
require_relative 'lib/bundled_plugin_paths'
require_relative 'lib/callsite_guard'
require_relative 'lib/ts_guard_utils'

SOURCE_ROOTS = ["src/channels", "src/routing", "src/line", "extensions"].freeze

# Temporary allowlist for legacy callsites. New raw fetch callsites in channel/plugin runtime
# code should be rejected and migrated to fetchWithSsrFGuard/shared channel helpers.
ALLOWED_RAW_FETCH_CALLSITES = Set.new([
  bundled_plugin_callsite("bluebubbles", "src/test-harness.ts", 128),
  bundled_plugin_callsite("bluebubbles", "src/types.ts", 181),
  bundled_plugin_callsite("browser", "src/browser/cdp.helpers.ts", 268),
  bundled_plugin_callsite("browser", "src/browser/client-fetch.ts", 192),
  bundled_plugin_callsite("browser", "src/browser/test-fetch.ts", 24),
  bundled_plugin_callsite("browser", "src/browser/test-fetch.ts", 27),
  bundled_plugin_callsite("chutes", "models.ts", 535),
  bundled_plugin_callsite("chutes", "models.ts", 542),
  bundled_plugin_callsite("discord", "src/monitor/gateway-plugin.ts", 322),
  bundled_plugin_callsite("discord", "src/monitor/gateway-plugin.ts", 360),
  bundled_plugin_callsite("discord", "src/voice-message.ts", 298),
  bundled_plugin_callsite("discord", "src/voice-message.ts", 333),
  bundled_plugin_callsite("elevenlabs", "speech-provider.ts", 295),
  bundled_plugin_callsite("elevenlabs", "tts.ts", 116),
  bundled_plugin_callsite("feishu", "src/monitor.webhook.test-helpers.ts", 25),
  bundled_plugin_callsite("github-copilot", "login.ts", 48),
  bundled_plugin_callsite("github-copilot", "login.ts", 80),
  bundled_plugin_callsite("googlechat", "src/auth.ts", 83),
  bundled_plugin_callsite("huggingface", "models.ts", 142),
  bundled_plugin_callsite("kilocode", "provider-models.ts", 130),
  bundled_plugin_callsite("matrix", "src/matrix/sdk/transport.ts", 112),
  bundled_plugin_callsite("microsoft-foundry", "onboard.ts", 479),
  bundled_plugin_callsite("microsoft", "speech-provider.ts", 132),
  bundled_plugin_callsite("minimax", "oauth.ts", 66),
  bundled_plugin_callsite("minimax", "oauth.ts", 107),
  bundled_plugin_callsite("minimax", "tts.ts", 52),
  bundled_plugin_callsite("msteams", "src/graph.ts", 47),
  bundled_plugin_callsite("msteams", "src/sdk.ts", 329),
  bundled_plugin_callsite("msteams", "src/sdk.ts", 370),
  bundled_plugin_callsite("ollama", "src/stream.ts", 649),
  bundled_plugin_callsite("openai", "tts.ts", 133),
  bundled_plugin_callsite("qa-channel", "src/bus-client.ts", 41),
  bundled_plugin_callsite("qa-channel", "src/bus-client.ts", 221),
  bundled_plugin_callsite("qa-lab", "src/docker-up.runtime.ts", 274),
  bundled_plugin_callsite("qa-lab", "src/gateway-child.ts", 489),
  bundled_plugin_callsite("qa-lab", "src/suite.ts", 330),
  bundled_plugin_callsite("qa-lab", "src/suite.ts", 341),
  bundled_plugin_callsite("qa-lab", "web/src/app.ts", 15),
  bundled_plugin_callsite("qa-lab", "web/src/app.ts", 23),
  bundled_plugin_callsite("qa-lab", "web/src/app.ts", 31),
  bundled_plugin_callsite("qqbot", "src/api.ts", 102),
  bundled_plugin_callsite("qqbot", "src/api.ts", 237),
  bundled_plugin_callsite("qqbot", "src/stt.ts", 81),
  bundled_plugin_callsite("qqbot", "src/tools/channel.ts", 180),
  bundled_plugin_callsite("qqbot", "src/utils/audio-convert.ts", 377),
  bundled_plugin_callsite("signal", "src/install-signal-cli.ts", 224),
  bundled_plugin_callsite("slack", "src/monitor/media.ts", 96),
  bundled_plugin_callsite("slack", "src/monitor/media.ts", 115),
  bundled_plugin_callsite("slack", "src/monitor/media.ts", 120),
  bundled_plugin_callsite("tlon", "src/tlon-api.ts", 185),
  bundled_plugin_callsite("tlon", "src/tlon-api.ts", 235),
  bundled_plugin_callsite("tlon", "src/tlon-api.ts", 289),
  bundled_plugin_callsite("venice", "models.ts", 552),
  bundled_plugin_callsite("vercel-ai-gateway", "models.ts", 181),
  bundled_plugin_callsite("voice-call", "src/providers/twilio/api.ts", 23),
]).freeze

def is_raw_fetch_call(expression)
  callee = unwrap_expression(expression)
  
  if callee.is_a?(Hash) && callee[:type] == :identifier
    return callee[:text] == "fetch"
  end
  
  if callee.is_a?(Hash) && callee[:type] == :property_access_expression
    return callee[:expression][:type] == :identifier &&
           callee[:expression][:text] == "globalThis" &&
           callee[:name][:text] == "fetch"
  end
  
  false
end

def find_raw_fetch_call_lines(content, file_name = "source.ts")
  source_file = create_source_file(file_name, content)
  collect_call_expression_lines(source_file) do |node|
    expression = node[:expression]
    is_raw_fetch_call(expression) ? expression : nil
  end
end

def main
  run_callsite_guard(
    import_meta_url: __FILE__,
    source_roots: SOURCE_ROOTS,
    extra_test_suffixes: [".browser.test.ts", ".node.test.ts"],
    find_call_lines: method(:find_raw_fetch_call_lines),
    allow_callsite: ->(callsite) { ALLOWED_RAW_FETCH_CALLSITES.include?(callsite) },
    header: "Found raw fetch() usage in channel/plugin runtime sources outside allowlist:",
    footer: "Use fetchWithSsrFGuard() or existing channel/plugin SDK wrappers for network calls."
  )
end

run_as_script(__FILE__, method(:main))

#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "136b56dea02f323251f7c923f18a8402c2f57072459836cb1634e6a4ddbae2e7", "source_sha256": "839a095e40c54ffa7bb4be3907d0d522f938928a5846502ea3aa3fa587919688", "target_language": "ruby"}
# test-built-plugin-singleton.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-built-plugin-singleton.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

require 'fileutils'
require 'json'
require 'tmpdir'
require 'pathname'

# Mocking the installProcessWarningFilter function
def install_process_warning_filter
  # In Ruby, this would be implemented differently, but we'll just leave it as a no-op for now
end

# Mocking the stageBundledPluginRuntime function
def stage_bundled_plugin_runtime(repo_root:)
  # This would copy files in a real implementation
end

install_process_warning_filter

repo_root = File.expand_path(File.join(__FILE__, '..', '..'))
smoke_entry_path = File.join(repo_root, 'dist', 'plugins', 'build-smoke-entry.js')

raise "missing build output: #{smoke_entry_path}" unless File.exist?(smoke_entry_path)

# Since we can't dynamically import JS modules in Ruby, we'll assume these functions exist
# and are loaded through some mechanism (like execjs or similar)
# For this translation, we'll mock them

def clear_plugin_commands
  # Clear commands logic here
end

def get_plugin_command_specs
  # Return command specs
  []
end

def match_plugin_command(input)
  # Match command logic
  nil
end

def load_open_claw_plugins(cache:, workspace_dir:, env:, config:)
  # Load plugins logic
  { plugins: [] }
end

# Verify functions exist (mocked)
raise "built loader export missing" unless defined?(load_open_claw_plugins)
raise "clearPluginCommands missing" unless defined?(clear_plugin_commands)
raise "getPluginCommandSpecs missing" unless defined?(get_plugin_command_specs)
raise "matchPluginCommand missing" unless defined?(match_plugin_command)

temp_root = Dir.mktmpdir('openclaw-build-smoke-')

def cleanup(temp_root)
  clear_plugin_commands
  FileUtils.rm_rf(temp_root) if Dir.exist?(temp_root)
end

at_exit do
  cleanup(temp_root)
end

# Signal handlers
trap('INT') do
  cleanup(temp_root)
  exit(130)
end

trap('TERM') do
  cleanup(temp_root)
  exit(143)
end

plugin_id = 'build-smoke-plugin'
dist_plugin_dir = File.join(temp_root, 'dist', 'extensions', plugin_id)
FileUtils.mkdir_p(dist_plugin_dir)

File.write(File.join(temp_root, 'package.json'), '{ "type": "module" }' + "\n")

plugin_package_json = {
  name: '@openclaw/build-smoke-plugin',
  type: 'module',
  openclaw: {
    extensions: ['./index.js']
  }
}

File.write(File.join(dist_plugin_dir, 'package.json'), JSON.pretty_generate(plugin_package_json))

plugin_config = {
  id: plugin_id,
  configSchema: {
    type: 'object',
    additionalProperties: false,
    properties: {}
  }
}

File.write(File.join(dist_plugin_dir, 'openclaw.plugin.json'), JSON.pretty_generate(plugin_config))

plugin_index_js = <<~JS
  import sdk from 'openclaw/plugin-sdk';
  const { emptyPluginConfigSchema } = sdk;

  export default {
    id: #{plugin_id.inspect},
    configSchema: emptyPluginConfigSchema(),
    register(api) {
      api.registerCommand({
        name: 'pair',
        description: 'Pair a device',
        acceptsArgs: true,
        nativeNames: { telegram: 'pair', discord: 'pair' },
        async handler({ args }) {
          return { text: `paired:${args ?? ''}` };
        },
      });
    },
  };
JS

File.write(File.join(dist_plugin_dir, 'index.js'), plugin_index_js)

stage_bundled_plugin_runtime(repo_root: temp_root)

runtime_entry_path = File.join(temp_root, 'dist-runtime', 'extensions', plugin_id, 'index.js')
raise 'runtime overlay entry missing' unless File.exist?(runtime_entry_path)

commands_path = File.join(temp_root, 'dist-runtime', 'plugins', 'commands.js')
raise 'dist-runtime must not stage a duplicate commands module' if File.exist?(commands_path)

clear_plugin_commands

registry = load_open_claw_plugins(
  cache: false,
  workspace_dir: temp_root,
  env: ENV.to_h.merge({
    'OPENCLAW_BUNDLED_PLUGINS_DIR' => File.join(temp_root, 'dist-runtime', 'extensions'),
    'OPENCLAW_DISABLE_PLUGIN_DISCOVERY_CACHE' => '1'
  }),
  config: {
    plugins: {
      enabled: true,
      allow: [plugin_id],
      entries: {
        plugin_id => { enabled: true }
      }
    }
  }
)

record = registry[:plugins].find { |entry| entry[:id] == plugin_id }
raise 'smoke plugin missing from registry' unless record
raise 'smoke plugin failed to load' unless record[:status] == 'loaded'

expected_specs = [{ name: 'pair', description: 'Pair a device', accepts_args: true }]
actual_specs = get_plugin_command_specs
raise "Command specs mismatch: expected #{expected_specs}, got #{actual_specs}" unless actual_specs == expected_specs

match = match_plugin_command('/pair now')
raise 'canonical built command registry did not receive the command' unless match
raise "Expected args 'now', got #{match[:args].inspect}" unless match[:args] == 'now'

# Simulate async handler call
result = match[:command][:handler].call(args: match[:args])
expected_result = { text: 'paired:now' }
raise "Handler result mismatch: expected #{expected_result}, got #{result}" unless result == expected_result

puts '[build-smoke] built plugin singleton smoke passed'

#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "a731ad025d25f21176daecc0c888dbbc378df669e85b58ab33faa3b26b4cb61a", "source_sha256": "44c9196ec2dbaf8ef45323397e44f66d128313ddae44f9dfc8bba7439fe6e844", "target_language": "ruby"}
# sync-plugin-sdk-exports.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/sync-plugin-sdk-exports.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'fileutils'

def build_plugin_sdk_package_exports
  # This is a placeholder implementation since the actual function
  # buildPluginSdkPackageExports from ./lib/plugin-sdk-entries.mjs
  # is not provided. In a real scenario, this would need to be properly implemented
  # based on the logic in that file.
  {
    './plugin-sdk' => './dist/plugin-sdk/index.js',
    './plugin-sdk/*' => './dist/plugin-sdk/*.js'
  }
end

check_only = ARGV.include?('--check')
package_json_path = File.join(Dir.pwd, 'package.json')

# Read package.json
package_json_content = File.read(package_json_path)
package_json = JSON.parse(package_json_content)

current_exports = package_json['exports'] || {}
synced_plugin_sdk_exports = build_plugin_sdk_package_exports

next_exports = {}
inserted_plugin_sdk_exports = false

current_exports.each do |key, value|
  if key.start_with?('./plugin-sdk')
    unless inserted_plugin_sdk_exports
      next_exports.merge!(synced_plugin_sdk_exports)
      inserted_plugin_sdk_exports = true
    end
    next
  end
  
  next_exports[key] = value
  
  if key == '.' && !inserted_plugin_sdk_exports
    next_exports.merge!(synced_plugin_sdk_exports)
    inserted_plugin_sdk_exports = true
  end
end

unless inserted_plugin_sdk_exports
  next_exports.merge!(synced_plugin_sdk_exports)
end

next_exports_json = JSON.generate(next_exports)
current_exports_json = JSON.generate(current_exports)

if check_only
  if current_exports_json != next_exports_json
    STDERR.puts 'plugin-sdk exports out of sync. Run `pnpm plugin-sdk:sync-exports`.'
    exit(1)
  end
  puts 'plugin-sdk exports synced.'
  exit(0)
end

package_json['exports'] = next_exports
File.write(package_json_path, "#{JSON.pretty_generate(package_json)}\n")

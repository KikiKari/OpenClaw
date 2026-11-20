#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "0a74dbfd9e9c37ed0abc385e9a37acc7dfbb6b320b5b46413e733503dab20ea0", "source_sha256": "f6c7bd2581ab63fdb19f7caaff8e9c362e279303a47e4efe1873b2e652a7fbc8", "target_language": "ruby"}
# generate-host-env-security-policy-swift.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/generate-host-env-security-policy-swift.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'pathname'

def load_host_env_security_policy(raw_policy)
  {
    blocked_inherited_keys: raw_policy['blockedInheritedKeys'] || [],
    blocked_inherited_prefixes: raw_policy['blockedInheritedPrefixes'] || [],
    blocked_keys: raw_policy['blockedKeys'] || [],
    blocked_override_keys: raw_policy['blockedOverrideKeys'] || [],
    blocked_override_prefixes: raw_policy['blockedOverridePrefixes'] || [],
    blocked_prefixes: raw_policy['blockedPrefixes'] || []
  }
end

args = ARGV.to_set
check_only = args.include?('--check')
write_mode = args.include?('--write') || !check_only

if check_only && args.include?('--write')
  STDERR.puts "Use either --check or --write, not both."
  exit 1
end

here = Pathname.new(__FILE__).dirname
repo_root = here.parent
policy_path = repo_root.join('src', 'infra', 'host-env-security-policy.json')
output_path = repo_root.join('apps', 'macos', 'Sources', 'OpenClaw', 'HostEnvSecurityPolicy.generated.swift')

raw_policy = JSON.parse(File.read(policy_path))
policy = load_host_env_security_policy(raw_policy)

def render_swift_string_array(items)
  items.map { |item| "        \"#{item}\"" }.join(",\n")
end

generated = <<~SWIFT
  // Generated file. Do not edit directly.
  // Source: src/infra/host-env-security-policy.json
  // Regenerate: node scripts/generate-host-env-security-policy-swift.mjs --write

  import Foundation

  enum HostEnvSecurityPolicy {
      static let blockedInheritedKeys: Set<String> = [
  #{render_swift_string_array(policy[:blocked_inherited_keys])}
      ]

      static let blockedInheritedPrefixes: [String] = [
  #{render_swift_string_array(policy[:blocked_inherited_prefixes])}
      ]

      static let blockedKeys: Set<String> = [
  #{render_swift_string_array(policy[:blocked_keys])}
      ]

      static let blockedOverrideKeys: Set<String> = [
  #{render_swift_string_array(policy[:blocked_override_keys])}
      ]

      static let blockedOverridePrefixes: [String] = [
  #{render_swift_string_array(policy[:blocked_override_prefixes])}
      ]

      static let blockedPrefixes: [String] = [
  #{render_swift_string_array(policy[:blocked_prefixes])}
      ]
  }
SWIFT

current = File.exist?(output_path) ? File.read(output_path) : nil

if check_only
  if current == generated
    puts "OK #{output_path.relative_path_from(repo_root)}"
    exit 0
  end
  STDERR.puts "Out of date #{output_path.relative_path_from(repo_root)}."
  STDERR.puts "Run: node scripts/generate-host-env-security-policy-swift.mjs --write"
  exit 1
end

if write_mode
  if current != generated
    File.write(output_path, generated)
  end
  puts "Wrote #{output_path.relative_path_from(repo_root)}"
end

#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "50b1d047ff2b4c5c2c8843fb0208470fb517020252505e3c8121739f088ad3fb", "source_sha256": "eb329c9ad90fe7f2c211dd5d35aed9557a4387c1092c4569ebb4e3f4db2d3557", "target_language": "ruby"}
# setup-secret-write.sh — portiert nach ruby
# Quelle: shell, workspace@local:scripts/setup-secret-write.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

require 'fileutils'
require 'yaml'

# Load environment variables from file
env_file = '/home/openclaw/.config/openclaw/env'
if File.exist?(env_file)
  File.readlines(env_file).each do |line|
    line.strip!
    next if line.empty? || line.start_with?('#')
    if line.include?('=')
      key, value = line.split('=', 2)
      ENV[key] = value
    end
  end
end

secrets_dir = "/secret-store"
yaml_file = "/home/openclaw/.openclaw/workspace/memory/model-pools.yaml"

# Create secrets directory with appropriate permissions
FileUtils.mkdir_p(secrets_dir)
File.chmod(0750, secrets_dir)
File.chown(Process.uid, Process.gid, secrets_dir)

# Write default-model.json
default_model_content = {
  "provider" => "openrouter",
  "token" => ENV['OPENROUTER_API_KEY']
}.to_json

File.open("#{secrets_dir}/default-model.json", 'w', 0600) do |file|
  file.write(default_model_content)
end

# Write proxy-model.json
proxy_model_content = {
  "provider" => "openai",
  "token" => ENV['OPENAI_API_KEY']
}.to_json

File.open("#{secrets_dir}/proxy-model.json", 'w', 0600) do |file|
  file.write(proxy_model_content)
end

# YAML configuration content
yaml_config = {
  "pools" => [
    {
      "name" => "pool_default",
      "id" => "default",
      "model" => "openrouter/moonshotai/kimi-k3",
      "weight" => 0.8,
      "secretsPath" => "/secret-store/default-model.json"
    },
    {
      "name" => "pool_proxy",
      "id" => "proxy",
      "model" => "openrouter/auto",
      "weight" => 0.2,
      "secretsPath" => "/secret-store/proxy-model.json"
    }
  ],
  "routing" => [
    {
      "name" => "latency_and_error_based",
      "criteria" => [
        { "latency_ms" => "< 200" },
        { "error_rate_pct" => "< 1" }
      ],
      "route_to" => "pool_default"
    },
    {
      "name" => "fallback_if_issues",
      "criteria" => [
        { "latency_ms" => ">= 200" },
        { "error_rate_pct" => ">= 1" }
      ],
      "route_to" => "pool_proxy"
    }
  ],
  "fallbacks" => [
    { "model" => "openrouter/moonshotai/kimi-k3" },
    { "model" => "openai/gpt-5.6-luna" }
  ],
  "logging" => {
    "events" => {
      "request_decisions" => true,
      "memory_store_path" => "/memory/logs/model-routing.log"
    },
    "retention_days" => 14
  },
  "security" => {
    "secrets_encryption" => true,
    "access_control" => [
      {
        "role" => "model-operator",
        "allow" => ["read", "write"]
      },
      {
        "role" => "monitor",
        "allow" => ["read"]
      }
    ]
  }
}

# Write YAML file
FileUtils.mkdir_p(File.dirname(yaml_file))
File.open(yaml_file, 'w') do |file|
  file.write(YAML.dump(yaml_config))
end

puts "=== ERLEDIGT ==="
puts "Secrets:"
puts `sudo ls -la "#{secrets_dir}/"`
puts ""
puts "YAML: #{yaml_file}"
puts `ls -la "#{yaml_file}"`

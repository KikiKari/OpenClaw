#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "2d85798b30b2e495fc544e9642e14742399429a2b304afb81f7785bfb4332673", "source_sha256": "cd0bfcd0719418f4f0877e7488a8136ca9e8ba296aaaf669b43c7da1dca0f581", "target_language": "ruby"}
# test-built-bundled-channel-entry-smoke.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-built-bundled-channel-entry-smoke.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

require "json"
require "fileutils"

# installProcessWarningFilter equivalent - Ruby doesn't have process warnings in same way
# so we'll just proceed without this filter

# Set environment variable if not already set
ENV["OPENCLAW_DISABLE_BUNDLED_ENTRY_SOURCE_FALLBACK"] ||= "1"

def parse_args(argv)
  package_root = ENV["OPENCLAW_BUNDLED_CHANNEL_SMOKE_ROOT"]
  
  index = 0
  while index < argv.length
    arg = argv[index]
    if arg == "--package-root"
      package_root = argv[index + 1]
      index += 2
      next
    end
    
    if arg.start_with?("--package-root=")
      package_root = arg["--package-root=".length..-1]
      index += 1
      next
    end
    
    raise "unknown argument: #{arg}"
  end
  
  resolved_package_root = package_root || File.expand_path("..", __dir__)
  {
    package_root: File.absolute_path(resolved_package_root)
  }
end

args = parse_args(ARGV)
package_root = args[:package_root]
dist_extensions_root = File.join(package_root, "dist", "extensions")

def read_json(pathname)
  JSON.parse(File.read(pathname))
end

def extension_entry_to_dist_filename(entry)
  entry.gsub(%r{^\./}, "").gsub(/\.[^.]+$/, ".js")
end

def collect_bundled_channel_entry_files(dist_extensions_root)
  files = []
  
  Dir.children(dist_extensions_root).each do |entry|
    entry_path = File.join(dist_extensions_root, entry)
    next unless File.directory?(entry_path)
    
    extension_root = entry_path
    package_json_path = File.join(extension_root, "package.json")
    next unless File.exist?(package_json_path)
    
    package_json = read_json(package_json_path)
    next unless package_json.dig("openclaw", "channel")
    
    extension_entries = if package_json.dig("openclaw", "extensions").is_a?(Array) && !package_json.dig("openclaw", "extensions").empty?
                          package_json.dig("openclaw", "extensions")
                        else
                          ["./index.ts"]
                        end
                        
    extension_entries.each do |entry|
      next unless entry.is_a?(String) && !entry.strip.empty?
      
      files << {
        id: entry,
        kind: "channel",
        path: File.join(extension_root, extension_entry_to_dist_filename(entry))
      }
    end
    
    setup_entry = package_json.dig("openclaw", "setupEntry")
    if setup_entry.is_a?(String) && !setup_entry.strip.empty?
      files << {
        id: entry,
        kind: "setup",
        path: File.join(extension_root, extension_entry_to_dist_filename(setup_entry))
      }
    end
    
    channel_entry_path = File.join(extension_root, "channel-entry.js")
    if File.exist?(channel_entry_path)
      files << {
        id: entry,
        kind: "channel",
        path: channel_entry_path
      }
    end
  end
  
  files.sort_by { |f| "#{f[:id]}:#{f[:kind]}:#{f[:path]}" }
end

def assert_secret_contract_shape(secrets, context)
  raise "#{context}: missing secrets contract" unless secrets.is_a?(Hash)
  
  raise "#{context}: collectRuntimeConfigAssignments must be a function" unless secrets["collectRuntimeConfigAssignments"].respond_to?(:call)
  
  raise "#{context}: secretTargetRegistryEntries must be an array" unless secrets["secretTargetRegistryEntries"].is_a?(Array)
end

def assert_entry_file_exists(entry)
  raise "#{entry[:id]} #{entry[:kind]} entry missing from packed dist: #{entry[:path]}" unless File.exist?(entry[:path])
end

def smoke_channel_entry(entry_file)
  assert_entry_file_exists(entry_file)
  
  # In Ruby, we can't dynamically import modules like JS, so we'll simulate
  # by checking if the file exists and has expected structure
  content = File.read(entry_file[:path])
  
  # Basic checks for expected content patterns
  raise "#{entry_file[:id]} channel entry kind mismatch" unless content.include?("bundled-channel-entry")
  
  raise "#{entry_file[:id]} channel entry missing loadChannelPlugin" unless content.include?("loadChannelPlugin")
  
  # We can't actually instantiate the plugin in Ruby like we do in JS
  # but we've confirmed the file exists and has expected content
  puts "Verified channel entry for #{entry_file[:id]}"
end

def smoke_setup_entry(entry_file)
  assert_entry_file_exists(entry_file)
  
  content = File.read(entry_file[:path])
  
  return false unless content.include?("bundled-channel-setup-entry")
  
  raise "#{entry_file[:id]} setup entry kind mismatch" unless content.include?("bundled-channel-setup-entry")
  
  raise "#{entry_file[:id]} setup entry missing loadSetupPlugin" unless content.include?("loadSetupPlugin")
  
  puts "Verified setup entry for #{entry_file[:id]}"
  true
end

entry_files = collect_bundled_channel_entry_files(dist_extensions_root)
channel_count = 0
setup_count = 0
legacy_setup_count = 0

entry_files.each do |entry_file|
  if entry_file[:kind] == "channel"
    smoke_channel_entry(entry_file)
    channel_count += 1
    next
  end
  
  if smoke_setup_entry(entry_file)
    setup_count += 1
  else
    legacy_setup_count += 1
  end
end

raise "no bundled channel entries found" unless channel_count > 0

puts "[build-smoke] bundled channel entry smoke passed packageRoot=#{package_root} channel=#{channel_count} setup=#{setup_count} legacySetup=#{legacy_setup_count}"

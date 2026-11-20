#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "f51848ac4ed03e0b77c0ae3815e98408da3595be6531ee130ad6b4d9d223ff88", "source_sha256": "5826d57477404d40d10bccd3a144f22f3f46ce4897073fa71d1d3868edfe8719", "target_language": "ruby"}
# format-generated-module.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/format-generated-module.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

require 'tmpdir'
require 'fileutils'
require 'open3'
require 'pathname'

def format_generated_module(source, repo_root:, output_path:, error_label:)
  resolved_repo_root = Pathname.new(repo_root).expand_path
  resolved_output_path = if Pathname.new(output_path).absolute?
                          Pathname.new(output_path)
                        else
                          resolved_repo_root + output_path
                        end
  direct_formatter_path = resolved_repo_root + 'node_modules' + '.bin' + 'oxfmt'
  use_direct_formatter = Gem.win_platform? == false && File.exist?(direct_formatter_path)
  command = use_direct_formatter ? direct_formatter_path.to_s : 'pnpm'
  
  temp_dir = Dir.mktmpdir('openclaw-generated-format-')
  temp_output_path = File.join(temp_dir, File.basename(resolved_output_path.to_s))
  
  begin
    File.write(temp_output_path, source, encoding: 'utf-8')
    
    args = if use_direct_formatter
             ['--write', temp_output_path]
           else
             ['exec', 'oxfmt', '--write', temp_output_path]
           end
           
    # Windows requires a shell to launch package-manager shim scripts reliably.
    opts = {}
    opts[:chdir] = resolved_repo_root.to_s
    opts[:external_encoding] = 'utf-8'
    if Gem.win_platform?
      opts[:shell] = true
    end
    
    stdout, stderr, status = Open3.capture3(command, *args, opts)
    
    unless status.success?
      details = stderr&.strip&.empty? ? nil : stderr.strip
      details ||= stdout&.strip&.empty? ? nil : stdout.strip
      details ||= 'unknown formatter failure'
      raise "failed to format generated #{error_label}: #{details}"
    end
    
    File.read(temp_output_path, encoding: 'utf-8')
  ensure
    FileUtils.rm_rf(temp_dir)
  end
end

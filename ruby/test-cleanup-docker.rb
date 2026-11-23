#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "09a9729aabbd9e741cab8805c27cbaf6985ba202607bc037b59caf9bab791e71", "source_sha256": "df77fd3273a53bf6d33c1c4df50c24d9526e06de477779a9b7a58f5b8ce3ed1d", "target_language": "ruby"}
# test-cleanup-docker.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/test-cleanup-docker.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

require 'pathname'
require 'fileutils'

# Get the root directory (equivalent to ROOT_DIR in bash)
root_dir = Pathname.new(__FILE__).dirname.parent.to_s

# Source the docker-e2e-logs.sh functionality
# In Ruby, we'll implement the necessary functions inline
def run_logged(name, *command)
  log_file = "logs/#{name}.log"
  FileUtils.mkdir_p(File.dirname(log_file))
  
  puts "Running: #{command.join(' ')}"
  system("echo '==> Build image: #{ENV['IMAGE_NAME']}'")
  
  # Execute command and log output
  begin
    output = `#{command.join(' ')} 2>&1`
    File.open(log_file, 'w') { |f| f.write(output) }
    
    unless $?.success?
      puts "Command failed: #{command.join(' ')}"
      puts output
      exit 1
    end
  rescue => e
    puts "Error executing command: #{e.message}"
    exit 1
  end
end

# Set environment variables with defaults (equivalent to IMAGE_NAME and PLATFORM)
image_name = ENV['OPENCLAW_CLEANUP_SMOKE_IMAGE'] || 'openclaw-cleanup-smoke:local'
platform = ENV['OPENCLAW_CLEANUP_SMOKE_PLATFORM'] || 'linux/amd64'

puts "==> Build image: #{image_name}"

# Run the docker build command with logging
run_logged(
  'cleanup-build',
  'docker', 'build',
  '-t', image_name,
  '-f', "#{root_dir}/scripts/docker/cleanup-smoke/Dockerfile",
  root_dir
)

puts "==> Run cleanup smoke test"
system("docker run --rm --platform #{platform} -t #{image_name}") || exit(1)

#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "f8cc639303f1401bdce5baa95af41b6a648632de3facc8ebd5d5c4aa7c8a4ba3", "source_sha256": "b31f1bce542d41c8328b88079d7d58fa9d018f246f3f05fa532df8fe4ef6e153", "target_language": "ruby"}
# sandbox-common-setup.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/sandbox-common-setup.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

require 'open3'
require 'shellwords'

# Set strict mode equivalent
def run_command(cmd)
  stdout, stderr, status = Open3.capture3(cmd)
  unless status.success?
    STDERR.puts stderr
    exit status.exitstatus
  end
  stdout
end

# Environment variables with defaults
base_image = ENV.fetch('BASE_IMAGE', 'openclaw-sandbox:bookworm-slim')
target_image = ENV.fetch('TARGET_IMAGE', 'openclaw-sandbox-common:bookworm-slim')
packages = ENV.fetch('PACKAGES', 'curl wget jq coreutils grep nodejs npm python3 git ca-certificates golang-go rustc cargo unzip pkg-config libasound2-dev build-essential file')
install_pnpm = ENV.fetch('INSTALL_PNPM', '1')
install_bun = ENV.fetch('INSTALL_BUN', '1')
bun_install_dir = ENV.fetch('BUN_INSTALL_DIR', '/opt/bun')
install_brew = ENV.fetch('INSTALL_BREW', '1')
brew_install_dir = ENV.fetch('BREW_INSTALL_DIR', '/home/linuxbrew/.linuxbrew')
final_user = ENV.fetch('FINAL_USER', 'sandbox')
use_buildx = ENV.fetch('OPENCLAW_DOCKER_BUILD_USE_BUILDX', '0')
cache_from = ENV.fetch('OPENCLAW_DOCKER_BUILD_CACHE_FROM', '')
cache_to = ENV.fetch('OPENCLAW_DOCKER_BUILD_CACHE_TO', '')

# Check if base image exists
begin
  run_command("docker image inspect #{base_image.shellescape}")
rescue
  puts "Base image missing: #{base_image}"
  puts "Building base image via scripts/sandbox-setup.sh..."
  run_command('scripts/sandbox-setup.sh')
end

puts "Building #{target_image} with: #{packages}"

# Build command construction
build_cmd = ['docker build']
if use_buildx == '1'
  build_cmd = ['docker', 'buildx', 'build', '--load']
  build_cmd += ['--cache-from', cache_from] if !cache_from.empty?
  build_cmd += ['--cache-to', cache_to] if !cache_to.empty?
end

# Build arguments
build_args = [
  '-t', target_image,
  '-f', 'Dockerfile.sandbox-common',
  '--build-arg', "BASE_IMAGE=#{base_image}",
  '--build-arg', "PACKAGES=#{packages}",
  '--build-arg', "INSTALL_PNPM=#{install_pnpm}",
  '--build-arg', "INSTALL_BUN=#{install_bun}",
  '--build-arg', "BUN_INSTALL_DIR=#{bun_install_dir}",
  '--build-arg', "INSTALL_BREW=#{install_brew}",
  '--build-arg', "BREW_INSTALL_DIR=#{brew_install_dir}",
  '--build-arg', "FINAL_USER=#{final_user}",
  '.'
]

full_command = (build_cmd + build_args).map(&:shellescape).join(' ')
run_command(full_command)

note = <<-NOTE
Built #{target_image}.
To use it, set agents.defaults.sandbox.docker.image to "#{target_image}" and restart.
If you want a clean re-create, remove old sandbox containers:
  docker rm -f $(docker ps -aq --filter label=openclaw.sandbox=1)
NOTE

puts note

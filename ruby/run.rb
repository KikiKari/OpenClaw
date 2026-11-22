#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "2b8d92bb6870f7f5082259759a7668f4a92d83bdb607be9cd509a76534f8a090", "source_sha256": "9bab70cc20775da1defcfadbbbef9ceb0f983a51d1a3988a76a20843d64c8471", "target_language": "ruby"}
# run.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/install-sh-nonroot/run.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

require 'open3'
require 'net/http'
require 'uri'

INSTALL_URL = ENV['OPENCLAW_INSTALL_URL'] || 'https://openclaw.bot/install.sh'
DEFAULT_PACKAGE = 'openclaw'
PACKAGE_NAME = ENV['OPENCLAW_INSTALL_PACKAGE'] || DEFAULT_PACKAGE

def source_script(dir)
  script_path = File.join(dir, '../install-sh-common/cli-verify.sh')
  if File.exist?(script_path)
    # In Ruby, we can't directly source a bash script, so we'll need to reimplement the function
    # For now, we'll define a Ruby equivalent of verify_installed_cli later
  end
end

# Get directory of this script
script_dir = File.dirname(File.realpath(__FILE__))
source_script(script_dir)

puts "==> Pre-flight: ensure git absent"
def command_exists?(cmd)
  system("command -v #{cmd} > /dev/null 2>&1")
end

if command_exists?('git')
  STDERR.puts "git is present unexpectedly"
  exit 1
end

puts "==> Pre-flight: ensure supported Node is already present"

node_check_script = <<~JS
  const version = process.versions.node.split(".").map(Number);
  const ok =
    version.length >= 2 &&
    (version[0] > 22 || (version[0] === 22 && version[1] >= 16));
  if (!ok) {
    process.stderr.write(`unsupported node ${process.versions.node}\\n`);
    process.exit(1);
  }
JS

stdin, stdout, stderr, wait_thr = Open3.popen3('node', '-e', node_check_script)
stdin.close
output = stdout.read
err_output = stderr.read
exit_status = wait_thr.value

unless exit_status.success?
  STDERR.print err_output
  exit exit_status.to_i
end

unless command_exists?('npm')
  STDERR.puts "npm not found"
  exit 1
end

puts "==> Run installer (non-root user)"

uri = URI(INSTALL_URL)
response = Net::HTTP.get_response(uri)
unless response.code == '200'
  STDERR.puts "Failed to download install script: #{response.code}"
  exit 1
end

install_script = response.body

# Execute the install script with bash
stdin, stdout, stderr, wait_thr = Open3.popen3('bash')
stdin.write(install_script)
stdin.close
output = stdout.read
err_output = stderr.read
exit_status = wait_thr.value

unless exit_status.success?
  STDERR.print err_output
  STDERR.puts output unless exit_status.success?
  exit exit_status.to_i
end

# Ensure PATH picks up user npm prefix
ENV['PATH'] = "#{ENV['HOME']}/.npm-global/bin:#{ENV['PATH']}"

puts "==> Verify git installed"
unless command_exists?('git')
  STDERR.puts "git not installed by installer"
  exit 1
end

EXPECTED_VERSION = ENV['OPENCLAW_INSTALL_EXPECT_VERSION'] || ''

def quiet_npm_view(package)
  stdin, stdout, stderr, wait_thr = Open3.popen3('npm', 'view', package, 'version')
  stdin.close
  output = stdout.read.strip
  err_output = stderr.read
  exit_status = wait_thr.value
  
  unless exit_status.success?
    STDERR.print err_output
    exit exit_status.to_i
  end
  
  output
end

if !EXPECTED_VERSION.empty?
  LATEST_VERSION = EXPECTED_VERSION
else
  LATEST_VERSION = quiet_npm_view(PACKAGE_NAME)
end

puts "==> Verify CLI installed"

# Reimplementing verify_installed_cli function from cli-verify.sh
def verify_installed_cli(package_name, expected_version)
  # Get installed version
  stdin, stdout, stderr, wait_thr = Open3.popen3('npm', 'list', '-g', package_name, '--depth=0')
  stdin.close
  output = stdout.read
  err_output = stderr.read
  exit_status = wait_thr.value
  
  unless exit_status.success? || err_output.include?('extraneous')
    STDERR.puts "Failed to check installed package:"
    STDERR.print err_output
    exit exit_status.to_i
  end
  
  # Extract version from output like: package@x.y.z
  match = output.match(/#{Regexp.escape(package_name)}@(\d+\.\d+\.\d+)/)
  if match.nil?
    STDERR.puts "Package #{package_name} not found in global installs"
    exit 1
  end
  
  installed_version = match[1]
  
  if installed_version != expected_version
    STDERR.puts "Version mismatch: expected #{expected_version}, got #{installed_version}"
    exit 1
  end
end

verify_installed_cli(PACKAGE_NAME, LATEST_VERSION)

puts "OK"

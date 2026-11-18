#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "ee6de9218711957d62268debe2df06ffff8ce2e5026f6da88b81ee929994481f", "source_sha256": "47740d82dac30833751ad7e0c569c7c084b01b1468243a6aebaf3f4a526f0a93", "target_language": "ruby"}
# pplx-refresh.sh — portiert nach ruby
# Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-refresh.sh
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

# Refresh the codespace Perplexity session from a locally-exported cookie.
#
# Usage:
#   ./pplx-refresh.rb [cookie-file]
#
# cookie-file defaults to ~/pplx-cookies.txt. Put your local browser's
# __Secure-next-auth.session-token value (raw), or the whole Cookie header,
# or a JSON cookie export, into that file first.
#
# Steps: ensure daemon browser -> read daemon passphrase -> inject into vault
#        -> trigger reinit -> verify authenticated.

require 'json'
require 'fileutils'

HERE = File.expand_path(File.dirname(__FILE__))
CFG = ENV['PERPLEXITY_CONFIG_DIR'] || File.join(Dir.home, '.perplexity-mcp')
PROFILE = ENV['PERPLEXITY_PROFILE'] || 'codespace'
COOKIE_FILE = ARGV[0] || File.join(Dir.home, 'pplx-cookies.txt')

unless File.exist?(COOKIE_FILE) && !File.zero?(COOKIE_FILE)
  puts "✗ Cookie file empty/missing: #{COOKIE_FILE}"
  puts "  Export __Secure-next-auth.session-token from your local browser"
  puts "  (DevTools → Application → Cookies → www.perplexity.ai) into that file."
  exit 1
end

# 1. ensure the extension daemon has a usable browser (idempotent)
system('bash', "#{HERE}/pplx-setup.sh")

# 2. daemon pid + vault passphrase (never guessed — read from the live daemon)
LOCK = File.join(CFG, 'daemon.lock')
unless File.exist?(LOCK)
  puts "✗ no daemon.lock at #{LOCK} — is the extension running?"
  exit 1
end

lock_data = JSON.parse(File.read(LOCK))
pid = lock_data['pid']

begin
  Process.getpgid(pid)
rescue Errno::ESRCH
  puts "✗ daemon pid #{pid} not running"
  exit 1
end

environ_file = "/proc/#{pid}/environ"
unless File.exist?(environ_file)
  puts "✗ no environ file for pid #{pid}"
  exit 1
end

pass = nil
File.read(environ_file).split("\0").each do |env_var|
  if env_var.start_with?('PERPLEXITY_VAULT_PASSPHRASE=')
    pass = env_var.sub('PERPLEXITY_VAULT_PASSPHRASE=', '')
    break
  end
end

if pass.nil? || pass.empty?
  puts "✗ no PERPLEXITY_VAULT_PASSPHRASE in daemon env"
  exit 1
end

# 3. locate the perplexity-user-mcp dist (populate npx cache if needed)
dist = Dir.glob(File.join(Dir.home, '.npm', '_npx', '*', 'perplexity-user-mcp', 'dist')).first
if dist.nil?
  system('npx', '-y', 'perplexity-user-mcp', '--version', out: '/dev/null', err: '/dev/null')
  dist = Dir.glob(File.join(Dir.home, '.npm', '_npx', '*', 'perplexity-user-mcp', 'dist')).first
end

# 4. inject
env = {
  'PERPLEXITY_VAULT_PASSPHRASE' => pass,
  'PERPLEXITY_CONFIG_DIR' => CFG,
  'PERPLEXITY_PROFILE' => PROFILE,
  'PPLX_DIST' => dist
}
system(env, 'node', "#{HERE}/pplx-inject.mjs", COOKIE_FILE)

# 5. trigger daemon reinit
reinit_file = File.join(CFG, 'profiles', PROFILE, '.reinit')
File.write(reinit_file, Time.now.to_i.to_s)
puts "→ reinit triggered, waiting for daemon..."

# 6. verify
stat_file = File.join(CFG, 'profiles', PROFILE, 'daemon-status.json')
20.times do
  sleep 1.5
  next unless File.exist?(stat_file)
  
  begin
    stat_data = JSON.parse(File.read(stat_file))
    authenticated = stat_data['authenticated']
    tier = stat_data['tier']
    
    if authenticated == true
      puts "✅ authenticated — tier: #{tier}"
      exit 0
    end
  rescue JSON::ParserError, Errno::ENOENT
    # Continue waiting if file doesn't exist or is invalid JSON
  end
end

puts "⚠️  not authenticated yet. Check: tail -20 #{File.join(CFG, 'daemon.log')}"
exit 1

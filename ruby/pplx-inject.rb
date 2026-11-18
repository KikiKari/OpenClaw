#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "b298548a6d14ff2f392b455172974683d8b784be32a93a31d14afd4afe71c133", "source_sha256": "9e1571035b3437fe4d1a830b7a20217de22a01508d7fc92bfed5fd58b7738b33", "target_language": "ruby"}
# pplx-inject.mjs — portiert nach ruby
# Quelle: javascript, OpenClaw@main:scripts/pplx-tools/pplx-inject.mjs
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'fileutils'
require 'open3'

PROFILE = ENV['PERPLEXITY_PROFILE'] || 'codespace'
EMAIL = ENV['PPLX_EMAIL'] || 'KarimKiki@gmx.de'
file = ARGV[0]
unless file
  puts "usage: ruby #{$0} <cookies-file>"
  exit 1
end

DIST = ENV['PPLX_DIST']
unless DIST && Dir.exist?(DIST)
  begin
    dist_output, status = Open3.capture2("find \"#{ENV['HOME']}/.npm/_npx\" -type d -path '*perplexity-user-mcp/dist' 2>/dev/null | head -1")
    DIST = dist_output.strip if status.success?
  rescue
  end
end

unless DIST && Dir.exist?(DIST)
  puts "cannot locate perplexity-user-mcp/dist (set PPLX_DIST)"
  exit 1
end

def chunk_for(symbol, entries = ["manual-login-runner.mjs", "login-runner.mjs", "cli.mjs"])
  entries.each do |entry|
    path = File.join(DIST, entry)
    next unless File.exist?(path)
    
    src = File.read(path, encoding: 'utf-8')
    src.scan(/import\s*\{([^}]*)\}\s*from\s*"(\.\/chunk-[^"]+\.mjs)"/) do |names_part, chunk_path|
      names = names_part.split(',').map do |s|
        s.strip.split(/\s+as\s+/)[0].strip
      end
      return File.join(DIST, chunk_path[2..]) if names.include?(symbol)
    end
  end
  nil
end

vault_chunk = chunk_for("Vault")
prof_chunk = chunk_for("getProfilePaths")
unless vault_chunk && prof_chunk
  puts "could not locate Vault/profile chunks in dist"
  exit 1
end

require vault_chunk
require prof_chunk

text = File.read(file, encoding: 'utf-8').strip
raw = nil

if text.start_with?('[') || text.start_with?('{')
  data = JSON.parse(text)
  raw = data.is_a?(Array) ? data : data['cookies']
  unless raw.is_a?(Array)
    puts "expected a JSON array of cookies"
    exit 1
  end
elsif text.start_with?('eyJ') && !text.include?('=') && !text.include?(';')
  raw = [{ 'name' => '__Secure-next-auth.session-token', 'value' => text }]
else
  raw = text.split(/;\s*/).map do |kv|
    i = kv.index('=')
    next nil if i.nil?
    { 'name' => kv[0...i].strip, 'value' => kv[i+1..].strip }
  end.compact
end

def norm_same_site(s)
  v = (s || '').to_s.downcase
  return 'None' if v == 'no_restriction' || v == 'none'
  return 'Strict' if v == 'strict'
  'Lax'
end

cookies = raw.select do |c|
  c && c['name'] && c['value']
end.select do |c|
  domain = c['domain'] || ''
  domain.include?('perplexity.ai') || domain.empty?
end.map do |c|
  domain = c['domain'] && c['domain'].include?('perplexity') ? c['domain'] : '.perplexity.ai'
  expires = c['expires'] || c['expirationDate'] || -1
  expires = expires.is_a?(Numeric) ? expires.floor : -1
  
  {
    'name' => c['name'],
    'value' => c['value'],
    'domain' => domain,
    'path' => c['path'] || '/',
    'expires' => expires,
    'httpOnly' => !!c['httpOnly'],
    'secure' => c.fetch('secure', true) != false,
    'sameSite' => norm_same_site(c['sameSite'])
  }
end

names = cookies.map { |c| c['name'] }
puts "Parsed #{cookies.size} perplexity.ai cookies: #{names.join(', ')}"
unless names.any? { |n| n.start_with?('__Secure-next-auth.session-token') }
  puts "WARNING: no '__Secure-next-auth.session-token' — session likely won't authenticate."
end

paths = getProfilePaths(PROFILE)
FileUtils.mkdir_p(paths[:dir]) unless Dir.exist?(paths[:dir])

vault = Vault.new
vault.set(PROFILE, 'cookies', JSON.generate(cookies))
vault.set(PROFILE, 'email', EMAIL)

unless File.exist?(paths[:modelsCache])
  File.write(paths[:modelsCache], JSON.pretty_generate({ 'models' => {} }))
end

recordLoginSuccess(PROFILE, {
  'tier' => 'pro',
  'loginMode' => 'manual',
  'lastLogin' => Time.now.iso8601
})

File.write(paths[:reinit], Time.now.to_i.to_s)
puts "OK: injected #{cookies.size} cookie(s) into vault profile '#{PROFILE}'."

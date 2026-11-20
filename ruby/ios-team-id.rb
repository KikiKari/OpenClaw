#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "48719d5a4332df68028067689767c17197753cbbaf8630eff2a1d2d167c3a019", "source_sha256": "ff0a573c1d18ce8554e3d7311f3c2ae463c9664ad4b824e0cb5888b499733213", "target_language": "ruby"}
# ios-team-id.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-team-id.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'open3'
require 'pathname'

def detect_python
  candidates = [ENV['IOS_PYTHON_BIN'], 'python3', 'python', '/usr/bin/python3'].compact
  candidates.each do |candidate|
    next if candidate.empty?
    begin
      Open3.capture2('command', '-v', candidate)
      return candidate
    rescue
      next
    end
  end
  nil
end

def append_team(team_id, is_free, team_name, team_ids, team_is_free, team_names)
  team_id = team_id.gsub("\r", '').strip
  is_free = is_free.to_s.gsub("\r", '').strip
  team_name = team_name.to_s.gsub("\r", '').strip
  
  return if team_id.empty?
  return if team_ids.include?(team_id)
  
  team_ids << team_id
  team_is_free << (is_free == '1' ? true : false)
  team_names << team_name
end

def load_teams_from_xcode_preferences(team_ids, team_is_free, team_names, python_cmd)
  return if python_cmd.nil?
  
  plist_path = File.join(Dir.home, 'Library', 'Preferences', 'com.apple.dt.Xcode.plist')
  return unless File.exist?(plist_path)
  
  cmd = "plutil -extract IDEProvisioningTeams json -o - \"#{plist_path}\" 2>/dev/null"
  
  stdout, stderr, status = Open3.capture3(cmd)
  return unless status.success?
  
  begin
    data = JSON.parse(stdout)
    return unless data.is_a?(Hash)
    
    data.each_value do |teams|
      next unless teams.is_a?(Array)
      
      teams.each do |team|
        next unless team.is_a?(Hash)
        
        team_id = team['teamID']&.to_s&.strip
        next if team_id.nil? || team_id.empty?
        
        is_free = team.fetch('isFreeProvisioningTeam', false) ? '1' : '0'
        team_name = team.fetch('teamName', '').to_s.gsub("\t", ' ').strip
        
        append_team(team_id, is_free, team_name, team_ids, team_is_free, team_names)
      end
    end
  rescue JSON::ParserError
    # Ignore JSON parsing errors
  end
end

def load_teams_from_legacy_defaults_key(team_ids, team_is_free, team_names)
  stdout, stderr, status = Open3.capture3('defaults read com.apple.dt.Xcode IDEProvisioningTeamIdentifiers 2>/dev/null')
  return unless status.success?
  
  teams = stdout.scan(/[A-Z0-9]{10}/)
  teams.each { |team| append_team(team, '0', '', team_ids, team_is_free, team_names) }
end

def load_teams_from_xcode_managed_profiles(team_ids, team_is_free, team_names, python_cmd)
  return if python_cmd.nil?
  
  profiles_dir = File.join(Dir.home, 'Library', 'MobileDevice', 'Provisioning Profiles')
  return unless Dir.exist?(profiles_dir)
  
  teams = []
  
  Dir.glob(File.join(profiles_dir, '*.mobileprovision')).each do |profile|
    next unless File.file?(profile)
    
    stdout, stderr, status = Open3.capture3("security cms -D -i \"#{profile}\" 2>/dev/null")
    next unless status.success?
    
    python_script = <<~PYTHON
      import plistlib, sys
      try:
          raw = sys.stdin.buffer.read()
          if not raw:
              raise SystemExit(0)
          d = plistlib.loads(raw)
          for tid in d.get("TeamIdentifier", []):
              print(tid)
      except Exception:
          pass
    PYTHON
    
    py_stdout, py_stderr, py_status = Open3.capture3(python_cmd, stdin_data: stdout)
    next unless py_status.success?
    
    py_stdout.each_line do |line|
      line.strip!
      teams << line unless line.empty?
    end
  end
  
  teams.uniq.each { |team| append_team(team, '0', '', team_ids, team_is_free, team_names) }
end

def has_xcode_account?
  plist_path = File.join(Dir.home, 'Library', 'Preferences', 'com.apple.dt.Xcode.plist')
  return false unless File.exist?(plist_path)
  
  stdout, stderr, status = Open3.capture3('defaults read com.apple.dt.Xcode DVTDeveloperAccountManagerAppleIDLists 2>/dev/null')
  return false unless status.success?
  return false if stdout.include?('does not exist')
  
  stdout.include?('identifier')
end

def load_teams_from_keychain_fallback(team_ids, team_is_free, team_names)
  stdout, stderr, status = Open3.capture3('security find-identity -p codesigning -v 2>/dev/null')
  return unless status.success?
  
  teams = stdout.scan(/\([A-Z0-9]{10}\)/).map { |match| match.tr('()', '') }
  teams.each { |team| append_team(team, '0', '', team_ids, team_is_free, team_names) }
end

# Main execution starts here

if !ENV['IOS_DEVELOPMENT_TEAM'].nil? && !ENV['IOS_DEVELOPMENT_TEAM'].empty?
  puts ENV['IOS_DEVELOPMENT_TEAM']
  exit 0
end

preferred_team = (ENV['IOS_PREFERRED_TEAM_ID'] || ENV['OPENCLAW_IOS_DEFAULT_TEAM_ID'] || 'Y5PE65HELJ').gsub("\r", '')
preferred_team_name = (ENV['IOS_PREFERRED_TEAM_NAME'] || '').gsub("\r", '')
allow_keychain_fallback = ENV['IOS_ALLOW_KEYCHAIN_TEAM_FALLBACK'] == '1'
prefer_non_free_team = ENV['IOS_PREFER_NON_FREE_TEAM'] != '0'

team_ids = []
team_is_free = []
team_names = []

python_cmd = detect_python

load_teams_from_xcode_preferences(team_ids, team_is_free, team_names, python_cmd)
load_teams_from_legacy_defaults_key(team_ids, team_is_free, team_names)

if team_ids.empty?
  load_teams_from_xcode_managed_profiles(team_ids, team_is_free, team_names, python_cmd)
end

if team_ids.empty? && allow_keychain_fallback
  load_teams_from_keychain_fallback(team_ids, team_is_free, team_names)
end

if team_ids.empty?
  if has_xcode_account?
    STDERR.puts "An Apple account is signed in to Xcode, but no Team ID could be resolved."
    STDERR.puts ""
    STDERR.puts "On Xcode 16+, team data is not written until you build a project."
    STDERR.puts "To fix this, do ONE of the following:"
    STDERR.puts ""
    STDERR.puts "  1. Open the iOS project in Xcode, select your Team in Signing &"
    STDERR.puts "     Capabilities, and build once. Then re-run this script."
    STDERR.puts ""
    STDERR.puts "  2. Set your Team ID directly:"
    STDERR.puts "       export IOS_DEVELOPMENT_TEAM=<your-10-char-team-id>"
    STDERR.puts "     Find your Team ID at: https://developer.apple.com/account#MembershipDetailsCard"
  elsif allow_keychain_fallback
    STDERR.puts "No Apple Team ID found. Open Xcode or install signing certificates first."
  else
    STDERR.puts "No Apple Team ID found in Xcode accounts. Open Xcode → Settings → Accounts and sign in, then retry."
    STDERR.puts "(Set IOS_ALLOW_KEYCHAIN_TEAM_FALLBACK=1 to allow keychain-only team detection.)"
  end
  exit 1
end

team_ids.each_with_index do |team_id, i|
  if team_id == preferred_team
    puts team_id
    exit 0
  end
end

unless preferred_team_name.empty?
  preferred_team_name_lc = preferred_team_name.downcase
  team_names.each_with_index do |team_name, i|
    if team_name.downcase == preferred_team_name_lc
      puts team_ids[i]
      exit 0
    end
  end
end

if prefer_non_free_team
  team_is_free.each_with_index do |is_free, i|
    if !is_free
      puts team_ids[i]
      exit 0
    end
  end
end

puts team_ids.first

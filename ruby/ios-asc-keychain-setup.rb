#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "207783d5c94d600971d9534c431b34696997477bf8b57f1e00a3104789a7f054", "source_sha256": "3c82de39b963e31592918456342c499f4e6477d2ee7404f215a5685c6d02674c", "target_language": "ruby"}
# ios-asc-keychain-setup.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-asc-keychain-setup.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

require 'optparse'
require 'pathname'
require 'fileutils'
require 'tempfile'

def usage
  puts <<~EOF
    Usage:
      scripts/ios-asc-keychain-setup.sh --key-path /path/to/AuthKey_XXXXXX.p8 --issuer-id <issuer-uuid> [options]

    Required:
      --key-path <path>      Path to App Store Connect API key (.p8)
      --issuer-id <uuid>     App Store Connect issuer ID

    Optional:
      --key-id <id>          API key ID (auto-detected from AuthKey_<id>.p8 if omitted)
      --service <name>       Keychain service name (default: openclaw-asc-key)
      --account <name>       Keychain account name (default: $USER or $LOGNAME)
      --write-env            Upsert non-secret env vars into apps/ios/fastlane/.env
      --env-file <path>      Override env file path used with --write-env
      -h, --help             Show this help

    Example:
      scripts/ios-asc-keychain-setup.sh \\
        --key-path "$HOME/keys/AuthKey_ABC1234567.p8" \\
        --issuer-id "00000000-1111-2222-3333-444444444444" \\
        --write-env
  EOF
end

def upsert_env_line(file, key, value)
  tmp = Tempfile.new('env')
  begin
    if File.exist?(file)
      File.readlines(file).each do |line|
        if line.match(/^#{Regexp.escape(key)}=/)
          tmp.puts("#{key}=#{value}")
        else
          tmp.puts(line)
        end
      end
      # If key was not found, append it
      unless File.readlines(file).any? { |line| line.match(/^#{Regexp.escape(key)}=/) }
        tmp.puts("#{key}=#{value}")
      end
    else
      tmp.puts("#{key}=#{value}")
    end
    tmp.close
    FileUtils.mv(tmp.path, file)
  ensure
    tmp.close unless tmp.closed?
  end
end

def delete_env_line(file, key)
  return unless File.exist?(file)

  tmp = Tempfile.new('env')
  begin
    File.readlines(file).each do |line|
      tmp.puts(line) unless line.match(/^#{Regexp.escape(key)}=/)
    end
    tmp.close
    FileUtils.mv(tmp.path, file)
  ensure
    tmp.close unless tmp.closed?
  end
end

options = {
  key_path: '',
  key_id: '',
  issuer_id: '',
  service: 'openclaw-asc-key',
  account: ENV['USER'] || ENV['LOGNAME'] || '',
  write_env: false,
  env_file: ''
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"

  opts.on('--key-path PATH', 'Path to App Store Connect API key (.p8)') do |v|
    options[:key_path] = v
  end

  opts.on('--key-id ID', 'API key ID (auto-detected from AuthKey_<id>.p8 if omitted)') do |v|
    options[:key_id] = v
  end

  opts.on('--issuer-id UUID', 'App Store Connect issuer ID') do |v|
    options[:issuer_id] = v
  end

  opts.on('--service NAME', 'Keychain service name (default: openclaw-asc-key)') do |v|
    options[:service] = v
  end

  opts.on('--account NAME', 'Keychain account name (default: $USER or $LOGNAME)') do |v|
    options[:account] = v
  end

  opts.on('--write-env', 'Upsert non-secret env vars into apps/ios/fastlane/.env') do |v|
    options[:write_env] = true
  end

  opts.on('--env-file PATH', 'Override env file path used with --write-env') do |v|
    options[:env_file] = v
  end

  opts.on('-h', '--help', 'Show this help') do
    usage
    exit
  end
end

begin
  parser.parse!
rescue OptionParser::InvalidOption => e
  puts "Unknown argument: #{e.message}"
  usage
  exit 1
end

if options[:key_path].empty? || options[:issuer_id].empty?
  puts "Missing required arguments."
  usage
  exit 1
end

unless File.exist?(options[:key_path])
  puts "Key file not found: #{options[:key_path]}"
  exit 1
end

if options[:key_id].empty?
  key_filename = File.basename(options[:key_path])
  if key_filename.match(/^AuthKey_([A-Za-z0-9]+)\.p8$/)
    options[:key_id] = $1
  else
    puts "Could not infer --key-id from filename '#{key_filename}'. Pass --key-id explicitly."
    exit 1
  end
end

if options[:account].empty?
  puts "Could not determine Keychain account. Pass --account explicitly."
  exit 1
end

key_content = File.read(options[:key_path])
if key_content.strip.empty?
  puts "Key file is empty: #{options[:key_path]}"
  exit 1
end

# Store in keychain
system('security', 'add-generic-password',
       '-a', options[:account],
       '-s', options[:service],
       '-w', key_content,
       '-U',
       out: '/dev/null')

puts "Stored ASC API private key in macOS Keychain (service='#{options[:service]}', account='#{options[:account]}')."
puts
puts "Export these vars for Fastlane:"
puts "ASC_KEY_ID=#{options[:key_id]}"
puts "ASC_ISSUER_ID=#{options[:issuer_id]}"
puts "ASC_KEYCHAIN_SERVICE=#{options[:service]}"
puts "ASC_KEYCHAIN_ACCOUNT=#{options[:account]}"

if options[:write_env]
  repo_root = Pathname.new(__FILE__).dirname.parent.parent.to_s
  default_env_file = File.join(repo_root, 'apps', 'ios', 'fastlane', '.env')
  
  env_file = options[:env_file].empty? ? default_env_file : options[:env_file]
  
  FileUtils.mkdir_p(File.dirname(env_file))
  FileUtils.touch(env_file) unless File.exist?(env_file)
  
  upsert_env_line(env_file, 'ASC_KEY_ID', options[:key_id])
  upsert_env_line(env_file, 'ASC_ISSUER_ID', options[:issuer_id])
  upsert_env_line(env_file, 'ASC_KEYCHAIN_SERVICE', options[:service])
  upsert_env_line(env_file, 'ASC_KEYCHAIN_ACCOUNT', options[:account])
  # Remove file/path based keys so Keychain is used by default.
  delete_env_line(env_file, 'ASC_KEY_PATH')
  delete_env_line(env_file, 'ASC_KEY_CONTENT')
  delete_env_line(env_file, 'APP_STORE_CONNECT_API_KEY_PATH')
  
  puts
  puts "Updated env file: #{env_file}"
end

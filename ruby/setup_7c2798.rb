#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "9dd74d0871aaab31bc79955876b11346a7ab6b2f13edc0ce2ace0030f67fa0b4", "source_sha256": "7c279836c2c2bf7bf1f0cd8868a320423a0e69387a65cec698db01e1d888a57a", "target_language": "ruby"}
# setup.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/setup.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'securerandom'
require 'fileutils'
require 'pathname'

def fail(message)
  STDERR.puts "ERROR: #{message}"
  exit 1
end

def require_cmd(cmd)
  unless system("command -v #{cmd} >/dev/null 2>&1")
    STDERR.puts "Missing dependency: #{cmd}"
    exit 1
  end
end

def run_docker_build(*args)
  ENV['DOCKER_BUILDKIT'] = '1'
  system("docker build #{args.join(' ')}")
end

def is_truthy_value(raw)
  raw = raw.to_s.downcase.strip
  ['1', 'true', 'yes', 'on'].include?(raw)
end

def read_config_gateway_token
  config_path = File.join(ENV['OPENCLAW_CONFIG_DIR'], 'openclaw.json')
  return nil unless File.exist?(config_path)

  if system('command -v python3 >/dev/null 2>&1')
    python_script = <<~PYTHON
      import json
      import sys

      path = sys.argv[1]
      try:
          with open(path, "r", encoding="utf-8") as f:
              cfg = json.load(f)
      except Exception:
          raise SystemExit(0)

      gateway = cfg.get("gateway")
      if not isinstance(gateway, dict):
          raise SystemExit(0)
      auth = gateway.get("auth")
      if not isinstance(auth, dict):
          raise SystemExit(0)
      token = auth.get("token")
      if isinstance(token, str):
          token = token.strip()
          if token:
              print(token)
    PYTHON

    result = IO.popen(['python3', '-c', python_script, config_path], &:read)
    return result.strip unless result.empty?
  end

  if system('command -v node >/dev/null 2>&1')
    node_script = <<~NODE
      const fs = require("node:fs");
      const configPath = process.argv[2];
      try {
        const cfg = JSON.parse(fs.readFileSync(configPath, "utf8"));
        const token = cfg?.gateway?.auth?.token;
        if (typeof token === "string" && token.trim().length > 0) {
          process.stdout.write(token.trim());
        }
      } catch {
        // Keep docker-setup resilient when config parsing fails.
      }
    NODE

    result = IO.popen(['node', '-e', node_script, config_path], &:read)
    return result.strip unless result.empty?
  end

  nil
end

def read_env_gateway_token(env_path)
  return nil unless File.exist?(env_path)

  File.readlines(env_path).each do |line|
    line.chomp!
    next unless line.start_with?('OPENCLAW_GATEWAY_TOKEN=')

    token = line.sub('OPENCLAW_GATEWAY_TOKEN=', '')
    return token unless token.strip.empty?
  end

  nil
end

def sync_gateway_config
  allowed_origin_json = ''
  current_allowed_origins = ''

  if ENV['OPENCLAW_GATEWAY_BIND'] != 'loopback'
    allowed_origin_json = "[\"http://localhost:#{ENV['OPENCLAW_GATEWAY_PORT']}\",\"http://127.0.0.1:#{ENV['OPENCLAW_GATEWAY_PORT']}\"]"
    begin
      current_allowed_origins = `#{run_prestart_cli('config', 'get', 'gateway.controlUi.allowedOrigins')} 2>/dev/null`.strip
    rescue
      current_allowed_origins = ''
    end
    current_allowed_origins.delete!("\r")
  end

  batch_json = "[{\"path\":\"gateway.mode\",\"value\":\"local\"},{\"path\":\"gateway.bind\",\"value\":\"#{ENV['OPENCLAW_GATEWAY_BIND']}\"}"
  if !allowed_origin_json.empty?
    if current_allowed_origins.empty? || current_allowed_origins == 'null' || current_allowed_origins == '[]'
      batch_json += ",{\"path\":\"gateway.controlUi.allowedOrigins\",\"value\":#{allowed_origin_json}}"
    else
      puts "Control UI allowlist already configured; leaving gateway.controlUi.allowedOrigins unchanged."
    end
  end
  batch_json += ']'

  system("#{run_prestart_cli('config', 'set', '--batch-json', batch_json)} >/dev/null")
  puts "Pinned gateway.mode=local and gateway.bind=#{ENV['OPENCLAW_GATEWAY_BIND']} for Docker setup."
  if !allowed_origin_json.empty?
    if current_allowed_origins.empty? || current_allowed_origins == 'null' || current_allowed_origins == '[]'
      puts "Set gateway.controlUi.allowedOrigins to #{allowed_origin_json} for non-loopback bind."
    end
  end
end

def run_prestart_gateway(*args)
  "docker compose #{COMPOSE_ARGS.join(' ')} run --rm --no-deps #{args.join(' ')}"
end

def run_prestart_cli(*args)
  "#{run_prestart_gateway('--entrypoint', 'node', 'openclaw-gateway', 'dist/index.js')} #{args.join(' ')}"
end

def run_runtime_cli(compose_scope = 'current', deps_mode = 'with-deps', *args)
  compose_args = case compose_scope
                  when 'current'
                    COMPOSE_ARGS.dup
                  when 'base'
                    BASE_COMPOSE_ARGS.dup
                  else
                    fail "Unknown runtime CLI compose scope: #{compose_scope}"
                  end

  run_args = ['run', '--rm']
  case deps_mode
  when 'with-deps'
    # Do nothing
  when 'no-deps'
    run_args << '--no-deps'
  else
    fail "Unknown runtime CLI deps mode: #{deps_mode}"
  end

  "docker compose #{compose_args.join(' ')} #{run_args.join(' ')} openclaw-cli #{args.join(' ')}"
end

def contains_disallowed_chars(value)
  value.include?("\n") || value.include?("\r") || value.include?("\t")
end

def is_valid_timezone(value)
  path = "/usr/share/zoneinfo/#{value}"
  File.exist?(path) && !File.directory?(path)
end

def validate_mount_path_value(label, value)
  fail "#{label} cannot be empty." if value.empty?
  fail "#{label} contains unsupported control characters." if contains_disallowed_chars(value)
  fail "#{label} cannot contain whitespace." if value.match(/\s/)
end

def validate_named_volume(value)
  fail 'OPENCLAW_HOME_VOLUME must match [A-Za-z0-9][A-Za-z0-9_.-]* when using a named volume.' unless value.match(/^[A-Za-z0-9][A-Za-z0-9_.-]*$/)
end

def validate_mount_spec(mount)
  fail 'OPENCLAW_EXTRA_MOUNTS entries cannot contain control characters.' if contains_disallowed_chars(mount)
  # Keep mount specs strict to avoid YAML structure injection.
  # Expected format: source:target[:options]
  fail "Invalid mount format '#{mount}'. Expected source:target[:options] without spaces." unless mount.match(/^[^[:space:],:]+:[^[:space:],:]+(:[^[:space:],:]+)?$/)
end

# Main execution starts here

require_cmd('docker')
unless system('docker compose version >/dev/null 2>&1')
  STDERR.puts 'Docker Compose not available (try: docker compose version)'
  exit 1
end

ROOT_DIR = Pathname.new(__FILE__).dirname.parent.parent.to_s
COMPOSE_FILE = File.join(ROOT_DIR, 'docker-compose.yml')
EXTRA_COMPOSE_FILE = File.join(ROOT_DIR, 'docker-compose.extra.yml')
IMAGE_NAME = ENV.fetch('OPENCLAW_IMAGE', 'openclaw:local')
EXTRA_MOUNTS = ENV.fetch('OPENCLAW_EXTRA_MOUNTS', '')
HOME_VOLUME_NAME = ENV.fetch('OPENCLAW_HOME_VOLUME', '')
RAW_SANDBOX_SETTING = ENV.fetch('OPENCLAW_SANDBOX', '')
SANDBOX_ENABLED = ''
DOCKER_SOCKET_PATH = ENV.fetch('OPENCLAW_DOCKER_SOCKET', '')
TIMEZONE = ENV.fetch('OPENCLAW_TZ', '')

if DOCKER_SOCKET_PATH.empty? && ENV['DOCKER_HOST']&.start_with?('unix://')
  DOCKER_SOCKET_PATH = ENV['DOCKER_HOST'][7..-1]
end

if DOCKER_SOCKET_PATH.empty?
  DOCKER_SOCKET_PATH = '/var/run/docker.sock'
end

SANDBOX_ENABLED = '1' if is_truthy_value(RAW_SANDBOX_SETTING)

ENV['OPENCLAW_CONFIG_DIR'] = File.expand_path(ENV.fetch('OPENCLAW_CONFIG_DIR', '~/.openclaw'))
ENV['OPENCLAW_WORKSPACE_DIR'] = File.expand_path(ENV.fetch('OPENCLAW_WORKSPACE_DIR', '~/.openclaw/workspace'))

validate_mount_path_value('OPENCLAW_CONFIG_DIR', ENV['OPENCLAW_CONFIG_DIR'])
validate_mount_path_value('OPENCLAW_WORKSPACE_DIR', ENV['OPENCLAW_WORKSPACE_DIR'])

unless HOME_VOLUME_NAME.empty?
  if HOME_VOLUME_NAME.include?('/')
    validate_mount_path_value('OPENCLAW_HOME_VOLUME', HOME_VOLUME_NAME)
  else
    validate_named_volume(HOME_VOLUME_NAME)
  end
end

fail 'OPENCLAW_EXTRA_MOUNTS cannot contain control characters.' if contains_disallowed_chars(EXTRA_MOUNTS)

if !SANDBOX_ENABLED.empty?
  validate_mount_path_value('OPENCLAW_DOCKER_SOCKET', DOCKER_SOCKET_PATH)
end

if !TIMEZONE.empty?
  fail 'OPENCLAW_TZ contains unsupported control characters.' if contains_disallowed_chars(TIMEZONE)
  fail 'OPENCLAW_TZ must be a valid IANA timezone string (e.g. Asia/Shanghai).' unless TIMEZONE.match(/^[A-Za-z0-9\/_+\-]+$/)
  fail 'OPENCLAW_TZ must match a timezone in /usr/share/zoneinfo (e.g. Asia/Shanghai).' unless is_valid_timezone(TIMEZONE)
end

FileUtils.mkdir_p(ENV['OPENCLAW_CONFIG_DIR'])
FileUtils.mkdir_p(ENV['OPENCLAW_WORKSPACE_DIR'])
# Seed directory tree eagerly so bind mounts work even on Docker Desktop/Windows
# where the container (even as root) cannot create new host subdirectories.
FileUtils.mkdir_p(File.join(ENV['OPENCLAW_CONFIG_DIR'], 'identity'))
FileUtils.mkdir_p(File.join(ENV['OPENCLAW_CONFIG_DIR'], 'agents/main/agent'))
FileUtils.mkdir_p(File.join(ENV['OPENCLAW_CONFIG_DIR'], 'agents/main/sessions'))

ENV['OPENCLAW_GATEWAY_PORT'] = ENV.fetch('OPENCLAW_GATEWAY_PORT', '18789')
ENV['OPENCLAW_BRIDGE_PORT'] = ENV.fetch('OPENCLAW_BRIDGE_PORT', '18790')
ENV['OPENCLAW_GATEWAY_BIND'] = ENV.fetch('OPENCLAW_GATEWAY_BIND', 'lan')
ENV['OPENCLAW_IMAGE'] = IMAGE_NAME
ENV['OPENCLAW_DOCKER_APT_PACKAGES'] = ENV.fetch('OPENCLAW_DOCKER_APT_PACKAGES', '')
ENV['OPENCLAW_EXTENSIONS'] = ENV.fetch('OPENCLAW_EXTENSIONS', '')
ENV['OPENCLAW_EXTRA_MOUNTS'] = EXTRA_MOUNTS
ENV['OPENCLAW_HOME_VOLUME'] = HOME_VOLUME_NAME
ENV['OPENCLAW_ALLOW_INSECURE_PRIVATE_WS'] = ENV.fetch('OPENCLAW_ALLOW_INSECURE_PRIVATE_WS', '')
ENV['OPENCLAW_SANDBOX'] = SANDBOX_ENABLED
ENV['OPENCLAW_DOCKER_SOCKET'] = DOCKER_SOCKET_PATH
ENV['OPENCLAW_TZ'] = TIMEZONE

# Detect Docker socket GID for sandbox group_add.
DOCKER_GID = ''
if !SANDBOX_ENABLED.empty? && File.socket?(DOCKER_SOCKET_PATH)
  begin
    DOCKER_GID = File.stat(DOCKER_SOCKET_PATH).gid.to_s
  rescue
    DOCKER_GID = ''
  end
end
ENV['DOCKER_GID'] = DOCKER_GID

if ENV['OPENCLAW_GATEWAY_TOKEN'].to_s.empty?
  EXISTING_CONFIG_TOKEN = read_config_gateway_token
  if !EXISTING_CONFIG_TOKEN.nil? && !EXISTING_CONFIG_TOKEN.empty?
    ENV['OPENCLAW_GATEWAY_TOKEN'] = EXISTING_CONFIG_TOKEN
    puts "Reusing gateway token from #{ENV['OPENCLAW_CONFIG_DIR']}/openclaw.json"
  else
    DOTENV_GATEWAY_TOKEN = read_env_gateway_token(File.join(ROOT_DIR, '.env'))
    if !DOTENV_GATEWAY_TOKEN.nil? && !DOTENV_GATEWAY_TOKEN.empty?
      ENV['OPENCLAW_GATEWAY_TOKEN'] = DOTENV_GATEWAY_TOKEN
      puts "Reusing gateway token from #{ROOT_DIR}/.env"
    elsif system('command -v openssl >/dev/null 2>&1')
      ENV['OPENCLAW_GATEWAY_TOKEN'] = `openssl rand -hex 32`.strip
    else
      ENV['OPENCLAW_GATEWAY_TOKEN'] = SecureRandom.hex(32)
    end
  end
end

COMPOSE_FILES = [COMPOSE_FILE]
COMPOSE_ARGS = []

def write_extra_compose(home_volume, *mounts)
  extra_compose_file = File.join(ROOT_DIR, 'docker-compose.extra.yml')
  File.open(extra_compose_file, 'w') do |f|
    f.puts <<~YAML
      services:
        openclaw-gateway:
          volumes:
    YAML

    if !home_volume.empty?
      gateway_home_mount = "#{home_volume}:/home/node"
      gateway_config_mount = "#{ENV['OPENCLAW_CONFIG_DIR']}:/home/node/.openclaw"
      gateway_workspace_mount = "#{ENV['OPENCLAW_WORKSPACE_DIR']}:/home/node/.openclaw/workspace"
      validate_mount_spec(gateway_home_mount)
      validate_mount_spec(gateway_config_mount)
      validate_mount_spec(gateway_workspace_mount)
      f.puts "      - #{gateway_home_mount}"
      f.puts "      - #{gateway_config_mount}"
      f.puts "      - #{gateway_workspace_mount}"
    end

    mounts.each do |mount|
      validate_mount_spec(mount)
      f.puts "      - #{mount}"
    end

    f.puts <<~YAML
      openclaw-cli:
        volumes:
    YAML

    if !home_volume.empty?
      f.puts "      - #{gateway_home_mount}"
      f.puts "      - #{gateway_config_mount}"
      f.puts "      - #{gateway_workspace_mount}"
    end

    mounts.each do |mount|
      validate_mount_spec(mount)
      f.puts "      - #{mount}"
    end

    if !home_volume.empty? && !home_volume.include?('/')
      validate_named_volume(home_volume)
      f.puts <<~YAML
        volumes:
          #{home_volume}:
      YAML
    end
  end
end

# When sandbox is requested, ensure Docker CLI build arg is set for local builds.
# Docker socket mount is deferred until sandbox prerequisites are verified.
if !SANDBOX_ENABLED.empty?
  ENV['OPENCLAW_INSTALL_DOCKER_CLI'] = '1' if ENV['OPENCLAW_INSTALL_DOCKER_CLI'].to_s.empty?
end

VALID_MOUNTS = []
if !EXTRA_MOUNTS.empty?
  EXTRA_MOUNTS.split(',').each do |mount|
    mount = mount.strip
    VALID_MOUNTS.push(mount) unless mount.empty?
  end
end

if !HOME_VOLUME_NAME.empty? || VALID_MOUNTS.length > 0
  if VALID_MOUNTS.length > 0
    write_extra_compose(HOME_VOLUME_NAME, *VALID_MOUNTS)
  else
    write_extra_compose(HOME_VOLUME_NAME)
  end
  COMPOSE_FILES.push(EXTRA_COMPOSE_FILE)
end

COMPOSE_FILES.each do |compose_file|
  COMPOSE_ARGS.push('-f', compose_file)
end

# Keep a base compose arg set without sandbox overlay so rollback paths can
# force a known-safe gateway service definition (no docker.sock mount).
BASE_COMPOSE_ARGS = COMPOSE_ARGS.dup
COMPOSE_HINT = 'docker compose'
COMPOSE_FILES.each do |compose_file|
  COMPOSE_HINT += " -f #{compose_file}"
end

ENV_FILE = File.join(ROOT_DIR, '.env')

def upsert_env(file, *keys)
  tmp = Tempfile.new('env')
  seen = ' '

  if File.exist?(file)
    File.readlines(file).each do |line|
      key = line.split('=').first
      replaced = false
      keys.each do |k|
        if key == k
          tmp.puts "#{k}=#{ENV[k]}"
          seen += "#{k} "
          replaced = true
          break
        end
      end
      tmp.puts line unless replaced
    end
  end

  keys.each do |k|
    unless seen.include?(" #{k} ")
      tmp.puts "#{k}=#{ENV[k]}"
    end
  end

  tmp.close
  FileUtils.mv(tmp.path, file)
end

upsert_env(ENV_FILE,
           'OPENCLAW_CONFIG_DIR',
           'OPENCLAW_WORKSPACE_DIR',
           'OPENCLAW_GATEWAY_PORT',
           'OPENCLAW_BRIDGE_PORT',
           'OPENCLAW_GATEWAY_BIND',
           'OPENCLAW_GATEWAY_TOKEN',
           'OPENCLAW_IMAGE',
           'OPENCLAW_EXTRA_MOUNTS',
           'OPENCLAW_HOME_VOLUME',
           'OPENCLAW_DOCKER_APT_PACKAGES',
           'OPENCLAW_EXTENSIONS',
           'OPENCLAW_SANDBOX',
           'OPENCLAW_DOCKER_SOCKET',
           'DOCKER_GID',
           'OPENCLAW_INSTALL_DOCKER_CLI',
           'OPENCLAW_ALLOW_INSECURE_PRIVATE_WS',
           'OPENCLAW_TZ')

if IMAGE_NAME == 'openclaw:local'
  puts '==> Building Docker image: openclaw:local'
  run_docker_build(
    '--build-arg', "OPENCLAW_DOCKER_APT_PACKAGES=#{ENV['OPENCLAW_DOCKER_APT_PACKAGES']}",
    '--build-arg', "OPENCLAW_EXTENSIONS=#{ENV['OPENCLAW_EXTENSIONS']}",
    '--build-arg', "OPENCLAW_INSTALL_DOCKER_CLI=#{ENV['OPENCLAW_INSTALL_DOCKER_CLI']}",
    '-t', IMAGE_NAME,
    '-f', File.join(ROOT_DIR, 'Dockerfile'),
    ROOT_DIR
  )
else
  puts "==> Pulling Docker image: #{IMAGE_NAME}"
  unless system("docker pull #{IMAGE_NAME}")
    STDERR.puts "ERROR: Failed to pull image #{IMAGE_NAME}. Please check the image name and your access permissions."
    exit 1
  end
end

# Ensure bind-mounted data directories are writable by the container's `node`
# user (uid 1000). Host-created dirs inherit the host user's uid which may
# differ, causing EACCES when the container tries to mkdir/write.
# Running a brief root container to chown is the portable Docker idiom --
# it works regardless of the host uid and doesn't require host-side root.
puts ''
puts '==> Fixing data-directory permissions'
# Use -xdev to restrict chown to the config-dir mount only — without it,
# the recursive chown would cross into the workspace bind mount and rewrite
# ownership of all user project files on Linux hosts.
# After fixing the config dir, only the OpenClaw metadata subdirectory
# (.openclaw/) inside the workspace gets chowned, not the user's project files.
system("#{run_prestart_gateway('--user', 'root', '--entrypoint', 'sh', 'openclaw-gateway', '-c',
                               'find /home/node/.openclaw -xdev -exec chown node:node {} +; \
                                [ -d /home/node/.openclaw/workspace/.openclaw ] && chown -R node:node /home/node/.openclaw/workspace/.openclaw || true')}")

puts ''
puts '==> Onboarding (interactive)'
puts 'Docker setup pins Gateway mode to local.'
puts 'Gateway runtime bind comes from OPENCLAW_GATEWAY_BIND (default: lan).'
puts "Current runtime bind: #{ENV['OPENCLAW_GATEWAY_BIND']}"
puts "Gateway token: #{ENV['OPENCLAW_GATEWAY_TOKEN']}"
puts 'Tailscale exposure: Off (use host-level tailnet/Tailscale setup separately).'
puts 'Install Gateway daemon: No (managed by Docker Compose)'
puts ''
system(run_prestart_cli('onboard', '--mode', 'local', '--no-install-daemon'))

puts ''
puts '==> Docker gateway defaults'
sync_gateway_config

puts ''
puts '==> Provider setup (optional)'
puts 'WhatsApp (QR):'
puts "  #{COMPOSE_HINT} run --rm openclaw-cli channels login"
puts 'Telegram (bot token):'
puts "  #{COMPOSE_HINT} run --rm openclaw-cli channels add --channel telegram --token <token>"
puts 'Discord (bot token):'
puts "  #{COMPOSE_HINT} run --rm openclaw-cli channels add --channel discord --token <token>"
puts 'Docs: https://docs.openclaw.ai/channels'

puts ''
puts '==> Starting gateway'
system("docker compose #{COMPOSE_ARGS.join(' ')} up -d openclaw-gateway")

# --- Sandbox setup (opt-in via OPENCLAW_SANDBOX=1) ---
if !SANDBOX_ENABLED.empty?
  puts ''
  puts '==> Sandbox setup'

  # Build sandbox image if Dockerfile.sandbox exists.
  if File.exist?(File.join(ROOT_DIR, 'Dockerfile.sandbox'))
    puts 'Building sandbox image: openclaw-sandbox:bookworm-slim'
    run_docker_build(
      '-t', 'openclaw-sandbox:bookworm-slim',
      '-f', File.join(ROOT_DIR, 'Dockerfile.sandbox'),
      ROOT_DIR
    )
  else
    STDERR.puts 'WARNING: Dockerfile.sandbox not found in #{ROOT_DIR}'
    STDERR.puts '  Sandbox config will be applied but no sandbox image will be built.'
    STDERR.puts '  Agent exec may fail if the configured sandbox image does not exist.'
  end

  # Defense-in-depth: verify Docker CLI in the running image before enabling
  # sandbox. This avoids claiming sandbox is enabled when the image cannot
  # launch sandbox containers.
  if system("docker compose #{COMPOSE_ARGS.join(' ')} run --rm --entrypoint docker openclaw-gateway --version >/dev/null 2>&1")
    puts 'Sandbox enabled: mode=non-main, scope=agent, workspaceAccess=none'
    puts 'Docs: https://docs.openclaw.ai/gateway/sandboxing'
    # Restart gateway with sandbox compose overlay to pick up socket mount + config.
    system("docker compose #{COMPOSE_ARGS.join(' ')} up -d openclaw-gateway")
  else
    STDERR.puts 'WARNING: Docker CLI not found inside the container image.'
    STDERR.puts '  Sandbox requires Docker CLI. Rebuild with --build-arg OPENCLAW_INSTALL_DOCKER_CLI=1'
    STDERR.puts '  or use a local build (OPENCLAW_IMAGE=openclaw:local). Skipping sandbox setup.'
    SANDBOX_ENABLED = ''
  end
end

# Apply sandbox config only if prerequisites are met.
if !SANDBOX_ENABLED.empty?
  # Mount Docker socket via a dedicated compose overlay. This overlay is
  # created only after sandbox prerequisites pass, so the socket is never
  # exposed when sandbox cannot actually run.
  if File.socket?(DOCKER_SOCKET_PATH)
    SANDBOX_COMPOSE_FILE = File.join(ROOT_DIR, 'docker-compose.sandbox.yml')
    File.open(SANDBOX_COMPOSE_FILE, 'w') do |f|
      f.puts <<~YAML
        services:
          openclaw-gateway:
            volumes:
              - #{DOCKER_SOCKET_PATH}:/var/run/docker.sock
      YAML
      if !ENV['DOCKER_GID'].empty?
        f.puts <<~YAML
            group_add:
              - "#{ENV['DOCKER_GID']}"
        YAML
      end
    end
    COMPOSE_ARGS.push('-f', SANDBOX_COMPOSE_FILE)
    puts '==> Sandbox: added Docker socket mount'
  else
    STDERR.puts "WARNING: OPENCLAW_SANDBOX enabled but Docker socket not found at #{DOCKER_SOCKET_PATH}."
    STDERR.puts '  Sandbox requires Docker socket access. Skipping sandbox setup.'
    SANDBOX_ENABLED = ''
  end
end

if !SANDBOX_ENABLED.empty?
  # Enable sandbox in OpenClaw config.
  sandbox_config_ok = true
  unless system("#{run_runtime_cli('current', 'no-deps', 'config', 'set', 'agents.defaults.sandbox.mode', '"non-main"')} >/dev/null")
    STDERR.puts 'WARNING: Failed to set agents.defaults.sandbox.mode'
    sandbox_config_ok = false
  end
  unless system("#{run_runtime_cli('current', 'no-deps', 'config', 'set', 'agents.defaults.sandbox.scope', '"agent"')} >/dev/null")
    STDERR.puts 'WARNING: Failed to set agents.defaults.sandbox.scope'
    sandbox_config_ok = false
  end
  unless system("#{run_runtime_cli('current', 'no-deps', 'config', 'set', 'agents.defaults.sandbox.workspaceAccess', '"none"')} >/dev/null")
    STDERR.puts 'WARNING: Failed to set agents.defaults.sandbox.workspaceAccess'
    sandbox_config_ok = false
  end

  if sandbox_config_ok
    puts 'Sandbox enabled: mode=non-main, scope=agent, workspaceAccess=none'
    puts 'Docs: https://docs.openclaw.ai/gateway/sandboxing'
    # Restart gateway with sandbox compose overlay to pick up socket mount + config.
    system("docker compose #{COMPOSE_ARGS.join(' ')} up -d openclaw-gateway")
  else
    STDERR.puts 'WARNING: Sandbox config was partially applied. Check errors above.'
    STDERR.puts '  Skipping gateway restart to avoid exposing Docker socket without a full sandbox policy.'
    unless system("#{run_runtime_cli('base', 'no-deps', 'config', 'set', 'agents.defaults.sandbox.mode', '"off"')} >/dev/null")
      STDERR.puts 'WARNING: Failed to roll back agents.defaults.sandbox.mode to off'
    else
      puts 'Sandbox mode rolled back to off due to partial sandbox config failure.'
    end
    if defined?(SANDBOX_COMPOSE_FILE) && File.exist?(SANDBOX_COMPOSE_FILE)
      File.delete(SANDBOX_COMPOSE_FILE)
    end
    # Ensure gateway service definition is reset without sandbox overlay mount.
    system("docker compose #{BASE_COMPOSE_ARGS.join(' ')} up -d --force-recreate openclaw-gateway")
  end
else
  # Keep reruns deterministic: if sandbox is not active for this run, reset
  # persisted sandbox mode so future execs do not require docker.sock by stale
  # config alone.
  unless system("#{run_runtime_cli('current', 'with-deps', 'config', 'set', 'agents.defaults.sandbox.mode', '"off"')} >/dev/null")
    STDERR.puts 'WARNING: Failed to reset agents.defaults.sandbox.mode to off'
  end
  if File.exist?(File.join(ROOT_DIR, 'docker-compose.sandbox.yml'))
    File.delete(File.join(ROOT_DIR, 'docker-compose.sandbox.yml'))
  end
end

puts ''
puts 'Gateway running with host port mapping.'
puts 'Access from tailnet devices via the host\'s tailnet IP.'
puts "Config: #{ENV['OPENCLAW_CONFIG_DIR']}"
puts "Workspace: #{ENV['OPENCLAW_WORKSPACE_DIR']}"
puts "Token: #{ENV['OPENCLAW_GATEWAY_TOKEN']}"
puts ''
puts 'Commands:'
puts "  #{COMPOSE_HINT} logs -f openclaw-gateway"
puts "  #{COMPOSE_HINT} exec openclaw-gateway node dist/index.js health --token \"#{ENV['OPENCLAW_GATEWAY_TOKEN']}\""

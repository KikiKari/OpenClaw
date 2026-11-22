#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "d3d7c320dcf109536a857be0c65dfe456488f6ca26ed24aa4ca69e3390f3bba5", "source_sha256": "9b573d1d5f5751c3fe5bb1eb243725ffb174987da9e458632a295c541458b2a0", "target_language": "ruby"}
# run-openclaw-podman.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/run-openclaw-podman.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

# Rootless OpenClaw in Podman: run after one-time setup.
#
# One-time setup (from repo root): ./scripts/podman/setup.sh
# Then:
#   ./scripts/run-openclaw-podman.sh launch        # Start gateway
#   ./scripts/run-openclaw-podman.sh launch setup  # Onboarding wizard
#
# Manage the running container from the host CLI:
#   openclaw --container openclaw dashboard --no-open
#   openclaw --container openclaw channels login
#
# Legacy: "setup-host" delegates to the Podman setup script

def resolve_user_home(user)
  home = ""
  if system("getent passwd #{user} >/dev/null 2>&1")
    home = `getent passwd #{user} 2>/dev/null | cut -d: -f6`.strip
  end
  if home.empty? && File.exist?("/etc/passwd")
    home = `awk -F: -v u="#{user}" '$1==u {print $6}' /etc/passwd 2>/dev/null`.strip
  end
  if home.empty?
    home = "/home/#{user}"
  end
  home
end

def fail(message)
  STDERR.puts message
  exit 1
end

def validate_single_line_value(label, value)
  if value.include?("\n") || value.include?("\r")
    fail "Invalid #{label}: control characters are not allowed."
  end
end

def validate_absolute_path(label, value)
  validate_single_line_value(label, value)
  fail "Invalid #{label}: expected an absolute path." unless value.start_with?("/")
  fail "Invalid #{label}: repeated slashes are not allowed." if value.include?("//")
  fail "Invalid #{label}: dot path segments are not allowed." if value.include?("/./") || value.end_with?("/.") || value.include?("/../") || value.end_with?("/..")
end

def validate_mount_source_path(label, value)
  validate_absolute_path(label, value)
  fail "Invalid #{label}: ':' is not allowed in Podman bind-mount source paths." if value.include?(":")
end

def ensure_safe_existing_regular_file(label, file)
  validate_absolute_path(label, file)
  fail "Missing #{label}: #{file}" unless File.exist?(file)
  fail "Unsafe #{label}: symlinks are not allowed (#{file})" if File.symlink?(file)
  fail "Unsafe #{label}: expected a regular file (#{file})" unless File.file?(file)
end

def ensure_safe_existing_dir(label, dir)
  validate_absolute_path(label, dir)
  fail "Missing #{label}: #{dir}" unless Dir.exist?(dir)
  fail "Unsafe #{label}: symlinks are not allowed (#{dir})" if File.symlink?(dir)
end

def stat_uid(path)
  if system("stat -f '%u' #{path} >/dev/null 2>&1")
    `stat -f '%u' #{path}`.strip
  else
    `stat -Lc '%u' #{path}`.strip
  end
end

def stat_mode(path)
  if system("stat -f '%Lp' #{path} >/dev/null 2>&1")
    `stat -f '%Lp' #{path}`.strip
  else
    `stat -Lc '%a' #{path}`.strip
  end
end

def ensure_private_existing_dir_owned_by_user(label, dir)
  ensure_safe_existing_dir(label, dir)
  uid = stat_uid(dir)
  fail "Unsafe #{label}: not owned by current user (#{dir})" unless uid == Process.uid.to_s
  mode = stat_mode(dir)
  fail "Unsafe #{label}: group/other writable (#{dir})" unless (mode.oct & 0022) == 0
end

def ensure_private_existing_regular_file_owned_by_user(label, file)
  ensure_safe_existing_regular_file(label, file)
  uid = stat_uid(file)
  fail "Unsafe #{label}: not owned by current user (#{file})" unless uid == Process.uid.to_s
  mode = stat_mode(file)
  fail "Unsafe #{label}: expected owner-only permissions (#{file})" unless (mode.oct & 0077) == 0
end

def ensure_safe_write_file_path(label, file)
  validate_absolute_path(label, file)
  if File.exist?(file)
    fail "Unsafe #{label}: symlinks are not allowed (#{file})" if File.symlink?(file)
    fail "Unsafe #{label}: expected a regular file (#{file})" unless File.file?(file)
  end
  dir = File.dirname(file)
  ensure_safe_existing_dir("#{label} parent directory", dir)
end

def write_file_atomically(file, mode)
  ensure_safe_write_file_path("output file", file)
  dir = File.dirname(file)
  tmp = Dir.mktmpdir(".tmp", dir)
  File.open(tmp, "w") { |f| f.write(STDIN.read) }
  File.chmod(mode, tmp)
  File.rename(tmp, file)
end

def load_podman_env_file(file)
  ensure_private_existing_regular_file_owned_by_user("Podman env file", file)
  dir = File.dirname(file)
  ensure_private_existing_dir_owned_by_user("Podman env directory", dir)
  
  File.foreach(file) do |line|
    trimmed = line.lstrip
    next if trimmed.empty? || trimmed.start_with?("#")
    next unless line.include?("=")
    
    key, value = line.split("=", 2)
    key = key.strip
    value = value.strip
    
    next unless key.match?(/^[A-Za-z_][A-Za-z0-9_]*$/)
    
    case key
    when "OPENCLAW_GATEWAY_TOKEN", "OPENCLAW_PODMAN_CONTAINER", "OPENCLAW_PODMAN_IMAGE", 
         "OPENCLAW_IMAGE", "OPENCLAW_PODMAN_PULL", "OPENCLAW_PODMAN_GATEWAY_HOST_PORT", 
         "OPENCLAW_GATEWAY_PORT", "OPENCLAW_PODMAN_BRIDGE_HOST_PORT", "OPENCLAW_BRIDGE_PORT", 
         "OPENCLAW_GATEWAY_BIND", "OPENCLAW_PODMAN_USERNS", "OPENCLAW_BIND_MOUNT_OPTIONS", 
         "OPENCLAW_PODMAN_PUBLISH_HOST"
      # Valid key
    else
      next
    end
    
    if (value.start_with?('"') && value.end_with?('"')) || (value.start_with?("'") && value.end_with?("'"))
      value = value[1..-2]
    end
    
    ENV[key] = value
  end
end

def validate_port(label, value)
  fail "Invalid #{label}: must be numeric." unless value.match?(/^[0-9]{1,5}$/)
  numeric = value.to_i
  fail "Invalid #{label}: out of range." unless numeric >= 1 && numeric <= 65535
end

platform_name = `uname -s 2>/dev/null`.strip rescue "unknown"

effective_user = `id -un`.strip
effective_home = ENV["HOME"] || ""
if effective_home.empty?
  effective_home = resolve_user_home(effective_user)
end

fail "Run run-openclaw-podman.sh as your normal user so Podman stays rootless." if Process.uid == 0

# Legacy: setup-host -> run the Podman setup script
if ARGV[0] == "setup-host"
  ARGV.shift
  repo_root = File.expand_path("../..", __FILE__)
  setup_podman = "#{repo_root}/scripts/podman/setup.sh"
  if File.exist?(setup_podman)
    exec setup_podman, *ARGV
  end
  setup_podman = "#{repo_root}/setup-podman.sh"
  if File.exist?(setup_podman)
    exec setup_podman, *ARGV
  end
  STDERR.puts "Podman setup script not found. Run from repo root: ./scripts/podman/setup.sh"
  exit 1
end

if ARGV[0] == "launch"
  ARGV.shift
end

if effective_home.empty?
  effective_home = "/tmp"
end
validate_absolute_path("effective home", effective_home)

config_dir = ENV["OPENCLAW_CONFIG_DIR"] || "#{effective_home}/.openclaw"
env_file = ENV["OPENCLAW_PODMAN_ENV"] || "#{config_dir}/.env"
# Bootstrap `.env` may set runtime/container options, but it must not
# relocate the config/workspace/env paths mid-run. Those path overrides are
# only honored from the parent process environment before bootstrap.
if File.exist?(env_file)
  load_podman_env_file(env_file)
end

config_dir = ENV["OPENCLAW_CONFIG_DIR"] || "#{effective_home}/.openclaw"
env_file = ENV["OPENCLAW_PODMAN_ENV"] || "#{config_dir}/.env"
workspace_dir = ENV["OPENCLAW_WORKSPACE_DIR"] || "#{config_dir}/workspace"
container_name = ENV["OPENCLAW_PODMAN_CONTAINER"] || "openclaw"
openclaw_image = ENV["OPENCLAW_PODMAN_IMAGE"] || ENV["OPENCLAW_IMAGE"] || "openclaw:local"
podman_pull = ENV["OPENCLAW_PODMAN_PULL"] || "never"
host_gateway_port = ENV["OPENCLAW_PODMAN_GATEWAY_HOST_PORT"] || ENV["OPENCLAW_GATEWAY_PORT"] || "18789"
host_bridge_port = ENV["OPENCLAW_PODMAN_BRIDGE_HOST_PORT"] || ENV["OPENCLAW_BRIDGE_PORT"] || "18790"
publish_host = ENV["OPENCLAW_PODMAN_PUBLISH_HOST"] || "127.0.0.1"
validate_mount_source_path("config directory", config_dir)
validate_mount_source_path("workspace directory", workspace_dir)
validate_absolute_path("env file path", env_file)
validate_single_line_value("container name", container_name)
validate_single_line_value("image name", openclaw_image)
validate_single_line_value("publish host", publish_host)
validate_port("gateway host port", host_gateway_port)
validate_port("bridge host port", host_bridge_port)

Dir.chdir(effective_home) rescue Dir.chdir("/tmp") rescue nil

run_setup = false
if ARGV[0] == "setup" || ARGV[0] == "onboard"
  run_setup = true
  ARGV.shift
end

Dir.mkdir(config_dir, 0700) unless Dir.exist?(config_dir)
Dir.mkdir(workspace_dir, 0700) unless Dir.exist?(workspace_dir)
Dir.mkdir("#{config_dir}/canvas", 0700) unless Dir.exist?("#{config_dir}/canvas")
Dir.mkdir("#{config_dir}/cron", 0700) unless Dir.exist?("#{config_dir}/cron")
File.chmod(0700, config_dir, workspace_dir)
ensure_private_existing_dir_owned_by_user("config directory", config_dir)
ensure_private_existing_dir_owned_by_user("workspace directory", workspace_dir)

def resolve_config_gateway_bind(config_dir)
  return "" unless system("openclaw >/dev/null 2>&1")
  
  result = `OPENCLAW_CONTAINER="" OPENCLAW_CONFIG_DIR="#{config_dir}" openclaw config get gateway.bind 2>/dev/null`
  result.strip
rescue
  ""
end

# For published container ports, the gateway must listen on the container
# interface, so the Podman launcher defaults to lan. Respect an explicit
# OPENCLAW_GATEWAY_BIND first, then gateway.bind in local config.
config_gateway_bind = resolve_config_gateway_bind(config_dir)
gateway_bind = ENV["OPENCLAW_GATEWAY_BIND"] || config_gateway_bind || "lan"

def upsert_env_var(file, key, value)
  ensure_safe_write_file_path("env file", file)
  dir = File.dirname(file)
  tmp = Dir.mktmpdir(".env.tmp", dir)
  
  if File.exist?(file)
    lines = File.readlines(file)
    found = false
    new_lines = lines.map do |line|
      if line =~ /^#{key}=/
        found = true
        "#{key}=#{value}\n"
      else
        line
      end
    end
    new_lines << "#{key}=#{value}\n" unless found
    File.open(tmp, "w") { |f| f.write(new_lines.join) }
  else
    File.open(tmp, "w") { |f| f.write("#{key}=#{value}\n") }
  end
  
  File.rename(tmp, file)
  File.chmod(0600, file) rescue nil
end

def generate_token_hex_32
  if system("openssl >/dev/null 2>&1")
    return `openssl rand -hex 32`.strip
  end
  
  if system("python3 >/dev/null 2>&1")
    result = `python3 -c "import secrets; print(secrets.token_hex(32))"`
    return result.strip
  end
  
  if system("od >/dev/null 2>&1")
    return `od -An -N32 -tx1 /dev/urandom | tr -d \" \\n\"`.strip
  end
  
  STDERR.puts "Missing dependency: need openssl or python3 (or od) to generate OPENCLAW_GATEWAY_TOKEN."
  exit 1
end

def create_token_env_file(file, token)
  dir = File.dirname(file)
  ensure_private_existing_dir_owned_by_user("token env directory", dir)
  tmp = Dir.mktmpdir(".token.env", dir)
  File.chmod(0600, tmp)
  File.open(tmp, "w") { |f| f.write("OPENCLAW_GATEWAY_TOKEN=#{token}\n") }
  tmp
end

def sync_local_control_ui_origins_via_cli(file, port)
  config_dir = File.dirname(file)
  return unless system("openclaw >/dev/null 2>&1")
  
  unless system("python3 >/dev/null 2>&1")
    system("OPENCLAW_CONTAINER=\"\" OPENCLAW_CONFIG_DIR=\"#{config_dir}\" openclaw config set gateway.controlUi.allowedOrigins \"[\\\"http://127.0.0.1:#{port}\\\",\\\"http://localhost:#{port}\\\"]\" --strict-json >/dev/null")
    return
  end
  
  allowed_json = `OPENCLAW_CONTAINER="" OPENCLAW_CONFIG_DIR="#{config_dir}" openclaw config get gateway.controlUi.allowedOrigins --json 2>/dev/null`.strip rescue ""
  
  merged_json = `python3 -c "
import json
import sys

port = '#{port}'
raw = '#{allowed_json}'
desired = [
    f'http://127.0.0.1:{port}',
    f'http://localhost:{port}',
]
allowed = []
if raw:
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, list):
            allowed = parsed
    except json.JSONDecodeError:
        allowed = []
cleaned = []
seen = set()
for origin in allowed + desired:
    if not isinstance(origin, str):
        continue
    normalized = origin.strip()
    if not normalized or normalized in seen:
        continue
    cleaned.append(normalized)
    seen.add(normalized)
print(json.dumps(cleaned))
"` rescue ""
  
  system("OPENCLAW_CONTAINER=\"\" OPENCLAW_CONFIG_DIR=\"#{config_dir}\" openclaw config set gateway.controlUi.allowedOrigins \"#{merged_json}\" --strict-json >/dev/null")
end

def sync_local_control_ui_origins(file, port)
  ensure_safe_write_file_path("config file", file)
  unless system("python3 >/dev/null 2>&1")
    STDERR.puts "Warning: python3 not found; unable to sync gateway.controlUi.allowedOrigins in #{file}."
    return
  end
  
  dir = File.dirname(file)
  ensure_private_existing_dir_owned_by_user("config file directory", dir)
  tmp = Dir.mktmpdir(".config.tmp", dir)
  
  unless system("python3 -c \"
import json
import sys

path = '#{file}'
port = '#{port}'
tmp = '#{tmp}'
try:
    with open(path, \\\"r\\\", encoding=\\\"utf-8\\\") as fh:
        data = json.load(fh)
except json.JSONDecodeError as exc:
    print(
        f\\\"Warning: unable to sync gateway.controlUi.allowedOrigins in {path}: existing config is not strict JSON ({exc}). Leaving file unchanged.\\\",
        file=sys.stderr,
    )
    raise SystemExit(1)
if not isinstance(data, dict):
    raise SystemExit(f\\\"{path}: expected top-level object\\\")
gateway = data.setdefault(\\\"gateway\\\", {})
if not isinstance(gateway, dict):
    raise SystemExit(f\\\"{path}: expected gateway object\\\")
gateway.setdefault(\\\"mode\\\", \\\"local\\\")
control_ui = gateway.setdefault(\\\"controlUi\\\", {})
if not isinstance(control_ui, dict):
    raise SystemExit(f\\\"{path}: expected gateway.controlUi object\\\")
allowed = control_ui.get(\\\"allowedOrigins\\\")
desired = [
    f\\\"http://127.0.0.1:{port}\\\",
    f\\\"http://localhost:{port}\\\",
]
if not isinstance(allowed, list):
    allowed = []
cleaned = []
seen = set()
for origin in allowed:
    if not isinstance(origin, str):
        continue
    normalized = origin.strip()
    if not normalized or normalized in seen:
        continue
    cleaned.append(normalized)
    seen.add(normalized)
for origin in desired:
    if origin not in seen:
        cleaned.append(origin)
        seen.add(origin)
control_ui[\\\"allowedOrigins\\\"] = cleaned
with open(tmp, \\\"w\\\", encoding=\\\"utf-8\\\") as fh:
    json.dump(data, fh, indent=2)
    fh.write(\\\"\\\\n\\\")
\" 2>/dev/null")
    File.delete(tmp) if File.exist?(tmp)
    sync_local_control_ui_origins_via_cli(file, port)
    return
  end
  
  unless File.size(tmp) > 0
    File.delete(tmp) if File.exist?(tmp)
    return
  end
  
  File.chmod(0600, tmp) rescue nil
  File.rename(tmp, file)
end

token_env_file = ""
at_exit do
  if !token_env_file.empty? && File.exist?(token_env_file)
    File.delete(token_env_file)
  end
end

if ENV["OPENCLAW_GATEWAY_TOKEN"].nil? || ENV["OPENCLAW_GATEWAY_TOKEN"].empty?
  ENV["OPENCLAW_GATEWAY_TOKEN"] = generate_token_hex_32
  Dir.mkdir(File.dirname(env_file), 0700) unless Dir.exist?(File.dirname(env_file))
  ensure_safe_existing_dir("env file directory", File.dirname(env_file))
  upsert_env_var(env_file, "OPENCLAW_GATEWAY_TOKEN", ENV["OPENCLAW_GATEWAY_TOKEN"])
  STDERR.puts "Generated OPENCLAW_GATEWAY_TOKEN and wrote it to #{env_file}."
end

config_json = "#{config_dir}/openclaw.json"
unless File.exist?(config_json)
  File.umask(0077)
  write_file_atomically(config_json, 0600)
  File.open(config_json, "w") { |f| f.write("{ \"gateway\": { \"mode\": \"local\" } }\n") }
  STDERR.puts "Created #{config_json} (minimal gateway.mode=local)."
end
sync_local_control_ui_origins(config_json, host_gateway_port)

podman_userns = ENV["OPENCLAW_PODMAN_USERNS"] || "keep-id"
userns_args = []
run_user_args = []

case podman_userns
when "", "auto"
  # No additional args
when "keep-id"
  userns_args = ["--userns=keep-id"]
when "host"
  userns_args = ["--userns=host"]
else
  STDERR.puts "Unsupported OPENCLAW_PODMAN_USERNS=#{podman_userns} (expected: keep-id, auto, host)."
  exit 2
end

run_uid = Process.uid
run_gid = Process.gid
if podman_userns == "keep-id"
  run_user_args = ["--user", "#{run_uid}:#{run_gid}"]
else
  STDERR.puts "Starting container without --user (OPENCLAW_PODMAN_USERNS=#{podman_userns}), mounts may require ownership fixes."
end

selinux_mount_opts = ""
if ENV["OPENCLAW_BIND_MOUNT_OPTIONS"].nil? || ENV["OPENCLAW_BIND_MOUNT_OPTIONS"].empty?
  if `uname -s 2>/dev/null`.strip == "Linux" && system("getenforce >/dev/null 2>&1")
    selinux_mode = `getenforce 2>/dev/null`.strip rescue ""
    if selinux_mode == "Enforcing" || selinux_mode == "Permissive"
      selinux_mount_opts = ",Z"
    end
  end
else
  selinux_mount_opts = ENV["OPENCLAW_BIND_MOUNT_OPTIONS"][1..-1] || ""
  selinux_mount_opts = ",#{selinux_mount_opts}" unless selinux_mount_opts.empty?
end

if run_setup
  token_env_file = create_token_env_file(env_file, ENV["OPENCLAW_GATEWAY_TOKEN"])
  exec "podman", "run", "--pull=#{podman_pull}", "--rm", "-it",
       "--init",
       *userns_args, *run_user_args,
       "-e", "HOME=/home/node", "-e", "TERM=xterm-256color", "-e", "BROWSER=echo",
       "-e", "NPM_CONFIG_CACHE=/home/node/.openclaw/.npm",
       "-e", "OPENCLAW_NO_RESPAWN=1",
       "--env-file", token_env_file,
       "-v", "#{config_dir}:/home/node/.openclaw:rw#{selinux_mount_opts}",
       "-v", "#{workspace_dir}:/home/node/.openclaw/workspace:rw#{selinux_mount_opts}",
       openclaw_image,
       "node", "dist/index.js", "onboard", *ARGV
end

token_env_file = create_token_env_file(env_file, ENV["OPENCLAW_GATEWAY_TOKEN"])
system("podman", "run", "--pull=#{podman_pull}", "-d", "--replace",
  "--name", container_name,
  "--init",
  *userns_args, *run_user_args,
  "-e", "HOME=/home/node", "-e", "TERM=xterm-256color",
  "-e", "NPM_CONFIG_CACHE=/home/node/.openclaw/.npm",
  "-e", "OPENCLAW_NO_RESPAWN=1",
  "--env-file", token_env_file,
  "-v", "#{config_dir}:/home/node/.openclaw:rw#{selinux_mount_opts}",
  "-v", "#{workspace_dir}:/home/node/.openclaw/workspace:rw#{selinux_mount_opts}",
  "-p", "#{publish_host}:#{host_gateway_port}:18789",
  "-p", "#{publish_host}:#{host_bridge_port}:18790",
  openclaw_image,
  "node", "dist/index.js", "gateway", "--bind", gateway_bind, "--port", "18789", out: "/dev/null")

puts "Container #{container_name} started: http://127.0.0.1:#{host_gateway_port}/"
puts "podman exec -it #{container_name} openclaw dashboard --no-open"
puts "podman exec -it #{container_name} openclaw devices approve --latest  # if pairing required"
puts "podman logs -f #{container_name}"
if platform_name == "Linux"
  puts "For auto-start/restarts, use: ./scripts/podman/setup.sh --quadlet (Quadlet + systemd user service)."
end

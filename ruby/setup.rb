#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "3c84ddbe327e4baa2bba4a448caea8706f599a76db4a1e1a864916d2ce0b8585", "source_sha256": "53a6908a18055c2a46b63b5da3ddbf4ea5f6b1867c1482c1dcc8903c3ab7b89a", "target_language": "ruby"}
# setup.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/podman/setup.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# One-time host setup for rootless OpenClaw in Podman. Uses the current
# non-root user throughout, builds or pulls the image into that user's Podman
# store, writes config under ~/.openclaw by default, and uses the repo-local
# launch script at ./scripts/run-openclaw-podman.sh.
#
# Usage: ./scripts/podman/setup.rb [--quadlet|--container]
#   --quadlet   Install a Podman Quadlet as the current user's systemd service
#   --container Only install image + config; you start the container manually (default)
#   Or set OPENCLAW_PODMAN_QUADLET=1 (or 0) to choose without a flag.
#
# After this, start the gateway manually:
#   ./scripts/run-openclaw-podman.sh launch
#   ./scripts/run-openclaw-podman.sh launch setup
# Or, if you used --quadlet:
#   systemctl --user start openclaw.service

require 'fileutils'
require 'json'
require 'securerandom'
require 'pathname'

def require_cmd(cmd)
  unless system("command -v #{cmd} >/dev/null 2>&1")
    STDERR.puts "Missing dependency: #{cmd}"
    exit 1
  end
end

def is_root?
  Process.uid == 0
end

def fail(msg)
  STDERR.puts msg
  exit 1
end

def validate_single_line_value(label, value)
  if value.include?("\n") || value.include?("\r")
    fail "Invalid #{label}: control characters are not allowed."
  end
end

def validate_absolute_path(label, value)
  validate_single_line_value(label, value)
  fail "Invalid #{label}: expected an absolute path." unless value.start_with?('/')
  fail "Invalid #{label}: repeated slashes are not allowed." if value.include?('//')
  fail "Invalid #{label}: dot path segments are not allowed." if value.include?('/./') || value.end_with?('/.') || value.include?('/../') || value.end_with?('/..')
end

def validate_mount_source_path(label, value)
  validate_absolute_path(label, value)
  fail "Invalid #{label}: ':' is not allowed in Podman bind-mount source paths." if value.include?(':')
end

def validate_container_name(value)
  validate_single_line_value("container name", value)
  fail "Invalid container name: #{value}" unless value.match?(/^[A-Za-z0-9][A-Za-z0-9_.-]*$/)
end

def validate_image_name(value)
  validate_single_line_value("image name", value)
  case value
  when /^oci-archive:|^docker-archive:|^dir:|^oci:|^containers-storage:|^docker-daemon:|^archive:/
    fail "Invalid image name: transport prefixes are not allowed: #{value}"
  end
  fail "Invalid image name: #{value}" unless value.match?(/^[A-Za-z0-9][A-Za-z0-9._\/:@-]*$/)
end

def ensure_safe_existing_dir(label, dir)
  validate_absolute_path(label, dir)
  fail "Missing #{label}: #{dir}" unless Dir.exist?(dir)
  fail "Unsafe #{label}: symlinks are not allowed (#{dir})" if File.symlink?(dir)
end

def stat_uid(path)
  if system("stat -f '%u' '#{path}' >/dev/null 2>&1")
    `stat -f '%u' '#{path}'`.strip
  else
    `stat -Lc '%u' '#{path}'`.strip
  end
end

def stat_mode(path)
  if system("stat -f '%Lp' '#{path}' >/dev/null 2>&1")
    `stat -f '%Lp' '#{path}'`.strip
  else
    `stat -Lc '%a' '#{path}'`.strip
  end
end

def ensure_private_existing_dir_owned_by_user(label, dir)
  ensure_safe_existing_dir(label, dir)
  uid = stat_uid(dir)
  fail "Unsafe #{label}: not owned by current user (#{dir})" unless uid == Process.uid.to_s
  mode = stat_mode(dir).to_i(8)
  fail "Unsafe #{label}: group/other writable (#{dir})" unless (mode & 0022) == 0
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

def write_file_atomically(file, mode, content)
  ensure_safe_write_file_path("output file", file)
  dir = File.dirname(file)
  tmp = Tempfile.new(".tmp", dir)
  tmp.write(content)
  tmp.close
  FileUtils.chmod(mode, tmp.path)
  FileUtils.mv(tmp.path, file)
rescue => e
  tmp.unlink if tmp
  raise e
end

def validate_port(label, value)
  fail "Invalid #{label}: must be numeric." unless value.match?(/^[0-9]{1,5}$/)
  numeric = value.to_i
  fail "Invalid #{label}: out of range." unless numeric >= 1 && numeric <= 65535
end

def escape_sed_replacement_pipe_delim(str)
  str.gsub(/[\\&|]/, '\\&')
end

def resolve_user_home(user)
  home = ""
  if system("command -v getent >/dev/null 2>&1")
    home = `getent passwd '#{user}' 2>/dev/null | cut -d: -f6`.strip rescue ""
  end
  if home.empty? && File.exist?("/etc/passwd")
    home = `awk -F: -v u='#{user}' '$1==u {print $6}' /etc/passwd 2>/dev/null`.strip rescue ""
  end
  if home.empty?
    home = "/home/#{user}"
  end
  home
end

def generate_token_hex_32
  if system("command -v openssl >/dev/null 2>&1")
    return `openssl rand -hex 32`.strip
  end
  if system("command -v python3 >/dev/null 2>&1")
    result = `python3 -c "import secrets; print(secrets.token_hex(32))"`.strip
    return result
  end
  if system("command -v od >/dev/null 2>&1")
    return `od -An -N32 -tx1 /dev/urandom | tr -d \" \\n\"`.strip
  end
  STDERR.puts "Missing dependency: need openssl or python3 (or od) to generate OPENCLAW_GATEWAY_TOKEN."
  exit 1
end

def seed_local_control_ui_origins(file, port)
  ensure_safe_write_file_path("config file", file)
  unless system("command -v python3 >/dev/null 2>&1")
    STDERR.puts "Warning: python3 not found; unable to seed gateway.controlUi.allowedOrigins in #{file}."
    return
  end
  dir = File.dirname(file)
  
  python_script = <<~PYTHON
    import json
    import sys

    path = sys.argv[1]
    port = sys.argv[2]
    try:
        with open(path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except json.JSONDecodeError as exc:
        print(
            f"Warning: unable to seed gateway.controlUi.allowedOrigins in {path}: existing config is not strict JSON ({exc}). Leaving file unchanged.",
            file=sys.stderr,
        )
        raise SystemExit(1)
    if not isinstance(data, dict):
        raise SystemExit(f"{path}: expected top-level object")
    gateway = data.setdefault("gateway", {})
    if not isinstance(gateway, dict):
        raise SystemExit(f"{path}: expected gateway object")
    gateway.setdefault("mode", "local")
    control_ui = gateway.setdefault("controlUi", {})
    if not isinstance(control_ui, dict):
        raise SystemExit(f"{path}: expected gateway.controlUi object")
    allowed = control_ui.get("allowedOrigins")
    managed_localhosts = {"127.0.0.1", "localhost"}
    desired = [
        f"http://127.0.0.1:{port}",
        f"http://localhost:{port}",
    ]
    if not isinstance(allowed, list):
        allowed = []
    cleaned = []
    for origin in allowed:
        if not isinstance(origin, str):
            continue
        normalized = origin.strip()
        if not normalized:
            continue
        if normalized.startswith("http://"):
            host_port = normalized[len("http://") :]
            host = host_port.split(":", 1)[0]
            if host in managed_localhosts:
                continue
        cleaned.append(normalized)
    control_ui["allowedOrigins"] = cleaned + desired
    with open(sys.argv[3], "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2)
        fh.write("\\n")
  PYTHON
  
  tmp_file = Tempfile.new(".config.tmp", dir)
  tmp_path = tmp_file.path
  tmp_file.close
  
  result = system("python3 -c #{python_script.dump} #{file} #{port} #{tmp_path}")
  
  unless result
    FileUtils.rm_f(tmp_path)
    return
  end
  
  unless File.size?(tmp_path)
    FileUtils.rm_f(tmp_path)
    return
  end
  
  FileUtils.chmod(0600, tmp_path) rescue nil
  FileUtils.mv(tmp_path, file)
end

def upsert_env_var(file, key, value)
  ensure_safe_write_file_path("env file", file)
  lines = []
  if File.exist?(file)
    lines = File.readlines(file).map(&:chomp)
  end
  
  found = false
  new_lines = lines.map do |line|
    if line.match(/^#{key}=/)
      found = true
      "#{key}=#{value}"
    else
      line
    end
  end
  
  unless found
    new_lines << "#{key}=#{value}"
  end
  
  File.open(file, 'w') do |f|
    f.puts new_lines
  end
  
  FileUtils.chmod(0600, file) rescue nil
end

# Main script logic starts here

repo_path = ENV['OPENCLAW_REPO_PATH'] || begin
  script_dir = File.dirname(File.realpath(__FILE__))
  File.expand_path("../../..", script_dir)
end

run_script_src = File.join(repo_path, "scripts", "run-openclaw-podman.sh")
quadlet_template = File.join(repo_path, "scripts", "podman", "openclaw.container.in")
openclaw_user = `id -un`.strip
openclaw_home = ENV['HOME'] || ""
openclaw_config_dir = ENV['OPENCLAW_CONFIG_DIR'] || ""
openclaw_workspace_dir = ENV['OPENCLAW_WORKSPACE_DIR'] || ""
openclaw_image = ENV['OPENCLAW_PODMAN_IMAGE'] || ENV['OPENCLAW_IMAGE'] || "openclaw:local"
openclaw_container_name = ENV['OPENCLAW_PODMAN_CONTAINER'] || "openclaw"
platform_name = `uname -s 2>/dev/null`.strip rescue "unknown"
host_gateway_port = ENV['OPENCLAW_PODMAN_GATEWAY_HOST_PORT'] || ENV['OPENCLAW_GATEWAY_PORT'] || "18789"
quadlet_gateway_port = "18789"

install_quadlet = false
ARGV.each do |arg|
  case arg
  when "--quadlet"
    install_quadlet = true
  when "--container"
    install_quadlet = false
  end
end

if !ENV['OPENCLAW_PODMAN_QUADLET'].nil? && !ENV['OPENCLAW_PODMAN_QUADLET'].empty?
  case ENV['OPENCLAW_PODMAN_QUADLET'].downcase
  when "1", "yes", "true"
    install_quadlet = true
  when "0", "no", "false"
    install_quadlet = false
  end
end

if install_quadlet && platform_name != "Linux"
  fail "--quadlet is only supported on Linux with systemd user services."
end

seed_gateway_port = install_quadlet ? quadlet_gateway_port : host_gateway_port

require_cmd("podman")
if is_root?
  STDERR.puts "Run scripts/podman/setup.rb as your normal user so Podman stays rootless."
  exit 1
end

if openclaw_image == "openclaw:local" && !File.exist?(File.join(repo_path, "Dockerfile"))
  STDERR.puts "Dockerfile not found at #{repo_path}. Set OPENCLAW_REPO_PATH to the repo root."
  exit 1
end

unless File.exist?(run_script_src)
  STDERR.puts "Launch script not found at #{run_script_src}."
  exit 1
end

if openclaw_home.empty?
  openclaw_home = resolve_user_home(openclaw_user)
end

if openclaw_home.empty?
  STDERR.puts "Unable to resolve HOME for user #{openclaw_user}."
  exit 1
end

if openclaw_config_dir.empty?
  openclaw_config_dir = File.join(openclaw_home, ".openclaw")
end

if openclaw_workspace_dir.empty?
  openclaw_workspace_dir = File.join(openclaw_config_dir, "workspace")
end

validate_absolute_path("home directory", openclaw_home)
validate_mount_source_path("config directory", openclaw_config_dir)
validate_mount_source_path("workspace directory", openclaw_workspace_dir)
validate_container_name(openclaw_container_name)
validate_image_name(openclaw_image)
validate_port("gateway host port", host_gateway_port)
validate_port("seed gateway port", seed_gateway_port)

FileUtils.mkdir_p([openclaw_config_dir, openclaw_workspace_dir], mode: 0700)
ensure_private_existing_dir_owned_by_user("config directory", openclaw_config_dir)
ensure_private_existing_dir_owned_by_user("workspace directory", openclaw_workspace_dir)

build_args = []
if !ENV['OPENCLAW_DOCKER_APT_PACKAGES'].nil? && !ENV['OPENCLAW_DOCKER_APT_PACKAGES'].empty?
  build_args += ["--build-arg", "OPENCLAW_DOCKER_APT_PACKAGES=#{ENV['OPENCLAW_DOCKER_APT_PACKAGES']}"]
end

if !ENV['OPENCLAW_EXTENSIONS'].nil? && !ENV['OPENCLAW_EXTENSIONS'].empty?
  build_args += ["--build-arg", "OPENCLAW_EXTENSIONS=#{ENV['OPENCLAW_EXTENSIONS']}"]
end

if openclaw_image == "openclaw:local"
  puts "Building image #{openclaw_image} ..."
  system("podman build -t '#{openclaw_image}' -f '#{File.join(repo_path, "Dockerfile")}' #{build_args.join(' ')} '#{repo_path}'")
else
  if system("podman image exists '#{openclaw_image}' >/dev/null 2>&1")
    puts "Using existing image #{openclaw_image}"
  else
    puts "Pulling image #{openclaw_image} ..."
    system("podman pull '#{openclaw_image}'")
  end
end

env_file = File.join(openclaw_config_dir, ".env")
unless File.exist?(env_file)
  token = generate_token_hex_32
  File.open(env_file, 'w', 0600) do |f|
    f.puts "OPENCLAW_GATEWAY_TOKEN=#{token}"
  end
  puts "Generated OPENCLAW_GATEWAY_TOKEN and wrote it to #{env_file}"
end

upsert_env_var(env_file, "OPENCLAW_PODMAN_CONTAINER", openclaw_container_name)
upsert_env_var(env_file, "OPENCLAW_PODMAN_IMAGE", openclaw_image)

config_json = File.join(openclaw_config_dir, "openclaw.json")
unless File.exist?(config_json)
  content = {
    "gateway" => {
      "mode" => "local",
      "controlUi" => {
        "allowedOrigins" => [
          "http://127.0.0.1:#{seed_gateway_port}",
          "http://localhost:#{seed_gateway_port}"
        ]
      }
    }
  }
  
  File.open(config_json, 'w', 0600) do |f|
    f.puts JSON.pretty_generate(content)
  end
  puts "Wrote minimal config to #{config_json}"
end

seed_local_control_ui_origins(config_json, seed_gateway_port)

if install_quadlet
  quadlet_dir = File.join(openclaw_home, ".config", "containers", "systemd")
  quadlet_dst = File.join(quadlet_dir, "openclaw.container")
  puts "Installing Quadlet to #{quadlet_dst} ..."
  FileUtils.mkdir_p(quadlet_dir)
  ensure_safe_existing_dir("quadlet directory", quadlet_dir)
  
  openclaw_home_escaped = escape_sed_replacement_pipe_delim(openclaw_home)
  openclaw_config_escaped = escape_sed_replacement_pipe_delim(openclaw_config_dir)
  openclaw_workspace_escaped = escape_sed_replacement_pipe_delim(openclaw_workspace_dir)
  openclaw_image_escaped = escape_sed_replacement_pipe_delim(openclaw_image)
  openclaw_container_escaped = escape_sed_replacement_pipe_delim(openclaw_container_name)
  
  template_content = File.read(quadlet_template)
  content = template_content
    .gsub("{{OPENCLAW_HOME}}", openclaw_home_escaped)
    .gsub("{{OPENCLAW_CONFIG_DIR}}", openclaw_config_escaped)
    .gsub("{{OPENCLAW_WORKSPACE_DIR}}", openclaw_workspace_escaped)
    .gsub("{{IMAGE_NAME}}", openclaw_image_escaped)
    .gsub("{{CONTAINER_NAME}}", openclaw_container_escaped)
  
  write_file_atomically(quadlet_dst, 0644, content)
  
  if system("command -v systemctl >/dev/null 2>&1")
    puts "Reloading and starting user service..."
    if system("systemctl --user daemon-reload") && system("systemctl --user start openclaw.service")
      puts "Quadlet installed and service started."
    else
      STDERR.puts "Quadlet installed, but automatic start failed."
      STDERR.puts "Try: systemctl --user daemon-reload && systemctl --user start openclaw.service"
      if system("command -v loginctl >/dev/null 2>&1")
        STDERR.puts "For boot persistence on headless hosts, you may also need: sudo loginctl enable-linger #{`whoami`.strip}"
      end
    end
  else
    STDERR.puts "systemctl not found; Quadlet installed but not started."
  end
else
  puts "Container setup complete."
end

puts
puts "Next:"
puts "  ./scripts/run-openclaw-podman.sh launch"
puts "  ./scripts/run-openclaw-podman.sh launch setup"
puts "  openclaw --container #{openclaw_container_name} dashboard --no-open"

#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "311d52aa3cbb2258d967c7153ae22bb3a30a27efec365b6b7cd28f2117897ab5", "source_sha256": "fbf046d1988d19407db864ee85d468151b410a1dc1cab4374f1f8119c6fb9897", "target_language": "ruby"}
# restart-mac.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/restart-mac.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

# Reset OpenClaw like Trimmy: kill running instances, rebuild, repackage, relaunch, verify.

require 'fileutils'
require 'digest'
require 'open3'
require 'timeout'

def log(msg)
  puts msg
end

def fail(msg)
  $stderr.puts "ERROR: #{msg}"
  exit 1
end

ROOT_DIR = File.expand_path(File.join(File.dirname(__FILE__), '..'))
APP_BUNDLE = ENV['OPENCLAW_APP_BUNDLE'] || ''
APP_PROCESS_PATTERN = 'OpenClaw.app/Contents/MacOS/OpenClaw'
DEBUG_PROCESS_PATTERN = "#{ROOT_DIR}/apps/macos/.build/debug/OpenClaw"
LOCAL_PROCESS_PATTERN = "#{ROOT_DIR}/apps/macos/.build-local/debug/OpenClaw"
RELEASE_PROCESS_PATTERN = "#{ROOT_DIR}/apps/macos/.build/release/OpenClaw"
LAUNCH_AGENT = "#{ENV['HOME']}/Library/LaunchAgents/ai.openclaw.mac.plist"
LOCK_KEY = Digest::SHA256.hexdigest(ROOT_DIR)[0...8]
LOCK_DIR = "#{ENV['TMPDIR'] || '/tmp'}/openclaw-restart-#{LOCK_KEY}"
LOCK_PID_FILE = "#{LOCK_DIR}/pid"
WAIT_FOR_LOCK = false
LOG_PATH = ENV['OPENCLAW_RESTART_LOG'] || '/tmp/openclaw-restart.log'
NO_SIGN = false
SIGN = false
AUTO_DETECT_SIGNING = true
GATEWAY_WAIT_SECONDS = (ENV['OPENCLAW_GATEWAY_WAIT_SECONDS'] || '0').to_i
LAUNCHAGENT_DISABLE_MARKER = "#{ENV['HOME']}/.openclaw/disable-launchagent"
ATTACH_ONLY = true

def run_step(label)
  log "==> #{label}"
  stdout, stderr, status = Open3.capture3(yield)
  unless status.success?
    fail "#{label} failed\n#{stderr}"
  end
  stdout
end

def cleanup
  FileUtils.rm_rf(LOCK_DIR) if Dir.exist?(LOCK_DIR)
end

def acquire_lock
  loop do
    if Dir.mkdir(LOCK_DIR)
      File.write(LOCK_PID_FILE, Process.pid.to_s)
      return
    end

    existing_pid = nil
    if File.exist?(LOCK_PID_FILE)
      existing_pid = File.read(LOCK_PID_FILE).strip
    end

    if existing_pid && kill_0(existing_pid)
      if WAIT_FOR_LOCK
        log "==> Another restart is running (pid #{existing_pid}); waiting..."
        while kill_0(existing_pid)
          sleep 1
        end
        next
      end
      log "==> Another restart is running (pid #{existing_pid}); re-run with --wait."
      exit 0
    end

    FileUtils.rm_rf(LOCK_DIR)
  end
end

def kill_0(pid)
  begin
    Process.kill(0, pid.to_i)
    true
  rescue Errno::ESRCH
    false
  rescue
    true
  end
end

def check_signing_keys
  stdout, _, status = Open3.capture3('security find-identity -p codesigning -v 2>/dev/null')
  return false unless status.success?
  stdout.match?(/(Developer ID Application|Apple Distribution|Apple Development)/)
end

at_exit { cleanup }
Signal.trap('INT') { exit 1 }
Signal.trap('TERM') { exit 1 }

ARGV.each do |arg|
  case arg
  when '--wait', '-w'
    WAIT_FOR_LOCK = true
  when '--no-sign'
    NO_SIGN = true
    AUTO_DETECT_SIGNING = false
  when '--sign'
    SIGN = true
    AUTO_DETECT_SIGNING = false
  when '--attach-only'
    ATTACH_ONLY = true
  when '--no-attach-only'
    ATTACH_ONLY = false
  when '--help', '-h'
    log "Usage: #{$0} [--wait] [--no-sign] [--sign] [--attach-only|--no-attach-only]"
    log "  --wait    Wait for other restart to complete instead of exiting"
    log "  --no-sign Force no code signing (fastest for development)"
    log "  --sign    Force code signing (will fail if no signing key available)"
    log "  --attach-only    Launch app with --attach-only (skip launchd install)"
    log "  --no-attach-only Launch app without attach-only override"
    log ""
    log "Env:"
    log "  OPENCLAW_GATEWAY_WAIT_SECONDS=0  Wait time before gateway port check (unsigned only)"
    log ""
    log "Unsigned recovery:"
    log "  node openclaw.mjs daemon install --force --runtime node"
    log "  node openclaw.mjs daemon restart"
    log ""
    log "Reset unsigned overrides:"
    log "  rm ~/.openclaw/disable-launchagent"
    log ""
    log "Default behavior: Auto-detect signing keys, fallback to --no-sign if none found"
    exit 0
  end
end

fail "Cannot use --sign and --no-sign together" if NO_SIGN && SIGN

FileUtils.mkdir_p(File.dirname(LOG_PATH))
File.unlink(LOG_PATH) if File.exist?(LOG_PATH)

log_file = File.open(LOG_PATH, 'w')
$stdout.reopen(log_file)
$stderr.reopen(log_file)

log "==> Log: #{LOG_PATH}"
log "==> Using --no-sign (unsigned flow enabled)" if NO_SIGN
log "==> Using --attach-only (skip launchd install)" if ATTACH_ONLY

acquire_lock

def kill_all_openclaw
  10.times do
    %W[
      #{APP_PROCESS_PATTERN}
      #{DEBUG_PROCESS_PATTERN}
      #{LOCAL_PROCESS_PATTERN}
      #{RELEASE_PROCESS_PATTERN}
    ].each do |pattern|
      system("pkill -f '#{pattern}' 2>/dev/null", out: File::NULL, err: File::NULL)
    end
    system("pkill -x 'OpenClaw' 2>/dev/null", out: File::NULL, err: File::NULL)
    
    patterns = [
      APP_PROCESS_PATTERN,
      DEBUG_PROCESS_PATTERN,
      LOCAL_PROCESS_PATTERN,
      RELEASE_PROCESS_PATTERN
    ]
    
    unless patterns.any? { |p| system("pgrep -f '#{p}' >/dev/null 2>&1", out: File::NULL, err: File::NULL) } &&
           system("pgrep -x 'OpenClaw' >/dev/null 2>&1", out: File::NULL, err: File::NULL)
      return
    end
    
    sleep 0.3
  end
end

def stop_launch_agent
  system("launchctl bootout gui/$UID/ai.openclaw.mac 2>/dev/null", out: File::NULL, err: File::NULL)
end

log "==> Killing existing OpenClaw instances"
kill_all_openclaw
stop_launch_agent

# Bundle Gateway-hosted Canvas A2UI assets.
run_step("bundle canvas a2ui") { "bash -lc \"cd '#{ROOT_DIR}' && pnpm canvas:a2ui:bundle\"" }

# Rebuild into the same path the packager consumes (.build).
run_step("clean build cache") { "bash -lc \"cd '#{ROOT_DIR}/apps/macos' && rm -rf .build .build-swift .swiftpm 2>/dev/null || true\"" }
run_step("swift build") { "bash -lc \"cd '#{ROOT_DIR}/apps/macos' && swift build -q --product OpenClaw\"" }

if AUTO_DETECT_SIGNING
  if check_signing_keys
    log "==> Signing keys detected, will code sign"
    SIGN = true
  else
    log "==> No signing keys found, will skip code signing (--no-sign)"
    NO_SIGN = true
  end
end

if NO_SIGN
  ENV['ALLOW_ADHOC_SIGNING'] = '1'
  ENV['SIGN_IDENTITY'] = '-'
  FileUtils.mkdir_p("#{ENV['HOME']}/.openclaw")
  run_step("disable launchagent writes") { "/usr/bin/touch '#{LAUNCHAGENT_DISABLE_MARKER}'" }
elsif SIGN
  fail "No signing identity found. Use --no-sign or install a signing key." unless check_signing_keys
  ENV.delete('ALLOW_ADHOC_SIGNING')
  ENV.delete('SIGN_IDENTITY')
end

# Package app (no embedded gateway).
run_step("package app") { "bash -lc \"cd '#{ROOT_DIR}' && SKIP_TSC=#{ENV['SKIP_TSC'] || '1'} '#{ROOT_DIR}/scripts/package-mac-app.sh'\"" }

def choose_app_bundle
  return APP_BUNDLE if APP_BUNDLE != '' && Dir.exist?(APP_BUNDLE)
  
  if Dir.exist?('/Applications/OpenClaw.app')
    return '/Applications/OpenClaw.app'
  end
  
  if Dir.exist?("#{ROOT_DIR}/dist/OpenClaw.app")
    bundle = "#{ROOT_DIR}/dist/OpenClaw.app"
    fail "dist/OpenClaw.app missing Sparkle after packaging" unless Dir.exist?("#{bundle}/Contents/Frameworks/Sparkle.framework")
    return bundle
  end
  
  fail "App bundle not found. Set OPENCLAW_APP_BUNDLE to your installed OpenClaw.app"
end

app_bundle = choose_app_bundle

# When signed, clear any previous launchagent override marker.
if !NO_SIGN && !ATTACH_ONLY && File.exist?(LAUNCHAGENT_DISABLE_MARKER)
  run_step("clear launchagent disable marker") { "/bin/rm -f '#{LAUNCHAGENT_DISABLE_MARKER}'" }
end

# When unsigned, ensure the gateway LaunchAgent targets the repo CLI (before the app launches).
if NO_SIGN && !ATTACH_ONLY
  run_step("install gateway launch agent (unsigned)") { "bash -lc \"cd '#{ROOT_DIR}' && node openclaw.mjs daemon install --force --runtime node\"" }
  run_step("restart gateway daemon (unsigned)") { "bash -lc \"cd '#{ROOT_DIR}' && node openclaw.mjs daemon restart\"" }
  
  if GATEWAY_WAIT_SECONDS > 0
    run_step("wait for gateway (unsigned)") { "sleep #{GATEWAY_WAIT_SECONDS}" }
  end
  
  gateway_port_script = <<~JS
    const fs = require("node:fs");
    const path = require("node:path");
    try {
      const raw = fs.readFileSync(path.join(process.env.HOME, ".openclaw", "openclaw.json"), "utf8");
      const cfg = JSON.parse(raw);
      const port = cfg && cfg.gateway && typeof cfg.gateway.port === "number" ? cfg.gateway.port : 18789;
      process.stdout.write(String(port));
    } catch {
      process.stdout.write("18789");
    }
  JS
  
  GATEWAY_PORT = run_step("get gateway port") { "node -e '#{gateway_port_script}'" }.strip
  
  run_step("verify gateway port #{GATEWAY_PORT} (unsigned)") { "bash -lc \"lsof -iTCP:#{GATEWAY_PORT} -sTCP:LISTEN | head -n 5 || true\"" }
end

ATTACH_ONLY_ARGS = ATTACH_ONLY ? ['--args', '--attach-only'] : []

# Launch the installed app in the foreground so the menu bar extra appears.
# LaunchServices can inherit a huge environment from this shell (secrets, prompt vars, etc.).
# That can cause launchd spawn failures and is undesirable for a GUI app anyway.
cmd = [
  'env', '-i',
  "HOME=#{ENV['HOME']}",
  "USER=#{ENV['USER'] || `id -un`.strip}",
  "LOGNAME=#{ENV['LOGNAME'] || `id -un`.strip}",
  "TMPDIR=#{ENV['TMPDIR'] || '/tmp'}",
  'PATH=/usr/bin:/bin:/usr/sbin:/sbin',
  "LANG=#{ENV['LANG'] || 'en_US.UTF-8'}",
  '/usr/bin/open',
  app_bundle,
  *ATTACH_ONLY_ARGS
].join(' ')

run_step("launch app") { cmd }

# Verify the app is alive.
sleep 1.5
if system("pgrep -f '#{APP_PROCESS_PATTERN}' >/dev/null 2>&1", out: File::NULL, err: File::NULL)
  log "OK: OpenClaw is running."
else
  fail "App exited immediately. Check #{LOG_PATH} or Console.app (User Reports)."
end

if NO_SIGN && !ATTACH_ONLY
  run_step("show gateway launch agent args (unsigned)") { "bash -lc \"/usr/bin/plutil -p '#{ENV['HOME']}/Library/LaunchAgents/ai.openclaw.gateway.plist' | head -n 40 || true\"" }
end

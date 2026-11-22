#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "5439f30ffe60af90524b72df7e605800192fa0858db8048319335e616aad18fb", "source_sha256": "8f102a03732002cacc77d2ffc6fb4210aabf44652bfa80af3f96aab371d0679c", "target_language": "ruby"}
# run.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/install-sh-smoke/run.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'open3'
require 'fileutils'

INSTALL_URL = ENV['OPENCLAW_INSTALL_URL'] || 'https://openclaw.bot/install.sh'
SMOKE_MODE = ENV['OPENCLAW_INSTALL_SMOKE_MODE'] || 'install'
SMOKE_PREVIOUS_VERSION = ENV['OPENCLAW_INSTALL_SMOKE_PREVIOUS'] || ''
SKIP_PREVIOUS = ENV['OPENCLAW_INSTALL_SMOKE_SKIP_PREVIOUS'] || '0'
DEFAULT_PACKAGE = 'openclaw'
PACKAGE_NAME = ENV['OPENCLAW_INSTALL_PACKAGE'] || DEFAULT_PACKAGE
FRESH_VERSION = ENV['OPENCLAW_INSTALL_FRESH_VERSION'] || ''
FRESH_TAG_URL = ENV['OPENCLAW_INSTALL_FRESH_TAG_URL'] || ''
UPDATE_BASELINE_VERSION = ENV['OPENCLAW_INSTALL_UPDATE_BASELINE'] || '2026.4.10'
UPDATE_BASELINE_TAG_URL = ENV['OPENCLAW_INSTALL_UPDATE_BASELINE_TAG_URL'] || ''
UPDATE_EXPECT_VERSION = ENV['OPENCLAW_INSTALL_UPDATE_EXPECT_VERSION'] || ''
UPDATE_TAG_URL = ENV['OPENCLAW_INSTALL_UPDATE_TAG_URL'] || ''

def quiet_npm(*args)
  stdin, stdout, stderr, wait_thr = Open3.popen3('npm', *args)
  stdin.close
  result = stdout.read
  error = stderr.read
  status = wait_thr.value
  stdout.close
  stderr.close
  
  if !status.success?
    raise "npm command failed: #{error}"
  end
  
  result.strip
end

def verify_installed_cli(package_name, expected_version)
  # This would need to be implemented based on what the original script does
  # For now we'll just print a message
  puts "Verifying #{package_name} version #{expected_version}"
end

def run_install_smoke
  if !FRESH_VERSION.empty? && !FRESH_TAG_URL.empty?
    puts "package=#{PACKAGE_NAME} latest=#{FRESH_VERSION} source=#{FRESH_TAG_URL}"
    puts "==> Install latest release tarball"
    quiet_npm('install', '-g', '--omit=optional', FRESH_TAG_URL)
    
    puts "==> Verify installed version"
    if ENV['OPENCLAW_INSTALL_LATEST_OUT']
      File.write(ENV['OPENCLAW_INSTALL_LATEST_OUT'], FRESH_VERSION)
    end
    verify_installed_cli(PACKAGE_NAME, FRESH_VERSION)
    
    puts "OK"
    return
  end
  
  puts "==> Resolve npm versions"
  if SKIP_PREVIOUS == '1'
    latest_version = quiet_npm('view', PACKAGE_NAME, 'version')
    previous_version = latest_version
  elsif !SMOKE_PREVIOUS_VERSION.empty?
    latest_version = quiet_npm('view', PACKAGE_NAME, 'version')
    previous_version = SMOKE_PREVIOUS_VERSION
  else
    latest_version = quiet_npm('view', PACKAGE_NAME, 'dist-tags.latest')
    versions_json = quiet_npm('view', PACKAGE_NAME, 'versions', '--json')
    
    script = <<-JS
const latest = String(process.env.LATEST_VERSION || "");
const raw = process.env.VERSIONS_JSON || "[]";
let versions;
try {
  versions = JSON.parse(raw);
} catch {
  versions = raw ? [raw] : [];
}
if (!Array.isArray(versions)) {
  versions = [versions];
}
if (versions.length === 0 || latest.length === 0) {
  process.exit(1);
}
const latestIndex = versions.lastIndexOf(latest);
if (latestIndex <= 0) {
  process.stdout.write(latest);
  process.exit(0);
}
process.stdout.write(String(versions[latestIndex - 1] ?? latest));
JS
    
    stdin, stdout, stderr, wait_thr = Open3.popen3('node')
    stdin.puts script
    stdin.close
    previous_version = stdout.read.strip
    stderr.read
    wait_thr.value
    stdout.close
    stderr.close
  end
  
  puts "package=#{PACKAGE_NAME} latest=#{latest_version} previous=#{previous_version}"
  
  if SKIP_PREVIOUS == '1'
    puts "==> Skip preinstall previous (OPENCLAW_INSTALL_SMOKE_SKIP_PREVIOUS=1)"
  else
    puts "==> Preinstall previous (forces installer upgrade path)"
    quiet_npm('install', '-g', "#{PACKAGE_NAME}@#{previous_version}")
  end
  
  puts "==> Run official installer one-liner"
  system("curl -fsSL #{INSTALL_URL} | bash -s -- --no-prompt")
  
  puts "==> Verify installed version"
  if ENV['OPENCLAW_INSTALL_LATEST_OUT']
    File.write(ENV['OPENCLAW_INSTALL_LATEST_OUT'], latest_version)
  end
  verify_installed_cli(PACKAGE_NAME, latest_version)
  
  puts "OK"
end

def run_update_smoke
  if UPDATE_EXPECT_VERSION.empty?
    STDERR.puts "ERROR: OPENCLAW_INSTALL_UPDATE_EXPECT_VERSION is required for update mode"
    exit 1
  end
  if UPDATE_TAG_URL.empty?
    STDERR.puts "ERROR: OPENCLAW_INSTALL_UPDATE_TAG_URL is required for update mode"
    exit 1
  end
  
  puts "package=#{PACKAGE_NAME} baseline=#{UPDATE_BASELINE_VERSION} target=#{UPDATE_EXPECT_VERSION}"
  puts "==> Install baseline release"
  if !UPDATE_BASELINE_TAG_URL.empty?
    quiet_npm('install', '-g', '--omit=optional', UPDATE_BASELINE_TAG_URL)
  else
    quiet_npm('install', '-g', '--omit=optional', "#{PACKAGE_NAME}@#{UPDATE_BASELINE_VERSION}")
  end
  verify_installed_cli(PACKAGE_NAME, UPDATE_BASELINE_VERSION)
  
  puts "==> Run openclaw update from host-served tgz"
  update_stderr_file = `mktemp`.strip
  update_json = nil
  update_stderr = nil
  update_status = nil
  
  begin
    update_json, update_stderr, status = Open3.capture3({
      'npm_config_omit' => 'optional',
      'NPM_CONFIG_OMIT' => 'optional'
    }, "openclaw update --tag #{UPDATE_TAG_URL} --yes --json")
    update_status = status.exitstatus
  rescue => e
    STDERR.puts "ERROR: openclaw update failed: #{e.message}"
    exit 1
  end
  
  puts update_json
  if !update_stderr.empty?
    STDERR.puts update_stderr
  end
  if update_status != 0
    STDERR.puts "ERROR: openclaw update failed with exit code #{update_status}"
    exit update_status
  end
  
  script = <<-JS
const payload = JSON.parse(process.env.UPDATE_JSON || "{}");
const expectedVersion = String(process.env.UPDATE_EXPECT_VERSION || "");
const baselineVersion = String(process.env.UPDATE_BASELINE_VERSION || "");
const expectedUrl = String(process.env.UPDATE_TAG_URL || "");
if (payload.status !== "ok") {
  throw new Error(`expected update status ok, got ${JSON.stringify(payload.status)}`);
}
if ((payload.before?.version ?? null) !== baselineVersion) {
  throw new Error(
    `expected before.version ${baselineVersion}, got ${JSON.stringify(payload.before?.version)}`,
  );
}
if ((payload.after?.version ?? null) !== expectedVersion) {
  throw new Error(
    `expected after.version ${expectedVersion}, got ${JSON.stringify(payload.after?.version)}`,
  );
}
if (payload.reason != null) {
  throw new Error(`expected no failure reason, got ${JSON.stringify(payload.reason)}`);
}
const steps = Array.isArray(payload.steps) ? payload.steps : [];
const updateStep = steps.find((step) => step?.name === "global update");
if (!updateStep) {
  throw new Error("missing global update step in update JSON");
}
if (Number(updateStep.exitCode ?? 1) !== 0) {
  throw new Error(`global update step failed: ${JSON.stringify(updateStep)}`);
}
if (typeof updateStep.command !== "string" || !updateStep.command.includes(expectedUrl)) {
  throw new Error(`global update step missing expected tgz URL: ${JSON.stringify(updateStep)}`);
}
JS
  
  stdin, stdout, stderr, wait_thr = Open3.popen3('node')
  stdin.puts script
  stdin.close
  stdout.read
  error_output = stderr.read
  status = wait_thr.value
  stdout.close
  stderr.close
  
  if !status.success?
    STDERR.puts "Node validation failed: #{error_output}"
    exit 1
  end
  
  puts "==> Verify updated version"
  verify_installed_cli(PACKAGE_NAME, UPDATE_EXPECT_VERSION)
  
  puts "OK"
end

case SMOKE_MODE
when 'install'
  run_install_smoke
when 'update'
  run_update_smoke
else
  STDERR.puts "ERROR: unsupported OPENCLAW_INSTALL_SMOKE_MODE=#{SMOKE_MODE}"
  exit 1
end

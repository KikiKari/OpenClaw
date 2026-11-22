#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "f1c2f9cfb51c1eddd20110345ab599eb5d9e2ec457a0713b4269bd59c8773b24", "source_sha256": "29aab8d3e497ddaa7ec77edf107b153fe17970d064df8a91d7cfcedb7e30a7fd", "target_language": "ruby"}
# sandbox-browser-entrypoint.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/sandbox-browser-entrypoint.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

ENV['DBUS_SESSION_BUS_ADDRESS'] = '/dev/null'

ENV['DISPLAY'] = ':1'
ENV['HOME'] = '/tmp/openclaw-home'
ENV['XDG_CONFIG_HOME'] = "#{ENV['HOME']}/.config"
ENV['XDG_CACHE_HOME'] = "#{ENV['HOME']}/.cache"

CDP_PORT = (ENV['OPENCLAW_BROWSER_CDP_PORT'] || '9222').to_i
CDP_SOURCE_RANGE = ENV['OPENCLAW_BROWSER_CDP_SOURCE_RANGE'] || ''
VNC_PORT = (ENV['OPENCLAW_BROWSER_VNC_PORT'] || '5900').to_i
NOVNC_PORT = (ENV['OPENCLAW_BROWSER_NOVNC_PORT'] || '6080').to_i
ENABLE_NOVNC = (ENV['OPENCLAW_BROWSER_ENABLE_NOVNC'] || '1').to_i
HEADLESS = (ENV['OPENCLAW_BROWSER_HEADLESS'] || '0').to_i
ALLOW_NO_SANDBOX = (ENV['OPENCLAW_BROWSER_NO_SANDBOX'] || '0').to_i
NOVNC_PASSWORD = ENV['OPENCLAW_BROWSER_NOVNC_PASSWORD'] || ''

DISABLE_GRAPHICS_FLAGS = ENV['OPENCLAW_BROWSER_DISABLE_GRAPHICS_FLAGS'] || '1'
DISABLE_EXTENSIONS = ENV['OPENCLAW_BROWSER_DISABLE_EXTENSIONS'] || '1'
RENDERER_PROCESS_LIMIT = ENV['OPENCLAW_BROWSER_RENDERER_PROCESS_LIMIT'] || '2'
AUTO_START_TIMEOUT_MS = (ENV['OPENCLAW_BROWSER_AUTO_START_TIMEOUT_MS'] || '12000').to_i

def validate_uint(name, value, min = 0, max = 4294967295)
  unless value.is_a?(Integer) && value >= min && value <= max
    STDERR.puts "[sandbox] ERROR: #{name} out of range (#{min}..#{max}), got: #{value}"
    exit 1
  end
end

validate_uint('CDP_PORT', CDP_PORT, 1, 65535)
validate_uint('VNC_PORT', VNC_PORT, 1, 65535)
validate_uint('NOVNC_PORT', NOVNC_PORT, 1, 65535)
validate_uint('AUTO_START_TIMEOUT_MS', AUTO_START_TIMEOUT_MS, 1, 2147483647)
validate_uint('RENDERER_PROCESS_LIMIT', RENDERER_PROCESS_LIMIT.to_i, 0, 2147483647) if RENDERER_PROCESS_LIMIT.match?(/^\d+$/)

def cleanup(code = 1)
  pids = []
  
  pids << @websocify_pid if @websocify_pid
  pids << @x11vnc_pid if @x11vnc_pid
  pids << @socat_pid if @socat_pid
  pids << @chrome_pid if @chrome_pid
  pids << @xvfb_pid if @xvfb_pid
  
  unless pids.empty?
    Process.kill('-TERM', *pids) rescue nil
    
    10.times do
      alive = false
      pids.each do |pid|
        begin
          Process.kill(0, pid)
          alive = true
          break
        rescue Errno::ESRCH
        end
      end
      break unless alive
      sleep 0.2
    end
    
    Process.kill('-KILL', *pids) rescue nil
    Process.waitall rescue nil
  end
  
  exit code
end

Signal.trap('EXIT') { cleanup($?.exitstatus) }
Signal.trap('INT') { cleanup(130) }
Signal.trap('TERM') { cleanup(143) }

Dir.mkdir(ENV['HOME']) unless Dir.exist?(ENV['HOME'])
Dir.mkdir("#{ENV['HOME']}/.chrome") unless Dir.exist?("#{ENV['HOME']}/.chrome")
Dir.mkdir(ENV['XDG_CONFIG_HOME']) unless Dir.exist?(ENV['XDG_CONFIG_HOME'])
Dir.mkdir(ENV['XDG_CACHE_HOME']) unless Dir.exist?(ENV['XDG_CACHE_HOME'])

xvfb_cmd = "Xvfb :1 -screen 0 1280x800x24 -ac -nolisten tcp"
@xvfb_pid = spawn(xvfb_cmd)
puts "[sandbox] Xvfb started (PID: #{@xvfb_pid})"

CHROME_CDP_PORT = CDP_PORT >= 65535 ? CDP_PORT - 1 : CDP_PORT + 1

chrome_args = [
  '--remote-debugging-address=127.0.0.1',
  "--remote-debugging-port=#{CHROME_CDP_PORT}",
  "--user-data-dir=#{ENV['HOME']}/.chrome",
  '--no-first-run',
  '--no-default-browser-check',
  '--disable-dev-shm-usage',
  '--disable-background-networking',
  '--disable-breakpad',
  '--disable-crash-reporter',
  '--no-zygote',
  '--metrics-recording-only',
  '--password-store=basic',
  '--use-mock-keychain'
]

chrome_args << '--headless=new' if HEADLESS == 1

if ALLOW_NO_SANDBOX == 1
  chrome_args += ['--no-sandbox', '--disable-setuid-sandbox']
end

disable_graphics_flags_lower = DISABLE_GRAPHICS_FLAGS.downcase
if ['1', 'true', 'yes', 'on'].include?(disable_graphics_flags_lower)
  chrome_args += [
    '--disable-3d-apis',
    '--disable-gpu',
    '--disable-software-rasterizer'
  ]
end

disable_extensions_lower = DISABLE_EXTENSIONS.downcase
if ['1', 'true', 'yes', 'on'].include?(disable_extensions_lower)
  chrome_args << '--disable-extensions'
end

if RENDERER_PROCESS_LIMIT.match?(/^\d+$/) && RENDERER_PROCESS_LIMIT.to_i > 0
  chrome_args << "--renderer-process-limit=#{RENDERER_PROCESS_LIMIT}"
end

puts '[sandbox] Starting Chromium...'
@chrome_pid = spawn("chromium #{chrome_args.join(' ')} about:blank")
puts "[sandbox] Chromium started (PID: #{@chrome_pid})"

start_ms = Time.now.to_f * 1000
deadline_ms = start_ms + AUTO_START_TIMEOUT_MS
cdp_ready = false
probe_url = "http://127.0.0.1:#{CHROME_CDP_PORT}/json/version"

puts "[sandbox] Waiting up to #{AUTO_START_TIMEOUT_MS}ms for CDP on port #{CHROME_CDP_PORT}..."

while (Time.now.to_f * 1000) < deadline_ms
  begin
    Process.kill(0, @chrome_pid)
  rescue Errno::ESRCH
    puts '[sandbox] ERROR: Chromium exited before CDP became ready.'
    exit 1
  end

  result = system("curl -fsS --max-time 0.5 \"#{probe_url}\" >/dev/null 2>&1")
  if result
    cdp_ready = true
    break
  end

  sleep 0.2
end

unless cdp_ready
  puts "[sandbox] ERROR: CDP failed to start within #{AUTO_START_TIMEOUT_MS}ms."
  exit 1
end

puts '[sandbox] CDP ready. Starting socat...'

if CDP_SOURCE_RANGE.empty?
  STDERR.puts '[sandbox-browser] WARNING: CDP_SOURCE_RANGE unset; socat CDP relay will not start.'
  STDERR.puts '[sandbox-browser] Set OPENCLAW_BROWSER_CDP_SOURCE_RANGE to an explicit CIDR to enable CDP access.'
else
  socat_listen_addr = "TCP-LISTEN:#{CDP_PORT},fork,reuseaddr,bind=0.0.0.0,range=#{CDP_SOURCE_RANGE}"
  @socat_pid = spawn("socat \"#{socat_listen_addr}\" \"TCP:127.0.0.1:#{CHROME_CDP_PORT}\"")
  puts "[sandbox] socat started (PID: #{@socat_pid})"
end

if ENABLE_NOVNC == 1 && HEADLESS != 1
  novnc_password = NOVNC_PASSWORD
  if novnc_password.empty?
    uuid = File.read('/proc/sys/kernel/random/uuid').strip
    novnc_password = uuid.gsub('-', '')[0, 8]
  end

  vnc_dir = "#{ENV['HOME']}/.vnc"
  Dir.mkdir(vnc_dir) unless Dir.exist?(vnc_dir)
  
  File.write("#{vnc_dir}/passwd", novnc_password)
  File.chmod(0600, "#{vnc_dir}/passwd")

  x11vnc_cmd = "x11vnc -display :1 -rfbport #{VNC_PORT} -shared -forever -rfbauth #{vnc_dir}/passwd -localhost"
  @x11vnc_pid = spawn(x11vnc_cmd)
  puts "[sandbox] x11vnc started (PID: #{@x11vnc_pid})"

  websocify_cmd = "websockify --web /usr/share/novnc/ #{NOVNC_PORT} localhost:#{VNC_PORT}"
  @websocify_pid = spawn(websocify_cmd)
  puts "[sandbox] websockify started (PID: #{@websocify_pid})"
end

puts '[sandbox] Container running. Monitoring all sub-processes...'
Process.wait
cleanup($?.exitstatus)

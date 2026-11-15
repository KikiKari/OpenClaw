#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "724e48ede38973142e20c3cc87caa4fb41f65f610bf150e9852f7fbb0fa0bcb0", "source_sha256": "acf29634657ddc4b0dd7488e70f24c496bf7bd82883eecf4ebbed3a1486457cd", "target_language": "ruby"}
# browser-session.mjs — portiert nach ruby
# Quelle: javascript, Onboarding@main:scripts/browser-session.mjs
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

# frozen_string_literal: true

# Persistente Browser-Sitzung der Sandbox.
#
# Zweck: Plattformen ohne (nutzbare) API — WaveSpeed-Konsole, Perplexity,
# Canva, Stock-Portale — erfordern einen echten Web-Login. Diese Sitzung
# speichert Cookies/LocalStorage DAUERHAFT in einem user-data-dir, akzeptiert
# Cookie-Banner automatisch und bleibt über Skript-Läufe hinweg angemeldet.
#
# Profil-Verzeichnis: <repo>/.browser-profile (gitignored — enthält Secrets).
#
# Nutzung (immer unter Xvfb, damit echtes Chrome mit Codecs läuft):
#   xvfb-run -a ruby scripts/browser-session.rb open <URL>          # öffnen, Cookies akzeptieren, Screenshot
#   xvfb-run -a ruby scripts/browser-session.rb login <URL> [--user-field ..] [--pass-field ..] [--env-user X] [--env-pass Y]
#   xvfb-run -a ruby scripts/browser-session.rb shot <URL> [--out file.png] [--wait ms] [--full]
#   xvfb-run -a ruby scripts/browser-session.rb state                 # gespeicherte Cookies auflisten (Domains)
#
# Die Sitzung wird NICHT geschlossen-und-verworfen: das Profil bleibt auf Platte.

require 'fileutils'
require 'pathname'
require 'json'
require 'securerandom'
require 'uri'

# Helper to find the script directory
def self_dir
  File.dirname(File.realpath(__FILE__))
end

REPO = Pathname.new(self_dir).parent.to_s
PROFILE = ENV['BROWSER_PROFILE_DIR'] || File.join(REPO, '.browser-profile')
CHROME_PATHS = ['/usr/bin/google-chrome-stable', '/usr/bin/google-chrome'].freeze
CHROME = CHROME_PATHS.find { |path| File.exist?(path) }

# Parse command line arguments
args = ARGV.dup
cmd = args.shift
target = args.shift

# Helper to extract flags
def flag(args, name, default = nil)
  idx = args.index("--#{name}")
  return default unless idx
  return default unless args[idx + 1]
  args[idx + 1]
end

def has_flag?(args, name)
  args.include?("--#{name}")
end

# Load .env file
def load_env(repo)
  env_file = File.join(repo, '.env')
  return {} unless File.exist?(env_file)
  
  env = {}
  File.readlines(env_file).each do |line|
    match = line.match(/^\s*([A-Z0-9_]+)\s*=\s*"?([^"]*)"?\s*$/)
    env[match[1]] = match[2] if match
  end
  env
end

# Accept cookies helper
def accept_cookies(page)
  labels = [
    'Accept all', 'Accept All', 'Alle akzeptieren', 'Accept all cookies',
    'Alle Cookies akzeptieren', 'I agree', 'Ich stimme zu', 'Zustimmen',
    'Allow all', 'Akzeptieren', 'Accept', 'Got it', 'Agree'
  ]
  
  labels.each do |label|
    begin
      btn = page.query_selector("button[contains(text(), '#{label}')]")
      if btn && btn.visible?
        btn.click
        return label
      end
    rescue StandardError
      next
    end
  end
  
  # Generic consent selectors
  selectors = ['#onetrust-accept-btn-handler', '[aria-label*="accept" i]', 'button[title*="accept" i]']
  selectors.each do |sel|
    begin
      el = page.query_selector(sel)
      if el && el.visible?
        el.click
        return sel
      end
    rescue StandardError
      next
    end
  end
  
  nil
end

# Create profile directory
FileUtils.mkdir_p(PROFILE)

# Setup proxy configuration
socks = flag(args, 'socks', nil)
proxy_server = socks ? "socks5://#{socks}" : (ENV['HTTPS_PROXY'] || ENV['https_proxy'] || nil)

# Launch browser with persistent context
require 'selenium-webdriver'

options = Selenium::WebDriver::Chrome::Options.new
options.add_argument('--no-sandbox')
options.add_argument('--autoplay-policy=no-user-gesture-required')
options.add_argument('--disable-blink-features=AutomationControlled')
options.add_argument("--user-data-dir=#{PROFILE}")
options.add_argument('--window-size=1440,900')

if proxy_server
  options.add_argument("--proxy-server=#{proxy_server}")
  options.add_argument('--proxy-bypass-list=localhost,127.0.0.1,::1')
  options.add_argument('--ssl-version-max=tls1.2') if proxy_server.include?('socks')
end

driver = Selenium::WebDriver.for(:chrome, options: options)
page = driver

begin
  if cmd == 'state'
    # Note: Selenium doesn't directly expose cookie storage info like Playwright
    puts "Profil: #{PROFILE}"
    puts "Cookies können nur im laufenden Browser kontrolliert werden"
  elsif cmd == 'open' || cmd == 'shot'
    raise 'URL fehlt' unless target
    
    page.navigate.to(target)
    sleep((flag(args, 'wait', '2500').to_i || 2500) / 1000.0)
    
    accepted = accept_cookies(page)
    puts "Cookie-Consent bestätigt via: #{accepted}" if accepted
    
    sleep(1)
    
    output_file = flag(args, 'out', File.join('/tmp', "browser-#{Time.now.to_i}.png"))
    screenshot_data = page.screenshot_as(:png)
    File.open(output_file, 'wb') { |f| f.write(screenshot_data) }
    
    puts "Screenshot: #{output_file}"
    puts "URL final: #{page.current_url}"
  elsif cmd == 'login'
    raise 'URL fehlt' unless target
    
    env = load_env(REPO)
    user = env[flag(args, 'env-user', '')] || flag(args, 'user', '')
    pass = env[flag(args, 'env-pass', '')] || flag(args, 'pass', '')
    
    page.navigate.to(target)
    sleep(2.5)
    
    accept_cookies(page)
    
    if user && !user.empty?
      user_field_selector = flag(args, 'user-field', 'input[type=email], input[name=email], input[name=username], input[id*=email i]')
      user_field = page.find(user_field_selector.split(',').first.strip)
      user_field.send_keys(user)
    end
    
    if pass && !pass.empty?
      pass_field_selector = flag(args, 'pass-field', 'input[type=password]')
      pass_field = page.find(pass_field_selector)
      pass_field.send_keys(pass)
    end
    
    output_file = flag(args, 'out', File.join('/tmp', "login-#{Time.now.to_i}.png"))
    screenshot_data = page.screenshot_as(:png)
    File.open(output_file, 'wb') { |f| f.write(screenshot_data) }
    
    puts "Login-Formular ausgefüllt (user=#{user ? 'gesetzt' : '-'}, pass=#{pass ? 'gesetzt' : '-'}). Screenshot: #{output_file}"
    puts "Absenden bewusst NICHT automatisch — nächster Schritt nach Sichtprüfung."
  else
    puts 'Befehle: open <URL> | shot <URL> | login <URL> | state'
  end
ensure
  driver.quit
end

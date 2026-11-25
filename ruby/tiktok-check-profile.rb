#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "ed5892e3bbad443b258b176a323e9bf47778a2820472907140747e76ca54845b", "source_sha256": "e90219318254f9b20057962724b153b7476a0511846415f2cc0a38bd9baa14f5", "target_language": "ruby"}
# tiktok-check-profile.js — portiert nach ruby
# Quelle: javascript, OpenClaw@gateway1:skills/tiktok-live/scripts/tiktok-check-profile.js
# auch in: workspace@local:git/skills/tiktok-live/scripts/tiktok-check-profile.js
# auch in: workspace@local:skills/tiktok-live/scripts/tiktok-check-profile.js
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

# frozen_string_literal: true

# TikTok Live Status Checker
# Prüft ausschließlich profilgebundene Live-Indikatoren.
# Der allgemeine TikTok-Navigationspunkt "LIVE" ist kein Statussignal.
# Unterstützt @handle-Normalisierung und optionalen Node-Lastschutz
# via TIKTOK_MAX_LOAD_PER_CPU (Exit-Code 75 bei NODE_BUSY).

require 'json'
require 'securerandom'

# Prüfe CPU Load und beende falls zu hoch
def reject_busy_node
  limit = ENV['TIKTOK_MAX_LOAD_PER_CPU']
  return unless limit && limit.to_f > 0

  cpu_count = [1, `nproc`.to_i].max
  load_avg = `cat /proc/loadavg`.split.first.to_f rescue 0.0
  normalized_load = load_avg / cpu_count

  return unless normalized_load > limit.to_f

  STDERR.puts "NODE_BUSY normalizedLoad=#{normalized_load.round(2)} limit=#{limit}"
  exit 75
end

reject_busy_node

# Hauptfunktion zur Prüfung des Live-Status
def check_live_status(username)
  require 'webdrivers'
  require 'selenium-webdriver'

  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless=new')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--disable-gpu')
  options.add_argument('--window-size=1920,1080')
  options.add_argument('--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')

  driver = Selenium::WebDriver.for(:chrome, options: options)
  
  begin
    # Gehe zum Profil
    driver.navigate.to("https://www.tiktok.com/@#{username}")
    sleep 2
    
    # DSGVO-Banner schließen - mehrere Varianten probieren
    # Variante 1: "Verstanden" Button (deutsch)
    verstanden_button = nil
    begin
      verstanden_button = driver.find_element(:css, 'button:contains("Verstanden"), [data-e2e="cookie-banner-accept"], button:contains("Accept")')
    rescue Selenium::WebDriver::Error::NoSuchElementError
      # Element nicht gefunden
    end
    
    if verstanden_button
      verstanden_button.click rescue nil
      sleep 1
    end
    
    # Variante 2: Andere Cookie-Buttons
    cookie_selectors = [
      'button:contains("Akzeptieren")',
      'button:contains("Alle akzeptieren")',
      'button:contains("Allow all")',
      'button:contains("Accept all")',
      'button.TUXButton:contains("Accept")',
      '[data-testid="cookie-policy-banner-accept"]'
    ]
    
    cookie_selectors.each do |selector|
      begin
        btn = driver.find_element(:css, selector)
        btn.click rescue nil
        sleep 0.5
        break
      rescue Selenium::WebDriver::Error::NoSuchElementError
        # Element nicht gefunden, nächster Versuch
      end
    end
    
    # Warte auf vollständiges Laden
    sleep 3
    
    # Warte auf network idle
    begin
      Selenium::WebDriver::Wait.new(timeout: 5).until { driver.execute_script("return document.readyState") == "complete" }
    rescue Selenium::WebDriver::Error::TimeoutError
      # Ignorieren - Seite sollte trotzdem genug geladen sein
    end
    
    # Nochmal warten für Live-Status-Prüfung durch TikTok
    sleep 2
    
    # Screenshot für Debugging (optional)
    if ENV['DEBUG'] == '1'
      driver.save_screenshot("/tmp/tiktok-#{username}.png")
    end
    
    # Check for LIVE indicators
    # Method 1: data-e2e="live-icon"
    live_icon_visible = false
    begin
      profile_scope = driver.find_element(:css, '[data-e2e="creator-page-header"], [data-e2e="profile-avatar"]')
      live_icon = profile_scope.find_element(:css, '[data-e2e="live-icon"]')
      live_icon_visible = live_icon.displayed?
    rescue Selenium::WebDriver::Error::NoSuchElementError
      # Element nicht gefunden
    end
    
    # Method 2: LIVE text/badge
    live_badge_visible = false
    begin
      profile_badge = profile_scope.find_element(:xpath, ".//*[text()[normalize-space()='LIVE']]")
      live_badge_visible = profile_badge.displayed?
    rescue Selenium::WebDriver::Error::NoSuchElementError
      # Element nicht gefunden
    end
    
    # Method 3: Roter Rahmen um Profilbild
    has_live_border = false
    profile_selectors = [
      'img[data-e2e="avatar"]',
      'div[data-e2e="profile-avatar"] img',
      '[data-e2e="creator-page-header"] img[alt*="profile"]'
    ]
    
    profile_selectors.each do |selector|
      begin
        profile_img = driver.find_element(:css, selector)
        styles = driver.execute_script(<<~JS, profile_img)
          var el = arguments[0];
          var computed = window.getComputedStyle(el);
          var parent = el.parentElement;
          var parentComputed = parent ? window.getComputedStyle(parent) : null;
          return {
            borderColor: computed.borderColor,
            borderStyle: computed.borderStyle,
            borderWidth: computed.borderWidth,
            outlineColor: computed.outlineColor,
            boxShadow: computed.boxShadow,
            parentBorderColor: parentComputed ? parentComputed.borderColor : null,
            parentBorderStyle: parentComputed ? parentComputed.borderStyle : null,
            parentBorderWidth: parentComputed ? parentComputed.borderWidth : null
          };
        JS
        
        # Prüfe auf rote/live-farbige Rahmen
        red_indicators = [
          styles['borderColor'],
          styles['outlineColor'],
          styles['parentBorderColor']
        ]
        
        red_indicators.each do |color|
          if color && (color.include?('255') || color.include?('red') || color.include?('rgb(254') || color.include?('fe2c55') || color.include?('#fe2c'))
            has_live_border = true
            break
          end
        end
        
        # Box-Shadow für Live-Indikator
        if styles['boxShadow'] && (styles['boxShadow'].include?('255') || styles['boxShadow'].include?('254'))
          has_live_border = true
        end
        
        break if has_live_border
      rescue Selenium::WebDriver::Error::NoSuchElementError
        # Element nicht gefunden, nächster Versuch
      end
    end
    
    # Method 4: Check für Live-Link
    has_live_link = false
    begin
      live_link = driver.find_element(:css, "a[href*='/@#{username}/live']")
      has_live_link = !live_link.nil?
    rescue Selenium::WebDriver::Error::NoSuchElementError
      # Element nicht gefunden
    end
    
    # Method 5: Check für pulsierenden roten Punkt
    live_indicator_visible = false
    begin
      live_indicator = profile_scope.find_element(:css, '[class*="live-indicator"], div[class*="LiveBadge"]')
      live_indicator_visible = live_indicator.displayed?
    rescue Selenium::WebDriver::Error::NoSuchElementError
      # Element nicht gefunden
    end
    
    is_live = live_icon_visible || live_badge_visible || has_live_border || has_live_link || live_indicator_visible
    
    result = {
      username: username,
      isLive: is_live,
      timestamp: Time.now.utc.iso8601,
      indicators: {
        liveIcon: live_icon_visible,
        liveBadge: live_badge_visible,
        liveBorder: has_live_border,
        liveLink: has_live_link,
        liveIndicator: live_indicator_visible
      }
    }
    
    puts JSON.pretty_generate(result)
    driver.quit
    return is_live
    
  rescue => e
    driver.quit rescue nil
    error_result = {
      error: true,
      message: e.message,
      stack: e.backtrace.join("\n"),
      timestamp: Time.now.utc.iso8601
    }
    STDERR.puts JSON.pretty_generate(error_result)
    exit 1
  end
end

# Hauptprogramm
if ARGV.empty?
  STDERR.puts 'Usage: ruby tiktok-check-profile.rb <username>'
  exit 1
end

raw_username = ARGV[0]
username = raw_username.sub(/^@+/, '')

if username.empty?
  STDERR.puts 'Username must not be empty'
  exit 1
end

begin
  is_live = check_live_status(username)
  exit(is_live ? 0 : 1)
rescue => e
  error_result = {
    error: true,
    message: e.message,
    timestamp: Time.now.utc.iso8601
  }
  STDERR.puts JSON.pretty_generate(error_result)
  exit 1
end

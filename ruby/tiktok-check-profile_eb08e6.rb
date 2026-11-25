#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "d011c16540c97085b14b6742fd083a03609cfbdf17f09cbcbd2e83bf62f8d7a5", "source_sha256": "eb08e6ac444b7c9611c2c56d0b5b99c5f3d6c627dce5fb23dd375d732ee39a65", "target_language": "ruby"}
# tiktok-check-profile.js — portiert nach ruby
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/tiktok-check-profile.js
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'net/http'
require 'uri'
require 'securerandom'
require 'fileutils'

# Load common functions from external file
load './tiktok-common.rb'

$username = nil

begin
  $username = normalize_username(ARGV[0])
rescue StandardError => e
  STDERR.puts 'Usage: ruby tiktok-check-profile.rb <username>'
  STDERR.puts e.message
  exit 64
end

enforce_load_limit('playwright_enhanced')

# Realistische Verzögerung (2-4s zufällig)
def human_delay(min = 2000, max = 4000)
  rand(min..max)
end

def close_dsgvo_banner(page)
  # Alle bekannten Cookie/DSGVO-Button-Varianten
  selectors = [
    'button:has-text("Verstanden")',
    '[data-e2e="cookie-banner-accept"]',
    'button:has-text("Accept")',
    'button:has-text("Akzeptieren")',
    'button:has-text("Alle akzeptieren")',
    'button:has-text("Allow all")',
    'button:has-text("Accept all")',
    'button.TUXButton:has-text("Accept")',
    '[data-testid="cookie-policy-banner-accept"]'
  ]

  selectors.each do |selector|
    begin
      btn = page.query_selector(selector)
      if btn
        btn.click
        sleep(human_delay(1000, 2000) / 1000.0)
        return true
      end
    rescue StandardError
      # weiter probieren
    end
  end
  false
end

def wait_for_page_ready(page)
  # KRITISCH: TikTok lädt die Seite in Phasen.
  # Der LIVE-Badge und der rote Rahmen erscheinen ERST wenn die Seite
  # vollständig geladen ist. Erkennbar am Menüband:
  # "Videos" + "Erneute Veröffentlichungen" + "Gelikt"
  # "Erneute Veröffentlichungen" erscheint als LETZTES.

  # Phase 1: Initiales Laden abwarten
  sleep(human_delay(2000, 3000) / 1000.0)

  # Phase 2: Warte explizit auf "Erneute Veröffentlichungen" Tab
  # Das ist der zuverlässigste Indikator für vollständigen Seitenaufbau
  page_ready = false
  begin
    page.wait_for_selector('text="Erneute Veröffentlichungen"', state: 'visible', timeout: 25000)
    page_ready = true
  rescue StandardError
    # Fallback: englische Version probieren
    begin
      page.wait_for_selector('text="Reposts"', state: 'visible', timeout: 5000)
      page_ready = true
    rescue StandardError
      # Letzter Fallback: einfach auf networkidle warten
      begin
        page.wait_for_load_state('networkidle', timeout: 10000)
      rescue StandardError
        # weiter
      end
    end
  end

  # Phase 3: Nach dem Erscheinen des Menübands noch kurz warten,
  # damit der LIVE-Badge/roter Rahmen gerendert wird
  sleep(human_delay(2000, 3000) / 1000.0)

  page_ready
end

def detect_live_status(page, username)
  indicators = {
    live_icon: false,
    live_badge: false,
    live_border: false,
    live_link: false,
    live_indicator: false
  }
  detection_method = 'none'

  # --- Priorität 1: LIVE-Icon innerhalb des exakten Account-LIVE-Links ---
  begin
    live_link = page.locator(live_href_selectors(username).join(', ')).first
    live_icon_visible = live_link.locator(
      '[data-e2e="live-icon"], [class*="LiveBadge"], [class*="live-indicator"]'
    ).first.visible?
    if live_icon_visible
      indicators[:live_icon] = true
      detection_method = 'live-icon'
      return { is_live: true, detection_method: detection_method, indicators: indicators }
    end
  rescue StandardError
    # weiter
  end

  # --- Priorität 2: exaktes LIVE-Badge innerhalb desselben Account-Links ---
  begin
    live_link = page.locator(live_href_selectors(username).join(', ')).first
    live_badge = live_link.locator('text=/^LIVE$/i').first
    live_badge_visible = live_badge.visible?
    if live_badge_visible
      indicators[:live_badge] = true
      detection_method = 'live-badge'
      return { is_live: true, detection_method: detection_method, indicators: indicators }
    end
  rescue StandardError
    # weiter
  end

  # --- Priorität 3: Live-Rahmen am Profilkopf/Avatar des Accounts ---
  begin
    profile_selectors = [
      '[data-e2e="user-page"] img[data-e2e="avatar"]',
      '[data-e2e="user-page"] div[data-e2e="profile-avatar"] img',
      'main header img[data-e2e="avatar"]',
      'main header [class*="avatar"] img'
    ]

    profile_selectors.each do |selector|
      profile_img = page.query_selector(selector)
      next unless profile_img

      styles = profile_img.evaluate(<<~JS)
        function(el) {
          const computed = window.getComputedStyle(el);
          const parent = el.parentElement;
          const parentComputed = parent ? window.getComputedStyle(parent) : null;
          const grandParent = parent ? parent.parentElement : null;
          const grandParentComputed = grandParent ? window.getComputedStyle(grandParent) : null;
          return {
            borderColor: computed.borderColor,
            outlineColor: computed.outlineColor,
            boxShadow: computed.boxShadow,
            parentBorderColor: parentComputed ? parentComputed.borderColor : null,
            parentBoxShadow: parentComputed ? parentComputed.boxShadow : null,
            grandParentBorderColor: grandParentComputed ? grandParentComputed.borderColor : null,
            grandParentBoxShadow: grandParentComputed ? grandParentComputed.boxShadow : null
          };
        }
      JS

      all_colors = [
        styles['borderColor'],
        styles['outlineColor'],
        styles['parentBorderColor'],
        styles['grandParentBorderColor']
      ]
      all_shadows = [
        styles['boxShadow'],
        styles['parentBoxShadow'],
        styles['grandParentBoxShadow']
      ]

      is_red = lambda { |color|
        return false unless color && color != 'none'
        color.include?('255') || color.include?('red') ||
          color.include?('rgb(254') || color.include?('fe2c55') ||
          color.include?('#fe2c') || color.include?('rgb(255, 0') ||
          color.include?('rgb(255, 44')
      }

      if all_colors.any? { |color| is_red.call(color) } || all_shadows.any? { |shadow| shadow && is_red.call(shadow) }
        indicators[:live_border] = true
        detection_method = 'live-border'
        return { is_live: true, detection_method: detection_method, indicators: indicators }
      end
    end
  rescue StandardError
    # weiter
  end

  # --- Priorität 4: Live-Indikator innerhalb des exakten Account-Links ---
  begin
    live_link = page.locator(live_href_selectors(username).join(', ')).first
    live_indicator_visible = live_link.locator(
      '[class*="live-indicator"], div[class*="LiveBadge"]'
    ).first.visible?
    if live_indicator_visible
      indicators[:live_indicator] = true
      detection_method = 'live-indicator'
      return { is_live: true, detection_method: detection_method, indicators: indicators }
    end
  rescue StandardError
    # weiter
  end

  # --- Priorität 5: sichtbarer exakter /@username/live-Link ---
  begin
    live_link = page.locator(live_href_selectors(username).join(', ')).first
    if live_link.visible?
      indicators[:live_link] = true
      detection_method = 'live-link'
      return { is_live: true, detection_method: detection_method, indicators: indicators }
    end
  rescue StandardError
    # weiter
  end

  { is_live: false, detection_method: detection_method, indicators: indicators }
end

def inspect_direct_live_state(page, username)
  successful_stream_response = false
  response_handler = lambda do |response|
    if is_successful_stream_response(response.status, response.url)
      successful_stream_response = true
    end
  end
  page.on('response', response_handler)
  begin
    page.goto("https://www.tiktok.com/@#{username}/live", wait_until: 'domcontentloaded', timeout: 30000)
    sleep(human_delay(8000, 10000) / 1000.0)
    current_url = URI.parse(page.url)
    body_text = page.locator('body').inner_text rescue ''
    classify_direct_live_state({
                                  username: username,
                                  current_path: current_url.path,
                                  title: page.title,
                                  body_text: body_text,
                                  successful_stream_response: successful_stream_response
                                })
  rescue StandardError => error
    { status: 'technical_error', reason: error.message }
  ensure
    page.remove_listener('response', response_handler)
  end
end

def check_live_status(username)
  browser = nil
  begin
    # Prüfe ob Playwright Chromium verfügbar ist
    chromium_path = `which playwright`
    raise "Playwright Chromium unavailable" if chromium_path.strip.empty?

    # Starte den Browser
    require 'playwright'
    browser = Playwright.create.chromium.launch(headless: true)
    context = browser.new_context(
      user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      viewport: { width: 1920, height: 1080 }
    )
    page = context.new_page

    # Navigiere zum Profil
    page.goto("https://www.tiktok.com/@#{username}", wait_until: 'domcontentloaded', timeout: 30000)

    # Step 1: DSGVO Banner schließen
    banner_closed = close_dsgvo_banner(page)

    # Step 2: Warte auf vollständigen Seitenaufbau
    # KRITISCH: LIVE-Badge erscheint erst nach "Erneute Veröffentlichungen"
    page_ready = wait_for_page_ready(page)

    # Debug-Screenshot
    if ENV['DEBUG'] == '1'
      page.screenshot(path: "/tmp/tiktok-#{username}-v2.png", full_page: true)
    end

    # Step 3: Live-Status prüfen (priorisiert)
    live_result = detect_live_status(page, username)

    # Step 4: Accountgenaue /live-Seite prüfen. Das trennt zugängliche
    # Streams, Login-/Content-Sperren und tatsächlich beendete Streams.
    direct_result = inspect_direct_live_state(page, username)
    final_status = if direct_result[:status] == 'restricted'
                     'restricted'
                   elsif live_result[:is_live] || direct_result[:status] == 'live'
                     'live'
                   else
                     direct_result[:status]
                   end

    # Ergebnis ausgeben
    result = {
      username: username,
      status: final_status,
      is_live: final_status == 'live' || final_status == 'restricted',
      detection_method: direct_result[:status] == 'restricted' ? 'account-live-restricted' : live_result[:detection_method],
      is_age_restricted: final_status == 'restricted',
      age_restriction_reason: final_status == 'restricted' ? direct_result[:reason] : nil,
      indicators: live_result[:indicators],
      banner_closed: banner_closed,
      page_fully_loaded: page_ready,
      timestamp: Time.now.utc.iso8601,
      version: '2.1'
    }

    puts JSON.pretty_generate(result)
    final_status
  rescue StandardError => error
    result = {
      username: username,
      is_live: false,
      status: 'technical_error',
      detection_method: 'error',
      is_age_restricted: false,
      age_restriction_reason: nil,
      indicators: {},
      error: error.message,
      timestamp: Time.now.utc.iso8601,
      version: 2
    }
    STDERR.puts JSON.pretty_generate(result)
    'technical_error'
  ensure
    browser&.close
  end
end

status = check_live_status($username)
exit(0) if status == 'live'
exit(1) if status == 'offline' || status == 'restricted'
exit(2)

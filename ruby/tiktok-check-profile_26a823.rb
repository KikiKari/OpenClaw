#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "d60a3946be4ae1a7e75bdf9ac9e9b9b73aa05e2ea2879de162658cf657f3e040", "source_sha256": "26a823a8fe0d3b94a8c9958ec8cf150765ddf3654a8806c9cc62eae06d9632db", "target_language": "ruby"}
# tiktok-check-profile.js — portiert nach ruby
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-check-profile.js
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

# Basic TikTok LIVE profile checker.
#
# Scopes every signal to the requested account and ignores unrelated sidebar
# LIVE labels. This profile-only checker does not classify restricted LIVE;
# use the enhanced checker or dispatcher for that distinction.
#
# Exit 0 = account-specific LIVE, 1 = offline, 2 = dependency/technical
# failure, 75 = overloaded before Playwright startup.

require 'json'
require 'fileutils'
require 'securerandom'

# Common functions module
module TikTokCommon
  def self.enforce_load_limit(method)
    # Placeholder for load limiting logic
    # In a real implementation, this would check system load
  end

  def self.live_href_selectors(username)
    [
      "a[href='/@#{username}/live']",
      "a[href='https://www.tiktok.com/@#{username}/live']"
    ]
  end

  def self.normalize_username(username)
    raise ArgumentError, 'Username is required' if username.nil? || username.empty?
    username.strip.gsub(/^@/, '')
  end
end

# Main checker class
class TikTokProfileChecker
  def initialize(username)
    @username = TikTokCommon.normalize_username(username)
    TikTokCommon.enforce_load_limit('playwright_basic')
  end

  def check_live_status
    # Check if Playwright Chromium is available
    unless playwright_available?
      error_output = {
        error: true,
        status: 'dependency_missing',
        method: 'playwright_basic',
        message: 'Playwright Chromium unavailable',
        timestamp: Time.now.utc.iso8601
      }
      puts JSON.pretty_generate(error_output)
      exit 2
    end

    # Launch browser
    require 'playwright'
    browser = Playwright.create.chromium.launch(headless: true)
    
    context = browser.contexts.new(
      user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      viewport: { width: 1920, height: 1080 }
    )
    
    page = context.pages.new
    
    begin
      # Navigate to profile
      page.goto("https://www.tiktok.com/@#{@username}", wait_until: 'domcontentloaded', timeout: 30000)
      
      # Wait for initial page build
      sleep 2
      
      # Close GDPR banner - try multiple variants
      # Variant 1: "Verstanden" button (German)
      verstanden_button = page.query_selector('button:has-text("Verstanden"), [data-e2e="cookie-banner-accept"], button:has-text("Accept")')
      if verstanden_button
        verstanden_button.click rescue nil
        sleep 1
      end
      
      # Variant 2: Other cookie buttons
      cookie_selectors = [
        'button:has-text("Akzeptieren")',
        'button:has-text("Alle akzeptieren")',
        'button:has-text("Allow all")',
        'button:has-text("Accept all")',
        'button.TUXButton:has-text("Accept")',
        '[data-testid="cookie-policy-banner-accept"]'
      ]
      
      cookie_selectors.each do |selector|
        btn = page.query_selector(selector)
        if btn
          btn.click rescue nil
          sleep 0.5
          break
        end
      end
      
      # Wait for complete loading ("Erneute Veröffentlichungen" tab)
      sleep 3
      
      # Additionally wait for network idle for API calls
      begin
        page.wait_for_load_state('networkidle', timeout: 5000)
      rescue
        # Ignore - page should be loaded enough anyway
      end
      
      # Wait again for Live status check by TikTok
      sleep 2
      
      # Screenshot for debugging (optional, only if DEBUG=1)
      if ENV['DEBUG'] == '1'
        page.screenshot(path: "/tmp/tiktok-#{@username}.png")
      end
      
      # Account-scoped LIVE indicators only. Sidebar/recommendation labels
      # are outside the exact /@username/live link and never count.
      # Method 1: live icon inside the exact account link
      live_link_selectors = TikTokCommon.live_href_selectors(@username).join(', ')
      live_link = page.locator(live_link_selectors).first
      has_live_link = live_link.visible? rescue false
      live_icon_visible = has_live_link && (
        live_link.locator('[data-e2e="live-icon"], [class*="LiveBadge"], [class*="live-indicator"]').first.visible? rescue false
      )
      
      # Method 2: exact LIVE text/badge inside the account link
      live_badge = has_live_link ? 
        live_link.locator('text=/^LIVE$/i').first :
        page.locator('body > __never_match__')
      live_badge_visible = live_badge.visible? rescue false
      
      # Method 3: Live frame at profile header/avatar
      profile_selectors = [
        '[data-e2e="user-page"] img[data-e2e="avatar"]',
        '[data-e2e="user-page"] div[data-e2e="profile-avatar"] img',
        'main header img[data-e2e="avatar"]',
        'main header [class*="avatar"] img'
      ]
      
      has_live_border = false
      profile_selectors.each do |selector|
        profile_img = page.query_selector(selector)
        if profile_img
          styles = profile_img.evaluate(<<~JS)
            function(el) {
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
            }
          JS
          
          # Check for red/live-colored borders
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
          
          # Box-shadow for live indicator (TikTok often uses glow effects)
          if styles['boxShadow'] && (styles['boxShadow'].include?('255') || styles['boxShadow'].include?('254'))
            has_live_border = true
          end
          
          break if has_live_border
        end
      end
      
      # Method 4: exact account LIVE link
      # Method 5: live indicator inside that account link
      live_indicator_visible = has_live_link && (
        live_link.locator('[class*="live-indicator"], div[class*="LiveBadge"]').first.visible? rescue false
      )
      
      is_live = has_live_link || has_live_border || live_icon_visible || live_indicator_visible || live_badge_visible
      
      output = {
        username: @username,
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
      
      puts JSON.pretty_generate(output)
      
      return is_live
      
    rescue => error
      error_output = {
        error: true,
        status: 'technical_error',
        message: error.message,
        stack: error.backtrace.join("\n"),
        timestamp: Time.now.utc.iso8601
      }
      puts JSON.pretty_generate(error_output)
      return nil
    ensure
      browser.close
    end
  end

  private

  def playwright_available?
    # Check if Playwright is available
    begin
      require 'playwright'
      true
    rescue LoadError
      false
    end
  end
end

# Main execution
if ARGV.length != 1
  puts 'Usage: ruby tiktok-check-profile.rb <username>'
  exit 64
end

username = ARGV[0]
checker = TikTokProfileChecker.new(username)
result = checker.check_live_status

exit_code = case result
            when nil
              2  # technical error
            when true
              0  # live
            else
              1  # offline
            end

exit exit_code

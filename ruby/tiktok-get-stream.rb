#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "4234f2be9beb279e2081844d2ad644908010442bc64b7d059eacf66fdf4293d7", "source_sha256": "1c74aa0ec785639584af8f4d4e128e120c85d9712a7fca7650c80bfc0c1fe946", "target_language": "ruby"}
# tiktok-get-stream.js — portiert nach ruby
# Quelle: javascript, OpenClaw@gateway1:skills/tiktok-live/scripts/tiktok-get-stream.js
# auch in: workspace@local:git/skills/tiktok-live/scripts/tiktok-get-stream.js
# auch in: workspace@local:skills/tiktok-live/scripts/tiktok-get-stream.js
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

# frozen_string_literal: true

# TikTok Stream URL Extractor
# Führt zuerst den profilgebundenen Status-Checker aus.
# Nur bei bestätigtem Live-Status werden FLV-Netzwerk-URLs erfasst.
# Offline wird keine Stream-URL ausgegeben.

require 'json'
require 'open3'
require 'securerandom'
require 'fileutils'

USERNAME = ARGV[0]&.gsub(/\A@+/, '')
unless USERNAME && !USERNAME.empty?
  STDERR.puts 'Usage: ruby tiktok-get-stream.rb <username>'
  exit 1
end

def reject_busy_node
  limit = ENV['TIKTOK_MAX_LOAD_PER_CPU']&.to_f
  return unless limit&.> 0

  cpu_count = [1, `nproc`.to_i].max
  normalized_load = `uptime`.split('average:').last.split(',').first.to_f / cpu_count
  return unless normalized_load > limit

  STDERR.puts "NODE_BUSY normalizedLoad=#{format('%.2f', normalized_load)} limit=#{limit}"
  exit 75
end

reject_busy_node

def verify_live_status(username)
  checker_path = File.join(File.dirname(__FILE__), 'tiktok-check-profile.rb')
  cmd = ["ruby", checker_path, username]

  Open3.popen3(*cmd) do |stdin, stdout, stderr, wait_thr|
    stdin.close
    begin
      output, _ = Timeout.timeout(60) { [stdout.read, stderr.read] }
      result = JSON.parse(output)
      result['isLive'] == true
    rescue JSON::ParserError
      false
    rescue Timeout::Error
      false
    end
  end
rescue => e
  STDERR.puts "Error checking live status: #{e.message}"
  false
end

def get_stream_url(username)
  unless verify_live_status(username)
    puts JSON.generate({
                         'username' => username,
                         'isLive' => false,
                         'error' => 'User is not currently live.',
                         'timestamp' => Time.now.utc.iso8601
                       })
    return false
  end

  # Start browser session with playwright
  require 'playwright'
  
  Playwright.create.then do |pw|
    pw.chromium.launch(headless: true) do |browser|
      context = browser.contexts.new_context(
        user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
      )
      page = context.pages.new_page
      
      flv_urls = []
      
      page.on(:request) do |request|
        url = request.url
        if url.include?('.flv') || url.include?('pull-flv')
          flv_urls << {
            'url' => url,
            'type' => request.resource_type,
            'timestamp' => Time.now.utc.iso8601
          }
        end
      end
      
      begin
        # Navigate to live page
        page.goto("https://www.tiktok.com/@#{username}/live", wait_until: 'load', timeout: 60000)
        
        # Wait for potential DSGVO/consent dialogs
        sleep 3
        
        # Accept cookies if present
        accept_button = page.query_selector('button[data-e2e="cookie-banner-accept"]')
        if accept_button
          accept_button.click
          sleep 1
        end
        
        # Wait for stream to load (5-10 seconds typically)
        sleep 8
        # Additional wait to allow network requests for FLV URLs to be captured
        sleep 10
        
        # Try to trigger video play if needed
        video = page.query_selector('video')
        if video
          video.evaluate('v => v.play()') rescue nil
          sleep 3
        end
        
        if flv_urls.any?
          # Deduplicate URLs
          unique_urls = flv_urls.uniq { |item| item['url'] }
          
          # Sort by quality indicator (if present in URL)
          suffix_ranks = [
            ['_origin.', 600], ['_uhd_60.', 550], ['_uhd.', 540],
            ['_hd_60.', 500], ['_hd.', 450], ['_sd.', 350], ['_ld.', 250]
          ]
          
          unique_urls.sort! do |a, b|
            get_quality = lambda do |url|
              suffix_ranks.each do |suffix, rank|
                return rank if url.include?(suffix)
              end
              match = url.match(/(\d+)p/)
              match ? match[1].to_i : 0
            end
            
            get_quality.call(b['url']) <=> get_quality.call(a['url'])
          end
          
          result = {
            'username' => username,
            'isLive' => true,
            'streamCount' => unique_urls.length,
            'streams' => unique_urls,
            'vlcCommand' => "vlc \"#{unique_urls.first['url']}\"",
            'timestamp' => Time.now.utc.iso8601
          }
          
          puts JSON.pretty_generate(result)
          true
        else
          puts JSON.generate({
                               'username' => username,
                               'isLive' => false,
                               'error' => 'No stream URLs found - user may not be live',
                               'timestamp' => Time.now.utc.iso8601
                             })
          false
        end
      rescue => error
        puts JSON.generate({
                             'error' => true,
                             'message' => error.message,
                             'timestamp' => Time.now.utc.iso8601
                           })
        false
      ensure
        browser.close if browser
      end
    end
  end
rescue => e
  puts JSON.generate({
                       'error' => true,
                       'message' => e.message,
                       'timestamp' => Time.now.utc.iso8601
                     })
  false
end

success = get_stream_url(USERNAME)
exit success ? 0 : 1

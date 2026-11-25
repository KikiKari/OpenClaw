#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "1705b05fa569c4f1ff00e70e99e80b9904f62a30a1a2b01ad389357274228d9a", "source_sha256": "f26b3eccbd673f5fa54aac1c90f22b0649827637622aa8e22ffab339ae8abc28", "target_language": "ruby"}
# test_vlc_switch.cjs — portiert nach ruby
# Quelle: javascript, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_vlc_switch.cjs
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

require 'fileutils'
require 'json'
require 'securerandom'

# Mocking Node.js modules and structures
module NodeFS
  def self.read_file_sync(path, encoding)
    File.read(path, encoding: encoding)
  end
end

module NodePath
  def self.join(*paths)
    File.join(*paths)
  end

  def self.dirname(path)
    File.dirname(path)
  end

  def self.basename(path)
    File.basename(path)
  end
end

module NodeAssert
  def self.strict_equal(actual, expected, message = nil)
    raise "#{message} Expected #{expected}, got #{actual}" unless actual == expected
  end

  def self.match(string, pattern, message = nil)
    raise "#{message} String does not match pattern" unless string.match(pattern)
  end

  def self.does_not_match(string, pattern, message = nil)
    raise "#{message} String matches pattern but should not" if string.match(pattern)
  end
end

# Simulate __dirname
__dirname = File.dirname(__FILE__)

# Read content.js
source = NodeFS.read_file_sync(NodePath.join(__dirname, '../browser-extension/content.js'), 'utf-8')

# Mock objects
listeners = {}
native = { muted: false, paused: false }
def native.pause
  self[:paused] = true
end

def native.play
  self[:paused] = false
  # Return a promise-like object
  Class.new do
    def self.then(&block)
      block.call
      self
    end

    def self.catch(&block)
      self
    end
  end
end

fallback = { muted: false, paused: false }
media = [native, fallback]
unrelated_video = native.dup
speech_audio = native.dup
surface = {
  query_selector_all: ->(selector) {
    NodeAssert.strict_equal(selector, 'video')
    media
  }
}

fallback[:closest] = ->(*) { { parent_element: surface } }

gain = { value: 0.7 }
changed = nil

# Create execution context
context = {
  audio_pipeline: { video: native, output_gain: { gain: gain } },
  document: {
    query_selector_all: ->(*) { raise 'Must not globally suppress page media' },
    document_element: {},
    add_event_listener: ->(name, fn) { listeners[name] = fn },
    remove_event_listener: ->(name) { listeners.delete(name) }
  },
  mutation_observer: Class.new do
    def initialize(fn)
      @fn = fn
      changed = fn
    end

    def observe(*)
    end

    def disconnect
    end
  end
}

# Extract and execute relevant code from content.js
start_index = source.index('  function suppressNativeAudio(')
end_index = source.index('  async function playMediaFallback(')
code_to_run = source[start_index..end_index]

# Simple JavaScript to Ruby translation for the specific functions we need
eval(code_to_run.gsub(/function\s+(\w+)/, 'def \1')
                 .gsub(/(\w+)\.(\w+)/, '\1[:\2]')
                 .gsub(/(\w+)\(([^)]*)\)/, '\1(\2)')
                 .gsub(/const\s+(\w+)\s*=\s*(.*)/, '\1 = \2')
                 .gsub(/let\s+(\w+)\s*=\s*(.*)/, '\1 = \2')
                 .gsub(/(\w+)\s*=\s*(.*)/, '\1 = \2')
                 .gsub(/===/, '==')
                 .gsub(/!==/, '!=')
                 .gsub(/;/, '')
                 .gsub(/\btrue\b/, 'true')
                 .gsub(/\bfalse\b/, 'false')
                 .gsub(/\bnull\b/, 'nil'))

# Execute suppressNativeAudio
release = suppress_native_audio(fallback)

# Assertions
NodeAssert.strict_equal(native[:muted], true)
NodeAssert.strict_equal(native[:paused], true)
NodeAssert.strict_equal(gain[:value], 0)
NodeAssert.strict_equal(fallback[:muted], false)
NodeAssert.strict_equal(fallback[:paused], false)

native[:paused] = false
listeners['play'].call
NodeAssert.strict_equal(native[:paused], true)

replacement = native.merge({ muted: false, paused: false })
media << replacement
changed.call
NodeAssert.strict_equal(replacement[:muted], true)
NodeAssert.strict_equal(replacement[:paused], true)

release.call
NodeAssert.strict_equal(native[:muted], false)
NodeAssert.strict_equal(native[:paused], false)
NodeAssert.strict_equal(gain[:value], 0.7)
NodeAssert.strict_equal(listeners.length, 0)
NodeAssert.strict_equal(unrelated_video[:paused], false)
NodeAssert.strict_equal(speech_audio[:paused], false)

context[:audio_pipeline][:video] = unrelated_video
release_unrelated = suppress_native_audio(fallback)
NodeAssert.strict_equal(gain[:value], 0.7, 'Unrelated audio pipeline must remain unchanged')
release_unrelated.call

# Read background.js
background = NodeFS.read_file_sync(NodePath.join(__dirname, '../browser-extension/background.js'), 'utf-8')
normal_start = background.index('async function openNormalLive(')
normal_end = background.index('chrome.sidePanel.setPanelBehavior')
normal = background[normal_start..normal_end]

NodeAssert.match(normal, /await chrome.tabs.update\(tabId, \{ url: normalLiveUrl\(handle\) \}\)/)
NodeAssert.does_not_match(normal, /if \(reloading\)/)
NodeAssert.match(source, /if \(holder\?\.isConnected\) return holder.querySelector\("video"\)/)

puts 'PASS: VLC isolates native audio, suppresses restarted/replaced media, restores on failure; Normal navigates even at same URL; existing fallback reused'

# Exercise switch functionality
def exercise_switch
  panel = NodeFS.read_file_sync(NodePath.join(__dirname, '../browser-extension/sidepanel.js'), 'utf-8')
  click_start = panel.index('  elements["player-vlc-frame"].addEventListener("click"')
  click_end = panel.index('  elements["player-volume"].addEventListener', click_start)
  
  click = nil
  starts = 0
  
  button = {
    add_event_listener: ->(event, fn) { click = fn }
  }
  
  panel_context = {
    elements: { 'player-vlc-frame' => button },
    install_vlc_if_needed: -> { raise 'Internal replacement must not wait for desktop installation' },
    run_player: ->(action, target) {
      NodeAssert.strict_equal(action, 'play-vlc-source')
      NodeAssert.strict_equal(target, button)
      starts += 1
    }
  }
  
  # Run panel code
  panel_code = panel[click_start..click_end]
  eval(panel_code.gsub(/function\s+(\w+)/, 'def \1')
                   .gsub(/(\w+)\.(\w+)/, '\1[:\2]')
                   .gsub(/(\w+)\(([^)]*)\)/, '\1(\2)')
                   .gsub(/const\s+(\w+)\s*=\s*(.*)/, '\1 = \2')
                   .gsub(/let\s+(\w+)\s*=\s*(.*)/, '\1 = \2')
                   .gsub(/(\w+)\s*=\s*(.*)/, '\1 = \2')
                   .gsub(/===/, '==')
                   .gsub(/!==/, '!=')
                   .gsub(/;/, '')
                   .gsub(/\btrue\b/, 'true')
                   .gsub(/\bfalse\b/, 'false')
                   .gsub(/\bnull\b/, 'nil'))
  
  click.call
  NodeAssert.strict_equal(starts, 1, 'VLC click dispatches internal player immediately')
  
  large_native = { 
    closest: ->(*) { nil }, 
    get_bounding_client_rect: ->(*) { { width: 1000, height: 1000 } } 
  }
  
  small_replacement = { 
    closest: ->(*) { {} }, 
    get_bounding_client_rect: ->(*) { { width: 100, height: 100 } } 
  }
  
  selection = {
    active_media_fallback_item: {},
    media_fallback_running: false,
    document: {
      query_selector: ->(*) { small_replacement },
      query_selector_all: ->(*) { [large_native, small_replacement] }
    }
  }
  
  # Run selection code
  selection_start = source.index('  function primaryVideo()')
  selection_end = source.index('  function playerToggleControl()')
  selection_code = source[selection_start..selection_end]
  
  eval(selection_code.gsub(/function\s+(\w+)/, 'def \1')
                      .gsub(/(\w+)\.(\w+)/, '\1[:\2]')
                      .gsub(/(\w+)\(([^)]*)\)/, '\1(\2)')
                      .gsub(/const\s+(\w+)\s*=\s*(.*)/, '\1 = \2')
                      .gsub(/let\s+(\w+)\s*=\s*(.*)/, '\1 = \2')
                      .gsub(/(\w+)\s*=\s*(.*)/, '\1 = \2')
                      .gsub(/===/, '==')
                      .gsub(/!==/, '!=')
                      .gsub(/;/, '')
                      .gsub(/\btrue\b/, 'true')
                      .gsub(/\bfalse\b/, 'false')
                      .gsub(/\bnull\b/, 'nil'))
  
  NodeAssert.strict_equal(primary_video(), small_replacement, 'Active replacement wins regardless of video size')
  
  selection[:active_media_fallback_item] = nil
  selection[:media_fallback_running] = true
  NodeAssert.strict_equal(primary_video(), small_replacement, 'Starting replacement owns player controls')
  
  selection[:media_fallback_running] = false
  NodeAssert.strict_equal(primary_video(), large_native, 'Inactive replacement excluded from native selection')
  
  navigated = 0
  ctx = {
    chrome: {
      tabs: {
        get: ->(*) { { url: 'https://www.tiktok.com/@test/live' } },
        update: ->(*) { navigated += 1 }
      }
    },
    get_state: ->(*) { {} },
    page_handle: ->(*) { 'test' },
    cancel_embed_session: ->(*) { },
    cancel_recovery_for_mode_change: ->(*) { },
    close_embed_chat_source: ->(*) { },
    arm_live_tab: ->(*) { },
    normal_live_url: ->(*) { 'https://www.tiktok.com/@test/live' }
  }
  
  # Run normal code
  eval(normal.gsub(/function\s+(\w+)/, 'def \1')
             .gsub(/(\w+)\.(\w+)/, '\1[:\2]')
             .gsub(/(\w+)\(([^)]*)\)/, '\1(\2)')
             .gsub(/const\s+(\w+)\s*=\s*(.*)/, '\1 = \2')
             .gsub(/let\s+(\w+)\s*=\s*(.*)/, '\1 = \2')
             .gsub(/(\w+)\s*=\s*(.*)/, '\1 = \2')
             .gsub(/===/, '==')
             .gsub(/!==/, '!=')
             .gsub(/;/, '')
             .gsub(/\btrue\b/, 'true')
             .gsub(/\bfalse\b/, 'false')
             .gsub(/\bnull\b/, 'nil'))
  
  open_normal_live(1)
  NodeAssert.strict_equal(navigated, 1, 'Normal must navigate even from the same LIVE URL')
  
  released = 0
  removed = 0
  created = 0
  
  video = {
    pause: ->(*) { },
    remove_attribute: ->(*) { },
    load: ->(*) { }
  }
  
  player = {
    media_fallback_running: false,
    media_fallback_page_url: 'live',
    location: { href: 'live' },
    attempted_media_fallback_urls: Set.new,
    active_media_fallback_item: nil,
    release_native_audio: nil,
    media_fallback_candidates: ->(x) { x },
    media_fallback_key: ->(x) { x[:url] },
    ensure_media_fallback_video: ->(*) { created += 1; video },
    suppress_native_audio: ->(*) { -> { released += 1 } },
    set_media_fallback_status: ->(*) { },
    destroy_media_fallback_player: ->(*) { },
    try_media_url: ->(*) { { ok: false, reason: 'test failure' } },
    get_player_state: ->(*) { {} },
    document: { get_element_by_id: ->(*) { { remove: -> { removed += 1 } } } }
  }
  
  # Run player code
  player_start = source.index('  async function playMediaFallback(')
  player_end = source.index('  async function configureLimiter(')
  player_code = source[player_start..player_end]
  
  eval(player_code.gsub(/function\s+(\w+)/, 'def \1')
                  .gsub(/(\w+)\.(\w+)/, '\1[:\2]')
                  .gsub(/(\w+)\(([^)]*)\)/, '\1(\2)')
                  .gsub(/const\s+(\w+)\s*=\s*(.*)/, '\1 = \2')
                  .gsub(/let\s+(\w+)\s*=\s*(.*)/, '\1 = \2')
                  .gsub(/(\w+)\s*=\s*(.*)/, '\1 = \2')
                  .gsub(/===/, '==')
                  .gsub(/!==/, '!=')
                  .gsub(/;/, '')
                  .gsub(/\btrue\b/, 'true')
                  .gsub(/\bfalse\b/, 'false')
                  .gsub(/\bnull\b/, 'nil'))
  
  play_media_fallback([])
  NodeAssert.strict_equal(created, 0, 'No sources must not cover the native player')
  
  result = play_media_fallback([{ url: 'test', quality: 'test' }])
  NodeAssert.strict_equal(result[:activated], false)
  NodeAssert.strict_equal(released, 1, 'Failed startup restores native audio')
  NodeAssert.strict_equal(removed, 1, 'Failed startup removes replacement')
  NodeAssert.strict_equal(player[:media_fallback_running], false)
  
  puts 'PASS: actual Normal handler navigates same URL; failed VLC startup restores native player; empty sources create no overlay'
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace
  exit 1
end

exercise_switch

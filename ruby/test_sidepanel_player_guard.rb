#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "3edf765fc3699b11039f0286b59e87f6657c419bc9f5951ec71035916fb448ef", "source_sha256": "982245244dd1863414e9d3aaedaf8afbfb270bbbc18cd490fbb288290b7667d3", "target_language": "ruby"}
# test_sidepanel_player_guard.cjs — portiert nach ruby
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_sidepanel_player_guard.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_sidepanel_player_guard.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_sidepanel_player_guard.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_sidepanel_player_guard.cjs
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

require 'fileutils'
require 'pathname'
require 'securerandom'

# Mocking Node.js modules and functions
module NodeFS
  def self.read_file_sync(path, encoding)
    File.read(path, encoding: encoding)
  end
end

module NodePath
  def self.join(*args)
    File.join(*args)
  end

  def self.dirname(path)
    File.dirname(path)
  end
end

module NodeVM
  class Context
    attr_accessor :activeTabId, :activeIsTikTok, :playerContextGeneration, :send, :renderPlayer

    def initialize(activeTabId:, activeIsTikTok:, playerContextGeneration:, send:, renderPlayer:)
      @activeTabId = activeTabId
      @activeIsTikTok = activeIsTikTok
      @playerContextGeneration = playerContextGeneration
      @send = send
      @renderPlayer = renderPlayer
    end
  end

  def self.create_context(context_hash)
    Context.new(
      activeTabId: context_hash[:activeTabId],
      activeIsTikTok: context_hash[:activeIsTikTok],
      playerContextGeneration: context_hash[:playerContextGeneration],
      send: context_hash[:send],
      renderPlayer: context_hash[:renderPlayer]
    )
  end

  def self.run_in_context(code, context)
    # Create a custom binding with context variables
    binding_obj = binding
    context.instance_variables.each do |var|
      binding_obj.local_variable_set(var.to_s.delete('@').to_sym, context.instance_variable_get(var))
    end
    
    # Evaluate code with access to context variables
    eval(code, binding_obj)
  end
end

module NodeAssert
  class AssertionError < StandardError; end
  
  def self.equal(actual, expected, message = "")
    raise AssertionError, message unless actual == expected
  end
  
  def self.match(string, pattern, message = "")
    raise AssertionError, message unless string.match(pattern)
  end
end

def main
  source = NodeFS.read_file_sync(NodePath.join(NodePath.dirname(__FILE__), '../browser-extension/sidepanel.js'), 'utf8')
  start = source.index('  async function refreshPlayer()')
  ending = source.index('  function setButtonBusy', start)
  
  raise "Could not find required functions in source" unless start && ending && start < ending
  
  reply = nil
  calls = 0
  rendered = []
  
  send_proc = proc do
    calls += 1
    promise = Promise.new
    reply = proc { |value| promise.resolve(value) }
    promise
  end
  
  render_player_proc = proc { |state| rendered.push(state) }
  
  context = NodeVM.create_context(
    activeTabId: 1,
    activeIsTikTok: true,
    playerContextGeneration: 0,
    send: send_proc,
    renderPlayer: render_player_proc
  )
  
  NodeVM.run_in_context(source[start..ending], context)
  
  pending = context.refreshPlayer.call
  context.activeTabId = 2
  reply.call({response: {playerState: {playing: true}}})
  pending.value if pending.is_a?(Promise)
  
  NodeAssert.equal(rendered.length, 0, 'Old tab response must be ignored')
  
  context.activeIsTikTok = false
  sync_pending = context.refreshPlayer.call
  sync_pending.value if sync_pending.is_a?(Promise)
  
  NodeAssert.equal(calls, 1, 'Non-TikTok tabs must not be polled')
  
  context.activeIsTikTok = true
  pending = context.refreshPlayer.call
  reply.call({response: {playerState: {playing: true}}})
  pending.value if pending.is_a?(Promise)
  
  NodeAssert.equal(rendered.length, 1, 'Current tab response must render')
  
  pending = context.refreshPlayer.call
  context.activeTabId = 3
  context.playerContextGeneration += 1
  context.activeTabId = 2
  context.playerContextGeneration += 1
  reply.call({response: {playerState: {playing: false}}})
  pending.value if pending.is_a?(Promise)
  
  NodeAssert.equal(rendered.length, 1, 'Returning to the same tab must not revive an old response')
  NodeAssert.match(source, /async function refresh\(\)\s*\{\s*playerContextGeneration\+\+;/, 
                   'Context invalidation must precede asynchronous tab lookup')
  
  puts 'PASS: stale tab response ignored, non-TikTok polling skipped, current response rendered'
rescue => error
  puts error.message
  exit(1)
end

# Simple Promise implementation for testing purposes
class Promise
  def initialize
    @resolved = false
    @value = nil
    @callbacks = []
  end
  
  def resolve(value)
    @resolved = true
    @value = value
    @callbacks.each { |cb| cb.call(value) }
  end
  
  def then(&block)
    if @resolved
      block.call(@value)
    else
      @callbacks << block
    end
    self
  end
  
  def value
    @value
  end
  
  def resolved?
    @resolved
  end
end

main

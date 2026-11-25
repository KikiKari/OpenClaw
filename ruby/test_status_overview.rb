#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "3e9a7ce4b06e36b0883bad5a52d31f74dc7696f0731f71edaeed97f80009edfb", "source_sha256": "50d76760028236c95fd616361fde31bbf4f6004b925acf38c870ee7052931015", "target_language": "ruby"}
# test_status_overview.cjs — portiert nach ruby
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_status_overview.cjs
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

require 'minitest/autorun'
require 'json'
require 'uri'

# Mock fetch implementation for testing
class MockFetch
  def initialize(&block)
    @fetch_impl = block
  end

  def call(url)
    @fetch_impl.call(url)
  end
end

# Storage mock
class MockStorage
  def initialize(data = {})
    @data = data
  end

  def get(keys = nil)
    if keys.nil?
      @data.dup
    else
      keys = [keys] unless keys.is_a?(Array)
      keys.each_with_object({}) { |k, h| h[k] = @data[k] if @data.key?(k) }
    end
  end

  def set(values)
    @data.merge!(values)
  end

  def remove(key)
    @data.delete(key)
  end
end

# Chrome alarms mock
class MockAlarms
  def initialize
    @alarms = {}
    @on_alarm_callbacks = []
  end

  def add_listener(&block)
    @on_alarm_callbacks << block
  end

  def create(name, options)
    @alarms[name] = options
  end

  def clear(name)
    @alarms.delete(name)
  end

  def trigger(name)
    @on_alarm_callbacks.each { |cb| cb.call({ 'name' => name }) }
  end

  def [](name)
    @alarms[name]
  end

  def has_key?(name)
    @alarms.key?(name)
  end
end

# Chrome tabs mock
class MockTabs
  def initialize(captured = nil)
    @opened = []
    @captured = captured
  end

  def create(options)
    @opened << options
  end

  def get(id)
    { 'id' => id, 'url' => 'chrome-extension://test/status-overview.html' }
  end

  def query(*)
    @captured&.[](tabs) || []
  end

  def send_message(id, *)
    @captured&.[](scans)&.<<(id)
  end

  attr_reader :opened
end

# Core functionality mock
class MockCore
  def inspect_metadata(room)
    { 'media' => room['media'] || [] }
  end

  def live_handle_from_url(url)
    match = url.match(/@([^\/]+)/)
    match ? match[1] : ''
  end
end

# Setup function to create test environment
def setup(fetch_impl, captured = nil)
  local_storage = {}
  session_storage = {}
  alarms = MockAlarms.new
  tabs = MockTabs.new(captured)
  
  chrome = {
    'storage' => {
      'local' => MockStorage.new(local_storage),
      'session' => MockStorage.new(session_storage)
    },
    'alarms' => alarms,
    'runtime' => {
      'onStartup' => { 'addListener' => ->(*) {} },
      'getURL' => ->(x) { "chrome-extension://test/#{x}" }
    },
    'tabs' => tabs
  }
  
  core = MockCore.new
  
  # Create context similar to JavaScript's global scope
  context = {
    'chrome' => chrome,
    'core' => core,
    'fetch' => fetch_impl,
    'getState' => ->(id) { captured&.[](states)&.[](id) || { 'media' => [] } },
    'URL' => URI,
    'Date' => Time,
    'Set' => Set,
    'Map' => Hash,
    'Object' => Object,
    'Array' => Array,
    'Math' => Math,
    'Number' => Numeric,
    'String' => String,
    'Promise' => lambda { |&block| block.call },
    'AbortController' => Class.new,
    'setTimeout' => ->(callback, delay) { Thread.new { sleep(delay/1000.0); callback.call } },
    'clearTimeout' => ->(*) {}
  }
  
  # Load the actual worker script
  source_path = File.join(File.dirname(__FILE__), '../browser-extension/status-overview-worker.js')
  source = File.read(source_path)
  
  # Evaluate the script in the context (simplified)
  eval(source + "\noverview = TLCOverview;")
  
  context['overview'] = context['TLCOverview']
  
  {
    'api' => context['overview'],
    'opened' => tabs.opened,
    'session' => session_storage,
    'alarms' => alarms,
    'fire' => -> { 
      alarms.trigger('tlc-overview-check')
      sleep(0.01) # Small delay to allow async operations
    }
  }
end

# Helper to generate HTML response
def html(handle, status, media = [])
  data = {
    'LiveRoom' => {
      'liveRoomUserInfo' => {
        'user' => { 'uniqueId' => handle },
        'liveRoom' => { 'status' => status, 'media' => media }
      }
    }
  }
  "<script id=\"SIGI_STATE\" type=\"application/json\">#{data.to_json}</script>"
end

class TestStatusOverview < Minitest::Test
  def test_checks_live_and_offline_via_direct_requests_without_opening_tabs
    requested = []
    x = setup(->(url) {
      requested << url
      name = url.match(/@([^\/]+)/)[1]
      status = name == 'one' ? 2 : 4
      media = [{ 'url' => 'https://cdn.test/a.flv', 'audioOnly' => false }]
      { 'ok' => true, 'text' => -> { html(name, status, media) } }
    })
    
    x['api'].message({ 'type' => 'TLC_OVERVIEW_SET', 'config' => { 'handles' => ['@One', 'Two'], 'interval' => 5 } })
    x['api'].message({ 'type' => 'TLC_OVERVIEW_CHECK' })
    
    result = x['api'].message({ 'type' => 'TLC_OVERVIEW_GET' })
    rows = result['rows']
    
    assert_equal 'online', rows[0]['status']
    assert_equal 1, rows[0]['media'].length
    assert_equal 'offline', rows[1]['status']
    assert_equal 0, rows[1]['media'].length
    assert_equal 2, requested.length
    assert_equal 0, x['opened'].length
    assert_equal 5, x['alarms']['tlc-overview-check']['periodInMinutes']
  end

  def test_unavailable_or_mismatched_response_is_an_error_never_falsely_offline
    x = setup(->(url) {
      if url.include?('@one/')
        { 'ok' => false }
      else
        { 'ok' => true, 'text' => -> { html('other', 4) } }
      end
    })
    
    x['api'].message({ 'type' => 'TLC_OVERVIEW_SET', 'config' => { 'handles' => ['one', 'two'] } })
    x['api'].message({ 'type' => 'TLC_OVERVIEW_CHECK' })
    
    result = x['api'].message({ 'type' => 'TLC_OVERVIEW_GET' })
    rows = result['rows']
    
    assert_equal 'error', rows[0]['status']
    assert_equal 'error', rows[1]['status']
  end

  def test_rejects_duplicate_and_invalid_names_opens_overview_in_requested_window
    x = setup(->(*) {})
    
    assert_raises(RuntimeError) do
      x['api'].message({ 'type' => 'TLC_OVERVIEW_SET', 'config' => { 'handles' => ['a', '@A'] } })
    end
    
    assert_raises(RuntimeError) do
      x['api'].message({ 'type' => 'TLC_OVERVIEW_SET', 'config' => { 'handles' => ['bad/name'] } })
    end
    
    x['api'].message({ 'type' => 'TLC_OVERVIEW_OPEN', 'windowId' => 23 })
    
    assert_equal 23, x['opened'][0]['windowId']
    assert_match /status-overview.html/, x['opened'][0]['url']
    
    assert_raises(RuntimeError) do
      x['api'].message({ 'type' => 'TLC_OVERVIEW_OPEN' })
    end
  end

  def test_does_not_apply_an_obsolete_result_after_changing_a_handle
    release = nil
    pending = -> { release = -> {} }
    
    x = setup(->(*) {
      pending.call
      { 'ok' => true, 'text' => -> { html('one', 2) } }
    })
    
    x['api'].message({ 'type' => 'TLC_OVERVIEW_SET', 'config' => { 'handles' => ['one'] } })
    check = x['api'].message({ 'type' => 'TLC_OVERVIEW_CHECK' })
    sleep(0.001)
    x['api'].message({ 'type' => 'TLC_OVERVIEW_SET', 'config' => { 'handles' => ['two'] } })
    release&.call
    check
    result = x['api'].message({ 'type' => 'TLC_OVERVIEW_GET' })
    row = result['rows'][0]
    
    assert_equal 'two', row['handle']
    assert_equal 'unknown', row['status']
  end

  def test_playing_streams_are_skipped_until_playback_stops_and_timer_can_be_disabled
    seen = []
    x = setup(->(url) {
      seen << url
      name = url.match(/@([^\/]+)/)[1]
      { 'ok' => true, 'text' => -> { html(name, 2) } }
    })
    
    x['api'].message({ 'type' => 'TLC_OVERVIEW_SET', 'config' => { 'handles' => ['one', 'two'], 'interval' => 5 } })
    
    sender = { 'tab' => { 'id' => 42 }, 'url' => 'chrome-extension://test/status-overview.html' }
    x['api'].message({ 'type' => 'TLC_OVERVIEW_PLAYBACK', 'index' => 0, 'handle' => 'one', 'playing' => true }, sender)
    x['api'].message({ 'type' => 'TLC_OVERVIEW_CHECK' })
    
    assert_equal 1, seen.length
    assert_match /@two/, seen[0]
    
    x['api'].message({ 'type' => 'TLC_OVERVIEW_PLAYBACK', 'index' => 0, 'handle' => 'one', 'playing' => false }, sender)
    x['api'].message({ 'type' => 'TLC_OVERVIEW_CHECK' })
    
    assert_equal 3, seen.length
    
    x['api'].message({ 'type' => 'TLC_OVERVIEW_SET', 'config' => { 'handles' => ['one', 'two'], 'enabled' => false } })
    
    assert_equal false, x['alarms'].has_key?('tlc-overview-check')
    x['fire'].call
    assert_equal 3, seen.length
  end

  def test_persists_settings_limits_sources_and_resets_only_handles
    media = (0...35).map do |i|
      { 'url' => "https://cdn.test/#{i}.flv", 'audioOnly' => i == 0 }
    end
    
    x = setup(->(*) {
      { 'ok' => true, 'text' => -> { html('one', 2, media) } }
    })
    
    x['api'].message({ 'type' => 'TLC_OVERVIEW_SET', 'config' => { 'handles' => ['one'], 'interval' => 7, 'maxLinks' => 30, 'showLinks' => true, 'autoSort' => true, 'skipOnline' => false } })
    x['api'].message({ 'type' => 'TLC_OVERVIEW_CHECK' })
    
    state = x['api'].message({ 'type' => 'TLC_OVERVIEW_GET' })
    
    assert_equal 30, state['rows'][0]['media'].length
    assert_equal true, state['rows'][0]['media'][0]['audioOnly']
    
    x['api'].message({ 'type' => 'TLC_OVERVIEW_SET', 'config' => { 'maxLinks' => 5 } })
    state = x['api'].message({ 'type' => 'TLC_OVERVIEW_GET' })
    
    assert_equal 5, state['rows'][0]['media'].length
    
    x['api'].message({ 'type' => 'TLC_OVERVIEW_RESET' })
    state = x['api'].message({ 'type' => 'TLC_OVERVIEW_GET' })
    
    assert_equal '', state['rows'][0]['handle']
    assert_equal 0, state['rows'][0]['media'].length
    assert_equal 7, state['config']['interval']
    assert_equal true, state['config']['autoSort']
    assert_equal true, state['config']['showLinks']
  end

  def test_skips_online_streams_only_when_the_option_is_enabled
    calls = 0
    x = setup(->(*) {
      calls += 1
      { 'ok' => true, 'text' => -> { html('one', 2, [{ 'url' => 'https://cdn.test/a.flv' }]) } }
    })
    
    x['api'].message({ 'type' => 'TLC_OVERVIEW_SET', 'config' => { 'handles' => ['one'], 'skipOnline' => true } })
    x['api'].message({ 'type' => 'TLC_OVERVIEW_CHECK' })
    x['api'].message({ 'type' => 'TLC_OVERVIEW_CHECK' })
    
    assert_equal 1, calls
    
    x['api'].message({ 'type' => 'TLC_OVERVIEW_SET', 'config' => { 'skipOnline' => false } })
    x['api'].message({ 'type' => 'TLC_OVERVIEW_CHECK' })
    
    assert_equal 2, calls
  end

  def test_retry_targets_the_original_handle_and_rejects_stale_or_invalid_slots
    x = setup(->(*) {})
    x['api'].message({ 'type' => 'TLC_OVERVIEW_SET', 'config' => { 'handles' => ['one', 'two'], 'skipOnline' => true } })
    
    x['session']['tlc-overview-row-1'] = { 'handle' => 'two', 'status' => 'online', 'media' => [{ 'url' => 'https://cdn.test/a.flv' }] }
    
    x['api'].message({ 'type' => 'TLC_OVERVIEW_RETRY', 'index' => 1, 'handle' => 'two' })
    
    assert_equal 'two', x['session']['tlc-overview-retry-1']['handle']
    
    assert_raises(RuntimeError) do
      x['api'].message({ 'type' => 'TLC_OVERVIEW_RETRY', 'index' => 1, 'handle' => 'one' })
    end
    
    assert_raises(RuntimeError) do
      x['api'].message({ 'type' => 'TLC_OVERVIEW_RETRY', 'index' => 9, 'handle' => 'two' })
    end
  end

  def test_online_without_links_is_checked_on_schedule_and_retries_only_its_own_slot
    seen = []
    x = setup(->(url) {
      name = url.match(/@([^\/]+)/)[1]
      seen << name
      media = name == 'two' ? [{ 'url' => 'https://cdn.test/two.flv' }] : []
      { 'ok' => true, 'text' => -> { html(name, 2, media) } }
    })
    
    x['api'].message({ 'type' => 'TLC_OVERVIEW_SET', 'config' => { 'handles' => ['one', 'two'], 'skipOnline' => true } })
    x['api'].message({ 'type' => 'TLC_OVERVIEW_CHECK' })
    x['api'].message({ 'type' => 'TLC_OVERVIEW_CHECK' })
    
    assert_equal ['one', 'two', 'one'], seen
    
    x['api'].message({ 'type' => 'TLC_OVERVIEW_RETRY', 'index' => 0, 'handle' => 'one' })
    
    assert_equal ['one', 'two', 'one', 'one'], seen
  end

  def test_top_selection_is_persisted_and_reset_preserves_it
    x = setup(->(*) {})
    
    x['api'].message({ 'type' => 'TLC_OVERVIEW_SET', 'config' => { 'top' => 'monitor' } })
    result = x['api'].message({ 'type' => 'TLC_OVERVIEW_GET' })
    
    assert_equal 'monitor', result['config']['top']
    
    x['api'].message({ 'type' => 'TLC_OVERVIEW_SET', 'config' => { 'top' => 'connection' } })
    result = x['api'].message({ 'type' => 'TLC_OVERVIEW_GET' })
    
    assert_equal 'connection', result['config']['top']
    
    x['api'].message({ 'type' => 'TLC_OVERVIEW_RESET' })
    result = x['api'].message({ 'type' => 'TLC_OVERVIEW_GET' })
    
    assert_equal 'connection', result['config']['top']
    
    x['api'].message({ 'type' => 'TLC_OVERVIEW_SET', 'config' => { 'top' => '' } })
    result = x['api'].message({ 'type' => 'TLC_OVERVIEW_GET' })
    
    assert_equal '', result['config']['top']
  end

  def test_manual_zero_link_retry_rescans_only_matching_live_tab_and_imports_its_captured_sources
    captured = {
      'tabs' => [
        { 'id' => 1, 'url' => 'https://www.tiktok.com/@one/live' },
        { 'id' => 2, 'url' => 'https://www.tiktok.com/@two/live' }
      ],
      'states' => {
        1 => { 'media' => [] },
        2 => { 'media' => [{ 'url' => 'https://cdn.test/wrong.flv' }] }
      },
      'scans' => []
    }
    
    x = setup(->(*) {
      { 'ok' => true, 'text' => -> { html('one', 2) } }
    }, captured)
    
    x['api'].message({ 'type' => 'TLC_OVERVIEW_SET', 'config' => { 'handles' => ['one'] } })
    x['api'].message({ 'type' => 'TLC_OVERVIEW_CHECK' })
    
    result = x['api'].message({ 'type' => 'TLC_OVERVIEW_GET' })
    assert_equal 0, result['rows'][0]['media'].length
    
    captured['states'][1]['media'] = [{ 'url' => 'https://cdn.test/live.flv', 'protocol' => 'FLV' }]
    x['api'].message({ 'type' => 'TLC_OVERVIEW_RETRY', 'index' => 0, 'handle' => 'one' })
    
    result = x['api'].message({ 'type' => 'TLC_OVERVIEW_GET' })
    row = result['rows'][0]
    
    assert_equal 'https://cdn.test/live.flv', row['media'][0]['url']
    assert_equal [1, 1], captured['scans']
  end

  def test_twenty_handles_persistent_grid_options_and_high_index_actions_are_supported
    x = setup(->(url) {
      name = url.match(/@([^\/]+)/)[1]
      { 'ok' => true, 'text' => -> { html(name, 2, [{ 'url' => "https://cdn.test/#{name}.flv" }]) } }
    })
    
    handles = (0...20).map { |i| "user#{i}" }
    x['api'].message({ 'type' => 'TLC_OVERVIEW_SET', 'config' => { 'handles' => handles, 'expanded' => true, 'reverse' => true, 'grid2' => true } })
    x['api'].message({ 'type' => 'TLC_OVERVIEW_CHECK' })
    
    result = x['api'].message({ 'type' => 'TLC_OVERVIEW_GET' })
    
    assert_equal 20, result['rows'].length
    assert_equal 'online', result['rows'][19]['status']
    assert_equal true, result['config']['reverse']
    assert_equal true, result['config']['grid2']
    
    x['api'].message({ 'type' => 'TLC_OVERVIEW_RETRY', 'index' => 19, 'handle' => 'user19' })
    
    assert_equal 'user19', x['session']['tlc-overview-retry-19']['handle']
    
    x['api'].message({ 'type' => 'TLC_OVERVIEW_SET', 'config' => { 'expanded' => false } })
    result = x['api'].message({ 'type' => 'TLC_OVERVIEW_GET' })
    
    assert_equal 'user19', result['config']['handles'][19]
    
    x['api'].message({ 'type' => 'TLC_OVERVIEW_RESET' })
    result = x['api'].message({ 'type' => 'TLC_OVERVIEW_GET' })
    
    assert_equal true, result['config']['handles'].all?(&:empty?)
  end

  def test_manual_retry_refreshes_playing_stream_urls_only_when_skip_online_is_disabled
    count = 0
    x = setup(->(*) {
      count += 1
      { 'ok' => true, 'text' => -> { html('one', 2, [{ 'url' => "https://cdn.test/live-#{count}.flv" }]) } }
    })
    
    x['api'].message({ 'type' => 'TLC_OVERVIEW_SET', 'config' => { 'handles' => ['one'], 'skipOnline' => false } })
    x['api'].message({ 'type' => 'TLC_OVERVIEW_CHECK' })
    
    sender = { 'tab' => { 'id' => 42 }, 'url' => 'chrome-extension://test/status-overview.html' }
    x['api'].message({ 'type' => 'TLC_OVERVIEW_PLAYBACK', 'index' => 0, 'handle' => 'one', 'playing' => true }, sender)
    x['api'].message({ 'type' => 'TLC_OVERVIEW_RETRY', 'index' => 0, 'handle' => 'one' })
    
    assert_equal 2, count
    
    result = x['api'].message({ 'type' => 'TLC_OVERVIEW_GET' })
    assert_match /live-2/, result['rows'][0]['media'][0]['url']
    assert_equal 'one', x['session']['tlc-overview-retry-0']['handle']
    
    x['api'].message({ 'type' => 'TLC_OVERVIEW_SET', 'config' => { 'skipOnline' => true } })
    x['api'].message({ 'type' => 'TLC_OVERVIEW_CHECK' })
    x['api'].message({ 'type' => 'TLC_OVERVIEW_RETRY', 'index' => 0, 'handle' => 'one' })
    
    assert_equal 2, count
  end
end

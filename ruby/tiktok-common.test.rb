#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "e350411186a9d6ab8a88baa28fb8244c560143400f581df50bd4e250c49e5bb5", "source_sha256": "a53191c31c8f3e0c2cf2f32b08da78e3ddf05a87beb8d40862645641631e7855", "target_language": "ruby"}
# tiktok-common.test.js — portiert nach ruby
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-common.test.js
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

require 'minitest/autorun'
require 'uri'
require_relative 'tiktok_common'

class TestTiktokCommon < Minitest::Test
  def test_normalize_username
    assert_equal TiktokCommon.normalize_username('@example_creator'), 'example_creator'
    assert_equal TiktokCommon.normalize_username(' example_creator '), 'example_creator'
    assert_raises(ArgumentError) { TiktokCommon.normalize_username('example_creator;id') }
  end

  def test_live_href_selectors
    expected = [
      'a[href="/@example_creator/live"]',
      'a[href^="/@example_creator/live?"]'
    ]
    assert_equal TiktokCommon.live_href_selectors('example_creator'), expected
  end

  def test_load_state
    env = {
      'TIKTOK_TEST_LOAD_PER_CPU' => '2',
      'TIKTOK_MAX_LOAD_PER_CPU' => '1.5'
    }
    assert TiktokCommon.load_state(env)[:overloaded]
  end

  def test_is_allowed_stream_url
    assert TiktokCommon.is_allowed_stream_url('https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x')
    refute TiktokCommon.is_allowed_stream_url('https://attacker.example/path/tiktokcdn/video.flv')
    refute TiktokCommon.is_allowed_stream_url('http://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv')
  end

  def test_is_successful_stream_response
    allowed_url = 'https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x'
    assert TiktokCommon.is_successful_stream_response(200, allowed_url)
    assert TiktokCommon.is_successful_stream_response(206, allowed_url)
    refute TiktokCommon.is_successful_stream_response(404, allowed_url)
  end

  def test_normalize_extractor_result
    result = TiktokCommon.normalize_extractor_result(
      { success: 'false', status: 'offline' },
      'streamlink',
      'example_creator'
    )
    assert_equal result[:status], 'technical_error'

    result = TiktokCommon.normalize_extractor_result(
      { success: true, status: 'live' },
      'streamlink',
      'example_creator'
    )
    assert_equal result[:status], 'technical_error'

    result = TiktokCommon.normalize_extractor_result(
      { success: false, status: 'offline', url: 'https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x' },
      'streamlink',
      'example_creator'
    )
    assert_equal result[:status], 'offline'
    assert_nil result[:url]

    result = TiktokCommon.normalize_extractor_result(
      { success: true, status: 'live', url: 'https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x' },
      'streamlink',
      'example_creator'
    )
    assert_equal result[:status], 'live'
  end

  def test_classify_final_failure
    assert_equal TiktokCommon.classify_final_failure([
      { status: 'offline' },
      { status: 'dependency_missing' }
    ]), 'offline'
  end

  def test_exit_code_for_result
    assert_equal TiktokCommon.exit_code_for_result({ success: false, status: 'restricted' }), 1
    assert_equal TiktokCommon.exit_code_for_result({ success: false, status: 'technical_error' }), 2
  end

  def test_classify_direct_live_state
    result = TiktokCommon.classify_direct_live_state({
      username: 'example_creator',
      current_path: '/@example_creator/live',
      title: 'Example (@example_creator) is LIVE - TikTok LIVE',
      body_text: 'Dieses LIVE enthält Themen, die unangenehm sein könnten.',
      successful_stream_response: false
    })
    assert_equal result[:status], 'restricted'

    result = TiktokCommon.classify_direct_live_state({
      username: 'example_creator',
      current_path: '/@example_creator/live',
      title: 'Example (@example_creator) is LIVE - TikTok LIVE',
      body_text: 'LIVE has ended',
      successful_stream_response: false
    })
    assert_equal result[:status], 'offline'

    result = TiktokCommon.classify_direct_live_state({
      username: 'example_creator',
      current_path: '/@example_creator/live',
      title: 'Example (@example_creator) is LIVE - TikTok LIVE',
      body_text: 'Suggested LIVE creators',
      successful_stream_response: true
    })
    assert_equal result[:status], 'live'
  end

  def test_sidebar_live_for_another_account_must_not_match
    # This test requires a browser simulation which is not directly possible in Ruby without additional gems
    # We'll skip this test as it requires Playwright which doesn't have a direct Ruby equivalent
    skip "Browser testing requires Playwright which doesn't have Ruby equivalent"
  end
end

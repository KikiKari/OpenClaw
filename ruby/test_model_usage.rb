#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "3ffd8d7f70dc9bd50f5afcdaddc32485e07b0d62579c05461667d07b0569a944", "source_sha256": "95f62a3e3f38308dd9be80e09ec85e4a14455ab95457febb8f915c0f54685141", "target_language": "ruby"}
# test_model_usage.py — portiert nach ruby
# Quelle: python, workspace@local:skills/github-clones/openclaw/skills/model-usage/scripts/test_model_usage.py
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

# frozen_string_literal: true

#
# Tests for model_usage helpers.
#

require 'date'
require 'minitest/autorun'
require_relative 'model_usage'

class TestModelUsage < Minitest::Test
  def test_positive_int_accepts_valid_numbers
    assert_equal positive_int('1'), 1
    assert_equal positive_int('7'), 7
  end

  def test_positive_int_rejects_zero_and_negative
    assert_raises(ArgumentError) { positive_int('0') }
    assert_raises(ArgumentError) { positive_int('-3') }
  end

  def test_filter_by_days_keeps_recent_entries
    today = Date.today
    entries = [
      { 'date' => (today - 5).strftime('%Y-%m-%d'), 'modelBreakdowns' => [] },
      { 'date' => (today - 1).strftime('%Y-%m-%d'), 'modelBreakdowns' => [] },
      { 'date' => today.strftime('%Y-%m-%d'), 'modelBreakdowns' => [] }
    ]

    filtered = filter_by_days(entries, 2)

    assert_equal filtered.length, 2
    assert_equal filtered[0]['date'], (today - 1).strftime('%Y-%m-%d')
    assert_equal filtered[1]['date'], today.strftime('%Y-%m-%d')
  end
end

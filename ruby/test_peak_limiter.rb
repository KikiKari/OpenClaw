#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "f070b5222d499f5f874eb3c57530be32efe90630f18f9d6f158fc42af59fe6dc", "source_sha256": "8e7a477eeeb754ba1e86a22a033ce29eb66d4c0500493fe596a60daf5ac9d10c", "target_language": "ruby"}
# test_peak_limiter.cjs — portiert nach ruby
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_peak_limiter.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_peak_limiter.cjs
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

require 'minitest/autorun'
require_relative '../browser-extension/content-core.rb'

class TestPeakLimiter < Minitest::Test
  def render(signal, strength, rate = 48000, enabled = true)
    kernel = create_peak_limiter(rate)
    output = signal.map { |channel| Array.new(channel.length + kernel.delay_samples, 0.0) }
    
    (0...output[0].length).step(128) do |start|
      length = [128, output[0].length - start].min
      input = signal.map do |channel|
        Array.new(length) { |i| channel[start + i] || 0.0 }
      end
      
      output_arrays = output.map { |channel| channel[start, length] }
      
      result = kernel.process(input, output_arrays, enabled, strength)
      
      # Copy results back to output arrays
      output.each_with_index do |channel, ch_idx|
        result[ch_idx].each_with_index do |val, idx|
          channel[start + idx] = val
        end
      end
    end
    
    { output: output, delay: kernel.delay_samples }
  end
  
  def peak(channel)
    channel.map(&:abs).max || 0.0
  end

  [44100, 48000, 96000].each do |rate|
    define_method("test_isolated_and_high_frequency_peaks_are_bounded_at_#{rate}_hz") do
      signal = Array.new(rate, 0.0)
      signal[1] = 1.0
      signal[127] = -1.0
      (1000...1100).each do |i|
        signal[i] = Math.sin(2 * Math::PI * 8000 * i.to_f / rate)
      end
      
      previous = 1.0
      [25, 75, 100].each do |strength|
        result = render([signal], strength, rate)
        output = result[:output]
        delay = result[:delay]
        
        measured = peak(output[0])
        ceiling = 10 ** (limiter_strength_to_dbfs(strength) / 20.0)
        
        assert(measured <= ceiling + 1e-7, "#{measured} exceeds #{ceiling}")
        assert(measured < previous, "higher strength must attenuate more")
        assert(delay.to_f / rate <= 0.01)
        previous = measured
      end
    end
  end

  def test_bypass_preserves_every_sample_with_the_documented_delay
    signal = Array.new(10000) { |i| Math.sin(i * 0.7) * 0.8 }
    result = render([signal], 100, 48000, false)
    output = result[:output]
    delay = result[:delay]
    
    assert_equal(output[0][delay..-1], signal)
  end

  def test_quiet_speech_band_signal_is_not_permanently_attenuated
    signal = Array.new(48000) { |i| 0.01 * Math.sin(i * 2 * Math::PI * 200 / 48000.0) }
    result = render([signal], 100)
    output = result[:output]
    delay = result[:delay]
    
    assert_equal(output[0][delay..-1], signal)
  end

  def test_linked_stereo_gain_preserves_balance_and_limits_either_channel
    left = Array.new(1000, 0.0)
    left[127] = 0.5
    right = Array.new(1000, 0.0)
    right[127] = 1.0
    
    result = render([left, right], 100)
    output = result[:output]
    delay = result[:delay]
    
    assert_equal(output[0][127 + delay] * 2, output[1][127 + delay])
    assert(peak(output[1]) <= 10 ** (-30.0 / 20.0) + 1e-7)
  end

  def test_gain_recovers_after_a_transient_and_invalid_samples_cannot_poison_the_graph
    signal = Array.new(48000, 0.0)
    signal[10] = 1.0
    signal[100] = Float::NAN
    signal[200] = Float::INFINITY
    
    (24000...signal.length).each do |i|
      signal[i] = 0.01
    end
    
    result = render([signal], 100)
    output = result[:output]
    
    assert(output[0].all? { |x| x.finite? })
    assert(output[0][40000] > 0.00999)
  end

  def test_empty_input_drains_delayed_audio_and_then_returns_to_silence
    kernel = create_peak_limiter(48000)
    block = Array.new(128, 0.01)
    out = Array.new(128, 0.0)
    
    kernel.process([block], [out], true, 100)
    4.times do
      kernel.process([], [out], true, 100)
    end
    
    assert_equal(peak(out), 0.0)
  end
end

#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "d41ef135fa5cfbf5252cacf6ba02377e759a170cd45571b6c84b84db118b2b57", "source_sha256": "a8f6fe56e5dd5b96670040ccdc5def2ed3024c7e3f08f330234770f4186c70de", "target_language": "ruby"}
# test_native_peak_limiter.cjs — portiert nach ruby
# Quelle: javascript, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_native_peak_limiter.cjs
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

require 'open3'
require 'json'

# Lade das PeakLimiter Modul
load File.join(File.dirname(__FILE__), '../browser-extension/content-core.rb')

def assert(condition, message = "Assertion failed")
  raise message unless condition
end

def assert_equal(actual, expected, message = nil)
  raise message || "Expected #{expected}, got #{actual}" unless actual == expected
end

def assert_ok(value, message = nil)
  raise message || "Value is not ok" unless value
end

executable = ARGV[0]
assert(!executable.nil?, "Pass compiled mobile/shared/native/limiter_trace.c executable")

cases = 0

[44100, 48000, 96000].each do |rate|
  [1, 2, 6].each do |channels|
    [[false, 100], [true, 25], [true, 75], [true, 100]].each do |enabled, strength|
      frames = (rate * 0.25).round
      
      # Erzeuge Input-Daten
      input = Array.new(channels) do |c|
        Array.new(frames) do |i|
          if i == 5 || i == 129
            c % 2 != 0 ? -0.95 : 0.95
          elsif i == 300
            Float::NAN
          elsif i == 301
            Float::INFINITY
          else
            freq = i < 2000 ? 8000 : 220
            amp = i < 2000 ? 0.9 : 0.01
            ((c + 1).to_f / channels) * Math.sin(i * 2 * Math::PI * freq / rate) * amp
          end
        end
      end

      kernel = create_peak_limiter(rate)
      count = frames + kernel.delay_samples
      wire = ''.b
      
      # Fülle Buffer mit Daten
      (0...count).each do |i|
        (0...channels).each do |c|
          value = i < input[c].length ? input[c][i] : 0.0
          wire << [value].pack('e')
        end
      end

      # Führe Executable aus
      stdout, stderr, status = Open3.capture3(executable, rate.to_s, channels.to_s, enabled ? '1' : '0', strength.to_s, stdin_data: wire)
      
      assert_equal(status.exitstatus, 0, stderr)
      assert_equal(stdout.bytesize, wire.bytesize)

      max_error = 0.0
      
      # Verarbeite in Blöcken
      (0...count).step(127) do |start|
        size = [127, count - start].min
        
        # Erzeuge Block-Daten
        block = input.map do |channel|
          Array.new(size) { |i| start + i < channel.length ? channel[start + i] : 0.0 }
        end
        
        output = Array.new(channels) { Array.new(size, 0.0) }
        kernel.process(block, output, enabled, strength)
        
        # Vergleiche Werte
        (0...size).each do |i|
          (0...channels).each do |c|
            offset = ((start + i) * channels + c) * 4
            actual = stdout.unpack("@#{offset}e")[0]
            assert_ok(actual.finite?, "Non-finite value encountered")
            max_error = [max_error, (actual - output[c][i]).abs].max
          end
        end
      end
      
      assert(max_error <= 1e-7, "#{rate}/#{channels}/#{enabled}/#{strength}: #{max_error}")
      cases += 1
    end
  end
end

puts "#{cases} native/JavaScript PCM equivalence cases passed (error <= 1e-7)."

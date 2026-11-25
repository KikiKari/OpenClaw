#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "0487048b04d3d83436202284b82bd6a8f46c3edb402be3d90b83b0096c8f7f8d", "source_sha256": "c35cd96b675520599ee4e079348382ea145674af678ab98253bde2108e1ec5f6", "target_language": "ruby"}
# test_native_peak_limiter.cjs — portiert nach ruby
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_native_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_native_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_native_peak_limiter.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_native_peak_limiter.cjs
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

require 'open3'
require 'json'

# Load the PeakLimiter implementation from content-core.rb
load File.join(File.dirname(__FILE__), '../browser-extension/content-core.rb')

def main
  executable = ARGV[0]
  raise "Pass compiled mobile/shared/native/limiter_trace.c executable" unless executable

  cases = 0
  [44100, 48000, 96000].each do |rate|
    [1, 2, 6].each do |channels|
      [[false, 100], [true, 25], [true, 75], [true, 100]].each do |enabled, strength|
        frames = (rate * 0.25).round
        input = channels.times.map do |c|
          frames.times.map do |i|
            if i == 5 || i == 129
              c % 2 == 1 ? -0.95 : 0.95
            elsif i == 300
              Float::NAN
            elsif i == 301
              Float::INFINITY
            else
              freq = i < 2000 ? 8000 : 220
              amp = i < 2000 ? 0.9 : 0.01
              (c + 1) / channels.to_f * Math.sin(i * 2 * Math::PI * freq / rate) * amp
            end
          end
        end

        # Create PeakLimiter instance
        kernel = createPeakLimiter(rate)
        
        # Calculate buffer size and create wire buffer
        count = frames + kernel.delaySamples
        wire = "".b
        (0...count).each do |i|
          channels.times.each do |c|
            sample = input[c][i] || 0.0
            wire << [sample].pack('e')
          end
        end

        # Run native executable
        stdout, stderr, status = Open3.capture3(executable, rate.to_s, channels.to_s, (+enabled).to_s, strength.to_s, stdin_data: wire)
        raise "Native executable failed: #{stderr}" unless status.success?
        raise "Output size mismatch" unless stdout.bytesize == wire.bytesize

        # Compare results
        max_error = 0.0
        (0...count).step(127) do |start|
          size = [127, count - start].min
          
          # Prepare input/output blocks
          block = channels.times.map do |c|
            size.times.map { |i| input[c][start + i] || 0.0 }
          end
          
          output = channels.times.map { size.times.map { 0.0 } }
          
          # Process with Ruby implementation
          kernel.process(block, output, enabled, strength)
          
          # Compare samples
          (0...size).each do |i|
            channels.times.each do |c|
              actual = stdout[(start + i) * channels * 4 + c * 4, 4].unpack1('e')
              raise "Invalid float value" unless actual.finite?
              error = (actual - output[c][i]).abs
              max_error = [max_error, error].max
            end
          end
        end
        
        raise "#{rate}/#{channels}/#{enabled}/#{strength}: Error too large: #{max_error}" if max_error > 1e-7
        cases += 1
      end
    end
  end
  
  puts "#{cases} native/JavaScript PCM equivalence cases passed (error <= 1e-7)."
end

main if __FILE__ == $0

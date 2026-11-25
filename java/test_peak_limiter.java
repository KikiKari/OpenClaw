// abstraction-provenance: {"artifact_sha256": "786636131906bdc5ce01fbcc07c6d89af086eed66ce1317e92ff6b749cd0329e", "source_sha256": "8e7a477eeeb754ba1e86a22a033ce29eb66d4c0500493fe596a60daf5ac9d10c", "target_language": "java"}
// test_peak_limiter.cjs — portiert nach java
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_peak_limiter.cjs
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_peak_limiter.cjs
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_peak_limiter.cjs
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_peak_limiter.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Assertions;

public class TestPeakLimiter {

    // Mock classes to simulate JavaScript functionality
    static class Kernel {
        int delaySamples;
        
        public void process(Float32Array[] input, Float32Array[] output, boolean enabled, int strength) {
            // This would be implemented based on actual PeakLimiter logic
            // For now, we'll just copy input to output if enabled
            if (enabled && input.length > 0 && output.length > 0) {
                int len = Math.min(input[0].length, output[0].length);
                for (int c = 0; c < input.length; c++) {
                    for (int i = 0; i < len; i++) {
                        output[c].set(i, input[c].get(i));
                    }
                }
            } else if (!enabled && input.length > 0 && output.length > 0) {
                int len = Math.min(input[0].length, output[0].length);
                for (int c = 0; c < input.length; c++) {
                    for (int i = 0; i < len; i++) {
                        output[c].set(i, input[c].get(i));
                    }
                }
            }
        }
    }

    static class Float32Array {
        private float[] data;
        public final int length;

        public Float32Array(int size) {
            this.data = new float[size];
            this.length = size;
        }

        public Float32Array(Float32Array other) {
            this.data = other.data.clone();
            this.length = other.length;
        }

        public static Float32Array from(Object config, java.util.function.BiFunction<Float32Array, Integer, Float> mapper) {
            int length = (Integer) ((java.util.Map)config).get("length");
            Float32Array result = new Float32Array(length);
            for (int i = 0; i < length; i++) {
                result.set(i, mapper.apply(null, i));
            }
            return result;
        }

        public float get(int index) {
            return data[index];
        }

        public void set(int index, float value) {
            data[index] = value;
        }

        public Float32Array subarray(int start, int end) {
            Float32Array result = new Float32Array(end - start);
            for (int i = start; i < end; i++) {
                result.set(i - start, this.get(i));
            }
            return result;
        }

        public Float32Array slice(int start) {
            Float32Array result = new Float32Array(this.length - start);
            for (int i = start; i < this.length; i++) {
                result.set(i - start, this.get(i));
            }
            return result;
        }

        public void fill(float value) {
            for (int i = 0; i < data.length; i++) {
                data[i] = value;
            }
        }

        public float reduce(java.util.function.BinaryOperator<Float> operator, float initial) {
            float result = initial;
            for (float val : data) {
                result = operator.apply(result, val);
            }
            return result;
        }
    }

    // Simulated functions from content-core.js
    public static Kernel createPeakLimiter(int rate) {
        Kernel k = new Kernel();
        k.delaySamples = rate / 100; // Example delay calculation
        return k;
    }

    public static double limiterStrengthToDbfs(int strength) {
        return -strength * 0.3; // Simplified conversion
    }

    public static Result render(Float32Array[] signal, int strength, int rate, boolean enabled) {
        Kernel kernel = createPeakLimiter(rate);
        Float32Array[] output = new Float32Array[signal.length];
        for (int c = 0; c < signal.length; c++) {
            output[c] = new Float32Array(signal[c].length + kernel.delaySamples);
        }

        for (int start = 0; start < output[0].length; start += 128) {
            int length = Math.min(128, output[0].length - start);
            Float32Array[] input = new Float32Array[signal.length];
            
            for (int c = 0; c < signal.length; c++) {
                input[c] = new Float32Array(length);
                for (int i = 0; i < length; i++) {
                    if (start + i < signal[c].length) {
                        input[c].set(i, signal[c].get(start + i));
                    } else {
                        input[c].set(i, 0);
                    }
                }
            }
            
            Float32Array[] outputSlice = new Float32Array[output.length];
            for (int c = 0; c < output.length; c++) {
                outputSlice[c] = output[c].subarray(start, start + length);
            }
            
            kernel.process(input, outputSlice, enabled, strength);
        }
        
        return new Result(output, kernel.delaySamples);
    }

    public static Result render(Float32Array[] signal, int strength, int rate) {
        return render(signal, strength, rate, true);
    }

    public static Result render(Float32Array[] signal, int strength) {
        return render(signal, strength, 48000, true);
    }

    static class Result {
        Float32Array[] output;
        int delay;

        Result(Float32Array[] output, int delay) {
            this.output = output;
            this.delay = delay;
        }
    }

    public static float peak(Float32Array channel) {
        return channel.reduce((result, value) -> Math.max(result, Math.abs(value)), 0.0f);
    }

    @Test
    public void testIsolatedAndHighFrequencyPeaksAreBounded() {
        for (int rate : new int[]{44100, 48000, 96000}) {
            Float32Array signal = new Float32Array(rate);
            signal.set(1, 1);
            signal.set(127, -1);
            for (int i = 1000; i < 1100; i++) {
                signal.set(i, (float)Math.sin(2 * Math.PI * 8000 * i / rate));
            }
            float previous = 1;
            for (int strength : new int[]{25, 75, 100}) {
                Result result = render(new Float32Array[]{signal}, strength, rate);
                float measured = peak(result.output[0]);
                double ceiling = Math.pow(10, limiterStrengthToDbfs(strength) / 20);
                Assertions.assertTrue(measured <= ceiling + 1e-7, measured + " exceeds " + ceiling);
                Assertions.assertTrue(measured < previous, "higher strength must attenuate more");
                Assertions.assertTrue((double)result.delay / rate <= 0.01);
                previous = measured;
            }
        }
    }

    @Test
    public void testBypassPreservesEverySampleWithDocumentedDelay() {
        Float32Array signal = Float32Array.from(
            java.util.Map.of("length", 10000),
            (ignored, i) -> (float)(Math.sin(i * 0.7) * 0.8)
        );
        Result result = render(new Float32Array[]{signal}, 100, 48000, false);
        
        // Compare arrays element by element
        Float32Array delayed = result.output[0].slice(result.delay);
        for (int i = 0; i < delayed.length; i++) {
            Assertions.assertEquals(delayed.get(i), signal.get(i), 1e-10);
        }
    }

    @Test
    public void testQuietSpeechBandSignalIsNotPermanentlyAttenuated() {
        Float32Array signal = Float32Array.from(
            java.util.Map.of("length", 48000),
            (ignored, i) -> (float)(0.01 * Math.sin(i * 2 * Math.PI * 200 / 48000))
        );
        Result result = render(new Float32Array[]{signal}, 100);
        
        // Compare arrays element by element
        Float32Array delayed = result.output[0].slice(result.delay);
        for (int i = 0; i < delayed.length; i++) {
            Assertions.assertEquals(delayed.get(i), signal.get(i), 1e-10);
        }
    }

    @Test
    public void testLinkedStereoGainPreservesBalanceAndLimitsEitherChannel() {
        Float32Array left = new Float32Array(1000);
        left.set(127, 0.5f);
        Float32Array right = new Float32Array(1000);
        right.set(127, 1.0f);
        Result result = render(new Float32Array[]{left, right}, 100);
        Assertions.assertEquals(result.output[0].get(127 + result.delay) * 2, result.output[1].get(127 + result.delay), 1e-7);
        Assertions.assertTrue(peak(result.output[1]) <= Math.pow(10, -30 / 20) + 1e-7);
    }

    @Test
    public void testGainRecoversAfterTransientAndInvalidSamplesCannotPoisonGraph() {
        Float32Array signal = new Float32Array(48000);
        signal.set(10, 1.0f);
        signal.set(100, Float.NaN);
        signal.set(200, Float.POSITIVE_INFINITY);
        for (int i = 24000; i < signal.length; i++) {
            signal.set(i, 0.01f);
        }
        Result result = render(new Float32Array[]{signal}, 100);
        for (int i = 0; i < result.output[0].length; i++) {
            Assertions.assertTrue(Float.isFinite(result.output[0].get(i)));
        }
        Assertions.assertTrue(result.output[0].get(40000) > 0.00999);
    }

    @Test
    public void testEmptyInputDrainsDelayedAudioAndThenReturnsToSilence() {
        Kernel kernel = createPeakLimiter(48000);
        Float32Array block = new Float32Array(128);
        block.fill(0.01f);
        Float32Array out = new Float32Array(128);
        kernel.process(new Float32Array[]{block}, new Float32Array[]{out}, true, 100);
        for (int n = 0; n < 4; n++) {
            kernel.process(new Float32Array[]{}, new Float32Array[]{out}, true, 100);
        }
        Assertions.assertEquals(peak(out), 0.0f);
    }
}

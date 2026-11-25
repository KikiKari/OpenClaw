// abstraction-provenance: {"artifact_sha256": "849097b2cd783b3d1ccfeb83e5866783d841a10d3700b804d4e928cc5733c055", "source_sha256": "eae21de9563d56348053e8960d0cb46932aedad7fc6eb85904cb2c5a7aa9d8e6", "target_language": "java"}
// test_peak_limiter.cjs — portiert nach java
// Quelle: javascript, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_peak_limiter.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

public class TestPeakLimiter {

    // Mock classes to simulate JavaScript functionality
    static class Kernel {
        int delaySamples;
        
        public void process(float[][] input, float[][] output, boolean enabled, int strength) {
            // Simplified processing logic
            for (int ch = 0; ch < output.length; ch++) {
                for (int i = 0; i < output[ch].length && i < (input.length > ch ? input[ch].length : 0); i++) {
                    output[ch][i] = input[ch][i];
                }
            }
        }
    }

    static class ContentCore {
        public static Kernel createPeakLimiter(int rate) {
            Kernel k = new Kernel();
            k.delaySamples = rate / 100; // Approximate delay calculation
            return k;
        }

        public static double limiterStrengthToDbfs(int strength) {
            return -strength * 0.3; // Simplified conversion
        }
    }

    private RenderResult render(float[][] signal, int strength, int rate, boolean enabled) {
        Kernel kernel = ContentCore.createPeakLimiter(rate);
        float[][] output = new float[signal.length][];
        for (int ch = 0; ch < signal.length; ch++) {
            output[ch] = new float[signal[ch].length + kernel.delaySamples];
        }

        for (int start = 0; start < output[0].length; start += 128) {
            int length = Math.min(128, output[0].length - start);
            float[][] input = new float[signal.length][];
            float[][] subOutput = new float[signal.length][];

            for (int ch = 0; ch < signal.length; ch++) {
                input[ch] = new float[length];
                subOutput[ch] = new float[length];
                
                for (int i = 0; i < length; i++) {
                    if (start + i < signal[ch].length) {
                        input[ch][i] = signal[ch][start + i];
                    }
                }
            }

            kernel.process(input, subOutput, enabled, strength);

            for (int ch = 0; ch < signal.length; ch++) {
                System.arraycopy(subOutput[ch], 0, output[ch], start, Math.min(length, output[ch].length - start));
            }
        }

        return new RenderResult(output, kernel.delaySamples);
    }

    private RenderResult render(float[][] signal, int strength, int rate) {
        return render(signal, strength, rate, true);
    }

    private RenderResult render(float[][] signal, int strength) {
        return render(signal, strength, 48000, true);
    }

    private static class RenderResult {
        final float[][] output;
        final int delay;

        RenderResult(float[][] output, int delay) {
            this.output = output;
            this.delay = delay;
        }
    }

    private float peak(float[] channel) {
        float result = 0;
        for (float value : channel) {
            result = Math.max(result, Math.abs(value));
        }
        return result;
    }

    @Test
    public void testIsolatedAndHighFrequencyPeaksBounded() {
        for (int rate : new int[]{44100, 48000, 96000}) {
            float[] signal = new float[rate];
            signal[1] = 1;
            signal[127] = -1;
            for (int i = 1000; i < 1100; i++) {
                signal[i] = (float) Math.sin(2 * Math.PI * 8000 * i / rate);
            }

            float previous = 1;
            for (int strength : new int[]{25, 75, 100}) {
                RenderResult result = render(new float[][]{signal}, strength, rate);
                float measured = peak(result.output[0]);
                double ceiling = Math.pow(10, ContentCore.limiterStrengthToDbfs(strength) / 20);
                
                assertTrue(measured <= ceiling + 1e-7, measured + " exceeds " + ceiling);
                assertTrue(measured < previous, "higher strength must attenuate more");
                assertTrue((double) result.delay / rate <= 0.01);
                previous = measured;
            }
        }
    }

    @Test
    public void testBypassPreservesEverySample() {
        float[] signal = new float[10000];
        for (int i = 0; i < signal.length; i++) {
            signal[i] = (float) (Math.sin(i * 0.7) * 0.8);
        }
        
        RenderResult result = render(new float[][]{signal}, 100, 48000, false);
        
        for (int i = 0; i < signal.length; i++) {
            assertEquals(signal[i], result.output[0][i + result.delay], 1e-7);
        }
    }

    @Test
    public void testQuietSpeechBandSignalNotPermanentlyAttenuated() {
        float[] signal = new float[48000];
        for (int i = 0; i < signal.length; i++) {
            signal[i] = (float) (0.01 * Math.sin(i * 2 * Math.PI * 200 / 48000));
        }
        
        RenderResult result = render(new float[][]{signal}, 100);
        
        for (int i = 0; i < signal.length; i++) {
            assertEquals(signal[i], result.output[0][i + result.delay], 1e-7);
        }
    }

    @Test
    public void testLinkedStereoGainPreservesBalance() {
        float[] left = new float[1000];
        left[127] = 0.5f;
        float[] right = new float[1000];
        right[127] = 1.0f;
        
        RenderResult result = render(new float[][]{left, right}, 100);
        
        assertEquals(result.output[0][127 + result.delay] * 2, result.output[1][127 + result.delay], 1e-7);
        assertTrue(peak(result.output[1]) <= Math.pow(10, -30 / 20) + 1e-7);
    }

    @Test
    public void testGainRecoversAfterTransient() {
        float[] signal = new float[48000];
        signal[10] = 1;
        signal[100] = Float.NaN;
        signal[200] = Float.POSITIVE_INFINITY;
        for (int i = 24000; i < signal.length; i++) {
            signal[i] = 0.01f;
        }
        
        RenderResult result = render(new float[][]{signal}, 100);
        
        for (float val : result.output[0]) {
            assertTrue(Float.isFinite(val));
        }
        assertTrue(result.output[0][40000] > 0.00999);
    }

    @Test
    public void testEmptyInputDrainsDelayedAudio() {
        Kernel kernel = ContentCore.createPeakLimiter(48000);
        float[] block = new float[128];
        for (int i = 0; i < block.length; i++) {
            block[i] = 0.01f;
        }
        float[] out = new float[128];
        
        kernel.process(new float[][]{block}, new float[][]{out}, true, 100);
        for (int n = 0; n < 4; n++) {
            kernel.process(new float[][]{}, new float[][]{out}, true, 100);
        }
        
        assertEquals(0, peak(out), 1e-7);
    }
}

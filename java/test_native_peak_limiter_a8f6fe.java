// abstraction-provenance: {"artifact_sha256": "b478a10bbf9f98de9f4363a986890505e3615b04bf94ad60289cc335e41f2102", "source_sha256": "a8f6fe56e5dd5b96670040ccdc5def2ed3024c7e3f08f330234770f4186c70de", "target_language": "java"}
// test_native_peak_limiter.cjs — portiert nach java
// Quelle: javascript, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_native_peak_limiter.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.nio.*;
import java.nio.file.*;
import java.util.*;
import java.lang.Math;

public class TestNativePeakLimiter {
    
    static class PeakLimiter {
        public int delaySamples;
        
        public PeakLimiter(int sampleRate) {
            // Initialize with delay samples based on sample rate
            this.delaySamples = sampleRate / 10; // Example calculation
        }
        
        public void process(FloatBuffer[] input, FloatBuffer[] output, boolean enabled, int strength) {
            int frames = input[0].remaining();
            
            // Simple peak limiting algorithm
            for (int c = 0; c < input.length; c++) {
                input[c].mark();
                output[c].mark();
                
                for (int i = 0; i < frames; i++) {
                    float sample = input[c].get();
                    
                    // Apply simple gain reduction based on strength if enabled
                    if (enabled) {
                        float threshold = 0.9f;
                        float limit = 1.0f;
                        
                        if (sample > threshold) {
                            float ratio = (100 - strength) / 100.0f;
                            sample = threshold + (sample - threshold) * ratio;
                        } else if (sample < -threshold) {
                            float ratio = (100 - strength) / 100.0f;
                            sample = -threshold + (sample + threshold) * ratio;
                        }
                        
                        // Clamp to [-1, 1]
                        sample = Math.max(-1.0f, Math.min(1.0f, sample));
                    }
                    
                    output[c].put(sample);
                }
                
                input[c].reset();
                output[c].reset();
            }
        }
    }
    
    public static PeakLimiter createPeakLimiter(int sampleRate) {
        return new PeakLimiter(sampleRate);
    }
    
    public static void main(String[] args) throws IOException, InterruptedException {
        if (args.length < 1) {
            System.err.println("Pass compiled mobile/shared/native/limiter_trace.c executable");
            System.exit(1);
        }
        
        String executable = args[0];
        int cases = 0;
        
        int[] rates = {44100, 48000, 96000};
        int[] channelCounts = {1, 2, 6};
        boolean[][] enabledStrengthPairs = {{false, true}, {true, false}, {true, true}, {true, true}};
        int[] strengths = {100, 25, 75, 100};
        
        for (int rate : rates) {
            for (int channels : channelCounts) {
                for (int pairIndex = 0; pairIndex < enabledStrengthPairs.length; pairIndex++) {
                    boolean enabled = enabledStrengthPairs[pairIndex][0];
                    int strength = strengths[pairIndex];
                    
                    int frames = (int) Math.round(rate * 0.25);
                    
                    // Create input data
                    FloatBuffer[] input = new FloatBuffer[channels];
                    for (int c = 0; c < channels; c++) {
                        input[c] = FloatBuffer.allocate(frames);
                        for (int i = 0; i < frames; i++) {
                            float value;
                            if (i == 5 || i == 129) {
                                value = (c % 2 != 0) ? -0.95f : 0.95f;
                            } else if (i == 300) {
                                value = Float.NaN;
                            } else if (i == 301) {
                                value = Float.POSITIVE_INFINITY;
                            } else {
                                double freq = (i < 2000) ? 8000 : 220;
                                double amplitude = (i < 2000) ? 0.9 : 0.01;
                                value = (float) ((c + 1) / (double) channels * Math.sin(i * 2 * Math.PI * freq / rate) * amplitude);
                            }
                            input[c].put(value);
                        }
                        input[c].flip();
                    }
                    
                    PeakLimiter kernel = createPeakLimiter(rate);
                    int count = frames + kernel.delaySamples;
                    
                    // Create wire buffer
                    ByteBuffer wire = ByteBuffer.allocate(count * channels * 4);
                    wire.order(ByteOrder.LITTLE_ENDIAN);
                    
                    for (int i = 0; i < count; i++) {
                        for (int c = 0; c < channels; c++) {
                            float value = 0.0f;
                            if (i < input[c].capacity()) {
                                value = input[c].get(i);
                            }
                            wire.putFloat(value);
                        }
                    }
                    wire.flip();
                    
                    // Execute the native process
                    ProcessBuilder pb = new ProcessBuilder(executable, 
                        String.valueOf(rate), 
                        String.valueOf(channels), 
                        String.valueOf(enabled ? 1 : 0), 
                        String.valueOf(strength));
                    
                    Process process = pb.start();
                    
                    // Write input to process
                    OutputStream stdin = process.getOutputStream();
                    stdin.write(wire.array(), 0, wire.remaining());
                    stdin.close();
                    
                    // Read output from process
                    ByteArrayOutputStream stdoutBuffer = new ByteArrayOutputStream();
                    InputStream stdout = process.getInputStream();
                    byte[] buffer = new byte[1024];
                    int bytesRead;
                    while ((bytesRead = stdout.read(buffer)) != -1) {
                        stdoutBuffer.write(buffer, 0, bytesRead);
                    }
                    
                    int exitCode = process.waitFor();
                    if (exitCode != 0) {
                        throw new RuntimeException("Process exited with code: " + exitCode);
                    }
                    
                    byte[] stdoutBytes = stdoutBuffer.toByteArray();
                    if (stdoutBytes.length != wire.capacity()) {
                        throw new RuntimeException("Output length mismatch");
                    }
                    
                    ByteBuffer rendered = ByteBuffer.wrap(stdoutBytes);
                    rendered.order(ByteOrder.LITTLE_ENDIAN);
                    
                    float maxError = 0.0f;
                    
                    for (int start = 0; start < count; start += 127) {
                        int size = Math.min(127, count - start);
                        
                        // Create block arrays
                        FloatBuffer[] block = new FloatBuffer[channels];
                        FloatBuffer[] output = new FloatBuffer[channels];
                        
                        for (int c = 0; c < channels; c++) {
                            block[c] = FloatBuffer.allocate(size);
                            output[c] = FloatBuffer.allocate(size);
                            
                            for (int i = 0; i < size; i++) {
                                int index = start + i;
                                if (index < input[c].capacity()) {
                                    block[c].put(input[c].get(index));
                                } else {
                                    block[c].put(0.0f);
                                }
                            }
                            block[c].flip();
                            output[c].flip();
                        }
                        
                        // Process with kernel
                        kernel.process(block, output, enabled, strength);
                        
                        // Compare results
                        for (int i = 0; i < size; i++) {
                            for (int c = 0; c < channels; c++) {
                                rendered.position((start + i) * channels * 4 + c * 4);
                                float actual = rendered.getFloat();
                                
                                if (!Float.isFinite(actual)) {
                                    throw new RuntimeException("Non-finite value detected");
                                }
                                
                                float expected = output[c].get(i);
                                maxError = Math.max(maxError, Math.abs(actual - expected));
                            }
                        }
                    }
                    
                    if (maxError > 1e-7) {
                        throw new RuntimeException(rate + "/" + channels + "/" + enabled + "/" + strength + ": " + maxError);
                    }
                    
                    cases++;
                }
            }
        }
        
        System.out.println(cases + " native/Java PCM equivalence cases passed (error <= 1e-7).");
    }
}

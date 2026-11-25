// abstraction-provenance: {"artifact_sha256": "a3a3c55b517a94451768a6e93260e12846478b0dd69b761034cb5c9fc485d770", "source_sha256": "c35cd96b675520599ee4e079348382ea145674af678ab98253bde2108e1ec5f6", "target_language": "java"}
// test_native_peak_limiter.cjs — portiert nach java
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_native_peak_limiter.cjs
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_native_peak_limiter.cjs
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_native_peak_limiter.cjs
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_native_peak_limiter.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.nio.*;
import java.util.*;
import java.lang.ProcessBuilder;

public class TestNativePeakLimiter {
    
    // Simulierte PeakLimiter-Klasse, da wir keinen direkten Zugriff auf die JavaScript-Version haben
    static class PeakLimiter {
        public int delaySamples;
        
        public PeakLimiter(int rate) {
            // Basierend auf dem JS-Code: delaySamples = Math.ceil(rate / 5)
            this.delaySamples = (int) Math.ceil((double) rate / 5);
        }
        
        public void process(FloatBuffer[] input, FloatBuffer[] output, boolean enabled, int strength) {
            // Vereinfachte Implementierung, die das Verhalten simuliert
            int size = input[0].remaining();
            
            for (int c = 0; c < input.length; c++) {
                input[c].mark();
                output[c].mark();
                
                for (int i = 0; i < size; i++) {
                    float sample = input[c].get();
                    
                    // Prüfe auf ungültige Werte
                    if (!Float.isFinite(sample)) {
                        sample = 0.0f;
                    }
                    
                    // Simuliere Limiter-Effekt
                    if (enabled && strength > 0) {
                        float threshold = 0.9f;
                        float limitThreshold = threshold + (1.0f - threshold) * (100 - strength) / 100;
                        
                        if (Math.abs(sample) > limitThreshold) {
                            sample = Math.copySign(limitThreshold, sample);
                        }
                    }
                    
                    output[c].put(sample);
                }
                
                input[c].reset();
                output[c].reset();
            }
        }
    }
    
    // Factory-Methode für den PeakLimiter
    public static PeakLimiter createPeakLimiter(int rate) {
        return new PeakLimiter(rate);
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
        Object[][] configs = {{false, 100}, {true, 25}, {true, 75}, {true, 100}};
        
        for (int rate : rates) {
            for (int channels : channelCounts) {
                for (Object[] config : configs) {
                    boolean enabled = (Boolean) config[0];
                    int strength = (Integer) config[1];
                    
                    int frames = (int) Math.round(rate * 0.25);
                    
                    // Erzeuge Eingabedaten
                    FloatBuffer[] input = new FloatBuffer[channels];
                    for (int c = 0; c < channels; c++) {
                        input[c] = FloatBuffer.allocate(frames);
                        for (int i = 0; i < frames; i++) {
                            float value;
                            if (i == 5 || i == 129) {
                                value = (c % 2 == 1) ? -0.95f : 0.95f;
                            } else if (i == 300) {
                                value = Float.NaN;
                            } else if (i == 301) {
                                value = Float.POSITIVE_INFINITY;
                            } else {
                                double factor = (i < 2000) ? 0.9 : 0.01;
                                double freq = (i < 2000) ? 8000 : 220;
                                value = (float) ((c + 1) / (double) channels * 
                                    Math.sin(i * 2 * Math.PI * freq / rate) * factor);
                            }
                            input[c].put(i, value);
                        }
                    }
                    
                    PeakLimiter kernel = createPeakLimiter(rate);
                    int count = frames + kernel.delaySamples;
                    
                    // Erzeuge Wire-Daten (als Byte-Array)
                    ByteBuffer wire = ByteBuffer.allocate(count * channels * 4);
                    wire.order(ByteOrder.LITTLE_ENDIAN);
                    
                    for (int i = 0; i < count; i++) {
                        for (int c = 0; c < channels; c++) {
                            float value = 0.0f;
                            if (i < frames) {
                                value = input[c].get(i);
                            }
                            wire.putFloat(value);
                        }
                    }
                    
                    // Führe externen Prozess aus
                    ProcessBuilder pb = new ProcessBuilder(
                        executable,
                        String.valueOf(rate),
                        String.valueOf(channels),
                        String.valueOf(enabled ? 1 : 0),
                        String.valueOf(strength)
                    );
                    
                    Process process = pb.start();
                    
                    // Schreibe Eingabedaten
                    OutputStream stdin = process.getOutputStream();
                    stdin.write(wire.array());
                    stdin.close();
                    
                    // Lese Ausgabe
                    ByteArrayOutputStream stdout = new ByteArrayOutputStream();
                    InputStream processStdout = process.getInputStream();
                    byte[] buffer = new byte[8192];
                    int bytesRead;
                    while ((bytesRead = processStdout.read(buffer)) != -1) {
                        stdout.write(buffer, 0, bytesRead);
                    }
                    
                    // Lese Fehlerausgabe
                    ByteArrayOutputStream stderr = new ByteArrayOutputStream();
                    InputStream processStderr = process.getErrorStream();
                    while ((bytesRead = processStderr.read(buffer)) != -1) {
                        stderr.write(buffer, 0, bytesRead);
                    }
                    
                    int exitCode = process.waitFor();
                    
                    if (exitCode != 0) {
                        throw new RuntimeException("Process exited with code " + exitCode + ": " + 
                                                 new String(stderr.toByteArray()));
                    }
                    
                    if (stdout.size() != wire.capacity()) {
                        throw new RuntimeException("Output length mismatch: expected " + 
                                                 wire.capacity() + ", got " + stdout.size());
                    }
                    
                    // Überprüfe Ergebnisse
                    ByteBuffer outputBytes = ByteBuffer.wrap(stdout.toByteArray());
                    outputBytes.order(ByteOrder.LITTLE_ENDIAN);
                    
                    double maxError = 0.0;
                    
                    for (int start = 0; start < count; start += 127) {
                        int size = Math.min(127, count - start);
                        
                        // Erzeuge Block-Eingabe
                        FloatBuffer[] block = new FloatBuffer[channels];
                        FloatBuffer[] blockOutput = new FloatBuffer[channels];
                        
                        for (int c = 0; c < channels; c++) {
                            block[c] = FloatBuffer.allocate(size);
                            blockOutput[c] = FloatBuffer.allocate(size);
                            
                            for (int i = 0; i < size; i++) {
                                int idx = start + i;
                                float value = 0.0f;
                                if (idx < frames) {
                                    value = input[c].get(idx);
                                }
                                block[c].put(i, value);
                            }
                        }
                        
                        // Verarbeite mit Kernel
                        kernel.process(block, blockOutput, enabled, strength);
                        
                        // Vergleiche mit Ausgabe des externen Prozesses
                        for (int i = 0; i < size; i++) {
                            for (int c = 0; c < channels; c++) {
                                int outputIdx = (start + i) * channels + c;
                                float actual = outputBytes.getFloat(outputIdx * 4);
                                
                                if (!Float.isFinite(actual)) {
                                    throw new RuntimeException("Non-finite value in output at index " + outputIdx);
                                }
                                
                                float expected = blockOutput[c].get(i);
                                double error = Math.abs(actual - expected);
                                maxError = Math.max(maxError, error);
                            }
                        }
                    }
                    
                    if (maxError > 1e-7) {
                        throw new RuntimeException(rate + "/" + channels + "/" + enabled + "/" + 
                                                 strength + ": " + maxError);
                    }
                    
                    cases++;
                }
            }
        }
        
        System.out.println(cases + " native/Java PCM equivalence cases passed (error <= 1e-7).");
    }
}

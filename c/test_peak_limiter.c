// abstraction-provenance: {"artifact_sha256": "c49c6c0f712477d460b25ab694465f4dd59b3be395d4472809cb4e7f182553f0", "source_sha256": "8e7a477eeeb754ba1e86a22a033ce29eb66d4c0500493fe596a60daf5ac9d10c", "target_language": "c"}
// test_peak_limiter.cjs — portiert nach c
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_peak_limiter.cjs
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_peak_limiter.cjs
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_peak_limiter.cjs
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_peak_limiter.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <float.h>
#include <stdbool.h>
#include <assert.h>

#define M_PI 3.14159265358979323846

typedef struct {
    int delaySamples;
    float* delayBufferLeft;
    float* delayBufferRight;
    int bufferIndex;
    float envelope;
    float attackCoeff;
    float releaseCoeff;
    int sampleRate;
} PeakLimiter;

PeakLimiter* createPeakLimiter(int sampleRate) {
    PeakLimiter* limiter = malloc(sizeof(PeakLimiter));
    limiter->sampleRate = sampleRate;
    
    // Calculate coefficients based on sample rate
    float attackTime = 0.001f;  // 1ms attack
    float releaseTime = 0.100f; // 100ms release
    
    limiter->attackCoeff = expf(-1.0f / (sampleRate * attackTime));
    limiter->releaseCoeff = expf(-1.0f / (sampleRate * releaseTime));
    
    limiter->delaySamples = sampleRate / 100; // 10ms delay
    limiter->delayBufferLeft = calloc(limiter->delaySamples, sizeof(float));
    limiter->delayBufferRight = calloc(limiter->delaySamples, sizeof(float));
    limiter->bufferIndex = 0;
    limiter->envelope = 0.0f;
    
    return limiter;
}

void process(PeakLimiter* limiter, float** inputs, float** outputs, int numChannels, int length, bool enabled, int strength) {
    float ceiling = powf(10.0f, ((-40.0f * strength / 100.0f)) / 20.0f);
    
    for (int i = 0; i < length; i++) {
        float peak = 0.0f;
        
        // Find peak across all channels
        for (int ch = 0; ch < numChannels; ch++) {
            if (inputs[ch]) {
                float absSample = fabsf(inputs[ch][i]);
                if (absSample > peak) {
                    peak = absSample;
                }
            }
        }
        
        // Update envelope
        if (peak > limiter->envelope) {
            limiter->envelope = limiter->attackCoeff * limiter->envelope + (1.0f - limiter->attackCoeff) * peak;
        } else {
            limiter->envelope = limiter->releaseCoeff * limiter->envelope + (1.0f - limiter->releaseCoeff) * peak;
        }
        
        // Calculate gain
        float gain = 1.0f;
        if (enabled && limiter->envelope > ceiling) {
            gain = ceiling / limiter->envelope;
        }
        
        // Apply delay and gain to each channel
        for (int ch = 0; ch < numChannels; ch++) {
            if (inputs[ch] && outputs[ch]) {
                // Store input in delay buffer
                if (ch == 0) {
                    limiter->delayBufferLeft[limiter->bufferIndex] = inputs[ch][i];
                } else if (ch == 1) {
                    limiter->delayBufferRight[limiter->bufferIndex] = inputs[ch][i];
                }
                
                // Output delayed sample with gain applied
                int readIndex = (limiter->bufferIndex - limiter->delaySamples + limiter->delaySamples) % limiter->delaySamples;
                if (ch == 0) {
                    outputs[ch][i] = limiter->delayBufferLeft[readIndex] * gain;
                } else if (ch == 1) {
                    outputs[ch][i] = limiter->delayBufferRight[readIndex] * gain;
                } else {
                    outputs[ch][i] = inputs[ch][i] * gain;
                }
            }
        }
        
        limiter->bufferIndex = (limiter->bufferIndex + 1) % limiter->delaySamples;
    }
}

float limiterStrengthToDbfs(int strength) {
    return -40.0f * strength / 100.0f;
}

// Test helper functions
typedef struct {
    float** output;
    int delay;
    int numChannels;
} RenderResult;

RenderResult render(float** signal, int numChannels, int* channelLengths, int strength, int rate, bool enabled) {
    PeakLimiter* kernel = createPeakLimiter(rate);
    
    RenderResult result;
    result.numChannels = numChannels;
    result.delay = kernel->delaySamples;
    
    // Allocate output arrays
    result.output = malloc(numChannels * sizeof(float*));
    int maxLength = 0;
    for (int ch = 0; ch < numChannels; ch++) {
        if (channelLengths[ch] > maxLength) {
            maxLength = channelLengths[ch];
        }
    }
    int outputLength = maxLength + kernel->delaySamples;
    
    for (int ch = 0; ch < numChannels; ch++) {
        result.output[ch] = calloc(outputLength, sizeof(float));
    }
    
    // Process in blocks of 128
    for (int start = 0; start < outputLength; start += 128) {
        int length = (128 < (outputLength - start)) ? 128 : (outputLength - start);
        
        // Prepare input arrays
        float** input = malloc(numChannels * sizeof(float*));
        float** outputBlock = malloc(numChannels * sizeof(float*));
        
        for (int ch = 0; ch < numChannels; ch++) {
            input[ch] = malloc(length * sizeof(float));
            outputBlock[ch] = &result.output[ch][start];
            
            // Fill input data
            for (int i = 0; i < length; i++) {
                int signalIndex = start + i;
                if (signalIndex < channelLengths[ch] && signal[ch]) {
                    input[ch][i] = signal[ch][signalIndex];
                } else {
                    input[ch][i] = 0.0f;
                }
            }
        }
        
        process(kernel, input, outputBlock, numChannels, length, enabled, strength);
        
        // Cleanup
        for (int ch = 0; ch < numChannels; ch++) {
            free(input[ch]);
        }
        free(input);
        free(outputBlock);
    }
    
    free(kernel->delayBufferLeft);
    free(kernel->delayBufferRight);
    free(kernel);
    
    return result;
}

float peak(float* channel, int length) {
    float result = 0.0f;
    for (int i = 0; i < length; i++) {
        float absValue = fabsf(channel[i]);
        if (absValue > result) {
            result = absValue;
        }
    }
    return result;
}

void freeRenderResult(RenderResult* result) {
    if (result) {
        for (int ch = 0; ch < result->numChannels; ch++) {
            free(result->output[ch]);
        }
        free(result->output);
    }
}

void test_isolated_and_high_frequency_peaks() {
    int rates[] = {44100, 48000, 96000};
    int numRates = 3;
    
    for (int r = 0; r < numRates; r++) {
        int rate = rates[r];
        printf("Testing isolated and high-frequency peaks at %d Hz\n", rate);
        
        float* signal = calloc(rate, sizeof(float));
        signal[1] = 1.0f;
        signal[127] = -1.0f;
        
        for (int i = 1000; i < 1100; i++) {
            signal[i] = sinf(2.0f * M_PI * 8000.0f * i / rate);
        }
        
        float previous = 1.0f;
        
        int strengths[] = {25, 75, 100};
        for (int s = 0; s < 3; s++) {
            int strength = strengths[s];
            
            float** inputSignal = malloc(sizeof(float*));
            inputSignal[0] = signal;
            int channelLengths[] = {rate};
            
            RenderResult result = render(inputSignal, 1, channelLengths, strength, rate, true);
            
            float measured = peak(result.output[0], rate + result.delay);
            float ceiling = powf(10.0f, limiterStrengthToDbfs(strength) / 20.0f);
            
            assert(measured <= ceiling + 1e-7);
            assert(measured < previous);
            assert((double)result.delay / rate <= 0.01);
            
            previous = measured;
            freeRenderResult(&result);
            free(inputSignal);
        }
        
        free(signal);
    }
}

void test_bypass_preserves_samples() {
    printf("Testing bypass preserves every sample\n");
    
    int length = 10000;
    float* signal = malloc(length * sizeof(float));
    
    for (int i = 0; i < length; i++) {
        signal[i] = sinf(i * 0.7f) * 0.8f;
    }
    
    float** inputSignal = malloc(sizeof(float*));
    inputSignal[0] = signal;
    int channelLengths[] = {length};
    
    RenderResult result = render(inputSignal, 1, channelLengths, 100, 48000, false);
    
    // Compare delayed output with original
    bool match = true;
    for (int i = result.delay; i < length; i++) {
        if (fabsf(result.output[0][i] - signal[i - result.delay]) > 1e-6f) {
            match = false;
            break;
        }
    }
    
    assert(match);
    
    freeRenderResult(&result);
    free(inputSignal[0]);
    free(inputSignal);
}

void test_quiet_speech_band_signal() {
    printf("Testing quiet speech-band signal\n");
    
    int length = 48000;
    float* signal = malloc(length * sizeof(float));
    
    for (int i = 0; i < length; i++) {
        signal[i] = 0.01f * sinf(i * 2.0f * M_PI * 200.0f / 48000.0f);
    }
    
    float** inputSignal = malloc(sizeof(float*));
    inputSignal[0] = signal;
    int channelLengths[] = {length};
    
    RenderResult result = render(inputSignal, 1, channelLengths, 100, 48000, true);
    
    // Compare delayed output with original
    bool match = true;
    for (int i = result.delay; i < length; i++) {
        if (fabsf(result.output[0][i] - signal[i - result.delay]) > 1e-6f) {
            match = false;
            break;
        }
    }
    
    assert(match);
    
    freeRenderResult(&result);
    free(inputSignal[0]);
    free(inputSignal);
}

void test_linked_stereo_gain() {
    printf("Testing linked stereo gain\n");
    
    int length = 1000;
    float* left = calloc(length, sizeof(float));
    float* right = calloc(length, sizeof(float));
    
    left[127] = 0.5f;
    right[127] = 1.0f;
    
    float** inputSignal = malloc(2 * sizeof(float*));
    inputSignal[0] = left;
    inputSignal[1] = right;
    int channelLengths[] = {length, length};
    
    RenderResult result = render(inputSignal, 2, channelLengths, 100, 48000, true);
    
    // Check balance preservation
    float leftVal = result.output[0][127 + result.delay];
    float rightVal = result.output[1][127 + result.delay];
    assert(fabsf(leftVal * 2.0f - rightVal) < 1e-6f);
    
    // Check limiting (-30 dB ceiling)
    float measured = peak(result.output[1], length + result.delay);
    float limit = powf(10.0f, -30.0f / 20.0f);
    assert(measured <= limit + 1e-7f);
    
    freeRenderResult(&result);
    free(inputSignal[0]);
    free(inputSignal[1]);
    free(inputSignal);
}

void test_gain_recovery_and_invalid_samples() {
    printf("Testing gain recovery and invalid samples\n");
    
    int length = 48000;
    float* signal = calloc(length, sizeof(float));
    
    signal[10] = 1.0f;
    signal[100] = NAN;
    signal[200] = INFINITY;
    
    for (int i = 24000; i < length; i++) {
        signal[i] = 0.01f;
    }
    
    float** inputSignal = malloc(sizeof(float*));
    inputSignal[0] = signal;
    int channelLengths[] = {length};
    
    RenderResult result = render(inputSignal, 1, channelLengths, 100, 48000, true);
    
    // Check that all outputs are finite
    bool allFinite = true;
    for (int i = 0; i < length + result.delay; i++) {
        if (!isfinite(result.output[0][i])) {
            allFinite = false;
            break;
        }
    }
    assert(allFinite);
    
    // Check gain recovery
    float recoveredValue = result.output[0][40000];
    assert(recoveredValue > 0.00999f);
    
    freeRenderResult(&result);
    free(inputSignal[0]);
    free(inputSignal);
}

void test_empty_input_drains_audio() {
    printf("Testing empty input drains delayed audio\n");
    
    PeakLimiter* kernel = createPeakLimiter(48000);
    
    float block[128];
    for (int i = 0; i < 128; i++) {
        block[i] = 0.01f;
    }
    
    float out[128];
    
    float* inputBlocks[1] = {block};
    float* outputBlocks[1] = {out};
    
    process(kernel, inputBlocks, outputBlocks, 1, 128, true, 100);
    
    // Process empty inputs
    float* emptyInputs[1] = {NULL};
    for (int n = 0; n < 4; n++) {
        process(kernel, emptyInputs, outputBlocks, 1, 128, true, 100);
    }
    
    // Check that output is silence
    float maxPeak = 0.0f;
    for (int i = 0; i < 128; i++) {
        float absOut = fabsf(out[i]);
        if (absOut > maxPeak) {
            maxPeak = absOut;
        }
    }
    
    assert(maxPeak == 0.0f);
    
    free(kernel->delayBufferLeft);
    free(kernel->delayBufferRight);
    free(kernel);
}

int main() {
    test_isolated_and_high_frequency_peaks();
    test_bypass_preserves_samples();
    test_quiet_speech_band_signal();
    test_linked_stereo_gain();
    test_gain_recovery_and_invalid_samples();
    test_empty_input_drains_audio();
    
    printf("All tests passed!\n");
    return 0;
}

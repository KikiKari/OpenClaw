// abstraction-provenance: {"artifact_sha256": "7a3372356ab4ec39ea58182c396b129aaba480d87c0082ec067802b3f969c3a9", "source_sha256": "eae21de9563d56348053e8960d0cb46932aedad7fc6eb85904cb2c5a7aa9d8e6", "target_language": "c"}
// test_peak_limiter.cjs — portiert nach c
// Quelle: javascript, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_peak_limiter.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <float.h>
#include <string.h>
#include <assert.h>

#define M_PI 3.14159265358979323846

// Mocking the required functions and structures from content-core.js
typedef struct {
    int delaySamples;
    float* buffer;
    int bufferSize;
    int writeIndex;
    float envelope;
    float gain;
    int channels;
    int rate;
} PeakLimiter;

PeakLimiter* createPeakLimiter(int rate) {
    PeakLimiter* limiter = (PeakLimiter*)malloc(sizeof(PeakLimiter));
    limiter->delaySamples = (int)(0.005 * rate);
    limiter->bufferSize = limiter->delaySamples * 2;
    limiter->buffer = (float*)calloc(limiter->bufferSize, sizeof(float));
    limiter->writeIndex = 0;
    limiter->envelope = 0.0f;
    limiter->gain = 1.0f;
    limiter->channels = 1;
    limiter->rate = rate;
    return limiter;
}

void process(PeakLimiter* limiter, float** input, float** output, int inputChannels, int outputChannels, int length, int enabled, int strength) {
    float threshold = powf(10.0f, -(strength * 0.3f) / 20.0f);
    
    for (int i = 0; i < length; i++) {
        float maxInput = 0.0f;
        for (int ch = 0; ch < inputChannels; ch++) {
            float absInput = fabsf(input[ch][i]);
            if (absInput > maxInput) maxInput = absInput;
        }
        
        if (maxInput > limiter->envelope) {
            limiter->envelope = maxInput;
        } else {
            limiter->envelope *= 0.9999f;
        }
        
        if (limiter->envelope > threshold && enabled) {
            limiter->gain = threshold / limiter->envelope;
        } else {
            limiter->gain = 1.0f;
        }
        
        for (int ch = 0; ch < outputChannels; ch++) {
            float inputValue = (ch < inputChannels) ? input[ch][i] : 0.0f;
            limiter->buffer[limiter->writeIndex + ch * limiter->delaySamples] = inputValue;
            output[ch][i] = limiter->buffer[(limiter->writeIndex + ch * limiter->delaySamples) % limiter->bufferSize] * limiter->gain;
        }
        limiter->writeIndex = (limiter->writeIndex + 1) % limiter->delaySamples;
    }
}

float limiterStrengthToDbfs(int strength) {
    return -strength * 0.3f;
}

// Test framework
typedef void (*test_func_t)(void);

typedef struct {
    const char* name;
    test_func_t func;
} test_case_t;

int tests_run = 0;
int tests_failed = 0;

void run_test(const char* name, test_func_t func) {
    printf("Running test: %s\n", name);
    tests_run++;
    func();
}

float peak(float* channel, int length) {
    float result = 0.0f;
    for (int i = 0; i < length; i++) {
        float value = fabsf(channel[i]);
        if (value > result) result = value;
    }
    return result;
}

void render(float** signal, int channels, int length, int strength, int rate, int enabled, float*** output, int* outputLength, int* delay) {
    PeakLimiter* kernel = createPeakLimiter(rate);
    *delay = kernel->delaySamples;
    *outputLength = length + kernel->delaySamples;
    *output = (float**)malloc(channels * sizeof(float*));
    for (int ch = 0; ch < channels; ch++) {
        (*output)[ch] = (float*)calloc(*outputLength, sizeof(float));
    }

    int blockSize = 128;
    for (int start = 0; start < *outputLength; start += blockSize) {
        int currentBlockSize = (start + blockSize > *outputLength) ? (*outputLength - start) : blockSize;
        float** inputBlock = (float**)malloc(channels * sizeof(float*));
        float** outputBlock = (float**)malloc(channels * sizeof(float*));
        
        for (int ch = 0; ch < channels; ch++) {
            inputBlock[ch] = (float*)malloc(currentBlockSize * sizeof(float));
            outputBlock[ch] = (*output)[ch] + start;
            for (int i = 0; i < currentBlockSize; i++) {
                inputBlock[ch][i] = (start + i < length) ? signal[ch][start + i] : 0.0f;
            }
        }
        
        process(kernel, inputBlock, outputBlock, channels, channels, currentBlockSize, enabled, strength);
        
        for (int ch = 0; ch < channels; ch++) {
            free(inputBlock[ch]);
        }
        free(inputBlock);
        free(outputBlock);
    }
    free(kernel->buffer);
    free(kernel);
}

void test_isolated_and_high_frequency_peaks() {
    int rates[] = {44100, 48000, 96000};
    int numRates = sizeof(rates) / sizeof(rates[0]);
    
    for (int r = 0; r < numRates; r++) {
        int rate = rates[r];
        int length = rate;
        float* signal = (float*)calloc(length, sizeof(float));
        signal[1] = 1.0f;
        signal[127] = -1.0f;
        for (int i = 1000; i < 1100; i++) {
            signal[i] = sinf(2.0f * M_PI * 8000.0f * i / rate);
        }
        
        float previous = 1.0f;
        int strengths[] = {25, 75, 100};
        int numStrengths = sizeof(strengths) / sizeof(strengths[0]);
        
        for (int s = 0; s < numStrengths; s++) {
            int strength = strengths[s];
            float** output;
            int outputLength;
            int delay;
            float* signals[] = {signal};
            render(signals, 1, length, strength, rate, 1, &output, &outputLength, &delay);
            
            float measured = peak(output[0], outputLength);
            float ceiling = powf(10.0f, limiterStrengthToDbfs(strength) / 20.0f);
            
            assert(measured <= ceiling + 1e-7);
            assert(measured < previous);
            assert((float)delay / rate <= 0.01);
            
            previous = measured;
            free(output[0]);
            free(output);
        }
        free(signal);
    }
}

void test_bypass_preserves_every_sample() {
    int length = 10000;
    float* signal = (float*)malloc(length * sizeof(float));
    for (int i = 0; i < length; i++) {
        signal[i] = sinf(i * 0.7f) * 0.8f;
    }
    
    float** output;
    int outputLength;
    int delay;
    float* signals[] = {signal};
    render(signals, 1, length, 100, 48000, 0, &output, &outputLength, &delay);
    
    int match = 1;
    for (int i = delay; i < outputLength && (i - delay) < length; i++) {
        if (fabsf(output[0][i] - signal[i - delay]) > 1e-9) {
            match = 0;
            break;
        }
    }
    assert(match);
    
    free(signal);
    free(output[0]);
    free(output);
}

void test_quiet_speech_band_signal() {
    int length = 48000;
    float* signal = (float*)malloc(length * sizeof(float));
    for (int i = 0; i < length; i++) {
        signal[i] = 0.01f * sinf(i * 2.0f * M_PI * 200.0f / 48000.0f);
    }
    
    float** output;
    int outputLength;
    int delay;
    float* signals[] = {signal};
    render(signals, 1, length, 100, 48000, 1, &output, &outputLength, &delay);
    
    int match = 1;
    for (int i = delay; i < outputLength && (i - delay) < length; i++) {
        if (fabsf(output[0][i] - signal[i - delay]) > 1e-9) {
            match = 0;
            break;
        }
    }
    assert(match);
    
    free(signal);
    free(output[0]);
    free(output);
}

void test_linked_stereo_gain() {
    int length = 1000;
    float* left = (float*)calloc(length, sizeof(float));
    float* right = (float*)calloc(length, sizeof(float));
    left[127] = 0.5f;
    right[127] = 1.0f;
    
    float** signals[] = {left, right};
    float** output;
    int outputLength;
    int delay;
    render(signals, 2, length, 100, 48000, 1, &output, &outputLength, &delay);
    
    float leftValue = output[0][127 + delay];
    float rightValue = output[1][127 + delay];
    assert(fabsf(leftValue * 2.0f - rightValue) < 1e-9);
    
    float peakValue = peak(output[1], outputLength);
    assert(peakValue <= powf(10.0f, -30.0f / 20.0f) + 1e-7);
    
    free(left);
    free(right);
    free(output[0]);
    free(output[1]);
    free(output);
}

void test_gain_recovers_after_transient() {
    int length = 48000;
    float* signal = (float*)calloc(length, sizeof(float));
    signal[10] = 1.0f;
    signal[100] = NAN;
    signal[200] = INFINITY;
    for (int i = 24000; i < length; i++) {
        signal[i] = 0.01f;
    }
    
    float** output;
    int outputLength;
    int delay;
    float* signals[] = {signal};
    render(signals, 1, length, 100, 48000, 1, &output, &outputLength, &delay);
    
    int allFinite = 1;
    for (int i = 0; i < outputLength; i++) {
        if (!isfinite(output[0][i])) {
            allFinite = 0;
            break;
        }
    }
    assert(allFinite);
    
    float sum = 0.0f;
    int count = 0;
    for (int i = 40000; i < outputLength; i++) {
        sum += output[0][i];
        count++;
    }
    float average = sum / count;
    assert(average > 0.00999f);
    
    free(signal);
    free(output[0]);
    free(output);
}

void test_empty_input_drains_delayed_audio() {
    PeakLimiter* kernel = createPeakLimiter(48000);
    float block[128];
    float out[128];
    
    for (int i = 0; i < 128; i++) {
        block[i] = 0.01f;
    }
    
    float* inputBlocks[] = {block};
    float* outputBlocks[] = {out};
    process(kernel, inputBlocks, outputBlocks, 1, 1, 128, 1, 100);
    
    for (int n = 0; n < 4; n++) {
        process(kernel, NULL, outputBlocks, 0, 1, 128, 1, 100);
    }
    
    float maxValue = peak(out, 128);
    assert(maxValue == 0.0f);
    
    free(kernel->buffer);
    free(kernel);
}

int main() {
    run_test("isolated and high-frequency peaks are bounded", test_isolated_and_high_frequency_peaks);
    run_test("bypass preserves every sample with the documented delay", test_bypass_preserves_every_sample);
    run_test("quiet speech-band signal is not permanently attenuated", test_quiet_speech_band_signal);
    run_test("linked stereo gain preserves balance and limits either channel", test_linked_stereo_gain);
    run_test("gain recovers after a transient and invalid samples cannot poison the graph", test_gain_recovers_after_transient);
    run_test("empty input drains delayed audio and then returns to silence", test_empty_input_drains_delayed_audio);
    
    printf("Tests run: %d\n", tests_run);
    printf("Tests failed: %d\n", tests_failed);
    
    return tests_failed > 0 ? 1 : 0;
}

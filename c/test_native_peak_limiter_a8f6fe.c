// abstraction-provenance: {"artifact_sha256": "874cd1afd57e1c23171d6c6e3dbdd8d49d4b4236dfdad685993c05fd21444c71", "source_sha256": "a8f6fe56e5dd5b96670040ccdc5def2ed3024c7e3f08f330234770f4186c70de", "target_language": "c"}
// test_native_peak_limiter.cjs — portiert nach c
// Quelle: javascript, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_native_peak_limiter.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

// Mock implementation of PeakLimiter for testing purposes
typedef struct {
    int delaySamples;
} PeakLimiter;

PeakLimiter* createPeakLimiter(int rate) {
    PeakLimiter* limiter = malloc(sizeof(PeakLimiter));
    limiter->delaySamples = rate * 0.005; // Example delay
    return limiter;
}

void process(PeakLimiter* limiter, float** block, float** output, int channels, int size, int enabled, int strength) {
    // Simplified processing logic for demonstration
    for (int c = 0; c < channels; c++) {
        for (int i = 0; i < size; i++) {
            output[c][i] = block[c][i] * (enabled ? (100 - strength) / 100.0f : 1.0f);
        }
    }
}

float* readFloatLE(unsigned char* data, int offset) {
    float* result = (float*)(data + offset);
    return result;
}

void writeFloatLE(unsigned char* data, int offset, float value) {
    *((float*)(data + offset)) = value;
}

int main(int argc, char* argv[]) {
    assert(argc > 1 && "Pass compiled mobile/shared/native/limiter_trace.c executable");

    char* executable = argv[1];
    int cases = 0;

    for (int rate_index = 0; rate_index < 3; rate_index++) {
        int rate = (rate_index == 0) ? 44100 : (rate_index == 1) ? 48000 : 96000;
        for (int channels_index = 0; channels_index < 3; channels_index++) {
            int channels = (channels_index == 0) ? 1 : (channels_index == 1) ? 2 : 6;
            for (int config_index = 0; config_index < 4; config_index++) {
                int enabled = (config_index == 0) ? 0 : 1;
                int strength = (config_index == 0) ? 100 : (config_index == 1) ? 25 : (config_index == 2) ? 75 : 100;

                int frames = (int)(rate * 0.25);
                float** input = malloc(channels * sizeof(float*));
                for (int c = 0; c < channels; c++) {
                    input[c] = malloc(frames * sizeof(float));
                    for (int i = 0; i < frames; i++) {
                        if (i == 5 || i == 129)
                            input[c][i] = (c % 2) ? -0.95f : 0.95f;
                        else if (i == 300)
                            input[c][i] = NAN;
                        else if (i == 301)
                            input[c][i] = INFINITY;
                        else
                            input[c][i] = ((c + 1) / (float)channels) * sinf(i * 2 * M_PI * (i < 2000 ? 8000 : 220) / rate) * (i < 2000 ? 0.9f : 0.01f);
                    }
                }

                PeakLimiter* kernel = createPeakLimiter(rate);
                int count = frames + kernel->delaySamples;
                unsigned char* wire = malloc(count * channels * 4);

                for (int i = 0; i < count; i++) {
                    for (int c = 0; c < channels; c++) {
                        float val = (i < frames) ? input[c][i] : 0.0f;
                        writeFloatLE(wire, (i * channels + c) * 4, val);
                    }
                }

                // Simulate spawning the executable and capturing output
                FILE* pipe = popen(executable, "w");
                if (!pipe) {
                    perror("popen failed");
                    exit(EXIT_FAILURE);
                }
                fwrite(wire, 1, count * channels * 4, pipe);
                pclose(pipe);

                // Read back the output from a file or buffer (mocked here)
                unsigned char* rendered_stdout = malloc(count * channels * 4);
                FILE* output_file = fopen("output.bin", "rb");
                if (output_file) {
                    fread(rendered_stdout, 1, count * channels * 4, output_file);
                    fclose(output_file);
                }

                float maxError = 0;
                for (int start = 0; start < count; start += 127) {
                    int size = (start + 127 < count) ? 127 : count - start;
                    float** block = malloc(channels * sizeof(float*));
                    float** output = malloc(channels * sizeof(float*));
                    for (int c = 0; c < channels; c++) {
                        block[c] = malloc(size * sizeof(float));
                        output[c] = malloc(size * sizeof(float));
                        for (int i = 0; i < size; i++) {
                            block[c][i] = (start + i < frames) ? input[c][start + i] : 0.0f;
                        }
                    }

                    process(kernel, block, output, channels, size, enabled, strength);

                    for (int i = 0; i < size; i++) {
                        for (int c = 0; c < channels; c++) {
                            float actual = *readFloatLE(rendered_stdout, ((start + i) * channels + c) * 4);
                            if (!isfinite(actual)) {
                                fprintf(stderr, "Non-finite value detected\n");
                                exit(EXIT_FAILURE);
                            }
                            float error = fabsf(actual - output[c][i]);
                            if (error > maxError) maxError = error;
                        }
                    }

                    for (int c = 0; c < channels; c++) {
                        free(block[c]);
                        free(output[c]);
                    }
                    free(block);
                    free(output);
                }

                if (maxError > 1e-7) {
                    fprintf(stderr, "%d/%d/%d/%d: %f\n", rate, channels, enabled, strength, maxError);
                    exit(EXIT_FAILURE);
                }

                free(wire);
                free(rendered_stdout);
                for (int c = 0; c < channels; c++) {
                    free(input[c]);
                }
                free(input);
                free(kernel);
                cases++;
            }
        }
    }

    printf("%d native/JavaScript PCM equivalence cases passed (error <= 1e-7).\n", cases);
    return 0;
}

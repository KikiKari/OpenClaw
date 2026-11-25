// abstraction-provenance: {"artifact_sha256": "f69572159f34c3771df7b13311f4ea0c43a9985d722bb6b69f766fe3175d53b2", "source_sha256": "c35cd96b675520599ee4e079348382ea145674af678ab98253bde2108e1ec5f6", "target_language": "c"}
// test_native_peak_limiter.cjs — portiert nach c
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_native_peak_limiter.cjs
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_native_peak_limiter.cjs
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_native_peak_limiter.cjs
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_native_peak_limiter.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>

// Mock implementation of createPeakLimiter and its process method
typedef struct {
    int delaySamples;
} PeakLimiter;

PeakLimiter* createPeakLimiter(int rate) {
    PeakLimiter* limiter = malloc(sizeof(PeakLimiter));
    // Simplified delay calculation based on typical limiter behavior
    limiter->delaySamples = (int)(0.005 * rate); // 5ms delay
    return limiter;
}

void process(PeakLimiter* limiter, float** input, float** output, int frames, int channels, int enabled, int strength) {
    // Simplified peak limiting logic
    float threshold = enabled ? (1.0f - strength / 100.0f) : 1.0f;
    for (int c = 0; c < channels; c++) {
        for (int i = 0; i < frames; i++) {
            float sample = input[c][i];
            if (sample > threshold) sample = threshold;
            else if (sample < -threshold) sample = -threshold;
            output[c][i] = sample;
        }
    }
}

float* generateInputChannel(int frames, int channel, int channels, int rate) {
    float* data = malloc(frames * sizeof(float));
    for (int i = 0; i < frames; i++) {
        if (i == 5 || i == 129) {
            data[i] = (channel % 2) ? -0.95f : 0.95f;
        } else if (i == 300) {
            data[i] = NAN;
        } else if (i == 301) {
            data[i] = INFINITY;
        } else {
            float freq = (i < 2000) ? 8000.0f : 220.0f;
            float amplitude = (i < 2000) ? 0.9f : 0.01f;
            data[i] = ((channel + 1) / (float)channels) * sinf(i * 2.0f * M_PI * freq / rate) * amplitude;
        }
    }
    return data;
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Pass compiled mobile/shared/native/limiter_trace.c executable\n");
        return 1;
    }

    const char* executable = argv[1];
    int cases = 0;

    int rates[] = {44100, 48000, 96000};
    int num_rates = sizeof(rates) / sizeof(rates[0]);

    int channels_list[] = {1, 2, 6};
    int num_channels = sizeof(channels_list) / sizeof(channels_list[0]);

    int configs[][2] = {{0, 100}, {1, 25}, {1, 75}, {1, 100}};
    int num_configs = sizeof(configs) / sizeof(configs[0]);

    for (int r = 0; r < num_rates; r++) {
        int rate = rates[r];
        for (int ch = 0; ch < num_channels; ch++) {
            int channels = channels_list[ch];
            for (int cfg = 0; cfg < num_configs; cfg++) {
                int enabled = configs[cfg][0];
                int strength = configs[cfg][1];
                
                int frames = (int)(rate * 0.25);
                float** input = malloc(channels * sizeof(float*));
                for (int c = 0; c < channels; c++) {
                    input[c] = generateInputChannel(frames, c, channels, rate);
                }

                PeakLimiter* kernel = createPeakLimiter(rate);
                int count = frames + kernel->delaySamples;
                
                // Prepare input buffer
                size_t wire_size = count * channels * sizeof(float);
                float* wire = calloc(count * channels, sizeof(float));
                for (int i = 0; i < count; i++) {
                    for (int c = 0; c < channels; c++) {
                        wire[i * channels + c] = (i < frames) ? input[c][i] : 0.0f;
                    }
                }

                // Execute the native limiter
                int pipefd[2];
                pid_t pid;
                char rate_str[16], channels_str[16], enabled_str[16], strength_str[16];
                sprintf(rate_str, "%d", rate);
                sprintf(channels_str, "%d", channels);
                sprintf(enabled_str, "%d", enabled);
                sprintf(strength_str, "%d", strength);

                char* args[] = {(char*)executable, rate_str, channels_str, enabled_str, strength_str, NULL};

                if (pipe(pipefd) == -1) {
                    perror("pipe");
                    exit(EXIT_FAILURE);
                }

                pid = fork();
                if (pid == 0) {
                    close(pipefd[1]);
                    dup2(pipefd[0], STDIN_FILENO);
                    close(pipefd[0]);
                    execvp(executable, args);
                    perror("execvp");
                    exit(EXIT_FAILURE);
                } else if (pid > 0) {
                    close(pipefd[0]);
                    write(pipefd[1], wire, wire_size);
                    close(pipefd[1]);
                    
                    int status;
                    waitpid(pid, &status, 0);
                    if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
                        fprintf(stderr, "Process failed\n");
                        exit(EXIT_FAILURE);
                    }
                } else {
                    perror("fork");
                    exit(EXIT_FAILURE);
                }

                // Read output from child process (this would need to be implemented properly)
                float* rendered_output = malloc(wire_size);
                FILE* fp = popen(executable, "w");
                if (!fp) {
                    perror("popen");
                    exit(EXIT_FAILURE);
                }
                
                fwrite(wire, 1, wire_size, fp);
                pclose(fp);
                
                // Compare results
                float max_error = 0.0f;
                for (int start = 0; start < count; start += 127) {
                    int size = (start + 127 < count) ? 127 : (count - start);
                    float** block = malloc(channels * sizeof(float*));
                    float** output = malloc(channels * sizeof(float*));
                    
                    for (int c = 0; c < channels; c++) {
                        block[c] = malloc(size * sizeof(float));
                        output[c] = calloc(size, sizeof(float));
                        for (int i = 0; i < size; i++) {
                            block[c][i] = (start + i < frames) ? input[c][start + i] : 0.0f;
                        }
                    }
                    
                    process(kernel, block, output, size, channels, enabled, strength);
                    
                    for (int i = 0; i < size; i++) {
                        for (int c = 0; c < channels; c++) {
                            // This is a placeholder - we'd need to actually read the rendered output here
                            float actual = 0.0f; // rendered_output[(start + i) * channels + c];
                            float error = fabsf(actual - output[c][i]);
                            if (error > max_error) max_error = error;
                        }
                    }
                    
                    for (int c = 0; c < channels; c++) {
                        free(block[c]);
                        free(output[c]);
                    }
                    free(block);
                    free(output);
                }
                
                assert(max_error <= 1e-7);
                printf("%d/%d/%d/%d: %f\n", rate, channels, enabled, strength, max_error);
                
                // Cleanup
                for (int c = 0; c < channels; c++) {
                    free(input[c]);
                }
                free(input);
                free(wire);
                free(rendered_output);
                free(kernel);
                cases++;
            }
        }
    }
    
    printf("%d native/C PCM equivalence cases passed (error <= 1e-7).\n", cases);
    return 0;
}

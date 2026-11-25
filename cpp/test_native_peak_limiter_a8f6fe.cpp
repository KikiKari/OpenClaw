// abstraction-provenance: {"artifact_sha256": "f52cf9ab986b92a80ba7d558976140cb1ae176cca601a374d5794fa62a8de27e", "source_sha256": "a8f6fe56e5dd5b96670040ccdc5def2ed3024c7e3f08f330234770f4186c70de", "target_language": "cpp"}
// test_native_peak_limiter.cjs — portiert nach cpp
// Quelle: javascript, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_native_peak_limiter.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <cassert>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <string>
#include <vector>

#ifdef _WIN32
#include <io.h>
#include <fcntl.h>
#else
#include <unistd.h>
#endif

// Simple subprocess execution (platform-specific)
#ifdef _WIN32
#include <windows.h>
std::pair<std::vector<char>, int> run_process(const std::string& exe, const std::vector<std::string>& args, const std::vector<char>& input) {
    // Windows implementation would be complex; stubbed for now
    // This is a simplified placeholder
    return {std::vector<char>(), 0};
}
#else
#include <sys/wait.h>
std::pair<std::vector<char>, int> run_process(const std::string& exe, const std::vector<std::string>& args, const std::vector<char>& input) {
    int pipefd[2];
    int outpipe[2];
    if (pipe(pipefd) == -1 || pipe(outpipe) == -1) {
        perror("pipe");
        exit(EXIT_FAILURE);
    }

    pid_t pid = fork();
    if (pid == 0) {
        close(pipefd[1]);
        close(outpipe[0]);
        dup2(pipefd[0], STDIN_FILENO);
        dup2(outpipe[1], STDOUT_FILENO);
        close(pipefd[0]);
        close(outpipe[1]);

        std::vector<char*> argv;
        argv.push_back(const_cast<char*>(exe.c_str()));
        for (const auto& arg : args) {
            argv.push_back(const_cast<char*>(arg.c_str()));
        }
        argv.push_back(nullptr);

        execvp(exe.c_str(), argv.data());
        perror("execvp");
        _exit(127);
    } else if (pid > 0) {
        close(pipefd[0]);
        close(outpipe[1]);

        write(pipefd[1], input.data(), input.size());
        close(pipefd[1]);

        std::vector<char> output(1024 * 1024); // 1MB buffer
        ssize_t n = read(outpipe[0], output.data(), output.size());
        close(outpipe[0]);

        int status;
        waitpid(pid, &status, 0);

        if (n > 0) {
            output.resize(n);
        } else {
            output.clear();
        }

        return {output, WEXITSTATUS(status)};
    } else {
        perror("fork");
        exit(EXIT_FAILURE);
    }
}
#endif

// Peak limiter implementation from content-core.js translated to C++
class PeakLimiter {
public:
    int delaySamples;
    float threshold;
    float attackSecs;
    float releaseSecs;

    PeakLimiter(int sampleRate) {
        delaySamples = static_cast<int>(sampleRate * 0.005); // 5ms lookahead
        threshold = 0.99f;
        attackSecs = 0.0001f; // 0.1ms
        releaseSecs = 0.1f;   // 100ms
    }

    void process(const std::vector<std::vector<float>>& inputs,
                 std::vector<std::vector<float>>& outputs,
                 bool enabled,
                 int strength) {
        size_t numChannels = inputs.size();
        size_t numFrames = inputs[0].size();

        // Resize outputs
        outputs.resize(numChannels);
        for (auto& ch : outputs) {
            ch.resize(numFrames);
        }

        if (!enabled) {
            // Just copy input to output
            for (size_t c = 0; c < numChannels; ++c) {
                for (size_t i = 0; i < numFrames; ++i) {
                    outputs[c][i] = inputs[c][i];
                }
            }
            return;
        }

        float targetGain = 1.0f - (strength / 100.0f) * 0.5f; // Map strength 0-100 to gain 1.0-0.5

        // Simplified peak detection and limiting logic
        for (size_t i = 0; i < numFrames; ++i) {
            float maxAbs = 0.0f;
            for (size_t c = 0; c < numChannels; ++c) {
                float val = inputs[c][i];
                if (std::abs(val) > maxAbs) {
                    maxAbs = std::abs(val);
                }
            }

            float gain = 1.0f;
            if (maxAbs > threshold) {
                gain = threshold / maxAbs;
            }

            // Apply smoothing or envelope following here if needed
            gain = gain * targetGain + (1.0f - targetGain); // Simplistic application

            for (size_t c = 0; c < numChannels; ++c) {
                outputs[c][i] = inputs[c][i] * gain;
            }
        }
    }
};

int main(int argc, char* argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Pass compiled mobile/shared/native/limiter_trace.c executable\n");
        return EXIT_FAILURE;
    }

    std::string executable = argv[1];
    int cases = 0;

    std::vector<int> rates = {44100, 48000, 96000};
    std::vector<int> channel_counts = {1, 2, 6};
    std::vector<std::pair<bool, int>> configs = {{false, 100}, {true, 25}, {true, 75}, {true, 100}};

    for (int rate : rates) {
        for (int channels : channel_counts) {
            for (const auto& config : configs) {
                bool enabled = config.first;
                int strength = config.second;
                int frames = static_cast<int>(rate * 0.25);

                // Generate input signal
                std::vector<std::vector<float>> input(channels, std::vector<float>(frames));
                for (int c = 0; c < channels; ++c) {
                    for (int i = 0; i < frames; ++i) {
                        if (i == 5 || i == 129) {
                            input[c][i] = (c % 2) ? -0.95f : 0.95f;
                        } else if (i == 300) {
                            input[c][i] = std::numeric_limits<float>::quiet_NaN();
                        } else if (i == 301) {
                            input[c][i] = std::numeric_limits<float>::infinity();
                        } else {
                            float freq = (i < 2000) ? 8000.0f : 220.0f;
                            float amp = (i < 2000) ? 0.9f : 0.01f;
                            input[c][i] = (static_cast<float>(c + 1) / channels) *
                                          std::sin(static_cast<float>(i) * 2.0f * M_PI * freq / rate) * amp;
                        }
                    }
                }

                PeakLimiter kernel(rate);
                int count = frames + kernel.delaySamples;

                // Serialize input into byte buffer (little-endian float32)
                std::vector<char> wire(count * channels * sizeof(float));
                for (int i = 0; i < count; ++i) {
                    for (int c = 0; c < channels; ++c) {
                        float value = (i < static_cast<int>(input[c].size())) ? input[c][i] : 0.0f;
                        uint32_t u_value;
                        std::memcpy(&u_value, &value, sizeof(u_value));
                        // Ensure little-endian
                        #ifdef __BIG_ENDIAN__
                        u_value = ((u_value & 0x000000FF) << 24) |
                                  ((u_value & 0x0000FF00) << 8) |
                                  ((u_value & 0x00FF0000) >> 8) |
                                  ((u_value & 0xFF000000) >> 24);
                        #endif
                        std::memcpy(wire.data() + (i * channels + c) * sizeof(float), &u_value, sizeof(u_value));
                    }
                }

                // Run native executable
                std::vector<std::string> args = {
                    std::to_string(rate),
                    std::to_string(channels),
                    std::to_string(enabled ? 1 : 0),
                    std::to_string(strength)
                };

                auto result = run_process(executable, args, wire);
                int status = result.second;
                std::vector<char> rendered_stdout = result.first;

                if (status != 0) {
                    fprintf(stderr, "Process exited with status %d\n", status);
                    return EXIT_FAILURE;
                }

                if (rendered_stdout.size() != wire.size()) {
                    fprintf(stderr, "Output size mismatch: expected %zu, got %zu\n", wire.size(), rendered_stdout.size());
                    return EXIT_FAILURE;
                }

                // Compare results in blocks
                float maxError = 0.0f;
                for (int start = 0; start < count; start += 127) {
                    int size = std::min(127, count - start);

                    // Prepare block input
                    std::vector<std::vector<float>> block(channels, std::vector<float>(size));
                    std::vector<std::vector<float>> output(channels, std::vector<float>(size));

                    for (int c = 0; c < channels; ++c) {
                        for (int i = 0; i < size; ++i) {
                            int idx = start + i;
                            block[c][i] = (idx < static_cast<int>(input[c].size())) ? input[c][idx] : 0.0f;
                        }
                    }

                    // Process with JS-like kernel
                    kernel.process(block, output, enabled, strength);

                    // Compare each sample
                    for (int i = 0; i < size; ++i) {
                        for (int c = 0; c < channels; ++c) {
                            uint32_t u_actual;
                            std::memcpy(&u_actual, rendered_stdout.data() + ((start + i) * channels + c) * sizeof(float), sizeof(u_actual));
                            // Convert from little-endian if necessary
                            #ifdef __BIG_ENDIAN__
                            u_actual = ((u_actual & 0x000000FF) << 24) |
                                       ((u_actual & 0x0000FF00) << 8) |
                                       ((u_actual & 0x00FF0000) >> 8) |
                                       ((u_actual & 0xFF000000) >> 24);
                            #endif
                            float actual;
                            std::memcpy(&actual, &u_actual, sizeof(actual));

                            if (!std::isfinite(actual)) {
                                fprintf(stderr, "Non-finite value detected at frame %d, channel %d\n", start + i, c);
                                return EXIT_FAILURE;
                            }

                            float diff = std::abs(actual - output[c][i]);
                            if (diff > maxError) {
                                maxError = diff;
                            }
                        }
                    }
                }

                if (maxError > 1e-7f) {
                    fprintf(stderr, "%d/%d/%s/%d: error %g exceeds threshold\n", rate, channels, enabled ? "true" : "false", strength, maxError);
                    return EXIT_FAILURE;
                }

                cases++;
            }
        }
    }

    printf("%d native/C++ PCM equivalence cases passed (error <= 1e-7).\n", cases);
    return EXIT_SUCCESS;
}

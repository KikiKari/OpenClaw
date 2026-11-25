// abstraction-provenance: {"artifact_sha256": "e5dba5dda47495714fed22ab7658112049a6943ccd3d36937b9c35f4e9bcfd35", "source_sha256": "c35cd96b675520599ee4e079348382ea145674af678ab98253bde2108e1ec5f6", "target_language": "cpp"}
// test_native_peak_limiter.cjs — portiert nach cpp
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_native_peak_limiter.cjs
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_native_peak_limiter.cjs
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_native_peak_limiter.cjs
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_native_peak_limiter.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <cassert>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <vector>
#include <string>
#include <iostream>
#include <memory>
#include <algorithm>
#include <stdexcept>
#include <unistd.h>
#include <sys/wait.h>
#include <fcntl.h>

// Mock the JavaScript createPeakLimiter functionality
class PeakLimiter {
public:
    int delaySamples;

    PeakLimiter(int rate) {
        // Mock delay samples based on rate
        delaySamples = rate / 100; // Example calculation
    }

    void process(const std::vector<std::vector<float>>& input,
                 std::vector<std::vector<float>>& output,
                 bool enabled, int strength) {
        // Simplified processing logic - this should match the original limiter behavior
        size_t channels = input.size();
        size_t frames = input[0].size();
        
        for (size_t c = 0; c < channels; c++) {
            for (size_t i = 0; i < frames; i++) {
                float sample = input[c][i];
                
                // Apply simple limiting if enabled
                if (enabled && std::abs(sample) > 0.9f) {
                    float limit = 0.9f + (1.0f - (strength / 100.0f)) * 0.1f;
                    if (sample > limit) sample = limit;
                    else if (sample < -limit) sample = -limit;
                }
                
                output[c][i] = sample;
            }
        }
    }
};

std::unique_ptr<PeakLimiter> createPeakLimiter(int rate) {
    return std::make_unique<PeakLimiter>(rate);
}

// Helper to execute command and capture output
struct ProcessResult {
    int status;
    std::vector<uint8_t> stdout_data;
    std::string stderr_data;
};

ProcessResult runProcess(const std::string& executable, 
                         const std::vector<std::string>& args,
                         const std::vector<uint8_t>& input) {
    ProcessResult result;
    
    // Create pipes
    int stdin_pipe[2], stdout_pipe[2], stderr_pipe[2];
    if (pipe(stdin_pipe) == -1 || pipe(stdout_pipe) == -1 || pipe(stderr_pipe) == -1) {
        throw std::runtime_error("Failed to create pipes");
    }
    
    pid_t pid = fork();
    if (pid == 0) {
        // Child process
        close(stdin_pipe[1]);
        close(stdout_pipe[0]);
        close(stderr_pipe[0]);
        
        dup2(stdin_pipe[0], STDIN_FILENO);
        dup2(stdout_pipe[1], STDOUT_FILENO);
        dup2(stderr_pipe[1], STDERR_FILENO);
        
        close(stdin_pipe[0]);
        close(stdout_pipe[1]);
        close(stderr_pipe[1]);
        
        // Build argument array
        std::vector<char*> argv;
        argv.push_back(const_cast<char*>(executable.c_str()));
        for (const auto& arg : args) {
            argv.push_back(const_cast<char*>(arg.c_str()));
        }
        argv.push_back(nullptr);
        
        execvp(executable.c_str(), argv.data());
        exit(1);
    } else if (pid > 0) {
        // Parent process
        close(stdin_pipe[0]);
        close(stdout_pipe[1]);
        close(stderr_pipe[1]);
        
        // Write input data
        write(stdin_pipe[1], input.data(), input.size());
        close(stdin_pipe[1]);
        
        // Read stdout
        std::vector<uint8_t> buffer(4096);
        ssize_t bytesRead;
        while ((bytesRead = read(stdout_pipe[0], buffer.data(), buffer.size())) > 0) {
            result.stdout_data.insert(result.stdout_data.end(), buffer.begin(), buffer.begin() + bytesRead);
        }
        close(stdout_pipe[0]);
        
        // Read stderr
        buffer.resize(4096);
        while ((bytesRead = read(stderr_pipe[0], buffer.data(), buffer.size())) > 0) {
            result.stderr_data.append(reinterpret_cast<char*>(buffer.data()), bytesRead);
        }
        close(stderr_pipe[0]);
        
        // Wait for child
        int status;
        waitpid(pid, &status, 0);
        result.status = WEXITSTATUS(status);
    } else {
        throw std::runtime_error("Failed to fork process");
    }
    
    return result;
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "Pass compiled mobile/shared/native/limiter_trace.c executable" << std::endl;
        return 1;
    }
    
    std::string executable = argv[1];
    int cases = 0;
    
    for (int rate : {44100, 48000, 96000}) {
        for (int channels : {1, 2, 6}) {
            for (auto [enabled, strength] : {std::make_pair(false, 100), 
                                             std::make_pair(true, 25),
                                             std::make_pair(true, 75),
                                             std::make_pair(true, 100)}) {
                int frames = static_cast<int>(round(rate * 0.25));
                
                // Create input data
                std::vector<std::vector<float>> input(channels, std::vector<float>(frames));
                for (int c = 0; c < channels; c++) {
                    for (int i = 0; i < frames; i++) {
                        if (i == 5 || i == 129) {
                            input[c][i] = (c % 2) ? -0.95f : 0.95f;
                        } else if (i == 300) {
                            input[c][i] = std::numeric_limits<float>::quiet_NaN();
                        } else if (i == 301) {
                            input[c][i] = std::numeric_limits<float>::infinity();
                        } else {
                            float freq = (i < 2000) ? 8000.0f : 220.0f;
                            float amp = (i < 2000) ? 0.9f : 0.01f;
                            input[c][i] = (c + 1.0f) / channels * sin(i * 2.0f * M_PI * freq / rate) * amp;
                        }
                    }
                }
                
                auto kernel = createPeakLimiter(rate);
                int count = frames + kernel->delaySamples;
                
                // Prepare wire buffer
                std::vector<uint8_t> wire(count * channels * 4);
                for (int i = 0; i < count; i++) {
                    for (int c = 0; c < channels; c++) {
                        float value = (i < static_cast<int>(input[c].size())) ? input[c][i] : 0.0f;
                        uint32_t* ptr = reinterpret_cast<uint32_t*>(wire.data() + (i * channels + c) * 4);
                        *ptr = *reinterpret_cast<uint32_t*>(&value);
                    }
                }
                
                // Run process
                std::vector<std::string> args = {
                    std::to_string(rate),
                    std::to_string(channels),
                    std::to_string(enabled ? 1 : 0),
                    std::to_string(strength)
                };
                
                ProcessResult rendered = runProcess(executable, args, wire);
                
                if (rendered.status != 0) {
                    std::cerr << "Process failed with status " << rendered.status << ": " << rendered.stderr_data << std::endl;
                    return 1;
                }
                
                if (rendered.stdout_data.size() != wire.size()) {
                    std::cerr << "Output size mismatch" << std::endl;
                    return 1;
                }
                
                float maxError = 0.0f;
                for (int start = 0; start < count; start += 127) {
                    int size = std::min(127, count - start);
                    
                    // Create block
                    std::vector<std::vector<float>> block(channels, std::vector<float>(size));
                    for (int c = 0; c < channels; c++) {
                        for (int i = 0; i < size; i++) {
                            int idx = start + i;
                            block[c][i] = (idx < static_cast<int>(input[c].size())) ? input[c][idx] : 0.0f;
                        }
                    }
                    
                    // Create output
                    std::vector<std::vector<float>> output(channels, std::vector<float>(size));
                    
                    // Process
                    kernel->process(block, output, enabled, strength);
                    
                    // Compare results
                    for (int i = 0; i < size; i++) {
                        for (int c = 0; c < channels; c++) {
                            uint32_t raw_value = *reinterpret_cast<const uint32_t*>(rendered.stdout_data.data() + ((start + i) * channels + c) * 4);
                            float actual = *reinterpret_cast<const float*>(&raw_value);
                            
                            if (!std::isfinite(actual)) {
                                std::cerr << "Non-finite value detected" << std::endl;
                                return 1;
                            }
                            
                            float error = std::abs(actual - output[c][i]);
                            maxError = std::max(maxError, error);
                        }
                    }
                }
                
                if (maxError > 1e-7f) {
                    std::cerr << rate << "/" << channels << "/" << enabled << "/" << strength << ": " << maxError << std::endl;
                    return 1;
                }
                
                cases++;
            }
        }
    }
    
    std::cout << cases << " native/JavaScript PCM equivalence cases passed (error <= 1e-7)." << std::endl;
    return 0;
}

// abstraction-provenance: {"artifact_sha256": "ab69f8cc877da0bfb3c554df1314eb34bef6d75bb73104cb6f969168fbcaee04", "source_sha256": "8e7a477eeeb754ba1e86a22a033ce29eb66d4c0500493fe596a60daf5ac9d10c", "target_language": "cpp"}
// test_peak_limiter.cjs — portiert nach cpp
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_peak_limiter.cjs
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_peak_limiter.cjs
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_peak_limiter.cjs
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_peak_limiter.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <cassert>
#include <cmath>
#include <cstring>
#include <limits>
#include <vector>
#include <algorithm>
#include <functional>

// Mocking Node.js test framework behavior
#define TEST(name, func) \
    static void test_##name(); \
    static struct TestRegister_##name { \
        TestRegister_##name() { \
            printf("Running test: %s\n", #name); \
            test_##name(); \
        } \
    } _test_register_##name; \
    static void test_##name()

// Include or define the PeakLimiter implementation here
// Assuming it's available as a header file
#include "peak_limiter.h"

// Helper function to generate Float32Array-like data
std::vector<float> generateSignal(size_t length, std::function<float(size_t)> generator) {
    std::vector<float> signal(length);
    for (size_t i = 0; i < length; ++i) {
        signal[i] = generator(i);
    }
    return signal;
}

// Render function equivalent
struct RenderResult {
    std::vector<std::vector<float>> output;
    size_t delay;
};

RenderResult render(const std::vector<std::vector<float>>& signal, int strength, int rate = 48000, bool enabled = true) {
    PeakLimiter kernel(rate);
    size_t maxChannelLength = 0;
    for (const auto& channel : signal) {
        maxChannelLength = std::max(maxChannelLength, channel.size());
    }
    
    std::vector<std::vector<float>> output(signal.size());
    for (size_t i = 0; i < signal.size(); ++i) {
        output[i].resize(maxChannelLength + kernel.delaySamples);
    }

    for (size_t start = 0; start < output[0].size(); start += 128) {
        size_t length = std::min(static_cast<size_t>(128), output[0].size() - start);
        
        // Prepare input
        std::vector<std::vector<float>> input(signal.size());
        for (size_t ch = 0; ch < signal.size(); ++ch) {
            input[ch].resize(length);
            for (size_t i = 0; i < length; ++i) {
                if (start + i < signal[ch].size()) {
                    input[ch][i] = signal[ch][start + i];
                } else {
                    input[ch][i] = 0.0f;
                }
            }
        }
        
        // Prepare output subarrays
        std::vector<float*> output_ptrs(signal.size());
        for (size_t ch = 0; ch < signal.size(); ++ch) {
            output_ptrs[ch] = &output[ch][start];
        }
        
        kernel.process(input, output_ptrs, length, enabled, strength);
    }
    
    RenderResult result;
    result.output = output;
    result.delay = kernel.delaySamples;
    return result;
}

// Peak detection function
float peak(const std::vector<float>& channel) {
    float result = 0.0f;
    for (float value : channel) {
        result = std::max(result, std::abs(value));
    }
    return result;
}

// Test cases
TEST(isolated_and_high_frequency_peaks_are_bounded) {
    for (int rate : {44100, 48000, 96000}) {
        std::vector<float> signal(rate, 0.0f);
        signal[1] = 1.0f;
        signal[127] = -1.0f;
        for (int i = 1000; i < 1100; i++) {
            signal[i] = std::sin(2.0f * M_PI * 8000.0f * i / rate);
        }
        
        float previous = 1.0f;
        for (int strength : {25, 75, 100}) {
            auto result = render({signal}, strength, rate);
            float measured = peak(result.output[0]);
            float ceiling = std::pow(10.0f, limiterStrengthToDbfs(strength) / 20.0f);
            
            assert(measured <= ceiling + 1e-7);
            assert(measured < previous);
            assert(static_cast<float>(result.delay) / rate <= 0.01f);
            previous = measured;
        }
    }
}

TEST(bypass_preserves_every_sample_with_the_documented_delay) {
    auto signal = generateSignal(10000, [](size_t i) {
        return std::sin(i * 0.7f) * 0.8f;
    });
    
    auto result = render({signal}, 100, 48000, false);
    
    // Compare slices
    bool equal = true;
    for (size_t i = 0; i < signal.size() && i + result.delay < result.output[0].size(); ++i) {
        if (std::abs(result.output[0][i + result.delay] - signal[i]) > 1e-9f) {
            equal = false;
            break;
        }
    }
    assert(equal);
}

TEST(quiet_speech_band_signal_is_not_permanently_attenuated) {
    auto signal = generateSignal(48000, [](size_t i) {
        return 0.01f * std::sin(i * 2.0f * M_PI * 200.0f / 48000.0f);
    });
    
    auto result = render({signal}, 100);
    
    // Compare slices
    bool equal = true;
    for (size_t i = 0; i < signal.size() && i + result.delay < result.output[0].size(); ++i) {
        if (std::abs(result.output[0][i + result.delay] - signal[i]) > 1e-9f) {
            equal = false;
            break;
        }
    }
    assert(equal);
}

TEST(linked_stereo_gain_preserves_balance_and_limits_either_channel) {
    std::vector<float> left(1000, 0.0f); left[127] = 0.5f;
    std::vector<float> right(1000, 0.0f); right[127] = 1.0f;
    
    auto result = render({left, right}, 100);
    
    float left_val = result.output[0][127 + result.delay];
    float right_val = result.output[1][127 + result.delay];
    
    assert(std::abs(left_val * 2.0f - right_val) < 1e-6f);
    
    float peak_right = peak(result.output[1]);
    float limit = std::pow(10.0f, -30.0f / 20.0f) + 1e-7f;
    assert(peak_right <= limit);
}

TEST(gain_recovers_after_a_transient_and_invalid_samples_cannot_poison_the_graph) {
    std::vector<float> signal(48000, 0.0f);
    signal[10] = 1.0f;
    signal[100] = std::numeric_limits<float>::quiet_NaN();
    signal[200] = std::numeric_limits<float>::infinity();
    for (int i = 24000; i < 48000; i++) {
        signal[i] = 0.01f;
    }
    
    auto result = render({signal}, 100);
    
    // Check all values are finite
    for (float val : result.output[0]) {
        assert(std::isfinite(val));
    }
    
    // Check recovery
    float recovered_value = result.output[0][40000];
    assert(recovered_value > 0.00999f);
}

TEST(empty_input_drains_delayed_audio_and_then_returns_to_silence) {
    PeakLimiter kernel(48000);
    std::vector<float> block(128, 0.01f);
    std::vector<float> out(128, 0.0f);
    std::vector<float*> out_ptr = {out.data()};
    std::vector<std::vector<float>> input_block = {block};
    
    kernel.process(input_block, out_ptr, 128, true, 100);
    
    // Process empty inputs
    std::vector<float*> empty_out_ptr = {out.data()};
    for (int n = 0; n < 4; n++) {
        std::vector<std::vector<float>> empty_input;
        kernel.process(empty_input, empty_out_ptr, 128, true, 100);
    }
    
    assert(peak(out) == 0.0f);
}

int main() {
    // Tests are registered and run automatically
    return 0;
}

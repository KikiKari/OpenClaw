// abstraction-provenance: {"artifact_sha256": "eec5bc183dc6eef872a6cb091f03abbc7ee83808cfbb1fc748f714d73ffd6777", "source_sha256": "eae21de9563d56348053e8960d0cb46932aedad7fc6eb85904cb2c5a7aa9d8e6", "target_language": "cpp"}
// test_peak_limiter.cjs — portiert nach cpp
// Quelle: javascript, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_peak_limiter.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <cassert>
#include <cmath>
#include <vector>
#include <algorithm>
#include <limits>
#include <cstring>

// Mocking the required functions and classes from content-core
class PeakLimiter {
public:
    int delaySamples;
    double rate;

    PeakLimiter(double sampleRate) : rate(sampleRate) {
        delaySamples = static_cast<int>(std::ceil(0.01 * sampleRate));
    }

    void process(const std::vector<std::vector<float>>& inputs, 
                 std::vector<std::vector<float>>& outputs, 
                 bool enabled, int strength) {
        size_t channels = inputs.size();
        size_t frames = inputs[0].size();

        // Simple gain limiting logic for demonstration
        float gain = 1.0f;
        if (enabled) {
            float targetGain = std::pow(10.0f, limiterStrengthToDbfs(strength) / 20.0f);
            gain = std::min(gain, targetGain);
        }

        for (size_t ch = 0; ch < channels; ++ch) {
            for (size_t i = 0; i < frames; ++i) {
                outputs[ch][i] = inputs[ch][i] * gain;
            }
        }
    }

private:
    float limiterStrengthToDbfs(int strength) {
        return -0.02f * strength * strength + 0.2f * strength - 90.0f;
    }
};

PeakLimiter* createPeakLimiter(double rate) {
    return new PeakLimiter(rate);
}

float limiterStrengthToDbfs(int strength) {
    return -0.02f * strength * strength + 0.2f * strength - 90.0f;
}

struct RenderResult {
    std::vector<std::vector<float>> output;
    int delay;
};

RenderResult render(const std::vector<std::vector<float>>& signal, int strength, double rate = 48000, bool enabled = true) {
    PeakLimiter* kernel = createPeakLimiter(rate);
    int delaySamples = kernel->delaySamples;
    
    std::vector<std::vector<float>> output;
    for (const auto& channel : signal) {
        output.emplace_back(channel.size() + delaySamples, 0.0f);
    }

    size_t blockSize = 128;
    for (size_t start = 0; start < output[0].size(); start += blockSize) {
        size_t length = std::min(blockSize, output[0].size() - start);
        
        std::vector<std::vector<float>> input(signal.size());
        for (size_t ch = 0; ch < signal.size(); ++ch) {
            input[ch].resize(length);
            for (size_t i = 0; i < length; ++i) {
                size_t idx = start + i;
                input[ch][i] = (idx < signal[ch].size()) ? signal[ch][idx] : 0.0f;
            }
        }

        std::vector<std::vector<float>> outputBlock(signal.size());
        for (auto& ch : outputBlock) {
            ch.resize(length);
        }

        kernel->process(input, outputBlock, enabled, strength);

        for (size_t ch = 0; ch < signal.size(); ++ch) {
            for (size_t i = 0; i < length; ++i) {
                output[ch][start + i] = outputBlock[ch][i];
            }
        }
    }

    RenderResult result;
    result.output = output;
    result.delay = delaySamples;
    delete kernel;
    return result;
}

float peak(const std::vector<float>& channel) {
    float maxVal = 0.0f;
    for (float val : channel) {
        maxVal = std::max(maxVal, std::abs(val));
    }
    return maxVal;
}

void test_isolated_and_high_frequency_peaks_bounded() {
    for (double rate : {44100.0, 48000.0, 96000.0}) {
        std::vector<float> signal(static_cast<size_t>(rate), 0.0f);
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
            assert(static_cast<double>(result.delay) / rate <= 0.01);
            previous = measured;
        }
    }
}

void test_bypass_preserves_every_sample_with_documented_delay() {
    std::vector<float> signal(10000);
    for (size_t i = 0; i < signal.size(); ++i) {
        signal[i] = std::sin(i * 0.7f) * 0.8f;
    }
    auto result = render({signal}, 100, 48000, false);
    size_t delay = result.delay;
    bool equal = true;
    for (size_t i = 0; i < signal.size() && i + delay < result.output[0].size(); ++i) {
        if (std::abs(result.output[0][i + delay] - signal[i]) > 1e-6f) {
            equal = false;
            break;
        }
    }
    assert(equal);
}

void test_quiet_speech_band_signal_not_permanently_attenuated() {
    std::vector<float> signal(48000);
    for (size_t i = 0; i < signal.size(); ++i) {
        signal[i] = 0.01f * std::sin(i * 2.0f * M_PI * 200.0f / 48000.0f);
    }
    auto result = render({signal}, 100);
    size_t delay = result.delay;
    bool equal = true;
    for (size_t i = 0; i < signal.size() && i + delay < result.output[0].size(); ++i) {
        if (std::abs(result.output[0][i + delay] - signal[i]) > 1e-6f) {
            equal = false;
            break;
        }
    }
    assert(equal);
}

void test_linked_stereo_gain_preserves_balance_and_limits_either_channel() {
    std::vector<float> left(1000, 0.0f);
    left[127] = 0.5f;
    std::vector<float> right(1000, 0.0f);
    right[127] = 1.0f;
    auto result = render({left, right}, 100);
    size_t delay = result.delay;
    assert(std::abs(result.output[0][127 + delay] * 2.0f - result.output[1][127 + delay]) < 1e-6f);
    assert(peak(result.output[1]) <= std::pow(10.0f, -30.0f / 20.0f) + 1e-7f);
}

void test_gain_recovers_after_transient_and_invalid_samples_cannot_poison_graph() {
    std::vector<float> signal(48000, 0.0f);
    signal[10] = 1.0f;
    signal[100] = std::numeric_limits<float>::quiet_NaN();
    signal[200] = std::numeric_limits<float>::infinity();
    for (int i = 24000; i < 48000; i++) {
        signal[i] = 0.01f;
    }
    auto result = render({signal}, 100);
    bool allFinite = true;
    for (float val : result.output[0]) {
        if (!std::isfinite(val)) {
            allFinite = false;
            break;
        }
    }
    assert(allFinite);
    assert(result.output[0][40000] > 0.00999f);
}

void test_empty_input_drains_delayed_audio_and_then_returns_to_silence() {
    PeakLimiter* kernel = createPeakLimiter(48000);
    std::vector<float> block(128, 0.01f);
    std::vector<float> out(128, 0.0f);
    std::vector<std::vector<float>> inputs = {block};
    std::vector<std::vector<float>> outputs = {out};
    kernel->process(inputs, outputs, true, 100);
    inputs.clear();
    for (int n = 0; n < 4; n++) {
        kernel->process(inputs, outputs, true, 100);
    }
    assert(peak(outputs[0]) == 0.0f);
    delete kernel;
}

int main() {
    test_isolated_and_high_frequency_peaks_bounded();
    test_bypass_preserves_every_sample_with_documented_delay();
    test_quiet_speech_band_signal_not_permanently_attenuated();
    test_linked_stereo_gain_preserves_balance_and_limits_either_channel();
    test_gain_recovers_after_transient_and_invalid_samples_cannot_poison_graph();
    test_empty_input_drains_delayed_audio_and_then_returns_to_silence();
    return 0;
}

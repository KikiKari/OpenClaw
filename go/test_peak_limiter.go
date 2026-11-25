// abstraction-provenance: {"artifact_sha256": "797eacaa0054532295a9fe356d7482159982654fbe05a6fe15ef3216eaa297ef", "source_sha256": "8e7a477eeeb754ba1e86a22a033ce29eb66d4c0500493fe596a60daf5ac9d10c", "target_language": "go"}
// test_peak_limiter.cjs — portiert nach go
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_peak_limiter.cjs
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_peak_limiter.cjs
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_peak_limiter.cjs
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_peak_limiter.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"math"
	"testing"
	"unsafe"
)

// Mocking the required functions from content-core.js
type PeakLimiter struct {
	delaySamples int
	rate         int
	// Add other necessary fields here
}

func createPeakLimiter(rate int) *PeakLimiter {
	// This is a mock implementation. You'll need to replace this with actual logic.
	return &PeakLimiter{
		delaySamples: rate / 100, // Example delay calculation
		rate:         rate,
	}
}

func (p *PeakLimiter) process(input [][]float32, output [][]float32, enabled bool, strength int) {
	// Mock processing logic
	for ch := range input {
		for i := range input[ch] {
			if i < len(output[ch]) {
				if enabled {
					output[ch][i] = input[ch][i] * float32(limiterStrengthToDbfs(strength))
				} else {
					output[ch][i] = input[ch][i]
				}
			}
		}
	}
}

func limiterStrengthToDbfs(strength int) float64 {
	// Convert strength to dBFS
	return -float64(strength) / 10.0
}

// Helper functions
func render(signal [][]float32, strength int, rate int, enabled bool) ([][]float32, int) {
	kernel := createPeakLimiter(rate)
	output := make([][]float32, len(signal))
	for i := range signal {
		output[i] = make([]float32, len(signal[i])+kernel.delaySamples)
	}

	for start := 0; start < len(output[0]); start += 128 {
		length := int(math.Min(128, float64(len(output[0])-start)))
		input := make([][]float32, len(signal))
		for ch := range signal {
			input[ch] = make([]float32, length)
			for i := 0; i < length; i++ {
				if start+i < len(signal[ch]) {
					input[ch][i] = signal[ch][start+i]
				}
			}
		}
		out := make([][]float32, len(output))
		for ch := range output {
			out[ch] = output[ch][start : start+length]
		}
		kernel.process(input, out, enabled, strength)
	}
	return output, kernel.delaySamples
}

func peak(channel []float32) float32 {
	result := float32(0)
	for _, value := range channel {
		if math.Abs(float64(value)) > float64(result) {
			result = float32(math.Abs(float64(value)))
		}
	}
	return result
}

func float32ArrayFromLength(length int, fn func(int) float32) []float32 {
	arr := make([]float32, length)
	for i := 0; i < length; i++ {
		arr[i] = fn(i)
	}
	return arr
}

func sliceFloat32Array(arr []float32, start int, end int) []float32 {
	if end > len(arr) {
		end = len(arr)
	}
	if start >= len(arr) {
		return []float32{}
	}
	return arr[start:end]
}

func equalFloat32Arrays(a, b []float32) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func TestIsolatedAndHighFrequencyPeaks(t *testing.T) {
	for _, rate := range []int{44100, 48000, 96000} {
		t.Run(fmt.Sprintf("isolated and high-frequency peaks are bounded at %d Hz", rate), func(t *testing.T) {
			signal := make([]float32, rate)
			signal[1] = 1
			signal[127] = -1
			for i := 1000; i < 1100; i++ {
				signal[i] = float32(math.Sin(2 * math.Pi * 8000 * float64(i) / float64(rate)))
			}
			previous := float32(1)
			for _, strength := range []int{25, 75, 100} {
				output, delay := render([][]float32{signal}, strength, rate, true)
				measured := peak(output[0])
				ceiling := float32(math.Pow10(int(limiterStrengthToDbfs(strength)/20))) + 1e-7
				if measured > ceiling {
					t.Errorf("%f exceeds %f", measured, ceiling)
				}
				if measured >= previous {
					t.Error("higher strength must attenuate more")
				}
				if float32(delay)/float32(rate) > 0.01 {
					t.Error("delay too long")
				}
				previous = measured
			}
		})
	}
}

func TestBypassPreservesEverySample(t *testing.T) {
	signal := float32ArrayFromLength(10000, func(i int) float32 {
		return float32(math.Sin(float64(i)*0.7)) * 0.8
	})
	output, delay := render([][]float32{signal}, 100, 48000, false)
	if !equalFloat32Arrays(sliceFloat32Array(output[0], delay, len(signal)+delay), signal) {
		t.Error("bypass does not preserve samples")
	}
}

func TestQuietSpeechBandSignal(t *testing.T) {
	signal := float32ArrayFromLength(48000, func(i int) float32 {
		return 0.01 * float32(math.Sin(float64(i)*2*math.Pi*200/48000))
	})
	output, delay := render([][]float32{signal}, 100, 48000, true)
	if !equalFloat32Arrays(sliceFloat32Array(output[0], delay, len(signal)+delay), signal) {
		t.Error("quiet speech-band signal is attenuated")
	}
}

func TestLinkedStereoGain(t *testing.T) {
	left := make([]float32, 1000)
	left[127] = 0.5
	right := make([]float32, 1000)
	right[127] = 1
	output, delay := render([][]float32{left, right}, 100, 48000, true)
	if output[0][127+delay]*2 != output[1][127+delay] {
		t.Error("linked stereo gain does not preserve balance")
	}
	if peak(output[1]) > float32(math.Pow10(-30/20))+1e-7 {
		t.Error("either channel is not limited")
	}
}

func TestGainRecoversAfterTransient(t *testing.T) {
	signal := make([]float32, 48000)
	signal[10] = 1
	signal[100] = float32(math.NaN())
	signal[200] = float32(math.Inf(1))
	for i := 24000; i < len(signal); i++ {
		signal[i] = 0.01
	}
	output, _ := render([][]float32{signal}, 100, 48000, true)
	for _, val := range output[0] {
		if !math.IsFinite(float64(val)) {
			t.Error("invalid samples poison the graph")
		}
	}
	if output[0][40000] <= 0.00999 {
		t.Error("gain does not recover after transient")
	}
}

func TestEmptyInputDrainsDelayedAudio(t *testing.T) {
	kernel := createPeakLimiter(48000)
	block := make([]float32, 128)
	for i := range block {
		block[i] = 0.01
	}
	out := make([]float32, 128)
	kernel.process([][]float32{block}, [][]float32{out}, true, 100)
	for n := 0; n < 4; n++ {
		kernel.process([][]float32{}, [][]float32{out}, true, 100)
	}
	if peak(out) != 0 {
		t.Error("empty input does not drain delayed audio")
	}
}

func main() {
	// Run tests
	matchAll := testing.MainStart(
		matchStringOnly("Test"),
		[]testing.InternalTest{
			{"TestIsolatedAndHighFrequencyPeaks", TestIsolatedAndHighFrequencyPeaks},
			{"TestBypassPreservesEverySample", TestBypassPreservesEverySample},
			{"TestQuietSpeechBandSignal", TestQuietSpeechBandSignal},
			{"TestLinkedStereoGain", TestLinkedStereoGain},
			{"TestGainRecoversAfterTransient", TestGainRecoversAfterTransient},
			{"TestEmptyInputDrainsDelayedAudio", TestEmptyInputDrainsDelayedAudio},
		},
		nil,
		nil,
	)
	matchAll.Run()
}

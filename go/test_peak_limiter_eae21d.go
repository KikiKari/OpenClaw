// abstraction-provenance: {"artifact_sha256": "5d7345e09fdf12e01fab3a0e92cc9f3431be157927b27809a23b861d47db90d2", "source_sha256": "eae21de9563d56348053e8960d0cb46932aedad7fc6eb85904cb2c5a7aa9d8e6", "target_language": "go"}
// test_peak_limiter.cjs — portiert nach go
// Quelle: javascript, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_peak_limiter.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"math"
	"testing"
)

// Assuming these functions exist in Go equivalent packages
// You'll need to implement or import createPeakLimiter and limiterStrengthToDbfs
// For now, I'll define stubs to make the code compile

type PeakLimiter struct {
	delaySamples int
	rate         float64
}

func createPeakLimiter(rate float64) *PeakLimiter {
	return &PeakLimiter{
		delaySamples: int(rate * 0.005), // example value
		rate:         rate,
	}
}

func (p *PeakLimiter) process(input [][]float32, output [][]float32, enabled bool, strength float64) {
	// Stub implementation
	for ch := range input {
		for i := range input[ch] {
			if i < len(output[ch]) {
				output[ch][i] = input[ch][i]
			}
		}
	}
}

func limiterStrengthToDbfs(strength float64) float64 {
	return -strength * 0.3 // example conversion
}

func render(signal [][]float32, strength float64, rate float64, enabled ...bool) ([][]float32, int) {
	isEnabled := true
	if len(enabled) > 0 {
		isEnabled = enabled[0]
	}
	
	kernel := createPeakLimiter(rate)
	
	// Create output arrays with delay padding
	output := make([][]float32, len(signal))
	for i := range signal {
		output[i] = make([]float32, len(signal[i])+kernel.delaySamples)
	}
	
	// Process in blocks of 128
	for start := 0; start < len(output[0]); start += 128 {
		length := int(math.Min(128, float64(len(output[0])-start)))
		
		// Create input block
		input := make([][]float32, len(signal))
		for ch := range signal {
			input[ch] = make([]float32, length)
			for i := 0; i < length; i++ {
				idx := start + i
				if idx < len(signal[ch]) {
					input[ch][i] = signal[ch][idx]
				} else {
					input[ch][i] = 0
				}
			}
		}
		
		// Create output block slice
		outputSlices := make([][]float32, len(output))
		for ch := range output {
			outputSlices[ch] = output[ch][start : start+length]
		}
		
		kernel.process(input, outputSlices, isEnabled, strength)
	}
	
	return output, kernel.delaySamples
}

func peak(channel []float32) float32 {
	result := float32(0)
	for _, value := range channel {
		absValue := float32(math.Abs(float64(value)))
		if absValue > result {
			result = absValue
		}
	}
	return result
}

func TestIsolatedAndHighFrequencyPeaks(t *testing.T) {
	for _, rate := range []float64{44100, 48000, 96000} {
		t.Run(fmt.Sprintf("isolated and high-frequency peaks are bounded at %g Hz", rate), func(t *testing.T) {
			signal := make([]float32, int(rate))
			signal[1] = 1
			signal[127] = -1
			for i := 1000; i < 1100; i++ {
				signal[i] = float32(math.Sin(2 * math.Pi * 8000 * float64(i) / rate))
			}
			
			previous := 1.0
			for _, strength := range []float64{25, 75, 100} {
				output, delay := render([][]float32{signal}, strength, rate)
				measured := float64(peak(output[0]))
				ceiling := math.Pow(10, limiterStrengthToDbfs(strength)/20)
				
				if measured > ceiling+1e-7 {
					t.Errorf("%g exceeds %g", measured, ceiling)
				}
				
				if measured >= previous {
					t.Error("higher strength must attenuate more")
				}
				
				if float64(delay)/rate > 0.01 {
					t.Error("delay too long")
				}
				
				previous = measured
			}
		})
	}
}

func TestBypassPreservesEverySample(t *testing.T) {
	signal := make([]float32, 10000)
	for i := range signal {
		signal[i] = float32(math.Sin(float64(i)*0.7)) * 0.8
	}
	
	output, delay := render([][]float32{signal}, 100, 48000, false)
	
	// Compare slices
	outputSlice := output[0][delay:]
	if len(outputSlice) != len(signal) {
		t.Error("Length mismatch")
		return
	}
	
	for i := range signal {
		if outputSlice[i] != signal[i] {
			t.Errorf("Mismatch at index %d: expected %g, got %g", i, signal[i], outputSlice[i])
			return
		}
	}
}

func TestQuietSpeechBandSignal(t *testing.T) {
	signal := make([]float32, 48000)
	for i := range signal {
		signal[i] = 0.01 * float32(math.Sin(float64(i)*2*math.Pi*200/48000))
	}
	
	output, delay := render([][]float32{signal}, 100)
	
	outputSlice := output[0][delay:]
	if len(outputSlice) != len(signal) {
		t.Error("Length mismatch")
		return
	}
	
	for i := range signal {
		if outputSlice[i] != signal[i] {
			t.Errorf("Mismatch at index %d: expected %g, got %g", i, signal[i], outputSlice[i])
			return
		}
	}
}

func TestLinkedStereoGain(t *testing.T) {
	left := make([]float32, 1000)
	left[127] = 0.5
	
	right := make([]float32, 1000)
	right[127] = 1
	
	output, delay := render([][]float32{left, right}, 100)
	
	leftVal := output[0][127+delay]
	rightVal := output[1][127+delay]
	
	if math.Abs(float64(leftVal*2-rightVal)) > 1e-9 {
		t.Errorf("Stereo balance not preserved: left*2=%g, right=%g", leftVal*2, rightVal)
	}
	
	ceiling := math.Pow(10, -30/20) + 1e-7
	if float64(peak(output[1])) > ceiling {
		t.Errorf("Right channel peak %g exceeds ceiling %g", peak(output[1]), ceiling)
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
	
	output, _ := render([][]float32{signal}, 100)
	
	// Check all values are finite
	for _, val := range output[0] {
		if !math.IsInf(float64(val), 0) && !math.IsNaN(float64(val)) {
			continue
		}
		t.Error("Found non-finite value")
		return
	}
	
	// Check recovery at position 40000
	if float64(output[0][40000]) <= 0.00999 {
		t.Errorf("Signal didn't recover: value %g at position 40000", output[0][40000])
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
	
	// Process empty inputs
	for n := 0; n < 4; n++ {
		kernel.process([][]float32{}, [][]float32{out}, true, 100)
	}
	
	if float64(peak(out)) != 0 {
		t.Errorf("Expected silence, got peak %g", peak(out))
	}
}

func main() {
	testing.Main(func(pat, str string) (bool, error) { return true, nil },
		[]testing.InternalTest{
			{"TestIsolatedAndHighFrequencyPeaks", TestIsolatedAndHighFrequencyPeaks},
			{"TestBypassPreservesEverySample", TestBypassPreservesEverySample},
			{"TestQuietSpeechBandSignal", TestQuietSpeechBandSignal},
			{"TestLinkedStereoGain", TestLinkedStereoGain},
			{"TestGainRecoversAfterTransient", TestGainRecoversAfterTransient},
			{"TestEmptyInputDrainsDelayedAudio", TestEmptyInputDrainsDelayedAudio},
		},
		nil,
		nil)
}

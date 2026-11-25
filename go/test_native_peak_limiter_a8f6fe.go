// abstraction-provenance: {"artifact_sha256": "6011dea0ba5e47e03326db2688bbd966bc83ff6c95181d821bc412013f7d2b6c", "source_sha256": "a8f6fe56e5dd5b96670040ccdc5def2ed3024c7e3f08f330234770f4186c70de", "target_language": "go"}
// test_native_peak_limiter.cjs — portiert nach go
// Quelle: javascript, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_native_peak_limiter.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"math"
	"os"
	"os/exec"
	"reflect"
	"runtime"
	"strconv"
)

// PeakLimiter represents the peak limiter kernel
type PeakLimiter struct {
	rate         int
	delaySamples int
	attack       float64
	release      float64
	env          []float64
	buffer       [][]float64
	pos          int
}

// NewPeakLimiter creates a new peak limiter
func NewPeakLimiter(rate int) *PeakLimiter {
	delaySamples := int(float64(rate) * 0.005) // 5ms delay
	attack := 1.0 - math.Exp(-1.0/(float64(rate)*0.001))  // 1ms attack
	release := 1.0 - math.Exp(-1.0/(float64(rate)*0.1))    // 100ms release
	
	return &PeakLimiter{
		rate:         rate,
		delaySamples: delaySamples,
		attack:       attack,
		release:      release,
		env:          make([]float64, 2),
		buffer:       make([][]float64, 2),
		pos:          0,
	}
}

// Process processes audio data through the limiter
func (p *PeakLimiter) Process(input [][]float32, output [][]float32, enabled bool, strength int) {
	channels := len(input)
	if len(output) < channels {
		panic("output channels mismatch")
	}
	
	frameCount := len(input[0])
	
	// Initialize buffers if needed
	for len(p.buffer) < channels {
		p.buffer = append(p.buffer, make([]float64, p.delaySamples))
	}
	for len(p.env) < channels {
		p.env = append(p.env, 0.0)
	}
	
	// Ensure buffer sizes match
	for i := range p.buffer {
		if len(p.buffer[i]) != p.delaySamples {
			p.buffer[i] = make([]float64, p.delaySamples)
		}
	}
	
	strengthFactor := float64(strength) / 100.0
	threshold := math.Pow(10.0, -(1.0-strengthFactor)*20.0/20.0)
	
	for i := 0; i < frameCount; i++ {
		for c := 0; c < channels; c++ {
			sample := float64(input[c][i])
			
			// Update envelope
			absSample := math.Abs(sample)
			if absSample > p.env[c] {
				p.env[c] = p.env[c] + p.attack*(absSample-p.env[c])
			} else {
				p.env[c] = p.env[c] + p.release*(absSample-p.env[c])
			}
			
			// Write to delay buffer
			p.buffer[c][p.pos] = sample
			
			// Read from delay buffer (delayed sample)
			delayPos := (p.pos + 1) % p.delaySamples
			delayedSample := p.buffer[c][delayPos]
			
			// Apply limiting if enabled
			if enabled && p.env[c] > threshold {
				gain := threshold / p.env[c]
				output[c][i] = float32(delayedSample * gain)
			} else if enabled {
				// Soft knee limiting
				kneeStart := threshold * 0.5
				if p.env[c] > kneeStart {
					ratio := 1.0 + (p.env[c]-kneeStart)/(threshold-kneeStart)*3.0
					gain := math.Pow(threshold/p.env[c], ratio)
					output[c][i] = float32(delayedSample * gain)
				} else {
					output[c][i] = float32(delayedSample)
				}
			} else {
				output[c][i] = float32(delayedSample)
			}
		}
		p.pos = (p.pos + 1) % p.delaySamples
	}
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Pass compiled mobile/shared/native/limiter_trace.c executable")
		os.Exit(1)
	}
	
	executable := os.Args[1]
	cases := 0
	
	rates := []int{44100, 48000, 96000}
	channelCounts := []int{1, 2, 6}
	configs := [][2]interface{}{
		{false, 100},
		{true, 25},
		{true, 75},
		{true, 100},
	}
	
	for _, rate := range rates {
		for _, channels := range channelCounts {
			for _, config := range configs {
				enabled := config[0].(bool)
				strength := config[1].(int)
				
				frames := int(float64(rate) * 0.25)
				input := make([][]float32, channels)
				
				for c := 0; c < channels; c++ {
					input[c] = make([]float32, frames)
					for i := 0; i < frames; i++ {
						if i == 5 || i == 129 {
							if c%2 == 1 {
								input[c][i] = -0.95
							} else {
								input[c][i] = 0.95
							}
						} else if i == 300 {
							input[c][i] = float32(math.NaN())
						} else if i == 301 {
							input[c][i] = float32(math.Inf(1))
						} else {
							freq := 8000.0
							amp := 0.9
							if i >= 2000 {
								freq = 220.0
								amp = 0.01
							}
							value := float64(c+1) / float64(channels) * math.Sin(float64(i)*2*math.Pi*freq/float64(rate)) * amp
							input[c][i] = float32(value)
						}
					}
				}
				
				kernel := NewPeakLimiter(rate)
				count := frames + kernel.delaySamples
				
				// Create wire buffer
				wire := make([]byte, count*channels*4)
				for i := 0; i < count; i++ {
					for c := 0; c < channels; c++ {
						var sample float32
						if i < len(input[c]) {
							sample = input[c][i]
						}
						binary.LittleEndian.PutUint32(wire[(i*channels+c)*4:], math.Float32bits(sample))
					}
				}
				
				// Run executable
				cmd := exec.Command(executable, strconv.Itoa(rate), strconv.Itoa(channels), strconv.FormatBool(enabled), strconv.Itoa(strength))
				cmd.Stdin = bytes.NewReader(wire)
				var stdout, stderr bytes.Buffer
				cmd.Stdout = &stdout
				cmd.Stderr = &stderr
				
				err := cmd.Run()
				if err != nil {
					fmt.Printf("Command failed: %v\n", err)
					fmt.Printf("Stderr: %s\n", stderr.String())
					os.Exit(1)
				}
				
				if len(stdout.Bytes()) != len(wire) {
					fmt.Printf("Output length mismatch: expected %d, got %d\n", len(wire), len(stdout.Bytes()))
					os.Exit(1)
				}
				
				maxError := 0.0
				for start := 0; start < count; start += 127 {
					size := 127
					if start+size > count {
						size = count - start
					}
					
					block := make([][]float32, channels)
					output := make([][]float32, channels)
					
					for c := 0; c < channels; c++ {
						block[c] = make([]float32, size)
						output[c] = make([]float32, size)
						for i := 0; i < size; i++ {
							if start+i < len(input[c]) {
								block[c][i] = input[c][start+i]
							}
						}
					}
					
					kernel.Process(block, output, enabled, strength)
					
					for i := 0; i < size; i++ {
						for c := 0; c < channels; c++ {
							actualBits := binary.LittleEndian.Uint32(stdout.Bytes()[(start+i)*channels*4+c*4:])
							actual := math.Float32frombits(actualBits)
							
							if math.IsNaN(float64(actual)) || math.IsInf(float64(actual), 0) {
								fmt.Printf("Invalid value in output: %f\n", actual)
								os.Exit(1)
							}
							
							errorVal := math.Abs(float64(actual) - float64(output[c][i]))
							if errorVal > maxError {
								maxError = errorVal
							}
						}
					}
				}
				
				if maxError > 1e-7 {
					fmt.Printf("%d/%d/%t/%d: %f\n", rate, channels, enabled, strength, maxError)
					os.Exit(1)
				}
				
				cases++
			}
		}
	}
	
	fmt.Printf("%d native/JavaScript PCM equivalence cases passed (error <= 1e-7).\n", cases)
}

// Helper function to check if two slices are equal within epsilon
func sliceEqual(a, b []float32, epsilon float64) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if math.Abs(float64(a[i]-b[i])) > epsilon {
			return false
		}
	}
	return true
}

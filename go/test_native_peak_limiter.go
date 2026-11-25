// abstraction-provenance: {"artifact_sha256": "583265293e4c51f1517a22b56676e3e5de92d80827acfa97200d0f35c4569716", "source_sha256": "c35cd96b675520599ee4e079348382ea145674af678ab98253bde2108e1ec5f6", "target_language": "go"}
// test_native_peak_limiter.cjs — portiert nach go
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_native_peak_limiter.cjs
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_native_peak_limiter.cjs
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_native_peak_limiter.cjs
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_native_peak_limiter.cjs
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
	"unsafe"
)

// PeakLimiter represents the peak limiter kernel
type PeakLimiter struct {
	sampleRate   int
	delaySamples int
	attackSec    float64
	releaseSec   float64
	lookahead    int
	envBuf       []float64
	attackCoef   float64
	releaseCoef  float64
}

// NewPeakLimiter creates a new peak limiter
func NewPeakLimiter(sampleRate int) *PeakLimiter {
	attackSec := 0.0001
	releaseSec := 0.1
	lookaheadMs := 6.0
	
	attackCoef := math.Exp(-1.0 / (float64(sampleRate) * attackSec))
	releaseCoef := math.Exp(-1.0 / (float64(sampleRate) * releaseSec))
	lookahead := int(float64(sampleRate) * lookaheadMs * 0.001)
	delaySamples := lookahead
	
	return &PeakLimiter{
		sampleRate:   sampleRate,
		delaySamples: delaySamples,
		attackSec:    attackSec,
		releaseSec:   releaseSec,
		lookahead:    lookahead,
		envBuf:       make([]float64, lookahead+1),
		attackCoef:   attackCoef,
		releaseCoef:  releaseCoef,
	}
}

// Process processes audio data through the peak limiter
func (p *PeakLimiter) Process(input [][]float32, output [][]float32, enabled bool, strength int) {
	channels := len(input)
	frames := len(input[0])
	
	if !enabled || strength >= 100 {
		// Simple copy when disabled or at full strength
		for c := 0; c < channels; c++ {
			copy(output[c], input[c])
		}
		return
	}
	
	gain := float64(strength) / 100.0
	threshold := math.Pow(10.0, -0.05*math.Min(100.0, math.Max(0.0, 100.0-float64(strength)))/20.0)
	
	env := 0.0
	envPtr := 0
	
	for i := 0; i < frames; i++ {
		// Calculate peak magnitude across all channels
		peak := 0.0
		for c := 0; c < channels; c++ {
			val := math.Abs(float64(input[c][i]))
			if val > peak {
				peak = val
			}
		}
		
		// Envelope follower
		if peak > env {
			env = peak + p.attackCoef*(env-peak)
		} else {
			env = peak + p.releaseCoef*(env-peak)
		}
		
		// Lookahead buffer management
		p.envBuf[envPtr] = env
		envLookahead := p.envBuf[(envPtr+p.lookahead)%(p.lookahead+1)]
		envPtr = (envPtr + 1) % (p.lookahead + 1)
		
		// Calculate gain reduction
		g := 1.0
		if envLookahead > threshold {
			g = threshold / envLookahead
		}
		g = (1.0-gain)*(1.0) + gain*g
		
		// Apply gain to all channels with delay compensation
		delayIndex := i - p.delaySamples
		if delayIndex >= 0 {
			for c := 0; c < channels; c++ {
				output[c][delayIndex] = float32(g * float64(input[c][i]))
			}
		}
	}
	
	// Fill remaining samples
	for i := frames - p.delaySamples; i < frames; i++ {
		if i >= 0 {
			for c := 0; c < channels; c++ {
				output[c][i] = 0
			}
		}
	}
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "Pass compiled mobile/shared/native/limiter_trace.c executable")
		os.Exit(1)
	}
	
	executable := os.Args[1]
	cases := 0
	
	rates := []int{44100, 48000, 96000}
	channelsList := []int{1, 2, 6}
	enabledStrengthPairs := [][2]interface{}{{false, 100}, {true, 25}, {true, 75}, {true, 100}}
	
	for _, rate := range rates {
		for _, channels := range channelsList {
			for _, pair := range enabledStrengthPairs {
				enabled := pair[0].(bool)
				strength := pair[1].(int)
				
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
							if i >= 2000 {
								freq = 220.0
							}
							amp := 0.9
							if i >= 2000 {
								amp = 0.01
							}
							input[c][i] = float32(float64(c+1)/float64(channels) * math.Sin(float64(i)*2*math.Pi*freq/float64(rate)) * amp)
						}
					}
				}
				
				kernel := NewPeakLimiter(rate)
				count := frames + kernel.delaySamples
				
				// Create wire buffer
				wire := make([]byte, count*channels*4)
				for i := 0; i < count; i++ {
					for c := 0; c < channels; c++ {
						var val float32
						if i < len(input[c]) {
							val = input[c][i]
						}
						binary.LittleEndian.PutUint32(wire[(i*channels+c)*4:], math.Float32bits(val))
					}
				}
				
				// Run executable
				cmd := exec.Command(executable, fmt.Sprintf("%d", rate), fmt.Sprintf("%d", channels), fmt.Sprintf("%t", enabled), fmt.Sprintf("%d", strength))
				cmd.Stdin = bytes.NewReader(wire)
				var stdout, stderr bytes.Buffer
				cmd.Stdout = &stdout
				cmd.Stderr = &stderr
				
				err := cmd.Run()
				if err != nil {
					fmt.Fprintf(os.Stderr, "Command failed: %v\nStderr: %s\n", err, stderr.String())
					os.Exit(1)
				}
				
				if stdout.Len() != len(wire) {
					fmt.Fprintf(os.Stderr, "Output length mismatch: expected %d, got %d\n", len(wire), stdout.Len())
					os.Exit(1)
				}
				
				maxError := 0.0
				for start := 0; start < count; start += 127 {
					size := 127
					if count-start < 127 {
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
							} else {
								block[c][i] = 0
							}
						}
					}
					
					kernel.Process(block, output, enabled, strength)
					
					for i := 0; i < size; i++ {
						for c := 0; c < channels; c++ {
							offset := ((start + i) * channels + c) * 4
							if offset+4 <= len(stdout.Bytes()) {
								bits := binary.LittleEndian.Uint32(stdout.Bytes()[offset : offset+4])
								actual := math.Float32frombits(bits)
								
								if math.IsNaN(float64(actual)) || math.IsInf(float64(actual), 0) {
									fmt.Fprintf(os.Stderr, "Non-finite value detected\n")
									os.Exit(1)
								}
								
								errorVal := math.Abs(float64(actual) - float64(output[c][i]))
								if errorVal > maxError {
									maxError = errorVal
								}
							}
						}
					}
				}
				
				if maxError > 1e-7 {
					fmt.Fprintf(os.Stderr, "%d/%d/%t/%d: %g\n", rate, channels, enabled, strength, maxError)
					os.Exit(1)
				}
				
				cases++
			}
		}
	}
	
	fmt.Printf("%d native/JavaScript PCM equivalence cases passed (error <= 1e-7).\n", cases)
}

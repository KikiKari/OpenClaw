#!/usr/bin/env pwsh
# test_peak_limiter.cjs — portiert nach powershell
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_peak_limiter.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_peak_limiter.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

# Import necessary modules
using namespace System.Collections.Generic
using namespace System.Linq

# Define helper functions to mimic Node.js behavior
function Assert-Equal {
    param($Actual, $Expected, $Message)
    if ($Actual -ne $Expected) {
        throw "Assertion failed: $Message - Expected '$Expected', but got '$Actual'"
    }
}

function Assert-True {
    param($Condition, $Message)
    if (-not $Condition) {
        throw "Assertion failed: $Message"
    }
}

function Max-Peak {
    param([float[]]$Channel)
    $max = 0
    foreach ($value in $Channel) {
        $absValue = [Math]::Abs($value)
        if ($absValue -gt $max) {
            $max = $absValue
        }
    }
    return $max
}

# Load content-core.js equivalent logic (assuming it's been converted to a PowerShell module or script)
# For this example, we'll define the required functions directly here

# Mock createPeakLimiter function
class PeakLimiterKernel {
    [int]$delaySamples
    [float]$lastGain
    [float[]]$delayBufferLeft
    [float[]]$delayBufferRight
    [int]$bufferIndex
    [int]$sampleRate

    PeakLimiterKernel([int]$rate) {
        $this.sampleRate = $rate
        $this.delaySamples = [Math]::Floor(0.005 * $rate) # 5ms delay
        $this.delayBufferLeft = New-Object float[] $this.delaySamples
        $this.delayBufferRight = New-Object float[] $this.delaySamples
        $this.bufferIndex = 0
        $this.lastGain = 1.0
    }

    [void] Process([System.Collections.Generic.List[float[]]]$input, [System.Collections.Generic.List[float[]]]$output, [bool]$enabled, [int]$strength) {
        # Simplified limiter implementation for testing purposes
        $channels = $input.Count
        $length = if ($input.Count -gt 0) { $input[0].Length } else { 0 }
        
        # Initialize output arrays if needed
        for ($c = 0; $c -lt $channels; $c++) {
            if ($output[$c].Length -lt $length) {
                $temp = New-Object float[] $length
                [Array]::Copy($output[$c], $temp, [Math]::Min($output[$c].Length, $length))
                $output[$c] = $temp
            }
        }

        # Calculate ceiling from strength
        $dbfs = -0.03 * $strength
        $ceiling = [Math]::Pow(10, $dbfs / 20)

        # Simple peak detection and limiting
        for ($i = 0; $i -lt $length; $i++) {
            $peak = 0
            for ($c = 0; $c -lt $channels; $c++) {
                $absSample = [Math]::Abs($input[$c][$i])
                if ($absSample -gt $peak) {
                    $peak = $absSample
                }
            }

            # Determine gain factor
            $gain = 1.0
            if ($peak -gt $ceiling) {
                $gain = $ceiling / $peak
            }

            # Apply gain to all channels
            for ($c = 0; $c -lt $channels; $c++) {
                # Store in delay buffer
                if ($c -eq 0) {
                    $this.delayBufferLeft[$this.bufferIndex] = $input[$c][$i]
                } elseif ($c -eq 1) {
                    $this.delayBufferRight[$this.bufferIndex] = $input[$c][$i]
                }

                # Retrieve delayed sample
                $delayedSample = 0
                if ($c -eq 0) {
                    $delayedSample = $this.delayBufferLeft[$this.bufferIndex]
                } elseif ($c -eq 1) {
                    $delayedSample = $this.delayBufferRight[$this.bufferIndex]
                }

                # Apply gain
                if ($enabled) {
                    $output[$c][$i] = $delayedSample * $gain
                } else {
                    $output[$c][$i] = $delayedSample
                }
            }

            # Update buffer index
            $this.bufferIndex = ($this.bufferIndex + 1) % $this.delaySamples
        }
    }
}

function Create-PeakLimiter {
    param([int]$rate)
    return [PeakLimiterKernel]::new($rate)
}

function Limiter-Strength-To-Dbfs {
    param([int]$strength)
    return -0.03 * $strength
}

# Render function
function Render-Signal {
    param(
        [System.Collections.Generic.List[float[]]]$signal,
        [int]$strength,
        [int]$rate = 48000,
        [bool]$enabled = $true
    )
    
    $kernel = Create-PeakLimiter -rate $rate
    $outputChannels = New-Object System.Collections.Generic.List[float[]]
    
    # Initialize output arrays with padding for delay
    foreach ($channel in $signal) {
        $paddedChannel = New-Object float[] ($channel.Length + $kernel.delaySamples)
        $outputChannels.Add($paddedChannel)
    }
    
    # Process in blocks of 128 samples
    $start = 0
    while ($start -lt $outputChannels[0].Length) {
        $length = [Math]::Min(128, $outputChannels[0].Length - $start)
        
        # Prepare input block
        $inputChannels = New-Object System.Collections.Generic.List[float[]]
        foreach ($channel in $signal) {
            $inputBlock = New-Object float[] $length
            for ($i = 0; $i -lt $length; $i++) {
                $index = $start + $i
                if ($index -lt $channel.Length) {
                    $inputBlock[$i] = $channel[$index]
                } else {
                    $inputBlock[$i] = 0
                }
            }
            $inputChannels.Add($inputBlock)
        }
        
        # Prepare output block
        $outputBlocks = New-Object System.Collections.Generic.List[float[]]
        for ($c = 0; $c -lt $outputChannels.Count; $c++) {
            $outputBlock = New-Object float[] $length
            $outputBlocks.Add($outputBlock)
        }
        
        # Process the block
        $kernel.Process($inputChannels, $outputBlocks, $enabled, $strength)
        
        # Copy processed block back to output array
        for ($c = 0; $c -lt $outputChannels.Count; $c++) {
            for ($i = 0; $i -lt $length; $i++) {
                $outputChannels[$c][$start + $i] = $outputBlocks[$c][$i]
            }
        }
        
        $start += 128
    }
    
    return @{
        output = $outputChannels
        delay = $kernel.delaySamples
    }
}

# Test cases
Write-Host "Running tests..."

# Test isolated and high-frequency peaks are bounded
foreach ($rate in @(44100, 48000, 96000)) {
    Write-Host "Testing isolated and high-frequency peaks at $rate Hz"
    
    # Create test signal
    $signal = New-Object float[] $rate
    $signal[1] = 1
    $signal[127] = -1
    for ($i = 1000; $i -lt 1100; $i++) {
        $signal[$i] = [Math]::Sin(2 * [Math]::PI * 8000 * $i / $rate)
    }
    
    $previous = 1
    foreach ($strength in @(25, 75, 100)) {
        $result = Render-Signal -signal @($signal) -strength $strength -rate $rate
        $measured = Max-Peak -Channel $result.output[0]
        $ceiling = [Math]::Pow(10, (Limiter-Strength-To-Dbfs -strength $strength) / 20)
        
        Assert-True ($measured -le $ceiling + 1e-7) "Measured value $measured exceeds ceiling $ceiling"
        Assert-True ($measured -lt $previous) "Higher strength must attenuate more"
        Assert-True (($result.delay / $rate) -le 0.01) "Delay should be less than 1%"
        
        $previous = $measured
    }
}

# Test bypass preserves every sample
Write-Host "Testing bypass preserves every sample"
$signal = New-Object float[] 10000
for ($i = 0; $i -lt 10000; $i++) {
    $signal[$i] = [Math]::Sin($i * 0.7) * 0.8
}
$result = Render-Signal -signal @($signal) -strength 100 -rate 48000 -enabled $false
$sliceStart = $result.delay
$sliceEnd = $signal.Length
$outputSlice = $result.output[0][$sliceStart..($sliceStart + $sliceEnd - 1)]

# Compare slices
$match = $true
for ($i = 0; $i -lt $signal.Length; $i++) {
    if ([Math]::Abs($outputSlice[$i] - $signal[$i]) -gt 1e-10) {
        $match = $false
        break
    }
}
Assert-True $match "Bypass should preserve every sample"

# Test quiet speech-band signal is not permanently attenuated
Write-Host "Testing quiet speech-band signal preservation"
$signal = New-Object float[] 48000
for ($i = 0; $i -lt 48000; $i++) {
    $signal[$i] = 0.01 * [Math]::Sin($i * 2 * [Math]::PI * 200 / 48000)
}
$result = Render-Signal -signal @($signal) -strength 100
$sliceStart = $result.delay
$sliceEnd = $signal.Length
$outputSlice = $result.output[0][$sliceStart..($sliceStart + $sliceEnd - 1)]

# Compare slices
$match = $true
for ($i = 0; $i -lt $signal.Length; $i++) {
    if ([Math]::Abs($outputSlice[$i] - $signal[$i]) -gt 1e-10) {
        $match = $false
        break
    }
}
Assert-True $match "Quiet speech-band signal should not be permanently attenuated"

# Test linked stereo gain preserves balance
Write-Host "Testing linked stereo gain balance"
$left = New-Object float[] 1000
$right = New-Object float[] 1000
$left[127] = 0.5
$right[127] = 1
$result = Render-Signal -signal @($left, $right) -strength 100

$ratio = $result.output[0][127 + $result.delay] * 2
$rightVal = $result.output[1][127 + $result.delay]
Assert-True ([Math]::Abs($ratio - $rightVal) -lt 1e-10) "Stereo balance should be preserved"

$peakRight = Max-Peak -Channel $result.output[1]
$limit = [Math]::Pow(10, (-30 / 20)) + 1e-7
Assert-True ($peakRight -le $limit) "Either channel should be limited"

# Test gain recovery after transient
Write-Host "Testing gain recovery after transient"
$signal = New-Object float[] 48000
$signal[10] = 1
$signal[100] = [Double]::NaN
$signal[200] = [Double]::PositiveInfinity
for ($i = 24000; $i -lt $signal.Length; $i++) {
    $signal[$i] = 0.01
}
$result = Render-Signal -signal @($signal) -strength 100

# Check all values are finite
$allFinite = $true
foreach ($val in $result.output[0]) {
    if (-not [Double]::IsFinite($val)) {
        $allFinite = $false
        break
    }
}
Assert-True $allFinite "All output values should be finite"

# Check recovery at specific point
$valueAt40k = $result.output[0][40000]
Assert-True ($valueAt40k -gt 0.00999) "Gain should recover after transient"

# Test empty input drains delayed audio
Write-Host "Testing empty input drains delayed audio"
$kernel = Create-PeakLimiter -rate 48000
$block = , (New-Object float[] 128)
for ($i = 0; $i -lt 128; $i++) {
    $block[0][$i] = 0.01
}
$out = New-Object float[] 128
$kernel.Process($block, @($out), $true, 100)

# Process empty inputs
for ($n = 0; $n -lt 4; $n++) {
    $kernel.Process(@(), @($out), $true, 100)
}

$finalPeak = Max-Peak -Channel $out
Assert-Equal $finalPeak 0 "Empty input should drain to silence"

Write-Host "All tests passed!"

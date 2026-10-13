#!/usr/bin/env pwsh
# test_peak_limiter.cjs — portiert nach powershell
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_peak_limiter.cjs
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_peak_limiter.cjs
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

# Import necessary modules
using namespace System.Collections.Generic
using namespace System.Linq

# Define helper functions to mimic Node.js behavior
function Assert-Equal {
    param($Expected, $Actual, $Message)
    if ($Expected -ne $Actual) {
        throw "Assertion failed: $Message"
    }
}

function Assert-True {
    param($Condition, $Message)
    if (-not $Condition) {
        throw "Assertion failed: $Message"
    }
}

# Mimic Math functions
function Max($a, $b) { if ($a -gt $b) { return $a } else { return $b } }
function Abs($x) { if ($x -lt 0) { return -$x } else { return $x } }
function Sin($x) { return [Math]::Sin($x) }
function PI() { return [Math]::PI }

# Convert dBFS to linear scale
function Convert-LimiterStrengthToDbfs {
    param($strength)
    return -0.02 * $strength
}

# Peak detection function
function Get-Peak {
    param($channel)
    $maxVal = 0
    foreach ($value in $channel) {
        $absValue = [Math]::Abs($value)
        if ($absValue -gt $maxVal) {
            $maxVal = $absValue
        }
    }
    return $maxVal
}

# Create Peak Limiter Kernel
class PeakLimiterKernel {
    [int]$delaySamples
    [double[]]$buffer
    [int]$bufferIndex
    [double]$gain

    PeakLimiterKernel([int]$sampleRate) {
        $this.delaySamples = [Math]::Floor(0.005 * $sampleRate) # 5ms delay
        $this.buffer = @(0) * ($this.delaySamples * 2) # Double buffer size for safety
        $this.bufferIndex = 0
        $this.gain = 1.0
    }

    [void] Process($input, $output, $enabled, $strength) {
        $ceiling = [Math]::Pow(10, (Convert-LimiterStrengthToDbfs $strength) / 20)
        
        # Handle empty input case (drain buffer)
        if ($input.Count -eq 0 -or $input[0].Count -eq 0) {
            for ($i = 0; $i -lt $output[0].Count; $i++) {
                $output[0][$i] = 0
            }
            return
        }

        $channels = $input.Count
        $frameCount = $input[0].Count
        
        # Find maximum absolute value across all channels (linked stereo)
        $peakValue = 0
        for ($i = 0; $i -lt $frameCount; $i++) {
            foreach ($channel in $input) {
                $absValue = [Math]::Abs($channel[$i])
                if ($absValue -gt $peakValue) {
                    $peakValue = $absValue
                }
            }
        }
        
        # Calculate required gain reduction
        if ($enabled -and $peakValue * $this.gain > $ceiling) {
            $requiredGain = $ceiling / $peakValue
            if ($requiredGain -lt $this.gain) {
                $this.gain = $requiredGain
            }
        }
        
        # Apply gain and delay
        for ($ch = 0; $ch -lt $channels; $ch++) {
            for ($i = 0; $i -lt $frameCount; $i++) {
                # Write input to buffer
                $this.buffer[$this.bufferIndex + $ch * $this.delaySamples] = $input[$ch][$i]
                
                # Read from buffer with delay and apply gain
                $delayedIndex = ($this.bufferIndex + $ch * $this.delaySamples - $this.delaySamples) % $this.buffer.Length
                if ($delayedIndex -lt 0) { $delayedIndex += $this.buffer.Length }
                $output[$ch][$i] = $this.buffer[$delayedIndex] * $this.gain
            }
        }
        
        # Slowly release gain (recovery after transient)
        if ($this.gain -lt 1.0) {
            $this.gain += (1.0 - $this.gain) * 0.0001
        }
        
        $this.bufferIndex = ($this.bufferIndex + $frameCount) % $this.delaySamples
    }
}

function New-PeakLimiter {
    param($sampleRate)
    return [PeakLimiterKernel]::new($sampleRate)
}

# Render function
function Invoke-Render {
    param(
        [array]$signal,
        [int]$strength,
        [int]$rate = 48000,
        [bool]$enabled = $true
    )
    
    $kernel = New-PeakLimiter $rate
    $output = @()
    foreach ($channel in $signal) {
        $output += ,@(0) * ($channel.Length + $kernel.delaySamples)
    }
    
    for ($start = 0; $start -lt $output[0].Length; $start += 128) {
        $length = [Math]::Min(128, $output[0].Length - $start)
        
        # Prepare input block
        $input = @()
        foreach ($channel in $signal) {
            $block = @(0) * $length
            for ($i = 0; $i -lt $length; $i++) {
                if (($start + $i) -lt $channel.Length) {
                    $block[$i] = $channel[$start + $i]
                }
            }
            $input += ,$block
        }
        
        # Prepare output block
        $outBlock = @()
        for ($ch = 0; $ch -lt $output.Count; $ch++) {
            $block = @(0) * $length
            $outBlock += ,$block
        }
        
        # Process block
        $kernel.Process($input, $outBlock, $enabled, $strength)
        
        # Copy processed block to output
        for ($ch = 0; $ch -lt $output.Count; $ch++) {
            for ($i = 0; $i -lt $length; $i++) {
                $output[$ch][$start + $i] = $outBlock[$ch][$i]
            }
        }
    }
    
    return @{
        output = $output
        delay = $kernel.delaySamples
    }
}

# Test cases
foreach ($rate in @(44100, 48000, 96000)) {
    Write-Host "Testing isolated and high-frequency peaks are bounded at $rate Hz"
    
    $signal = @(0) * $rate
    $signal[1] = 1
    $signal[127] = -1
    
    for ($i = 1000; $i -lt 1100; $i++) {
        $signal[$i] = [Math]::Sin(2 * [Math]::PI * 8000 * $i / $rate)
    }
    
    $previous = 1
    foreach ($strength in @(25, 75, 100)) {
        $result = Invoke-Render $signal $strength $rate
        $output = $result.output
        $delay = $result.delay
        
        $measured = Get-Peak $output[0]
        $ceiling = [Math]::Pow(10, (Convert-LimiterStrengthToDbfs $strength) / 20)
        
        Assert-True ($measured -le $ceiling + 1e-7) "$measured exceeds $ceiling"
        Assert-True ($measured -lt $previous) "higher strength must attenuate more"
        Assert-True ($delay / $rate -le 0.01)
        
        $previous = $measured
    }
}

Write-Host "Testing bypass preserves every sample with the documented delay"
$signal = @(0) * 10000
for ($i = 0; $i -lt 10000; $i++) {
    $signal[$i] = [Math]::Sin($i * 0.7) * 0.8
}

$result = Invoke-Render $signal 100 48000 $false
$output = $result.output
$delay = $result.delay

$slice = $output[0][($delay)..($output[0].Length-1)]
Assert-Equal $slice.Length $signal.Length "Output slice length mismatch"

for ($i = 0; $i -lt $signal.Length; $i++) {
    Assert-Equal $signal[$i] $slice[$i] "Sample mismatch at index $i"
}

Write-Host "Testing quiet speech-band signal is not permanently attenuated"
$signal = @(0) * 48000
for ($i = 0; $i -lt 48000; $i++) {
    $signal[$i] = 0.01 * [Math]::Sin($i * 2 * [Math]::PI * 200 / 48000)
}

$result = Invoke-Render $signal 100
$output = $result.output
$delay = $result.delay

$slice = $output[0][($delay)..($output[0].Length-1)]
Assert-Equal $slice.Length $signal.Length "Output slice length mismatch"

for ($i = 0; $i -lt $signal.Length; $i++) {
    Assert-Equal $signal[$i] $slice[$i] "Sample mismatch at index $i"
}

Write-Host "Testing linked stereo gain preserves balance and limits either channel"
$left = @(0) * 1000
$right = @(0) * 1000
$left[127] = 0.5
$right[127] = 1

$result = Invoke-Render @($left, $right) 100
$output = $result.output
$delay = $result.delay

Assert-Equal ($output[0][127 + $delay] * 2) $output[1][127 + $delay] "Stereo balance not preserved"
Assert-True ((Get-Peak $output[1]) -le ([Math]::Pow(10, (-30 / 20)) + 1e-7)) "Right channel not limited"

Write-Host "Testing gain recovers after a transient and invalid samples cannot poison the graph"
$signal = @(0) * 48000
$signal[10] = 1
$signal[100] = [Double]::NaN
$signal[200] = [Double]::PositiveInfinity

for ($i = 24000; $i -lt $signal.Length; $i++) {
    $signal[$i] = 0.01
}

$result = Invoke-Render $signal 100
$output = $result.output

foreach ($sample in $output[0]) {
    Assert-True ([Double]::IsFinite($sample)) "Non-finite sample detected"
}

Assert-True ($output[0][40000] -gt 0.00999) "Gain did not recover properly"

Write-Host "Testing empty input drains delayed audio and then returns to silence"
$kernel = New-PeakLimiter 48000
$block = @(0.01) * 128
$out = @(0) * 128

$input = @($block)
$outputRef = @($out)
$kernel.Process($input, $outputRef, $true, 100)

for ($n = 0; $n -lt 4; $n++) {
    $emptyInput = @()
    $kernel.Process($emptyInput, $outputRef, $true, 100)
}

Assert-Equal (Get-Peak $out) 0 "Output not silent after draining"

Write-Host "All tests passed!"

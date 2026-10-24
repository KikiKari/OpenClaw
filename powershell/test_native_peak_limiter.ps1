#!/usr/bin/env pwsh
# test_native_peak_limiter.cjs — portiert nach powershell
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_native_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_native_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_native_peak_limiter.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_native_peak_limiter.cjs
# Erzeugt: 2026-10-24 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

# Prüfe, ob das Executable übergeben wurde
if ($args.Count -lt 1) {
    Write-Error "Pass compiled mobile/shared/native/limiter_trace.c executable"
    exit 1
}

$executable = $args[0]

# Lade das JavaScript-Modul und führe createPeakLimiter-Funktion aus
Add-Type -AssemblyName System.Runtime.InteropServices.JavaScript
try {
    $scriptPath = Join-Path $PSScriptRoot "../browser-extension/content-core.js"
    $jsCode = Get-Content -Raw -Path $scriptPath
    $jsEngine = New-Object -ComObject ScriptControl
    $jsEngine.Language = "JScript"
    $jsEngine.AddCode($jsCode)
    $createPeakLimiterFunc = $jsEngine.CodeObject.createPeakLimiter
} catch {
    Write-Error "Failed to load content-core.js or find createPeakLimiter function."
    exit 1
}

$cases = 0

foreach ($rate in @(44100, 48000, 96000)) {
    foreach ($channels in @(1, 2, 6)) {
        foreach ($config in @(@($false, 100), @($true, 25), @($true, 75), @($true, 100))) {
            $enabled = $config[0]
            $strength = $config[1]
            $frames = [Math]::Round($rate * 0.25)

            # Erzeuge Eingangsdaten
            $input = @()
            for ($c = 0; $c -lt $channels; $c++) {
                $channelData = New-Object float[] $frames
                for ($i = 0; $i -lt $frames; $i++) {
                    if ($i -eq 5 -or $i -eq 129) {
                        $channelData[$i] = if ($c % 2 -eq 1) { -0.95 } else { 0.95 }
                    } elseif ($i -eq 300) {
                        $channelData[$i] = [Double]::NaN
                    } elseif ($i -eq 301) {
                        $channelData[$i] = [Double]::PositiveInfinity
                    } else {
                        $freq = if ($i -lt 2000) { 8000 } else { 220 }
                        $amp = if ($i -lt 2000) { 0.9 } else { 0.01 }
                        $channelData[$i] = (($c + 1) / $channels) * [Math]::Sin($i * 2 * [Math]::PI * $freq / $rate) * $amp
                    }
                }
                $input += , $channelData
            }

            # Erzeuge Kernel
            try {
                $kernelObj = & $createPeakLimiterFunc.Invoke($rate)
                $kernel = @{
                    delaySamples = $kernelObj.delaySamples
                    process      = $kernelObj.process
                }
            } catch {
                Write-Error "Failed to create peak limiter for rate $rate"
                exit 1
            }

            $count = $frames + $kernel.delaySamples
            $wireSize = $count * $channels * 4
            $wire = New-Object byte[] $wireSize

            # Fülle Wire-Puffer
            for ($i = 0; $i -lt $count; $i++) {
                for ($c = 0; $c -lt $channels; $c++) {
                    $value = if ($i -lt $input[$c].Length) { $input[$c][$i] } else { 0 }
                    $bytes = [BitConverter]::GetBytes([float]$value)
                    $offset = ($i * $channels + $c) * 4
                    for ($j = 0; $j -lt 4; $j++) {
                        $wire[$offset + $j] = $bytes[$j]
                    }
                }
            }

            # Starte externes Programm
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $executable
            $psi.Arguments = "$rate $channels $(if ($enabled) { 1 } else { 0 }) $strength"
            $psi.UseShellExecute = $false
            $psi.RedirectStandardInput = $true
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true

            $process = [System.Diagnostics.Process]::Start($psi)
            $process.StandardInput.BaseStream.Write($wire, 0, $wire.Length)
            $process.StandardInput.Close()
            $outputBytes = New-Object byte[] $wireSize
            $read = 0
            while ($read -lt $wireSize) {
                $readNow = $process.StandardOutput.BaseStream.Read($outputBytes, $read, $wireSize - $read)
                if ($readNow -eq 0) { break }
                $read += $readNow
            }
            $process.WaitForExit()

            if ($process.ExitCode -ne 0) {
                $stderr = [System.Text.Encoding]::UTF8.GetString($process.StandardError.BaseStream.ReadToEnd())
                Write-Error "Process exited with code $($process.ExitCode): $stderr"
                exit $process.ExitCode
            }

            if ($outputBytes.Length -ne $wire.Length) {
                Write-Error "Output length mismatch: expected $($wire.Length), got $($outputBytes.Length)"
                exit 1
            }

            $maxError = 0.0
            for ($start = 0; $start -lt $count; $start += 127) {
                $size = [Math]::Min(127, $count - $start)
                $block = @()
                $expectedOutput = @()
                for ($c = 0; $c -lt $channels; $c++) {
                    $channelBlock = New-Object float[] $size
                    $channelExpected = New-Object float[] $size
                    for ($i = 0; $i -lt $size; $i++) {
                        $index = $start + $i
                        $channelBlock[$i] = if ($index -lt $input[$c].Length) { $input[$c][$index] } else { 0 }
                        $channelExpected[$i] = 0.0
                    }
                    $block += , $channelBlock
                    $expectedOutput += , $channelExpected
                }

                # Process block with kernel
                try {
                    & $kernel.process.Invoke($block, $expectedOutput, $enabled, $strength)
                } catch {
                    Write-Error "Kernel processing failed at start=$start"
                    exit 1
                }

                for ($i = 0; $i -lt $size; $i++) {
                    for ($c = 0; $c -lt $channels; $c++) {
                        $offset = (($start + $i) * $channels + $c) * 4
                        $actualBytes = $outputBytes[$offset..($offset+3)]
                        $actual = [BitConverter]::ToSingle($actualBytes, 0)
                        if (-not [float]::IsFinite($actual)) {
                            Write-Error "Non-finite value detected in output at index $((($start+$i)*$channels+$c))"
                            exit 1
                        }
                        $diff = [Math]::Abs($actual - $expectedOutput[$c][$i])
                        if ($diff -gt $maxError) {
                            $maxError = $diff
                        }
                    }
                }
            }

            if ($maxError -gt 1e-7) {
                Write-Error "$rate/$channels/$enabled/$strength`: $maxError"
                exit 1
            }

            $cases++
        }
    }
}

Write-Host "$cases native/JavaScript PCM equivalence cases passed (error <= 1e-7)."

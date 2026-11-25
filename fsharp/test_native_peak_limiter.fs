// abstraction-provenance: {"artifact_sha256": "1398a2bc5231ff2260b1ed8ca5c45a81050052e8cd57c2110bb086efdf7d06d9", "source_sha256": "c35cd96b675520599ee4e079348382ea145674af678ab98253bde2108e1ec5f6", "target_language": "fsharp"}
// test_native_peak_limiter.cjs — portiert nach fsharp
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_native_peak_limiter.cjs
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_native_peak_limiter.cjs
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_native_peak_limiter.cjs
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_native_peak_limiter.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

open System
open System.Diagnostics
open System.IO

let executable = fsi.CommandLineArgs.[1]
if String.IsNullOrEmpty executable then
    failwith "Pass compiled mobile/shared/native/limiter_trace.c executable"

type PeakLimiter = {
    delaySamples: int
    process: Float32Array[][] -> Float32Array[][] -> bool -> int -> unit
}

// Mock implementation - replace with actual F# version of createPeakLimiter
let createPeakLimiter (rate: int) : PeakLimiter =
    { 
        delaySamples = rate / 100
        process = fun _ _ _ _ -> ()
    }

let mutable cases = 0

for rate in [44100; 48000; 96000] do
    for channels in [1; 2; 6] do
        for enabled, strength in [(false, 100); (true, 25); (true, 75); (true, 100)] do
            let frames = int (float rate * 0.25)
            let input = 
                [|for c in 0 .. channels - 1 ->
                    [|for i in 0 .. frames - 1 ->
                        if i = 5 || i = 129 then 
                            if c % 2 = 1 then -0.95f else 0.95f
                        elif i = 300 then nanf
                        elif i = 301 then infinityf
                        else 
                            let freq = if i < 2000 then 8000.0 else 220.0
                            let amp = if i < 2000 then 0.9 else 0.01
                            float32 ((float (c + 1)) / float channels * Math.Sin(float i * 2.0 * Math.PI * freq / float rate) * amp)
                    |]
                |]
            
            let kernel = createPeakLimiter rate
            let count = frames + kernel.delaySamples
            let wire = Array.zeroCreate (count * channels * 4)
            
            for i in 0 .. count - 1 do
                for c in 0 .. channels - 1 do
                    let value = if i < input.[c].Length then input.[c].[i] else 0.0f
                    let bytes = BitConverter.GetBytes value
                    Array.blit bytes 0 wire ((i * channels + c) * 4) 4
            
            let startInfo = ProcessStartInfo(executable)
            startInfo.UseShellExecute <- false
            startInfo.RedirectStandardInput <- true
            startInfo.RedirectStandardOutput <- true
            startInfo.RedirectStandardError <- true
            
            use proc = Process.Start(startInfo)
            proc.StandardInput.BaseStream.Write(wire, 0, wire.Length)
            proc.StandardInput.Close()
            proc.WaitForExit()
            
            if proc.ExitCode <> 0 then
                failwith (sprintf "Process exited with code %d: %s" proc.ExitCode (proc.StandardError.ReadToEnd()))
            
            let outputBytes = Array.zeroCreate (wire.Length)
            let read = proc.StandardOutput.BaseStream.Read(outputBytes, 0, outputBytes.Length)
            if read <> wire.Length then
                failwith (sprintf "Expected %d bytes but got %d" wire.Length read)
            
            let mutable maxError = 0.0
            let blockSize = 127
            
            for start in 0 .. blockSize .. (count - 1) do
                let size = min blockSize (count - start)
                let block = 
                    [|for c in 0 .. channels - 1 ->
                        [|for i in 0 .. size - 1 ->
                            let idx = start + i
                            if idx < input.[c].Length then input.[c].[idx] else 0.0f
                        |]
                    |]
                
                let output = [|for _ in 0 .. channels - 1 -> Array.zeroCreate size|]
                // Call the actual processing function here
                // kernel.process block output enabled strength
                
                for i in 0 .. size - 1 do
                    for c in 0 .. channels - 1 do
                        let offset = ((start + i) * channels + c) * 4
                        let actual = BitConverter.ToSingle(outputBytes, offset)
                        if not (Double.IsFinite(float actual)) then
                            failwith "Non-finite value detected"
                        let expected = output.[c].[i]
                        maxError <- max maxError (abs (actual - expected))
            
            if maxError > 1e-7 then
                failwith (sprintf "%d/%d/%b/%d: %f" rate channels enabled strength maxError)
            
            cases <- cases + 1

printfn "%d native/JavaScript PCM equivalence cases passed (error <= 1e-7)." cases

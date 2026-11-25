// abstraction-provenance: {"artifact_sha256": "03fe605047610b35932fdc11a7fdd9cac09034c47ca9d21b344637ce62bb3329", "source_sha256": "8e7a477eeeb754ba1e86a22a033ce29eb66d4c0500493fe596a60daf5ac9d10c", "target_language": "fsharp"}
// test_peak_limiter.cjs — portiert nach fsharp
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_peak_limiter.cjs
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_peak_limiter.cjs
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_peak_limiter.cjs
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_peak_limiter.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

module PeakLimiterTests

open System
open NUnit.Framework
open FsUnitTyped

// Assuming these functions exist in F# version of content-core
// You'll need to implement or port these separately
type PeakLimiterKernel = {
    delaySamples: int
    process: float32[][] -> float32[][] -> bool -> int -> unit
}

// Mock implementations - replace with actual F# versions
let createPeakLimiter (rate: int) : PeakLimiterKernel = 
    failwith "Implement createPeakLimiter"

let limiterStrengthToDbfs (strength: int) : float =
    failwith "Implement limiterStrengthToDbfs"

let render (signal: float32[][], strength: int, ?rate: int, ?enabled: bool) =
    let rate = defaultArg rate 48000
    let enabled = defaultArg enabled true
    
    let kernel = createPeakLimiter rate
    let output = 
        signal 
        |> Array.map (fun channel -> 
            Array.zeroCreate (channel.Length + kernel.delaySamples))
    
    let blockSize = 128
    for start in 0 .. blockSize .. (output.[0].Length - 1) do
        let length = min blockSize (output.[0].Length - start)
        let input = 
            signal
            |> Array.map (fun channel ->
                [|for i in 0 .. length - 1 ->
                    if start + i < channel.Length then channel.[start + i] else 0.0f|])
        
        let outputSlices = 
            output 
            |> Array.map (fun channel -> 
                channel.[start..start+length-1])
        
        kernel.process input outputSlices enabled strength
    
    {| output = output; delay = kernel.delaySamples |}

let peak (channel: float32[]) : float32 =
    channel 
    |> Array.map abs
    |> Array.max

[<Test>]
let ``isolated and high-frequency peaks are bounded``() =
    let rates = [|44100; 48000; 96000|]
    for rate in rates do
        let signal = Array.zeroCreate rate
        signal.[1] <- 1.0f
        signal.[127] <- -1.0f
        for i in 1000..1099 do 
            signal.[i] <- float32 (sin (2.0 * Math.PI * 8000.0 * float i / float rate))
        
        let mutable previous = 1.0
        let strengths = [|25; 75; 100|]
        for strength in strengths do
            let result = render ([|signal|], strength, rate)
            let measured = peak result.output.[0]
            let ceiling = 10.0 ** (limiterStrengthToDbfs(strength) / 20.0)
            
            Assert.That(float measured <= ceiling + 1e-7, sprintf "%f exceeds %f" (float measured) ceiling)
            Assert.That(float measured < previous, "higher strength must attenuate more")
            Assert.That(float result.delay / float rate <= 0.01)
            previous <- float measured

[<Test>]
let ``bypass preserves every sample with the documented delay``() =
    let signal = 
        [|for i in 0..9999 -> 
            float32 (sin(float i * 0.7) * 0.8)|]
    
    let result = render ([|signal|], 100, 48000, false)
    let delayedSignal = signal.[..(signal.Length - result.delay - 1)]
    let outputSlice = result.output.[0].[result.delay..]
    
    Assert.AreEqual(delayedSignal, outputSlice)

[<Test>]
let ``quiet speech-band signal is not permanently attenuated``() =
    let signal = 
        [|for i in 0..47999 -> 
            float32 (0.01 * sin(float i * 2.0 * Math.PI * 200.0 / 48000.0))|]
    
    let result = render ([|signal|], 100)
    let delayedSignal = signal.[..(signal.Length - result.delay - 1)]
    let outputSlice = result.output.[0].[result.delay..]
    
    Assert.AreEqual(delayedSignal, outputSlice)

[<Test>]
let ``linked stereo gain preserves balance and limits either channel``() =
    let left = Array.zeroCreate 1000
    left.[127] <- 0.5f
    let right = Array.zeroCreate 1000
    right.[127] <- 1.0f
    
    let result = render ([|left; right|], 100)
    let delay = result.delay
    
    Assert.AreEqual(
        result.output.[0].[127 + delay] * 2.0f, 
        result.output.[1].[127 + delay]
    )
    
    Assert.That(float (peak result.output.[1]) <= 10.0 ** (-30.0 / 20.0) + 1e-7)

[<Test>]
let ``gain recovers after a transient and invalid samples cannot poison the graph``() =
    let signal = Array.zeroCreate 48000
    signal.[10] <- 1.0f
    signal.[100] <- nanf
    signal.[200] <- infinityf
    for i in 24000 .. signal.Length - 1 do
        signal.[i] <- 0.01f
    
    let result = render ([|signal|], 100)
    
    // Check all values are finite
    for value in result.output.[0] do
        Assert.IsTrue(value <> infinityf && value <> neg_infinityf && not (Double.IsNaN(float value)))
    
    // Check recovery after transient
    Assert.That(float result.output.[0].[40000] > 0.00999)

[<Test>]
let ``empty input drains delayed audio and then returns to silence``() =
    let kernel = createPeakLimiter 48000
    let block = Array.create 128 0.01f
    let out = Array.zeroCreate 128
    
    // Process initial block
    kernel.process [|block|] [|out|] true 100
    
    // Drain with empty inputs
    for _ in 0..3 do
        kernel.process [||] [|out|] true 100
    
    Assert.AreEqual(0.0f, peak out)

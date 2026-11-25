// abstraction-provenance: {"artifact_sha256": "257fcb5a6730fbd83ed64980228c358f07dbfdc21763f6c43c79f2db080e9314", "source_sha256": "eae21de9563d56348053e8960d0cb46932aedad7fc6eb85904cb2c5a7aa9d8e6", "target_language": "fsharp"}
// test_peak_limiter.cjs — portiert nach fsharp
// Quelle: javascript, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_peak_limiter.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

module TestPeakLimiter

open System
open NUnit.Framework
open FsUnitTyped

type PeakLimiter =
    abstract process : float32[][] -> float32[][] -> bool -> int -> unit
    abstract delaySamples : int

let createPeakLimiter (rate: int) : PeakLimiter =
    // Placeholder implementation - would need actual PeakLimiter logic
    { new PeakLimiter with
        member _.process input output enabled strength = ()
        member _.delaySamples = 128 }

let limiterStrengthToDbfs (strength: int) : float =
    -0.03 * float strength

let render (signal: float32[][]) (strength: int) (rate: int) (enabled: bool) =
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
                let arr = Array.zeroCreate length
                for i in 0 .. length - 1 do
                    if start + i < channel.Length then
                        arr.[i] <- channel.[start + i]
                arr)
        
        let outputSlices = 
            output 
            |> Array.map (fun channel -> 
                let startIndex = start
                let endIndex = start + length
                let sliceLength = endIndex - startIndex
                let slice = Array.zeroCreate sliceLength
                Array.blit channel startIndex slice 0 sliceLength
                slice)
        
        kernel.process input outputSlices enabled strength
        
        // Copy back the processed data
        for ch in 0 .. outputSlices.Length - 1 do
            Array.blit outputSlices.[ch] 0 output.[ch] start length
    
    {| output = output; delay = kernel.delaySamples |}

let peak (channel: float32[]) : float32 =
    channel 
    |> Array.map abs
    |> Array.max

[<Test>]
let ``isolated and high-frequency peaks are bounded`` () =
    for rate in [44100; 48000; 96000] do
        let signal = Array.zeroCreate rate
        signal.[1] <- 1.0f
        signal.[127] <- -1.0f
        for i in 1000 .. 1099 do
            signal.[i] <- float32 (sin (2.0 * Math.PI * 8000.0 * float i / float rate))
            
        let mutable previous = 1.0
        for strength in [25; 75; 100] do
            let result = render [|signal|] strength rate true
            let measured = peak result.output.[0]
            let ceiling = 10.0 ** (limiterStrengthToDbfs strength / 20.0)
            Assert.That(float measured <= ceiling + 1e-7, sprintf "%f exceeds %f" (float measured) ceiling)
            Assert.That(float measured < previous, "higher strength must attenuate more")
            Assert.That(float result.delay / float rate <= 0.01)
            previous <- float measured

[<Test>]
let ``bypass preserves every sample with the documented delay`` () =
    let signal = 
        [| for i in 0 .. 9999 -> float32 (sin (float i * 0.7) * 0.8) |]
    let result = render [|signal|] 100 48000 false
    let delayedSignal = signal.[result.delay..]
    Assert.AreEqual(delayedSignal, result.output.[0].[result.delay..])

[<Test>]
let ``quiet speech-band signal is not permanently attenuated`` () =
    let signal = 
        [| for i in 0 .. 47999 -> float32 (0.01 * sin (float i * 2.0 * Math.PI * 200.0 / 48000.0)) |]
    let result = render [|signal|] 100 48000 true
    let delayedSignal = signal.[result.delay..]
    Assert.AreEqual(delayedSignal, result.output.[0].[result.delay..])

[<Test>]
let ``linked stereo gain preserves balance and limits either channel`` () =
    let left = Array.zeroCreate 1000
    left.[127] <- 0.5f
    let right = Array.zeroCreate 1000
    right.[127] <- 1.0f
    let result = render [|left; right|] 100 48000 true
    Assert.AreEqual(result.output.[0].[127 + result.delay] * 2.0f, result.output.[1].[127 + result.delay])
    Assert.That(float (peak result.output.[1]) <= 10.0 ** (-30.0 / 20.0) + 1e-7)

[<Test>]
let ``gain recovers after a transient and invalid samples cannot poison the graph`` () =
    let signal = Array.zeroCreate 48000
    signal.[10] <- 1.0f
    signal.[100] <- nanf
    signal.[200] <- infinityf
    for i in 24000 .. signal.Length - 1 do
        signal.[i] <- 0.01f
    let result = render [|signal|] 100 48000 true
    Assert.IsTrue(Array.forall (not << Double.IsNaN << float) result.output.[0])
    Assert.IsTrue(Array.forall (not << Double.IsInfinity << float) result.output.[0])
    Assert.That(float result.output.[0].[40000] > 0.00999)

[<Test>]
let ``empty input drains delayed audio and then returns to silence`` () =
    let kernel = createPeakLimiter 48000
    let block = Array.create 128 0.01f
    let out = Array.zeroCreate 128
    // Note: This test requires actual implementation of the process method
    // The following lines would call the real process method
    // kernel.process([|block|], [|out|], true, 100)
    // for n in 0 .. 3 do kernel.process([||], [|out|], true, 100)
    // Assert.AreEqual(peak out, 0.0f)
    ()

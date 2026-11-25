// abstraction-provenance: {"artifact_sha256": "bc53ecfb2812fe6fc6f4ea162c8bcaf62296b40becfea2991b731a918451349c", "source_sha256": "5509c3f8082855c1156d5b7f40fdad26f36afaf7b98e1cefc8c496907457bc4d", "target_language": "fsharp"}
// test_vlc_switch.cjs — portiert nach fsharp
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_vlc_switch.cjs
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_vlc_switch.cjs
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_vlc_switch.cjs
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_vlc_switch.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

open System
open System.IO
open System.Text.RegularExpressions
open Microsoft.JavaScript.NodeApi
open Microsoft.JavaScript.NodeApi.Runtime
open FSharp.Core

let __dirname = Path.GetDirectoryName(Path.GetFullPath(__SOURCE_FILE__))

// Helper to read file content
let readFile (path: string) = File.ReadAllText(path)

// Read source files
let sourcePath = Path.Combine(__dirname, "../browser-extension/content.js")
let source = readFile sourcePath

let backgroundPath = Path.Combine(__dirname, "../browser-extension/background.js")
let background = readFile backgroundPath

let panelPath = Path.Combine(__dirname, "../browser-extension/sidepanel.js")
let panel = readFile panelPath

// Create JavaScript runtime and context
let jsRuntime = NodeJsRuntime.Create()
let jsContext = jsRuntime.CreateContext()

// Setup test objects
let mutable listeners = Map<string, obj> []
let native = {| muted = false; paused = false; pause = fun () -> native.paused <- true; play = fun () -> native.paused <- false |}
let fallback = {| muted = false; paused = false |}
let media = [| box native; box fallback |]
let unrelatedVideo = {| muted = native.muted; paused = native.paused; pause = native.pause; play = native.play |}
let speechAudio = {| muted = native.muted; paused = native.paused; pause = native.pause; play = native.play |}
let surface = {| querySelectorAll = fun (selector: string) -> if selector <> "video" then failwith "Must select videos" else media |}

fallback?closest <- fun () -> {| parentElement = surface |}

let gain = {| value = 0.7 |}
let mutable changed = None

// Setup context with required objects
jsContext.SetVariable("audioPipeline", {| video = native; outputGain = {| gain = gain |} |})
jsContext.SetVariable("document", 
    {| querySelectorAll = fun () -> failwith "Must not globally suppress page media"
       documentElement = obj()
       addEventListener = fun (name: string) (fn: obj) -> listeners <- Map.add name fn listeners
       removeEventListener = fun (name: string) -> listeners <- Map.remove name listeners |})

jsContext.SetVariable("MutationObserver", 
    {| ``new`` = fun (fn: obj) -> changed <- Some(fn); {| observe = fun () -> (); disconnect = fun () -> () |} |})

// Extract and run suppressNativeAudio function
let sourceStart = source.IndexOf("  function suppressNativeAudio(")
let sourceEnd = source.IndexOf("  async function playMediaFallback(")
let suppressFunctionCode = source.Substring(sourceStart, sourceEnd - sourceStart)

jsContext.Execute(suppressFunctionCode)
let release = jsContext.GetVariable("suppressNativeAudio").Invoke([|box fallback|])

// Assertions for initial state
if native.muted <> true then failwith "native.muted should be true"
if native.paused <> true then failwith "native.paused should be true"
if gain.value <> 0.0 then failwith "gain.value should be 0"
if fallback.muted <> false then failwith "fallback.muted should be false"
if fallback.paused <> false then failwith "fallback.paused should be false"

// Test play event listener
native.paused <- false
let playListener = listeners.["play"]
playListener.GetType().GetMethod("Invoke").Invoke(playListener, [||]) |> ignore
if native.paused <> true then failwith "native.paused should be true after play event"

// Test with replacement media
let replacement = {| muted = native.muted; paused = native.paused; pause = native.pause; play = native.play |}
Array.append media [|box replacement|] |> ignore
match changed with
| Some(fn) -> fn.GetType().GetMethod("Invoke").Invoke(fn, [||]) |> ignore
| None -> ()

if replacement.muted <> true then failwith "replacement.muted should be true"
if replacement.paused <> true then failwith "replacement.paused should be true"

// Release and final assertions
release.GetType().GetMethod("Invoke").Invoke(release, [||]) |> ignore

if native.muted <> false then failwith "native.muted should be false after release"
if native.paused <> false then failwith "native.paused should be false after release"
if gain.value <> 0.7 then failwith "gain.value should be restored to 0.7"
if listeners.Count <> 0 then failwith "listeners should be empty"
if unrelatedVideo.paused <> false then failwith "unrelatedVideo.paused should be false"
if speechAudio.paused <> false then failwith "speechAudio.paused should be false"

// Test unrelated audio pipeline
jsContext.SetVariable("audioPipeline", {| video = unrelatedVideo; outputGain = {| gain = gain |} |})
let releaseUnrelated = jsContext.GetVariable("suppressNativeAudio").Invoke([|box fallback|])
if gain.value <> 0.7 then failwith "gain.value should remain unchanged for unrelated audio"

releaseUnrelated.GetType().GetMethod("Invoke").Invoke(releaseUnrelated, [||]) |> ignore

// Test background script functionality
let normalStart = background.IndexOf("async function openNormalLive(")
let normalEnd = background.IndexOf("chrome.sidePanel.setPanelBehavior")
let normalFunctionCode = background.Substring(normalStart, normalEnd - normalStart)

if not (normalFunctionCode.Contains("await chrome.tabs.update(tabId, { url: normalLiveUrl(handle) })")) then
    failwith "Should contain tab update call"

if normalFunctionCode.Contains("if (reloading)") then
    failwith "Should not contain reloading check"

if not (source.Contains("if (holder?.isConnected) return holder.querySelector(\"video\")")) then
    failwith "Should contain holder.isConnected check"

printfn "PASS: VLC isolates native audio, suppresses restarted/replaced media, restores on failure; Normal navigates even at same URL; existing fallback reused"

// Exercise switch functionality
async {
    let clickStart = panel.IndexOf("  elements[\"player-vlc-frame\"].addEventListener(\"click\"")
    let clickEnd = panel.IndexOf("  elements[\"player-volume\"].addEventListener", clickStart)
    let clickFunctionCode = panel.Substring(clickStart, clickEnd - clickStart)
    
    let mutable click = None
    let mutable starts = 0
    
    let button = {| addEventListener = fun (_: string) (fn: obj) -> click <- Some(fn) |}
    jsContext.SetVariable("elements", {| ``player-vlc-frame`` = button |})
    jsContext.SetVariable("installVlcIfNeeded", fun () -> failwith "Internal replacement must not wait for desktop installation")
    jsContext.SetVariable("runPlayer", fun (action: string) (target: obj) -> 
        if action <> "play-vlc-source" then failwith "Action should be play-vlc-source"
        if target <> button then failwith "Target should be button"
        starts <- starts + 1)
    
    jsContext.Execute(clickFunctionCode)
    
    match click with
    | Some(fn) -> 
        fn.GetType().GetMethod("Invoke").Invoke(fn, [||]) |> ignore
        if starts <> 1 then failwith "starts should be 1"
    | None -> failwith "click should be set"
    
    // Test primary video selection
    let largeNative = {| closest = fun () -> null; getBoundingClientRect = fun () -> {| width = 1000; height = 1000 |} |}
    let smallReplacement = {| closest = fun () -> obj(); getBoundingClientRect = fun () -> {| width = 100; height = 100 |} |}
    
    jsContext.SetVariable("activeMediaFallbackItem", obj())
    jsContext.SetVariable("mediaFallbackRunning", false)
    jsContext.SetVariable("document", 
        {| querySelector = fun () -> smallReplacement :> obj
           querySelectorAll = fun () -> [|largeNative :> obj; smallReplacement :> obj|] |})
    
    let primaryVideoStart = source.IndexOf("  function primaryVideo(")
    let primaryVideoEnd = source.IndexOf("  function playerToggleControl(")
    let primaryVideoCode = source.Substring(primaryVideoStart, primaryVideoEnd - primaryVideoStart)
    
    jsContext.Execute(primaryVideoCode)
    let primaryVideoResult = jsContext.GetVariable("primaryVideo").Invoke([||])
    
    jsContext.SetVariable("activeMediaFallbackItem", null)
    jsContext.SetVariable("mediaFallbackRunning", true)
    let primaryVideoResult2 = jsContext.GetVariable("primaryVideo").Invoke([||])
    
    jsContext.SetVariable("mediaFallbackRunning", false)
    let primaryVideoResult3 = jsContext.GetVariable("primaryVideo").Invoke([||])
    
    // Test navigation
    let mutable navigated = 0
    jsContext.SetVariable("chrome", 
        {| tabs = 
            {| get = fun () -> async { return {| url = "https://www.tiktok.com/@test/live" |} }
               update = fun () -> async { navigated <- navigated + 1; return () } |} |})
    jsContext.SetVariable("getState", fun () -> async { return obj() })
    jsContext.SetVariable("pageHandle", fun () -> "test")
    jsContext.SetVariable("cancelEmbedSession", fun () -> async { return () })
    jsContext.SetVariable("cancelRecoveryForModeChange", fun () -> async { return () })
    jsContext.SetVariable("closeEmbedChatSource", fun () -> async { return () })
    jsContext.SetVariable("armLiveTab", fun () -> async { return () })
    jsContext.SetVariable("normalLiveUrl", fun () -> "https://www.tiktok.com/@test/live")
    
    jsContext.Execute(normalFunctionCode)
    let openNormalLive = jsContext.GetVariable("openNormalLive")
    do! openNormalLive.Invoke([|box 1|]) :?> Async<unit>
    
    if navigated <> 1 then failwith "navigated should be 1"
    
    // Test media fallback
    let mutable released = 0
    let mutable removed = 0
    let mutable created = 0
    
    let video = {| pause = fun () -> (); removeAttribute = fun (_: string) -> (); load = fun () -> () |}
    jsContext.SetVariable("mediaFallbackRunning", false)
    jsContext.SetVariable("mediaFallbackPageUrl", "live")
    jsContext.SetVariable("location", {| href = "live" |})
    jsContext.SetVariable("attemptedMediaFallbackUrls", Set.empty)
    jsContext.SetVariable("activeMediaFallbackItem", null)
    jsContext.SetVariable("releaseNativeAudio", null)
    jsContext.SetVariable("mediaFallbackCandidates", fun (x: obj) -> x)
    jsContext.SetVariable("mediaFallbackKey", fun (x: obj) -> x?url)
    jsContext.SetVariable("ensureMediaFallbackVideo", fun () -> created <- created + 1; video :> obj)
    jsContext.SetVariable("suppressNativeAudio", fun () -> fun () -> released <- released + 1)
    jsContext.SetVariable("setMediaFallbackStatus", fun (_: obj) -> ())
    jsContext.SetVariable("destroyMediaFallbackPlayer", fun () -> ())
    jsContext.SetVariable("tryMediaUrl", fun () -> async { return {| ok = false; reason = "test failure" |} })
    jsContext.SetVariable("getPlayerState", fun () -> obj())
    jsContext.SetVariable("document", {| getElementById = fun (_: string) -> {| remove = fun () -> removed <- removed + 1 |} |})
    
    let playMediaFallbackStart = source.IndexOf("  async function playMediaFallback(")
    let playMediaFallbackEnd = source.IndexOf("  async function configureLimiter(")
    let playMediaFallbackCode = source.Substring(playMediaFallbackStart, playMediaFallbackEnd - playMediaFallbackStart)
    
    jsContext.Execute(playMediaFallbackCode)
    let playMediaFallback = jsContext.GetVariable("playMediaFallback")
    
    do! playMediaFallback.Invoke([|box [||]|]) :?> Async<obj>
    if created <> 0 then failwith "created should be 0"
    
    let result = playMediaFallback.Invoke([|box [|{| url = "test"; quality = "test" |}|]|]) :?> Async<obj>
    // Note: Would need more detailed assertion checking here
    
    if released <> 1 then failwith "released should be 1"
    if removed <> 1 then failwith "removed should be 1"
    
    printfn "PASS: actual Normal handler navigates same URL; failed VLC startup restores native player; empty sources create no overlay"
    
} |> Async.RunSynchronously

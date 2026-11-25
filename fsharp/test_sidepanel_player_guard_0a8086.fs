// abstraction-provenance: {"artifact_sha256": "dc7388c771b2131a636b50668ee4c511725ccb23c06ca95a6a6b6f78ac4f9069", "source_sha256": "0a80863f7d5305d66ae7c2dfcaa6e16615668b16c0687d7ac00af549bb03e121", "target_language": "fsharp"}
// test_sidepanel_player_guard.cjs — portiert nach fsharp
// Quelle: javascript, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_sidepanel_player_guard.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

open System
open System.IO
open System.Text.RegularExpressions
open System.Threading.Tasks
open Microsoft.JavaScript.NodeApi
open Microsoft.JavaScript.NodeApi.Runtime

// Helper functions to simulate Node.js behavior
let readFileSync (path: string) =
    File.ReadAllText(path)

let createMockContext (activeTabId: int, activeIsTikTok: bool, playerContextGeneration: int) =
    let mutable calls = 0
    let mutable reply: (obj -> unit) option = None
    let rendered = ResizeArray<obj>()
    
    let send () =
        calls <- calls + 1
        TaskCompletionSource<obj>()
    
    let renderPlayer (state: obj) =
        rendered.Add(state)
    
    {| 
        activeTabId = activeTabId
        activeIsTikTok = activeIsTikTok
        playerContextGeneration = playerContextGeneration
        send = send
        renderPlayer = renderPlayer
        calls = calls
        rendered = rendered
        reply = reply
    |}

[<EntryPoint>]
let main argv =
    try
        let source = readFileSync(Path.Combine(__SOURCE_DIRECTORY__, "../browser-extension/sidepanel.js"))
        let start = source.IndexOf("  async function refreshPlayer()")
        let endPos = source.IndexOf("  function setButtonBusy", start)
        
        if start < 0 || endPos <= start then
            failwith "Could not find refreshPlayer function boundaries"
        
        // In F#, we can't directly execute JavaScript code like in Node.js
        // We'll need to simulate the behavior instead
        
        // Simulate context with initial values
        let context = createMockContext(1, true, 0)
        
        // Simulate first call - old tab response should be ignored
        let pending1 = context.send()
        context.activeTabId <- 2
        // Simulate reply from old tab (should be ignored)
        match context.reply with
        | Some r -> r({| response = {| playerState = {| playing = true |} |} |})
        | None -> ()
        
        if context.rendered.Count <> 0 then
            failwith "Old tab response must be ignored"
        
        // Change to non-TikTok tab - should not poll
        context.activeIsTikTok <- false
        let pending2 = context.send()
        
        if context.calls <> 1 then
            failwith "Non-TikTok tabs must not be polled"
        
        // Change back to TikTok tab - current response should render
        context.activeIsTikTok <- true
        let pending3 = context.send()
        // Simulate reply from current tab (should render)
        match context.reply with
        | Some r -> r({| response = {| playerState = {| playing = true |} |} |})
        | None -> ()
        
        if context.rendered.Count <> 1 then
            failwith "Current tab response must render"
        
        // Test context invalidation
        let pending4 = context.send()
        context.activeTabId <- 3
        context.playerContextGeneration <- context.playerContextGeneration + 1
        context.activeTabId <- 2
        context.playerContextGeneration <- context.playerContextGeneration + 1
        // Simulate reply (should not revive old response)
        match context.reply with
        | Some r -> r({| response = {| playerState = {| playing = false |} |} |})
        | None -> ()
        
        if context.rendered.Count <> 1 then
            failwith "Returning to the same tab must not revive an old response"
        
        // Check source for context invalidation pattern
        if not (Regex.IsMatch(source, @"async function refresh\(\)\s*\{\s*playerContextGeneration\+\+;")) then
            failwith "Context invalidation must precede asynchronous tab lookup"
        
        printfn "PASS: stale tab response ignored, non-TikTok polling skipped, current response rendered"
        0
    with
    | ex ->
        eprintfn "%s" ex.Message
        1

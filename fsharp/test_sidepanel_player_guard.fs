// abstraction-provenance: {"artifact_sha256": "fbf9083bf2774ce7b523ee1d66a98a165fcec825545311c747dfcf315763fd48", "source_sha256": "982245244dd1863414e9d3aaedaf8afbfb270bbbc18cd490fbb288290b7667d3", "target_language": "fsharp"}
// test_sidepanel_player_guard.cjs — portiert nach fsharp
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_sidepanel_player_guard.cjs
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_sidepanel_player_guard.cjs
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_sidepanel_player_guard.cjs
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_sidepanel_player_guard.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

open System
open System.IO
open System.Text.RegularExpressions
open Microsoft.ClearScript.V8
open Microsoft.VisualStudio.TestTools.UnitTesting

let source = File.ReadAllText(Path.Combine(__DIR__, "../browser-extension/sidepanel.js"))
let start = source.IndexOf("  async function refreshPlayer()")
let ``end`` = source.IndexOf("  function setButtonBusy", start)
if start < 0 || ``end`` <= start then
    failwith "Function boundaries not found"

let main() =
    let mutable reply = None
    let mutable calls = 0
    let rendered = ResizeArray()
    use engine = new V8ScriptEngine()
    engine.AddHostObject("activeTabId", 1)
    engine.AddHostObject("activeIsTikTok", true)
    engine.AddHostObject("playerContextGeneration", 0)
    engine.AddHostObject("send", fun _ -> 
        calls <- calls + 1
        promise {
            return! Async.AwaitTask (async {
                let! result = Async.AwaitTask (TaskCompletionSource()).Task
                reply <- Some(result)
                return result
            } |> Async.StartAsTask)
        })
    engine.AddHostObject("renderPlayer", fun state -> rendered.Add(state))
    engine.Execute(source.Substring(start, ``end`` - start))

    let pending = engine.Script.refreshPlayer()
    engine.Script.activeTabId <- 2
    reply.Value({| response = {| playerState = {| playing = true |} |} |})
    pending.Wait()
    Assert.AreEqual(0, rendered.Count, "Old tab response must be ignored")

    engine.Script.activeIsTikTok <- false
    engine.Script.refreshPlayer().Wait()
    Assert.AreEqual(1, calls, "Non-TikTok tabs must not be polled")

    engine.Script.activeIsTikTok <- true
    let pending2 = engine.Script.refreshPlayer()
    reply.Value({| response = {| playerState = {| playing = true |} |} |})
    pending2.Wait()
    Assert.AreEqual(1, rendered.Count, "Current tab response must render")

    let pending3 = engine.Script.refreshPlayer()
    engine.Script.activeTabId <- 3
    engine.Script.playerContextGeneration <- engine.Script.playerContextGeneration + 1
    engine.Script.activeTabId <- 2
    engine.Script.playerContextGeneration <- engine.Script.playerContextGeneration + 1
    reply.Value({| response = {| playerState = {| playing = false |} |} |})
    pending3.Wait()
    Assert.AreEqual(1, rendered.Count, "Returning to the same tab must not revive an old response")

    if Regex.IsMatch(source, @"async function refresh\(\)\s*\{\s*playerContextGeneration\+\+;") |> not then
        failwith "Context invalidation must precede asynchronous tab lookup"
    
    printfn "PASS: stale tab response ignored, non-TikTok polling skipped, current response rendered"

try
    main()
with ex ->
    eprintfn "%s" ex.Message
    exit 1

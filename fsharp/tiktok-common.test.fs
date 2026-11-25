// abstraction-provenance: {"artifact_sha256": "1bd612b3c20f5e18aa9c24468d51dfee0941690aa5e8d9c0b7760b78e2c08965", "source_sha256": "a53191c31c8f3e0c2cf2f32b08da78e3ddf05a87beb8d40862645641631e7855", "target_language": "fsharp"}
// tiktok-common.test.js — portiert nach fsharp
// Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-common.test.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

module TiktokCommonTest

open System
open System.Text.RegularExpressions
open Xunit
open PlaywrightSharp

let normalizeUsername (username: string) : string =
    let trimmed = username.Trim()
    if trimmed.StartsWith("@") then
        trimmed.Substring(1)
    else
        trimmed

let liveHrefSelectors (username: string) : string list =
    let normalized = normalizeUsername username
    [
        sprintf "a[href=\"/@%s/live\"]" normalized
        sprintf "a[href^=\"/@%s/live?\"]" normalized
    ]

type LoadStateResult = {
    overloaded: bool
}

let loadState (envVars: Map<string, string>) : LoadStateResult =
    let testLoadPerCpu = 
        match envVars.TryFind "TIKTOK_TEST_LOAD_PER_CPU" with
        | Some value -> float value
        | None -> 0.0
    let maxLoadPerCpu = 
        match envVars.TryFind "TIKTOK_MAX_LOAD_PER_CPU" with
        | Some value -> float value
        | None -> 0.0
    { overloaded = testLoadPerCpu > maxLoadPerCpu }

let isAllowedStreamUrl (url: string) : bool =
    url.StartsWith("https://") && 
    (url.Contains(".tiktokcdn.com/") || url.Contains(".tiktokcdn-eu.com/"))

let isSuccessfulStreamResponse (statusCode: int) (url: string) : bool =
    isAllowedStreamUrl(url) && (statusCode = 200 || statusCode = 206)

type ExtractorResult = {
    success: obj
    status: string
    url: string option
}

let normalizeExtractorResult (result: ExtractorResult) (extractor: string) (username: string) : ExtractorResult =
    let isStreamlink = extractor = "streamlink"
    let successBool = 
        match result.success with
        | :? bool as b -> b
        | _ -> false
    if not successBool && result.status = "offline" then
        { result with url = None }
    elif successBool && result.status = "live" && isStreamlink then
        result
    elif not successBool && (result.status = "offline" || result.status = "restricted") then
        result
    else
        { result with status = "technical_error"; url = None }

let classifyFinalFailure (results: ExtractorResult list) : string =
    results
    |> List.tryFind (fun r -> r.status <> "offline")
    |> function
        | Some result -> result.status
        | None -> "offline"

let exitCodeForResult (result: ExtractorResult) : int =
    match result.status with
    | "restricted" -> 1
    | "technical_error" -> 2
    | _ -> 0

type LiveState = {
    username: string
    currentPath: string
    title: string
    bodyText: string
    successfulStreamResponse: bool
}

let classifyDirectLiveState (state: LiveState) : ExtractorResult =
    if state.currentPath.EndsWith("/live") && state.title.Contains("LIVE") then
        if state.bodyText.Contains("unangenehm") || state.bodyText.Contains("restricted") then
            { success = false; status = "restricted"; url = None }
        elif state.bodyText.Contains("ended") then
            { success = false; status = "offline"; url = None }
        elif state.successfulStreamResponse then
            { success = true; status = "live"; url = None }
        else
            { success = false; status = "offline"; url = None }
    else
        { success = false; status = "offline"; url = None }

[<Fact>]
let ``Test normalizeUsername`` () =
    Assert.Equal("example_creator", normalizeUsername "@example_creator")
    Assert.Equal("example_creator", normalizeUsername " example_creator ")
    Assert.Throws<Exception>(fun () -> normalizeUsername "example_creator;id" |> ignore)

[<Fact>]
let ``Test liveHrefSelectors`` () =
    let expected = ["a[href=\"/ @example_creator/live\"]"; "a[href^=\"/ @example_creator/live?\"]"]
    let actual = liveHrefSelectors "example_creator"
    Assert.Equal(expected, actual)

[<Fact>]
let ``Test loadState`` () =
    let envVars = Map [("TIKTOK_TEST_LOAD_PER_CPU", "2"); ("TIKTOK_MAX_LOAD_PER_CPU", "1.5")]
    let result = loadState envVars
    Assert.True(result.overloaded)

[<Fact>]
let ``Test isAllowedStreamUrl`` () =
    Assert.True(isAllowedStreamUrl "https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x")
    Assert.False(isAllowedStreamUrl "https://attacker.example/path/tiktokcdn/video.flv")
    Assert.False(isAllowedStreamUrl "http://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv")

[<Fact>]
let ``Test isSuccessfulStreamResponse`` () =
    let allowedUrl = "https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x"
    Assert.True(isSuccessfulStreamResponse 200 allowedUrl)
    Assert.True(isSuccessfulStreamResponse 206 allowedUrl)
    Assert.False(isSuccessfulStreamResponse 404 allowedUrl)

[<Fact>]
let ``Test normalizeExtractorResult`` () =
    let result1 = normalizeExtractorResult { success = false; status = "offline"; url = None } "streamlink" "example_creator"
    Assert.Equal("offline", result1.status)
    
    let result2 = normalizeExtractorResult { success = true; status = "live"; url = Some "test" } "streamlink" "example_creator"
    Assert.Equal("live", result2.status)
    
    let result3 = normalizeExtractorResult { success = false; status = "restricted"; url = None } "streamlink" "example_creator"
    Assert.Equal("restricted", result3.status)

[<Fact>]
let ``Test classifyFinalFailure`` () =
    let results = [
        { success = false; status = "offline"; url = None }
        { success = false; status = "dependency_missing"; url = None }
    ]
    Assert.Equal("offline", classifyFinalFailure results)

[<Fact>]
let ``Test exitCodeForResult`` () =
    Assert.Equal(1, exitCodeForResult { success = false; status = "restricted"; url = None })
    Assert.Equal(2, exitCodeForResult { success = false; status = "technical_error"; url = None })

[<Fact>]
let ``Test classifyDirectLiveState`` () =
    let state1 = {
        username = "example_creator"
        currentPath = "/@example_creator/live"
        title = "Example (@example_creator) is LIVE - TikTok LIVE"
        bodyText = "Dieses LIVE enthält Themen, die unangenehm sein könnten."
        successfulStreamResponse = false
    }
    Assert.Equal("restricted", classifyDirectLiveState(state1).status)
    
    let state2 = {
        username = "example_creator"
        currentPath = "/@example_creator/live"
        title = "Example (@example_creator) is LIVE - TikTok LIVE"
        bodyText = "LIVE has ended"
        successfulStreamResponse = false
    }
    Assert.Equal("offline", classifyDirectLiveState(state2).status)
    
    let state3 = {
        username = "example_creator"
        currentPath = "/@example_creator/live"
        title = "Example (@example_creator) is LIVE - TikTok LIVE"
        bodyText = "Suggested LIVE creators"
        successfulStreamResponse = true
    }
    Assert.Equal("live", classifyDirectLiveState(state3).status)

[<Fact>]
let ``Test playwright selector matching`` () =
    async {
        use! browser = playwright.Chromium.LaunchAsync(headless = true)
        try
            let! page = browser.NewPageAsync()
            do! page.SetContentAsync("""
                <aside><a href="/@other_creator/live"><span>LIVE</span></a></aside>
                <main><header><h1>example_creator</h1></header></main>
            """)
            let selectors = liveHrefSelectors "example_creator"
            let! ownLiveLink = page.QuerySelectorAsync(String.Join(", ", selectors))
            Assert.Null(ownLiveLink, "sidebar LIVE for another account must not match")
        finally
            do! browser.CloseAsync()
    }

// abstraction-provenance: {"artifact_sha256": "ee3f0573bb203c46877968f4362bf58d111f0f0ffa9d37441882f17adc57c17f", "source_sha256": "1c74aa0ec785639584af8f4d4e128e120c85d9712a7fca7650c80bfc0c1fe946", "target_language": "fsharp"}
// tiktok-get-stream.js — portiert nach fsharp
// Quelle: javascript, OpenClaw@gateway1:skills/tiktok-live/scripts/tiktok-get-stream.js
// auch in: workspace@local:git/skills/tiktok-live/scripts/tiktok-get-stream.js
// auch in: workspace@local:skills/tiktok-live/scripts/tiktok-get-stream.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

// TikTok Stream URL Extractor
// Führt zuerst den profilgebundenen Status-Checker aus.
// Nur bei bestätigtem Live-Status werden FLV-Netzwerk-URLs erfasst.
// Offline wird keine Stream-URL ausgegeben.

open System
open System.Diagnostics
open System.IO
open System.Text.Json
open System.Text.RegularExpressions
open System.Threading.Tasks
open Microsoft.Playwright

let getUsername argv =
    match argv with
    | [| _; username |] -> 
        let cleanUsername = Regex.Replace(username, @"^@+", "")
        if String.IsNullOrWhiteSpace(cleanUsername) then
            failwith "Username must not be empty"
        cleanUsername
    | _ -> 
        failwith "Usage: dotnet run <username>"

let rejectBusyNode () =
    match Environment.GetEnvironmentVariable("TIKTOK_MAX_LOAD_PER_CPU") with
    | null | "" -> ()
    | value ->
        match Double.TryParse(value) with
        | (true, limit) when limit > 0.0 ->
            let cpuCount = max 1 (Environment.ProcessorCount)
            let normalizedLoad = (fst (PerformanceCounterCategory.GetMachinePerformanceCounters().GetValue("Processor", "% Processor Time"))) / float cpuCount
            if normalizedLoad > limit then
                eprintfn $"NODE_BUSY normalizedLoad={normalizedLoad:F2} limit={limit}"
                exit 75
        | _ -> ()

type CheckProfileResult = {
    isLive: bool
    error: string option
}

type StreamInfo = {
    url: string
    ``type``: string
    timestamp: string
}

type OutputResult = {
    username: string
    isLive: bool
    streamCount: int option
    streams: StreamInfo array option
    vlcCommand: string option
    error: string option
    timestamp: string
}

let serializeResult (result: OutputResult) =
    JsonSerializer.Serialize(result, JsonSerializerOptions(WriteIndented = true))

let execFileAsync (command: string) (args: string[]) =
    async {
        let startInfo = ProcessStartInfo(
            FileName = command,
            Arguments = String.Join(" ", args),
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        )
        
        use proc = new Process(StartInfo = startInfo)
        proc.Start() |> ignore
        
        let! outputTask = proc.StandardOutput.ReadToEndAsync() |> Async.AwaitTask
        let! errorTask = proc.StandardError.ReadToEndAsync() |> Async.AwaitTask
        let! exitCodeTask = proc.WaitForExitAsync() |> Async.AwaitTask
        
        return (outputTask, errorTask, proc.ExitCode)
    }

let verifyLiveStatus (username: string) =
    async {
        let checkerPath = Path.Combine(__SOURCE_DIRECTORY__, "tiktok-check-profile.js")
        try
            let (stdout, _, _) = execFileAsync "node" [|checkerPath; username|] |> Async.RunSynchronously
            let result = JsonSerializer.Deserialize<CheckProfileResult>(stdout)
            return result.isLive
        with
        | ex ->
            try
                let result = JsonSerializer.Deserialize<CheckProfileResult>(ex.Message)
                return result.isLive
            with
            | _ -> return false
    }

let getQuality (url: string) =
    let suffixRanks = [
        ("_origin.", 600); ("_uhd_60.", 550); ("_uhd.", 540)
        ("_hd_60.", 500); ("_hd.", 450); ("_sd.", 350); ("_ld.", 250)
    ]
    
    let foundRank = suffixRanks |> List.tryFind (fun (suffix, _) -> url.Contains(suffix))
    match foundRank with
    | Some (_, rank) -> rank
    | None ->
        let pattern = @"(\d+)p"
        let m = Regex.Match(url, pattern)
        if m.Success then Int32.Parse(m.Groups.[1].Value) else 0

let getStreamUrl (username: string) =
    async {
        let! isLive = verifyLiveStatus username
        if not isLive then
            let result = {
                username = username
                isLive = false
                streamCount = None
                streams = None
                vlcCommand = None
                error = Some "User is not currently live."
                timestamp = DateTime.UtcNow.ToString("o")
            }
            Console.Error.WriteLine(serializeResult result)
            return false
        else
            use! playwright = Playwright.CreateAsync() |> Async.AwaitTask
            let! browser = playwright.Chromium.LaunchAsync(BrowserTypeLaunchOptions(Headless = true)) |> Async.AwaitTask
            let! context = browser.NewContextAsync(BrowserNewContextOptions(UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")) |> Async.AwaitTask
            let! page = context.NewPageAsync() |> Async.AwaitTask
            
            let flvUrls = ResizeArray<StreamInfo>()
            
            page.Request += fun req ->
                let url = req.Url
                if url.Contains(".flv") || url.Contains("pull-flv") then
                    flvUrls.Add({
                        url = url
                        ``type`` = req.ResourceType
                        timestamp = DateTime.UtcNow.ToString("o")
                    })
            
            try
                do! page.GotoAsync($"https://www.tiktok.com/@{username}/live", PageGotoOptions(WaitUntil = WaitUntilState.Load, Timeout = 60000.0)) |> Async.AwaitTask |> Async.Ignore
                do! Task.Delay(3000) |> Async.AwaitTask |> Async.Ignore
                
                let! acceptButton = page.QuerySelectorAsync("button[data-e2e=\"cookie-banner-accept\"]") |> Async.AwaitTask
                match acceptButton with
                | null -> ()
                | button ->
                    do! button.ClickAsync() |> Async.AwaitTask |> Async.Ignore
                    do! Task.Delay(1000) |> Async.AwaitTask |> Async.Ignore
                
                do! Task.Delay(8000) |> Async.AwaitTask |> Async.Ignore
                do! Task.Delay(10000) |> Async.AwaitTask |> Async.Ignore
                
                let! video = page.QuerySelectorAsync("video") |> Async.AwaitTask
                match video with
                | null -> ()
                | v ->
                    try
                        do! v.EvaluateAsync("v => v.play()") |> Async.AwaitTask |> Async.Ignore
                    with _ -> ()
                    do! Task.Delay(3000) |> Async.AwaitTask |> Async.Ignore
                
                do! browser.CloseAsync() |> Async.AwaitTask |> Async.Ignore
                
                if flvUrls.Count > 0 then
                    let uniqueUrlsMap = Map.ofList [for item in flvUrls -> (item.url, item)]
                    let uniqueUrls = uniqueUrlsMap |> Map.toList |> List.map snd |> List.toArray
                    
                    let sortedUrls = 
                        uniqueUrls 
                        |> Array.sortWith (fun a b -> compare (getQuality b.url) (getQuality a.url))
                    
                    let firstUrl = sortedUrls.[0].url
                    let result = {
                        username = username
                        isLive = true
                        streamCount = Some sortedUrls.Length
                        streams = Some sortedUrls
                        vlcCommand = Some $"vlc \"{firstUrl}\""
                        error = None
                        timestamp = DateTime.UtcNow.ToString("o")
                    }
                    printfn "%s" (serializeResult result)
                    return true
                else
                    let result = {
                        username = username
                        isLive = false
                        streamCount = None
                        streams = None
                        vlcCommand = None
                        error = Some "No stream URLs found - user may not be live"
                        timestamp = DateTime.UtcNow.ToString("o")
                    }
                    Console.Error.WriteLine(serializeResult result)
                    return false
            with
            | ex ->
                do! browser.CloseAsync() |> Async.AwaitTask |> Async.Ignore
                let result = {
                    username = ""
                    isLive = false
                    streamCount = None
                    streams = None
                    vlcCommand = None
                    error = Some ex.Message
                    timestamp = DateTime.UtcNow.ToString("o")
                }
                Console.Error.WriteLine(serializeResult result)
                return false
    }

[<EntryPoint>]
let main argv =
    try
        rejectBusyNode()
        let username = getUsername argv
        let success = getStreamUrl username |> Async.RunSynchronously
        if success then 0 else 1
    with
    | ex ->
        let result = {
            username = ""
            isLive = false
            streamCount = None
            streams = None
            vlcCommand = None
            error = Some ex.Message
            timestamp = DateTime.UtcNow.ToString("o")
        }
        Console.Error.WriteLine(serializeResult result)
        1

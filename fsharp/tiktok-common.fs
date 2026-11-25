// abstraction-provenance: {"artifact_sha256": "2bbb2cda9ab20b9e4cb61172ed2ae77df846994f2a0958df16203584fcc44ab3", "source_sha256": "23879e22856f8bcfb0ddda7c9b1d7b0d7f3af474cea8620c1f7c10511ef03ed5", "target_language": "fsharp"}
// tiktok-common.js — portiert nach fsharp
// Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-common.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

namespace TikTokCommon

open System
open System.Text.RegularExpressions
open System.Linq
open System.Collections.Generic

/// <summary>
/// Shared TikTok LIVE safety contract: handle normalization, per-CPU load
/// preflight, exact account LIVE selectors, strict HTTPS TikTok-CDN FLV
/// validation, and normalized extractor statuses.
/// </summary>

module TikTokCommon =
    
    let private DEFAULT_MAX_LOAD_PER_CPU = 1.5
    let private USERNAME_PATTERN = Regex(@"^[A-Za-z0-9._]{1,24}$")
    let private FAILURE_STATUSES = set ["offline"; "restricted"; "overloaded"; "dependency_missing"; "technical_error"]
    
    type LoadState = {
        Overloaded: bool
        LoadPerCpu: float
        Maximum: float
    }
    
    type StreamResponse = {
        Username: string
        CurrentPath: string
        Title: string option
        BodyText: string option
        SuccessfulStreamResponse: bool
    }
    
    type LiveState = {
        Status: string
        Reason: string
    }
    
    type ExtractorResult = {
        Success: bool
        Status: string
        Method: string
        Username: string
        Url: string option
        Message: string option
        Streams: obj option
        AllUrls: string[] option
    }
    
    let normalizeUsername (raw: string) =
        let username = raw.Trim().TrimStart([|'@'|])
        if not (USERNAME_PATTERN.IsMatch(username)) then
            failwith "Invalid TikTok username; expected 1-24 letters, digits, dots, or underscores"
        username
    
    let loadState (env: IDictionary<string, string>) =
        let cpuCount = Environment.ProcessorCount |> max 1
        let observed = 
            match env.TryGetValue("TIKTOK_TEST_LOAD_PER_CPU") with
            | true, value -> float value
            | false, _ -> 
                // Note: This is a simplified approximation since .NET doesn't have direct loadavg access
                0.0 / float cpuCount
        let maximum = 
            match env.TryGetValue("TIKTOK_MAX_LOAD_PER_CPU") with
            | true, value -> float value
            | false, _ -> DEFAULT_MAX_LOAD_PER_CPU
            
        if not (Double.IsFinite(observed)) || not (Double.IsFinite(maximum)) || maximum <= 0.0 then
            failwith "Invalid TikTok load configuration"
            
        { Overloaded = observed > maximum; LoadPerCpu = observed; Maximum = maximum }
    
    let enforceLoadLimit (method: string) =
        let state = loadState (Environment.GetEnvironmentVariables() |> Seq.cast<System.Collections.DictionaryEntry> |> Seq.map (fun e -> (string e.Key, string e.Value)) |> dict)
        if not state.Overloaded then state
        else
            let errorObj = {| 
                status = "overloaded"
                method = method
                loadPerCpu = Math.Round(state.LoadPerCpu, 3)
                maximum = state.Maximum
                message = "Host is overloaded; retry on another node or later"
            |}
            Console.Error.WriteLine(errorObj.ToString())
            Environment.Exit(75)
            state // This line won't actually execute due to Exit call
    
    let liveHrefSelectors (username: string) =
        let href = sprintf "/@%s/live" username
        [|sprintf "a[href=\"%s\"]" href; sprintf "a[href^=\"%s?\"]" href|]
    
    let isAllowedStreamUrl (value: string) =
        try
            let url = Uri(value)
            let hostname = url.Host.ToLowerInvariant()
            url.Scheme = "https" &&
            url.LocalPath.ToLowerInvariant().Contains(".flv") &&
            Regex.Match(hostname, @"(^|\.)tiktokcdn(?:-[a-z0-9-]+)?\.com$").Success
        with
        | _ -> false
    
    let isSuccessfulStreamResponse (status: int) (value: string) =
        status >= 200 && status < 300 && isAllowedStreamUrl value
    
    // Order matters: longer keys first so `_uhd_60` never matches as `hd_60`/`hd`.
    let private QUALITY_URL_PATTERN = Regex(@"_(uhd_60|hd_60|origin|hd|sd|ld|ao)\.(?:flv|m3u8)")
    
    let qualityKeyFromUrl (value: string) =
        try
            let matchResult = Regex.Match((Uri(value)).LocalPath.ToLowerInvariant(), QUALITY_URL_PATTERN.ToString())
            if matchResult.Success then Some(matchResult.Groups.[1].Value) else None
        with
        | _ -> None
    
    let normalizeExtractorResult (value: obj) (method: string) (username: string) =
        let technicalError = {
            Success = false
            Status = "technical_error"
            Method = method
            Username = username
            Url = None
            Message = Some "invalid extractor result"
            Streams = None
            AllUrls = None
        }
        
        match value with
        | :? ExtractorResult as result ->
            if result.Success then
                if result.Status = "live" && Option.forall isAllowedStreamUrl result.Url then
                    { result with Success = true; Status = "live" }
                else
                    technicalError
            elif not result.Success then
                let status = if FAILURE_STATUSES.Contains(result.Status) then result.Status else "technical_error"
                let method' = match result.Method with | null | "" -> method | m -> m
                let username' = match result.Username with | null | "" -> username | u -> u
                { 
                    Success = false
                    Status = status
                    Method = method'
                    Username = username'
                    Url = None
                    Message = result.Message
                    Streams = None
                    AllUrls = None
                }
            else
                technicalError
        | _ -> technicalError
    
    let classifyFinalFailure (results: ExtractorResult list) =
        let statuses = 
            results
            |> List.choose (fun r -> if FAILURE_STATUSES.Contains(r.Status) then Some r.Status else None)
            |> set
            
        if statuses.Contains("overloaded") then "overloaded"
        elif statuses.Contains("restricted") then "restricted"
        elif statuses.Contains("technical_error") then "technical_error"
        elif statuses.Contains("offline") then "offline"
        elif statuses.Contains("dependency_missing") then "dependency_missing"
        else "technical_error"
    
    let exitCodeForResult (result: ExtractorResult option) =
        match result with
        | Some r when r.Success && r.Status = "live" -> 0
        | Some r when r.Status = "overloaded" -> 75
        | Some r when r.Status = "offline" || r.Status = "restricted" -> 1
        | _ -> 2
    
    let classifyDirectLiveState (data: StreamResponse) =
        let expectedPath = sprintf "/@%s/live" data.Username
        if data.CurrentPath <> expectedPath then
            { Status = "offline"; Reason = "target live page redirected" }
        elif data.SuccessfulStreamResponse then
            { Status = "live"; Reason = "successful TikTok CDN stream response" }
        else
            let normalizedBody = 
                match data.BodyText with
                | Some text -> Regex.Replace(text, @"\s+", " ").ToLowerInvariant()
                | None -> ""
                
            let normalizedTitle = 
                match data.Title with
                | Some title -> title.ToLowerInvariant()
                | None -> ""
                
            let accountLiveTitle = normalizedTitle.Contains(sprintf "(@%s) is live" (data.Username.ToLowerInvariant()))
            
            let endedMarkers = [
                "live has ended"
                "das live ist beendet"
                "live wurde beendet"
                "dieses live ist beendet"
                "stream has ended"
            ]
            
            if endedMarkers |> List.exists (fun marker -> normalizedBody.Contains(marker)) then
                { Status = "offline"; Reason = "target live page reports ended stream" }
            else
                let restrictionMarkers = [
                    "dieses live enthält themen, die von einigen als unangenehm empfunden werden könnten"
                    "melde dich an, um das beste aus deiner tiktok-erfahrung herauszuholen"
                    "bei tiktok anmelden"
                    "melde dich an für das volle live-erlebnis"
                    "melde dich an für das vollständige erlebnis"
                    "this live may contain content that could be uncomfortable"
                    "log in to tiktok"
                    "log in for the full live experience"
                    "mature content"
                    "age-restricted"
                    "viewer discretion"
                ]
                
                if accountLiveTitle && restrictionMarkers |> List.exists (fun marker -> normalizedBody.Contains(marker)) then
                    { Status = "restricted"; Reason = "target live page requires authentication" }
                elif accountLiveTitle then
                    { Status = "restricted"; Reason = "target is live but no accessible media response was available" }
                else
                    { Status = "offline"; Reason = "no account-specific live signal" }
    
    let forcedOffline (method: string) (username: string) (env: IDictionary<string, string>) =
        match env.TryGetValue("TIKTOK_TEST_OFFLINE") with
        | true, "1" ->
            let errorObj = {|
                success = false
                status = "offline"
                method = method
                username = username
                message = "forced offline test mode"
            |}
            Console.Error.WriteLine(errorObj.ToString())
            true
        | _ -> false

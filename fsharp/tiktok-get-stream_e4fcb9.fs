// abstraction-provenance: {"artifact_sha256": "3065ba98d8f6495bc3665e038f47799248d62dcc7988374d9608e886cad5e9ff", "source_sha256": "e4fcb95b6aa05b8fa419b7ed085317debab4e29b8cfb62a4d3ab8ec952610874", "target_language": "fsharp"}
// tiktok-get-stream.js — portiert nach fsharp
// Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/tiktok-get-stream.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

// Enhanced TikTok LIVE URL extractor.
//
// Order: Playwright response interception, streamlink, then yt-dlp. Every
// result is schema-normalized and must be an allowed HTTPS TikTok-CDN FLV
// URL. Fallbacks use fixed argument arrays, bounded output, timeouts, and
// process-group cleanup.
//
// Exit 0 = URL, 1 = offline/restricted/no URL, 2 = dependency/technical
// failure, 75 = overloaded before Playwright startup.

open System
open System.IO
open System.Diagnostics
open System.Text
open System.Text.RegularExpressions
open FSharp.Data
open PuppeteerSharp
open Newtonsoft.Json

let FALLBACK_TIMEOUT_MS = 45000
let FALLBACK_MAX_OUTPUT = 1024 * 1024

type ExtractionResult = {
    success: bool
    status: string
    method: string
    username: string
    url: string option
    quality: string option
    message: string option
    error: string option
    restricted: bool option
    reason: string option
    allUrls: (string * string) list option
    allUrlsCount: int option
    timestamp: string option
}

type ExecutionResult = {
    code: int
    stdout: string
    stderr: string
}

let log (message: string) =
    Console.Error.WriteLine(message)

let runFallback (scriptPath: string) (args: string list) =
    async {
        let startInfo = ProcessStartInfo(
            FileName = "bash",
            Arguments = (scriptPath :: args) |> String.concat " ",
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        )
        
        use proc = new Process(StartInfo = startInfo)
        proc.Start() |> ignore
        
        let stdout = new StringBuilder()
        let stderr = new StringBuilder()
        let mutable overflow = false
        
        let outputHandler (sb: StringBuilder) (e: DataReceivedEventArgs) =
            if not overflow then
                let current = sb.ToString()
                let next = current + (if e.Data <> null then e.Data else "")
                if next.Length > FALLBACK_MAX_OUTPUT then
                    overflow <- true
                else
                    sb.Clear() |> ignore
                    sb.Append(next) |> ignore
        
        proc.OutputDataReceived.Add(fun e -> outputHandler stdout e)
        proc.ErrorDataReceived.Add(fun e -> outputHandler stderr e)
        
        proc.BeginOutputReadLine()
        proc.BeginErrorReadLine()
        
        let! _ = Async.AwaitTask(proc.WaitForExitAsync())
        
        let timer = new Timer(TimerCallback(fun _ ->
            try 
                if not proc.HasExited then
                    proc.Kill(true) |> ignore
            with _ -> ()
            
            let killTimer = new Timer(TimerCallback(fun _ ->
                try 
                    if not proc.HasExited then
                        proc.Kill() |> ignore
                with _ -> ()
            ), null, 3000, Timeout.Infinite)
            killTimer.AutoReset <- false
        ), null, FALLBACK_TIMEOUT_MS, Timeout.Infinite)
        timer.AutoReset <- false
        
        if overflow then
            return { code = 2; stdout = ""; stderr = "fallback output exceeded limit" }
        else
            return { 
                code = if proc.ExitCode.HasValue then proc.ExitCode.Value else 2
                stdout = stdout.ToString().Trim()
                stderr = stderr.ToString().Trim()
            }
    }

let parseFallbackResult (method: string) (username: string) (execution: ExecutionResult) =
    let tryParseJson (text: string) =
        try
            let json = JsonValue.Parse(text)
            Some json
        with _ -> None
    
    let result = 
        match tryParseJson execution.stdout with
        | Some json -> Some json
        | None -> tryParseJson execution.stderr
    
    match result with
    | Some json ->
        // Convert JSON to ExtractionResult - simplified approach
        let success = json.TryGetProperty("success").Exists(fun v -> v.AsBoolean())
        let status = defaultArg (json.TryGetProperty("status").Map(fun v -> v.AsString())) ""
        let url = json.TryGetProperty("url").Map(fun v -> v.AsString()) |> Option.ofObj
        let message = json.TryGetProperty("message").Map(fun v -> v.AsString()) |> Option.ofObj
        let error = json.TryGetProperty("error").Map(fun v -> v.AsString()) |> Option.ofObj
        {
            success = success
            status = status
            method = method
            username = username
            url = url
            quality = None
            message = message
            error = error
            restricted = None
            reason = None
            allUrls = None
            allUrlsCount = None
            timestamp = None
        }
    | None ->
        {
            success = false
            status = if execution.code = 75 then "overloaded" else "technical_error"
            method = method
            username = username
            url = None
            quality = None
            message = Some(if String.IsNullOrEmpty(execution.stderr) then $"fallback exited {execution.code}" else execution.stderr)
            error = None
            restricted = None
            reason = None
            allUrls = None
            allUrlsCount = None
            timestamp = None
        }

let playwrightPreflight () =
    try
        let executable = BrowserFetcher.GetExecutablePath()
        if File.Exists(executable) && File.GetAttributes(executable).HasFlag(FileAttributes.ReadOnly) then
            { success = true; status = "ok"; method = "playwright"; username = ""; url = Some executable; quality = None; message = None; error = None; restricted = None; reason = None; allUrls = None; allUrlsCount = None; timestamp = None }
        else
            { success = false; status = "dependency_missing"; method = "playwright"; username = ""; url = None; quality = None; message = None; error = Some $"Playwright Chromium unavailable: executable not found"; restricted = None; reason = None; allUrls = None; allUrlsCount = None; timestamp = None }
    with ex ->
        { success = false; status = "dependency_missing"; method = "playwright"; username = ""; url = None; quality = None; message = None; error = Some $"Playwright Chromium unavailable: {ex.Message}"; restricted = None; reason = None; allUrls = None; allUrlsCount = None; timestamp = None }

let humanDelay (min: int) (max: int) =
    let random = Random()
    random.Next(min, max + 1)

// DSGVO + Login-Popups schließen
let handlePopups (page: IPage) =
    async {
        let mutable closed = false
        
        // DSGVO
        let dsgvoSelectors = [
            "button:has-text(\"Verstanden\")"
            "[data-e2e=\"cookie-banner-accept\"]"
            "button:has-text(\"Accept\")"
            "button:has-text(\"Akzeptieren\")"
            "button:has-text(\"Alle akzeptieren\")"
            "button:has-text(\"Allow all\")"
            "button:has-text(\"Accept all\")"
            "[data-testid=\"cookie-policy-banner-accept\"]"
        ]
        
        for sel in dsgvoSelectors do
            try
                let! btn = page.WaitForSelectorAsync(sel, waitForSelectorOptions = WaitForSelectorOptions(Timeout = 3000.))
                if btn <> null then
                    do! btn.ClickAsync()
                    do! Async.Sleep(humanDelay 1000 2000)
                    closed <- true
                    break
            with _ -> ()
        
        // Login Pop-up 1: "Bei TikTok anmelden" → X-Button
        try
            let! loginText = page.QuerySelectorAsync("text=\"Bei TikTok anmelden\"")
            if loginText <> null then
                let! closeBtn = page.QuerySelectorAsync("div[role=\"dialog\"] [aria-label=\"Close\"], div[role=\"dialog\"] button[aria-label=\"Schließen\"], div[role=\"dialog\"] svg")
                if closeBtn <> null then
                    do! closeBtn.ClickAsync()
                    do! Async.Sleep(humanDelay 1000 2000)
                    closed <- true
        with _ -> ()
        
        // Login Pop-up 2: "Jetzt nicht" Button
        try
            let! skipBtn = page.QuerySelectorAsync("button:has-text(\"Jetzt nicht\"), button:has-text(\"Not now\")")
            if skipBtn <> null then
                do! skipBtn.ClickAsync()
                do! Async.Sleep(humanDelay 1000 2000)
                closed <- true
        with _ -> ()
        
        return closed
    }

// Prüfe ob Stream eingeschränkt ist (nach Popup-Handling)
let checkRestrictions (page: IPage) =
    async {
        let restrictionTexts = [
            "text=\"Bei TikTok anmelden\""
            "text=/Dieses LIVE enthält Themen/"
            "text=\"Melde dich an für das vollständige Erlebnis\""
            "text=/Melde dich an für das volle/"
            "text=\"Log in to TikTok\""
            "text=/mature content/"
            "text=/age-restricted/"
        ]
        
        for sel in restrictionTexts do
            try
                let! el = page.QuerySelectorAsync(sel)
                if el <> null then
                    let! visible = el.IsVisibleAsync()
                    if visible then
                        return { restricted = true; reason = Some(sel.Replace("text=", "").Replace("/", "").Replace("\"", "")) }
            with _ -> ()
        
        return { restricted = false; reason = None }
    }

// Playwright-basierte FLV-Extraktion
let extractWithPlaywright (username: string) (qualityPreference: string) =
    async {
        let preflight = playwrightPreflight()
        if not preflight.success then
            return {
                success = false
                method = "playwright"
                status = preflight.status
                username = username
                url = None
                quality = None
                message = None
                error = preflight.error
                restricted = None
                reason = None
                allUrls = None
                allUrlsCount = None
                timestamp = None
            }
        
        try
            let launchOptions = LaunchOptions(
                Headless = true,
                Args = [| "--no-sandbox"; "--disable-setuid-sandbox"; "--disable-gpu"; "--disable-dev-shm-usage" |]
            )
            
            use! browser = Puppeteer.LaunchAsync(launchOptions)
            let! context = browser.CreateIncognitoBrowserContextAsync()
            let! page = context.NewPageAsync()
            
            // Set user agent
            do! page.SetUserAgentAsync("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
            do! page.SetViewportAsync(ViewPortOptions(Width = 1920, Height = 1080))
            
            // FLV-URLs sammeln via Event-Listener BEVOR wir navigieren
            let collectedUrls = ResizeArray<_>()
            
            page.Response.Add(fun response ->
                let url = response.Url
                if collectedUrls.Count < 100 && url.Contains(".flv") && response.Status = HttpStatusCode.OK then
                    collectedUrls.Add({ url = url; status = int response.Status; timestamp = DateTime.UtcNow.ToString("o") })
            )
            
            // Navigiere direkt zu /live
            do! page.GoToAsync($"https://www.tiktok.com/@{username}/live", waitForOptions = NavigationOptions(WaitUntil = [| WaitUntilNavigation.DOMContentLoaded |], Timeout = 30000.))
            
            // Popups schließen
            do! handlePopups page
            
            // Warte auf Seitenaufbau
            do! Async.Sleep(humanDelay 3000 5000)
            try
                do! page.WaitForLoadStateAsync(LoadState.NetworkIdle, waitForOptions = WaitForOptions(Timeout = 10000.))
            with _ -> ()
            
            // Prüfe auf Einschränkungen
            let! restrictions = checkRestrictions page
            if restrictions.restricted then
                log $"Playwright: Stream restricted - {defaultArg restrictions.reason ""}"
                return {
                    success = false
                    method = "playwright"
                    status = "restricted"
                    username = username
                    url = None
                    quality = None
                    message = None
                    error = None
                    restricted = Some true
                    reason = restrictions.reason
                    allUrls = None
                    allUrlsCount = None
                    timestamp = None
                }
            
            // Versuche Video abzuspielen falls nötig
            try
                let! video = page.QuerySelectorAsync("video")
                if video <> null then
                    try
                        do! video.EvaluateFunctionAsync("v => v.play()")
                    with _ -> ()
            with _ -> ()
            
            // Warte auf FLV-URLs (Stream muss laden)
            do! Async.Sleep(humanDelay 8000 12000)
            
            // Zweiter Versuch Popups zu schließen (können nach Delay erscheinen)
            do! handlePopups page
            do! Async.Sleep(humanDelay 3000 5000)
            
            // Nochmal Restrictions prüfen
            let! restrictions2 = checkRestrictions page
            if restrictions2.restricted then
                log $"Playwright: Stream became restricted after wait - {defaultArg restrictions2.reason ""}"
                return {
                    success = false
                    method = "playwright"
                    status = "restricted"
                    username = username
                    url = None
                    quality = None
                    message = None
                    error = None
                    restricted = Some true
                    reason = restrictions2.reason
                    allUrls = None
                    allUrlsCount = None
                    timestamp = None
                }
            
            // URLs auswerten
            if collectedUrls.Count = 0 then
                log "Playwright: No FLV URLs captured via network monitoring."
                return {
                    success = false
                    method = "playwright"
                    status = "offline"
                    username = username
                    url = None
                    quality = None
                    message = None
                    error = None
                    restricted = Some false
                    reason = Some "No FLV URLs found"
                    allUrls = None
                    allUrlsCount = None
                    timestamp = None
                }
            
            // Deduplizieren und nach Qualität sortieren
            let uniqueUrls = 
                collectedUrls
                |> Seq.groupBy (fun item -> item.url.Split('?').[0])
                |> Seq.map snd
                |> Seq.map Seq.head
                |> Seq.toList
            
            // Qualitäts-Präferenz anwenden
            let qualityOrder = 
                match qualityPreference with
                | "original" -> ["_origin.flv"; "_uhd_60.flv"; "_hd_60.flv"; "_hd.flv"; "_sd.flv"; "_ld.flv"]
                | "1080p60" -> ["_uhd_60.flv"; "_hd_60.flv"; "_hd.flv"; "_sd.flv"; "_ld.flv"]
                | "720p60" -> ["_hd_60.flv"; "_hd.flv"; "_sd.flv"; "_ld.flv"]
                | "720p" -> ["_hd.flv"; "_sd.flv"; "_ld.flv"]
                | "540p" -> ["_sd.flv"; "_ld.flv"]
                | "360p" -> ["_ld.flv"]
                | _ -> ["_origin.flv"; "_uhd_60.flv"; "_hd_60.flv"; "_hd.flv"; "_sd.flv"; "_ld.flv"] // auto
            
            let bestUrl = 
                qualityOrder
                |> List.tryPick (fun suffix -> 
                    uniqueUrls 
                    |> List.tryFind (fun u -> u.url.Contains(suffix))
                )
                |> function
                    | Some url -> Some url
                    | None when qualityPreference = "auto" || qualityPreference = "original" -> 
                        uniqueUrls |> List.tryHead
                    | _ -> None
            
            match bestUrl with
            | None ->
                return {
                    success = false
                    method = "playwright"
                    status = "quality_unavailable"
                    username = username
                    url = None
                    quality = None
                    message = None
                    error = None
                    restricted = None
                    reason = Some $"Requested quality {qualityPreference} was not captured in this fresh browser session"
                    allUrls = None
                    allUrlsCount = None
                    timestamp = None
                }
            | Some url ->
                return {
                    success = true
                    status = "live"
                    method = "playwright"
                    username = username
                    url = Some url.url
                    quality = Some qualityPreference
                    message = None
                    error = None
                    restricted = None
                    reason = None
                    allUrls = Some(uniqueUrls |> List.map (fun item -> (item.url, qualityKeyFromUrl item.url)))
                    allUrlsCount = Some uniqueUrls.Length
                    timestamp = Some(DateTime.UtcNow.ToString("o"))
                }
                
        with ex ->
            log $"Playwright error: {ex.Message}"
            return {
                success = false
                method = "playwright"
                status = "technical_error"
                username = username
                url = None
                quality = None
                message = None
                error = Some ex.Message
                restricted = None
                reason = None
                allUrls = None
                allUrlsCount = None
                timestamp = None
            }
    }

// Streamlink Fallback
let tryStreamlink (username: string) (quality: string) =
    async {
        let scriptPath = Path.Combine(__SOURCE_DIRECTORY__, "extraction-methods", "extract-tiktok-streamlink.sh")
        let! execution = runFallback scriptPath [username; quality; "--json"]
        return parseFallbackResult "streamlink" username execution
    }

// yt-dlp Fallback
let tryYtDlp (username: string) (quality: string) =
    async {
        let scriptPath = Path.Combine(__SOURCE_DIRECTORY__, "extraction-methods", "extract-tiktok-yt-dlp.sh")
        let ytFormat = 
            match quality with
            | "original" -> "hls-origin/hls-pull/hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-origin/flv-hd/flv-ld"
            | "1080p60" -> "hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld"
            | "720p60" -> "hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld"
            | "720p" -> "hls-hd/hls-sd/hls-ld/flv-hd/flv-sd/flv-ld"
            | "540p" -> "hls-sd/hls-ld/flv-sd/flv-ld"
            | "360p" -> "hls-ld/flv-ld"
            | _ -> "hls-origin/hls-hd/hls-sd/hls-ld/hls-pull/flv-origin/flv-hd/flv-ld" // auto
        
        let! execution = runFallback scriptPath [username; ytFormat; "--json"]
        return parseFallbackResult "yt-dlp" username execution
    }

// Hauptfunktion mit Fallback-Kette
let getStreamUrl (username: string) (qualityPreference: string) =
    async {
        let timestamp = DateTime.UtcNow.ToString("o")
        
        // --- 1. Playwright ---
        log $"[1/3] Trying Playwright for @{username}..."
        let! pwResult = extractWithPlaywright username qualityPreference
        if pwResult.success then
            return { pwResult with timestamp = Some timestamp }
        
        if pwResult.status = "restricted" || pwResult.status = "overloaded" then
            return pwResult
        
        log $"Playwright result: {defaultArg pwResult.reason (defaultArg pwResult.error "failed")}"
        
        // --- 2. Streamlink (bounded fallback; output is normalized below) ---
        log $"[2/3] Trying streamlink for @{username} (quality: {qualityPreference})..."
        let! slResult = tryStreamlink username qualityPreference
        if slResult.success then
            return slResult
        
        if slResult.status = "restricted" || slResult.status = "overloaded" then
            return slResult
        
        log $"Streamlink result: {defaultArg slResult.message (defaultArg slResult.error "failed")}"
        
        // --- 3. yt-dlp (final bounded fallback; output is normalized below) ---
        log $"[3/3] Trying yt-dlp for @{username}..."
        let! ytResult = tryYtDlp username qualityPreference
        if ytResult.success then
            return ytResult
        
        if ytResult.status = "restricted" || ytResult.status = "overloaded" then
            return ytResult
        
        log $"yt-dlp result: {defaultArg ytResult.message (defaultArg ytResult.error "failed")}"
        
        // --- Alle fehlgeschlagen ---
        let status = classifyFinalFailure [pwResult; slResult; ytResult]
        return {
            success = false
            status = status
            method = ""
            username = username
            url = None
            quality = None
            message = Some "All extraction methods failed (Playwright, streamlink, yt-dlp)."
            error = None
            restricted = None
            reason = None
            allUrls = None
            allUrlsCount = None
            timestamp = Some timestamp
        }
    }

// Helper functions that need to be implemented based on tiktok-common.js
let classifyFinalFailure (_results: ExtractionResult list) = "unknown_failure"
let enforceLoadLimit (_method: string) = ()
let forcedOffline (_method: string) (_username: string) = false
let isSuccessfulStreamResponse (_status: int) (_url: string) = true
let normalizeExtractorResult (_value: obj) (_method: string) (_username: string) = 
    { success = false; status = ""; method = method; username = username; url = None; quality = None; message = None; error = None; restricted = None; reason = None; allUrls = None; allUrlsCount = None; timestamp = None }
let normalizeUsername (username: string) = username
let qualityKeyFromUrl (_url: string) = "unknown"

let exitCodeForResult (_result: ExtractionResult) = 1

// --- CLI ---
[<EntryPoint>]
let main argv =
    if argv.Length < 1 then
        Console.Error.WriteLine("Usage: tiktok-get-stream <username> [quality: original|1080p60|720p60|720p|540p|360p|auto] [--json]")
        1
    else
        try
            let cliUsername = normalizeUsername argv.[0]
            enforceLoadLimit "playwright_streamlink_ytdlp"
            if forcedOffline "playwright_streamlink_ytdlp" cliUsername then
                1
            else
                let cliQuality = 
                    argv 
                    |> Array.skip 1
                    |> Array.tryFind (fun arg -> not (arg.StartsWith("--")))
                    |> Option.defaultValue "auto"
                
                let cliJson = Array.contains "--json" argv
                
                if not (["original"; "1080p60"; "720p60"; "720p"; "540p"; "360p"; "auto"] |> List.contains cliQuality) then
                    Console.Error.WriteLine("Invalid quality; expected original, 1080p60, 720p60, 720p, 540p, 360p, or auto")
                    64
                else
                    let result = getStreamUrl cliUsername cliQuality |> Async.RunSynchronously
                    
                    if cliJson then
                        Console.WriteLine(JsonConvert.SerializeObject(result, Formatting.Indented))
                    else
                        if result.success then
                            Console.WriteLine(defaultArg result.url "")
                        else
                            Console.Error.WriteLine(defaultArg result.message "")
                    
                    exitCodeForResult result
        with ex ->
            Console.Error.WriteLine($"Unhandled error: {ex.Message}")
            2

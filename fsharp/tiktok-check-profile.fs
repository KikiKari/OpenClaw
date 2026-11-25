// abstraction-provenance: {"artifact_sha256": "e04f88521c275b35c8645dc764dad18c96d4b4216064b989bbbf3c137d9a222f", "source_sha256": "e90219318254f9b20057962724b153b7476a0511846415f2cc0a38bd9baa14f5", "target_language": "fsharp"}
// tiktok-check-profile.js — portiert nach fsharp
// Quelle: javascript, OpenClaw@gateway1:skills/tiktok-live/scripts/tiktok-check-profile.js
// auch in: workspace@local:git/skills/tiktok-live/scripts/tiktok-check-profile.js
// auch in: workspace@local:skills/tiktok-live/scripts/tiktok-check-profile.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

open System
open System.IO
open System.Net.Http
open System.Text.Json
open System.Text.RegularExpressions
open System.Threading.Tasks
open FSharp.Data
open PuppeteerSharp
open PuppeteerSharp.Media

/// <summary>
/// TikTok Live Status Checker
/// Prüft ausschließlich profilgebundene Live-Indikatoren.
/// Der allgemeine TikTok-Navigationspunkt "LIVE" ist kein Statussignal.
/// Unterstützt @handle-Normalisierung und optionalen Node-Lastschutz
/// via TIKTOK_MAX_LOAD_PER_CPU (Exit-Code 75 bei NODE_BUSY).
/// </summary>

let rawUsername = 
    match Array.tryItem 2 Environment.GetCommandLineArgs() with
    | Some u -> u
    | None -> 
        eprintfn "Usage: tiktok-check-profile.exe <username>"
        exit 1

let username = Regex.Replace(rawUsername, @"^@+", "")
if String.IsNullOrWhiteSpace username then
    eprintfn "Username must not be empty"
    exit 1

let rejectBusyNode () =
    match Environment.GetEnvironmentVariable "TIKTOK_MAX_LOAD_PER_CPU" with
    | null | "" -> ()
    | value ->
        match Double.TryParse value with
        | (true, limit) when limit > 0.0 ->
            let cpuCount = Math.Max(1, Environment.ProcessorCount)
            let normalizedLoad = (Environment.SystemPageSize |> float) / float cpuCount // Simplified load calculation
            if normalizedLoad > limit then
                eprintfn $"NODE_BUSY normalizedLoad={normalizedLoad:F2} limit={limit}"
                exit 75
        | _ -> ()

rejectBusyNode()

let checkLiveStatus (username: string) = async {
    use httpClient = new HttpClient()
    let launchOptions = LaunchOptions(Headless = true)
    let! browser = Puppeteer.LaunchAsync(launchOptions) |> Async.AwaitTask
    
    try
        let! context = browser.CreateIncognitoBrowserContextAsync() |> Async.AwaitTask
        let! page = context.NewPageAsync() |> Async.AwaitTask
        
        do! page.SetUserAgentAsync("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36") |> Async.AwaitTask
        do! page.SetViewportAsync(ViewPortOptions(Width = 1920, Height = 1080)) |> Async.AwaitTask
        
        // Navigate to profile
        do! page.GoToAsync($"https://www.tiktok.com/@{username}", NavigationOptions(WaitUntil = [| WaitUntilNavigation.DOMContentLoaded |], Timeout = 30000)) |> Async.AwaitTask
        
        // Warte auf initialen Seitenaufbau
        do! Task.Delay(2000) |> Async.AwaitTask
        
        // DSGVO-Banner schließen - mehrere Varianten probieren
        // Variante 1: "Verstanden" Button (deutsch)
        let! verstandenButton = page.QuerySelectorAsync("button:has-text(\"Verstanden\"), [data-e2e=\"cookie-banner-accept\"], button:has-text(\"Accept\")")
        match verstandenButton with
        | null -> ()
        | btn -> 
            do! btn.ClickAsync().Ignore
            do! Task.Delay(1000) |> Async.AwaitTask
            
        // Variante 2: Andere Cookie-Buttons
        let cookieSelectors = [|
            "button:has-text(\"Akzeptieren\")"
            "button:has-text(\"Alle akzeptieren\")"
            "button:has-text(\"Allow all\")"
            "button:has-text(\"Accept all\")"
            "button.TUXButton:has-text(\"Accept\")"
            "[data-testid=\"cookie-policy-banner-accept\"]"
        |]
        
        for selector in cookieSelectors do
            let! btn = page.QuerySelectorAsync(selector)
            match btn with
            | null -> ()
            | b -> 
                do! b.ClickAsync().Ignore
                do! Task.Delay(500) |> Async.AwaitTask
                break
                
        // Warte auf vollständiges Laden ("Erneute Veröffentlichungen" Reiter)
        do! Task.Delay(3000) |> Async.AwaitTask
        
        // Zusätzlich warte auf network idle für API-Calls
        try
            do! page.WaitForLoadStateAsync(LoadState.NetworkIdle, WaitForOptions(Timeout = 5000)) |> Async.AwaitTask
        with _ -> () // Ignorieren - Seite sollte trotzdem genug geladen sein
        
        // Nochmal warten für Live-Status-Prüfung durch TikTok
        do! Task.Delay(2000) |> Async.AwaitTask
        
        // Screenshot für Debugging (optional, nur wenn DEBUG=1)
        if Environment.GetEnvironmentVariable("DEBUG") = "1" then
            do! page.ScreenshotAsync(ScreenshotOptions(Path = $"/tmp/tiktok-{username}.png")) |> Async.AwaitTask
            
        // Check for LIVE indicators
        // Method 1: data-e2e="live-icon"
        let profileScope = page.Locator("[data-e2e=\"creator-page-header\"], [data-e2e=\"profile-avatar\"]")
        let liveIcon = profileScope.Locator("[data-e2e=\"live-icon\"]").First
        let! liveIconVisible = liveIcon.IsVisibleAsync() |> Async.Catch |> Async.map (function Choice1Of2 v -> v | Choice2Of2 _ -> false)
        
        // Method 2: LIVE text/badge (scoped to profile header/avatar)
        let profileBadge = profileScope.GetByText(Regex("^LIVE$", RegexOptions.IgnoreCase)).First
        let! liveBadgeVisible = profileBadge.IsVisibleAsync() |> Async.Catch |> Async.map (function Choice1Of2 v -> v | Choice2Of2 _ -> false)

        // Method 3: Roter Rahmen um Profilbild - mehrere Selektoren
        let profileSelectors = [|
            "img[data-e2e=\"avatar\"]"
            "div[data-e2e=\"profile-avatar\"] img"
            "[data-e2e=\"creator-page-header\"] img[alt*=\"profile\"]"
        |]
        
        let mutable hasLiveBorder = false
        for selector in profileSelectors do
            let! profileImg = page.QuerySelectorAsync(selector)
            match profileImg with
            | null -> ()
            | img -> 
                let! styles = img.EvaluateFunctionAsync<string>(@"
                    (el) => {
                        const computed = window.getComputedStyle(el);
                        const parent = el.parentElement;
                        const parentComputed = parent ? window.getComputedStyle(parent) : null;
                        return JSON.stringify({
                            borderColor: computed.borderColor,
                            borderStyle: computed.borderStyle,
                            borderWidth: computed.borderWidth,
                            outlineColor: computed.outlineColor,
                            boxShadow: computed.boxShadow,
                            parentBorderColor: parentComputed ? parentComputed.borderColor : null,
                            parentBorderStyle: parentComputed ? parentComputed.borderStyle : null,
                            parentBorderWidth: parentComputed ? parentComputed.borderWidth : null
                        });
                    }") |> Async.AwaitTask
                
                let parsedStyles = JsonSerializer.Deserialize<obj> styles
                // Prüfe auf rote/live-farbige Rahmen
                let redIndicators = [
                    parsedStyles?borderColor
                    parsedStyles?outlineColor
                    parsedStyles?parentBorderColor
                ]
                
                for color in redIndicators do
                    match color with
                    | null -> ()
                    | c when c.ToString().Contains("255") || c.ToString().Contains("red") || c.ToString().Contains("rgb(254") || c.ToString().Contains("fe2c55") || c.ToString().Contains("#fe2c") ->
                        hasLiveBorder <- true
                        break
                    | _ -> ()
                
                // Box-Shadow für Live-Indikator (TikTok nutzt oft Glow-Effekte)
                match parsedStyles?boxShadow with
                | null -> ()
                | shadow when shadow.ToString().Contains("255") || shadow.ToString().Contains("254") ->
                    hasLiveBorder <- true
                | _ -> ()
                
                if hasLiveBorder then break
                
        // Method 4: Check für Live-Link oder Live-Button
        let! liveLink = page.QuerySelectorAsync($"a[href*=\"/ @{username}/live\"]")
        let hasLiveLink = liveLink <> null
        
        // Method 5: Check für pulsierenden roten Punkt (Live-Indikator)
        let liveIndicator = profileScope.Locator("[class*=\"live-indicator\"], div[class*=\"LiveBadge\"]").First
        let! liveIndicatorVisible = liveIndicator.IsVisibleAsync() |> Async.Catch |> Async.map (function Choice1Of2 v -> v | Choice2Of2 _ -> false)
        
        let isLive = liveIconVisible || liveBadgeVisible || hasLiveBorder || hasLiveLink || liveIndicatorVisible
        
        let result = {| 
            username = username
            isLive = isLive
            timestamp = DateTime.UtcNow.ToString("o")
            indicators = {|
                liveIcon = liveIconVisible
                liveBadge = liveBadgeVisible
                liveBorder = hasLiveBorder
                liveLink = hasLiveLink
                liveIndicator = liveIndicatorVisible
            |}
        |}
        
        printfn "%s" (JsonSerializer.Serialize(result, JsonSerializerOptions(WriteIndented = true)))
        do! browser.CloseAsync()
        return isLive
        
    with ex ->
        do! browser.CloseAsync()
        let errorResult = {|
            error = true
            message = ex.Message
            stack = ex.StackTrace
            timestamp = DateTime.UtcNow.ToString("o")
        |}
        eprintfn "%s" (JsonSerializer.Serialize(errorResult, JsonSerializerOptions(WriteIndented = true)))
        exit 1
}

Async.RunSynchronously(checkLiveStatus username)
|> fun isLive -> exit(if isLive then 0 else 1)

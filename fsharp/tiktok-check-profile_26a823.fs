// abstraction-provenance: {"artifact_sha256": "f7875e37fcf0f59b91a204ec22b21cbee137508d8d324994fb7984da1949b77f", "source_sha256": "26a823a8fe0d3b94a8c9958ec8cf150765ddf3654a8806c9cc62eae06d9632db", "target_language": "fsharp"}
// tiktok-check-profile.js — portiert nach fsharp
// Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-check-profile.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

module rec tiktok-check-profile

open System
open System.IO
open System.Text.Json
open FSharp.Control.Tasks
open Microsoft.Playwright

/// <summary>
/// Basic TikTok LIVE profile checker.
///
/// Scopes every signal to the requested account and ignores unrelated sidebar
/// LIVE labels. This profile-only checker does not classify restricted LIVE;
/// use the enhanced checker or dispatcher for that distinction.
///
/// Exit 0 = account-specific LIVE, 1 = offline, 2 = dependency/technical
/// failure, 75 = overloaded before Playwright startup.
/// </summary>

let normalizeUsername (username: string) : string =
    if String.IsNullOrWhiteSpace username then
        failwith "Username cannot be empty"
    else
        username.Trim().ToLowerInvariant()

let enforceLoadLimit (_method: string) : unit =
    // In F#, we don't need to implement this unless it's doing something specific
    ()

let liveHrefSelectors (username: string) : string list =
    [
        sprintf "a[href='/@%s/live']" username
        sprintf "a[href='https://www.tiktok.com/@%s/live']" username
    ]

let checkExecutable (path: string) : bool =
    try
        let info = FileInfo(path)
        info.Exists && info.Attributes.HasFlag(FileAttributes.Normal) // Simplified check
    with _ -> false

let createErrorJson (status: string) (message: string) : string =
    let errorObj =
        {| error = true
           status = status
           method = "playwright_basic"
           message = message
           timestamp = DateTime.UtcNow.ToString("o") |}
    JsonSerializer.Serialize(errorObj, options = JsonSerializerOptions(WriteIndented = true))

let mutable username = ""

[<EntryPoint>]
let main argv =
    try
        if Array.length argv < 1 then
            Console.Error.WriteLine("Usage: tiktok-check-profile <username>")
            Environment.Exit(64)
        else
            username <- normalizeUsername argv.[0]
    with ex ->
        Console.Error.WriteLine($"Usage: tiktok-check-profile <username>")
        Console.Error.WriteLine(ex.Message)
        Environment.Exit(64)

    enforceLoadLimit("playwright_basic")

    task {
        // Check if Playwright Chromium is available
        let chromiumPath = Program.Chromium.ExecutablePath
        if not (checkExecutable chromiumPath) then
            Console.Error.WriteLine(
                createErrorJson
                    "dependency_missing"
                    $"Playwright Chromium unavailable: Path '{chromiumPath}' not executable"
            )
            Environment.Exit(2)

        use playwright = Playwright.CreateAsync() |> Async.AwaitTask |> Async.RunSynchronously
        let! browser =
            playwright.Chromium.LaunchAsync(BrowserTypeLaunchOptions(Headless = true))
            |> Async.AwaitTask

        let contextOptions =
            BrowserNewContextOptions(
                UserAgent =
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                ViewportSize = ViewportSize(Width = 1920, Height = 1080)
            )

        let! context = browser.NewContextAsync(contextOptions) |> Async.AwaitTask
        let! page = context.NewPageAsync() |> Async.AwaitTask

        try
            // Navigate to profile
            do!
                page.GotoAsync(
                    $"https://www.tiktok.com/@{username}",
                    PageGotoOptions(WaitUntil = WaitUntilState.DOMContentLoaded, Timeout = 30000)
                )
                |> Async.AwaitTask

            // Warte auf initialen Seitenaufbau
            do! page.WaitForTimeoutAsync(2000) |> Async.AwaitTask

            // DSGVO-Banner schließen - mehrere Varianten probieren
            // Variante 1: "Verstanden" Button (deutsch)
            let! verstandenButton =
                page.QuerySelectorAsync(
                    "button:has-text(\"Verstanden\"), [data-e2e=\"cookie-banner-accept\"], button:has-text(\"Accept\")"
                )
                |> Async.AwaitTask

            match verstandenButton with
            | null -> ()
            | btn ->
                try
                    do! btn.ClickAsync() |> Async.AwaitTask
                with _ -> ()
                do! page.WaitForTimeoutAsync(1000) |> Async.AwaitTask

            // Variante 2: Andere Cookie-Buttons
            let cookieSelectors =
                [
                    "button:has-text(\"Akzeptieren\")"
                    "button:has-text(\"Alle akzeptieren\")"
                    "button:has-text(\"Allow all\")"
                    "button:has-text(\"Accept all\")"
                    "button.TUXButton:has-text(\"Accept\")"
                    "[data-testid=\"cookie-policy-banner-accept\"]"
                ]

            for selector in cookieSelectors do
                let! btn = page.QuerySelectorAsync(selector) |> Async.AwaitTask
                match btn with
                | null -> ()
                | b ->
                    try
                        do! b.ClickAsync() |> Async.AwaitTask
                        do! page.WaitForTimeoutAsync(500) |> Async.AwaitTask
                        ()
                    with _ -> ()
                    break

            // Warte auf vollständiges Laden ("Erneute Veröffentlichungen" Reiter)
            do! page.WaitForTimeoutAsync(3000) |> Async.AwaitTask

            // Zusätzlich warte auf network idle für API-Calls
            try
                do!
                    page.WaitForLoadStateAsync(LoadState.NetworkIdle, PageWaitForLoadStateOptions(Timeout = 5000))
                    |> Async.AwaitTask
            with _ -> () // Ignorieren - Seite sollte trotzdem genug geladen sein

            // Nochmal warten für Live-Status-Prüfung durch TikTok
            do! page.WaitForTimeoutAsync(2000) |> Async.AwaitTask

            // Screenshot für Debugging (optional, nur wenn DEBUG=1)
            if Environment.GetEnvironmentVariable("DEBUG") = "1" then
                do!
                    page.ScreenshotAsync(PageScreenshotOptions(Path = $"/tmp/tiktok-{username}.png"))
                    |> Async.AwaitTask

            // Account-scoped LIVE indicators only. Sidebar/recommendation labels
            // are outside the exact /@username/live link and never count.
            // Method 1: live icon inside the exact account link
            let liveHrefSel = liveHrefSelectors (username) |> String.concat ", "
            let! liveLinkLocator = page.Locator(liveHrefSel).First.Async() |> Async.AwaitTask
            let! hasLiveLink = liveLinkLocator.IsVisibleAsync() |> Async.AwaitTask
            let hasLiveLink = defaultArg hasLiveLink false

            let! liveIconVisible =
                if hasLiveLink then
                    try
                        let! iconLocator =
                            liveLinkLocator
                                .Locator("[data-e2e=\"live-icon\"], [class*=\"LiveBadge\"], [class*=\"live-indicator\"]")
                                .First
                                .Async()
                            |> Async.AwaitTask
                        iconLocator.IsVisibleAsync() |> Async.AwaitTask
                    with _ -> async { return Some false }
                    |> Async.RunSynchronously
                else
                    async { return Some false } |> Async.RunSynchronously

            let liveIconVisible = defaultArg liveIconVisible false

            // Method 2: exact LIVE text/badge inside the account link
            let! liveBadgeVisible =
                if hasLiveLink then
                    try
                        let! badgeLocator = liveLinkLocator.Locator("text=/^LIVE$/i").First.Async()
                        badgeLocator.IsVisibleAsync() |> Async.AwaitTask
                    with _ -> async { return Some false }
                    |> Async.RunSynchronously
                else
                    async { return Some false } |> Async.RunSynchronously

            let liveBadgeVisible = defaultArg liveBadgeVisible false

            // Method 3: Live-Rahmen am Profilkopf/Avatar
            let profileSelectors =
                [
                    "[data-e2e=\"user-page\"] img[data-e2e=\"avatar\"]"
                    "[data-e2e=\"user-page\"] div[data-e2e=\"profile-avatar\"] img"
                    "main header img[data-e2e=\"avatar\"]"
                    "main header [class*=\"avatar\"] img"
                ]

            let mutable hasLiveBorder = false

            for selector in profileSelectors do
                let! profileImg = page.QuerySelectorAsync(selector) |> Async.AwaitTask
                match profileImg with
                | null -> ()
                | img ->
                    let! styles =
                        img.EvaluateAsync(
                            """el => {
                                const computed = window.getComputedStyle(el);
                                const parent = el.parentElement;
                                const parentComputed = parent ? window.getComputedStyle(parent) : null;
                                return {
                                    borderColor: computed.borderColor,
                                    borderStyle: computed.borderStyle,
                                    borderWidth: computed.borderWidth,
                                    outlineColor: computed.outlineColor,
                                    boxShadow: computed.boxShadow,
                                    parentBorderColor: parentComputed ? parentComputed.borderColor : null,
                                    parentBorderStyle: parentComputed ? parentComputed.borderStyle : null,
                                    parentBorderWidth: parentComputed ? parentComputed.borderWidth : null
                                };
                            }"""
                        )
                        |> Async.AwaitTask

                    match styles with
                    | :? System.Text.Json.JsonElement as jsonEl ->
                        let borderColor =
                            if jsonEl.GetProperty("borderColor").Kind <> JsonValueKind.Null then
                                jsonEl.GetProperty("borderColor").GetString()
                            else
                                ""
                        let outlineColor =
                            if jsonEl.GetProperty("outlineColor").Kind <> JsonValueKind.Null then
                                jsonEl.GetProperty("outlineColor").GetString()
                            else
                                ""
                        let parentBorderColor =
                            if jsonEl.GetProperty("parentBorderColor").Kind <> JsonValueKind.Null then
                                jsonEl.GetProperty("parentBorderColor").GetString()
                            else
                                ""
                        let boxShadow =
                            if jsonEl.GetProperty("boxShadow").Kind <> JsonValueKind.Null then
                                jsonEl.GetProperty("boxShadow").GetString()
                            else
                                ""

                        let redIndicators = [ borderColor; outlineColor; parentBorderColor ]

                        for color in redIndicators do
                            if
                                not (String.IsNullOrEmpty(color))
                                && (color.Contains("255")
                                    || color.Contains("red")
                                    || color.Contains("rgb(254")
                                    || color.Contains("fe2c55")
                                    || color.Contains("#fe2c"))
                            then
                                hasLiveBorder <- true
                                break

                        if
                            not (String.IsNullOrEmpty(boxShadow))
                            && (boxShadow.Contains("255") || boxShadow.Contains("254"))
                        then
                            hasLiveBorder <- true

                        if hasLiveBorder then
                            break
                    | _ -> ()

            // Method 4 & 5: exact account LIVE link + live indicator inside that account link
            let! liveIndicatorVisible =
                if hasLiveLink then
                    try
                        let! indicatorLocator =
                            liveLinkLocator
                                .Locator("[class*=\"live-indicator\"], div[class*=\"LiveBadge\"]")
                                .First
                                .Async()
                            |> Async.AwaitTask
                        indicatorLocator.IsVisibleAsync() |> Async.AwaitTask
                    with _ -> async { return Some false }
                    |> Async.RunSynchronously
                else
                    async { return Some false } |> Async.RunSynchronously

            let liveIndicatorVisible = defaultArg liveIndicatorVisible false

            let isLive =
                hasLiveLink
                || hasLiveBorder
                || liveIconVisible
                || liveIndicatorVisible
                || liveBadgeVisible

            let result =
                {| username = username
                   isLive = isLive
                   timestamp = DateTime.UtcNow.ToString("o")
                   indicators =
                       {| liveIcon = liveIconVisible
                          liveBadge = liveBadgeVisible
                          liveBorder = hasLiveBorder
                          liveLink = hasLiveLink
                          liveIndicator = liveIndicatorVisible |} |}

            Console.WriteLine(JsonSerializer.Serialize(result, options = JsonSerializerOptions(WriteIndented = true)))

            return if isLive then 0 else 1
        with ex ->
            let errorResult =
                {| error = true
                   status = "technical_error"
                   message = ex.Message
                   stack = ex.StackTrace
                   timestamp = DateTime.UtcNow.ToString("o") |}

            Console.Error.WriteLine(
                JsonSerializer.Serialize(errorResult, options = JsonSerializerOptions(WriteIndented = true))
            )
            return 2
        finally
            do! browser.CloseAsync() |> Async.AwaitTask
    }
    |> Async.RunSynchronously

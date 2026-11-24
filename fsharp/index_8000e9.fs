// abstraction-provenance: {"artifact_sha256": "d457a5125095b0df8d4c1b8fc4eb49467937906403596c7600a7be286ad5a3d8", "source_sha256": "8000e9809d37f9906f93defd5eae67343fbc40139349c6251ff385eeee2cb8fb", "target_language": "fsharp"}
// index.html — portiert nach fsharp
// Quelle: html, Onboarding@main:development/preview-renders/hover-mock/index.html
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

open System
open System.IO

type HtmlElement = 
    | Element of string * Map<string, string> * HtmlElement list
    | Text of string
    | RawHtml of string

let attr (name: string) (value: string) = name, value
let (=?) name value = attr name value

let element tag attrs children = Element(tag, Map.ofList attrs, children)
let text s = Text(s)
let raw s = RawHtml(s)

let html attrs children = element "html" (("lang", "de") :: attrs) children
let head children = element "head" [] children
let meta attrs = element "meta" attrs []
let title children = element "title" [] children
let style children = element "style" [] children
let link attrs = element "link" attrs []
let body attrs children = element "body" attrs children
let h1 attrs children = element "h1" attrs children
let p attrs children = element "p" attrs children
let div attrs children = element "div" attrs children
let span attrs children = element "span" attrs children
let img attrs = element "img" attrs []

let render (element: HtmlElement): string =
    let rec render' indent el =
        match el with
        | Text s -> s
        | RawHtml s -> s
        | Element(tag, attrs, children) ->
            let attrsStr = 
                attrs 
                |> Map.toList 
                |> List.map (fun (k, v) -> sprintf "%s=\"%s\"" k v)
                |> String.concat " "
                |> (fun s -> if s = "" then "" else " " + s)
            
            if children.IsEmpty then
                sprintf "<%s%s />" tag attrsStr
            else
                let childContent = 
                    children 
                    |> List.map (render' (indent + "  "))
                    |> String.concat ""
                
                if childContent.Contains("<") then
                    sprintf "<%s%s>%s</%s>" tag attrsStr childContent tag
                else
                    sprintf "<%s%s>%s</%s>" tag attrsStr childContent tag
    
    match element with
    | Element(_, _, _) -> render' "" element
    | Text s -> s
    | RawHtml s -> s

let doctype = "<!DOCTYPE html>"

let buildDocument() =
    let cssContent = """
  :root {
    --bg: #FAF8F4;
    --ink: #1B1A17;
    --accent: #A8542F;
    --accent-2: #2E7D7B;
    --font-display: 'Newsreader', Georgia, serif;
    --font-body: 'Hanken Grotesk', -apple-system, sans-serif;
    --font-mono: 'JetBrains Mono', monospace;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: var(--font-body);
    background: var(--bg);
    color: var(--ink);
    padding: 32px 16px 80px;
  }
  h1 {
    font-family: var(--font-display);
    font-weight: 500;
    font-size: 28px;
    max-width: 1400px;
    margin: 0 auto 12px;
  }
  .intro {
    max-width: 1400px;
    margin: 0 auto 32px;
    color: #666;
    font-size: 14px;
    line-height: 1.5;
  }
  .grid {
    display: grid;
    gap: 32px;
    max-width: 1400px;
    margin: 0 auto;
  }
  .variant {
    background: #000;
    border-radius: 16px;
    overflow: hidden;
    box-shadow: 0 12px 40px rgba(0,0,0,0.15);
  }
  .variant-header {
    background: #fff;
    padding: 16px 24px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
    border-bottom: 1px solid #eee;
  }
  .variant-label {
    font-family: var(--font-mono);
    font-size: 11px;
    letter-spacing: 0.2em;
    text-transform: uppercase;
    color: var(--accent);
    font-weight: 600;
  }
  .variant-title {
    font-family: var(--font-display);
    font-size: 20px;
    font-weight: 500;
  }
  .variant-desc {
    font-size: 13px;
    color: #666;
    flex: 1;
    text-align: right;
  }
  .scene {
    position: relative;
    aspect-ratio: 16 / 9;
    background: url('bg.png') center/cover no-repeat;
    overflow: hidden;
  }
  .orb {
    position: absolute;
    width: 12%;
    aspect-ratio: 1;
    left: 42%;
    top: 55%;
    transform: translate(-50%, -50%);
    cursor: pointer;
  }
  .orb img { width: 100%; height: 100%; object-fit: contain; }

  /* Variante 1: Karte daneben */
  .card-preview {
    position: absolute;
    left: 55%;
    top: 45%;
    background: rgba(255,255,255,0.98);
    padding: 16px 20px;
    border-radius: 12px;
    box-shadow: 0 8px 24px rgba(0,0,0,0.25);
    width: 240px;
    animation: slideIn 0.3s ease-out;
  }
  .card-preview .badge {
    display: inline-block;
    background: var(--accent-2);
    color: white;
    font-family: var(--font-mono);
    font-size: 9px;
    letter-spacing: 0.15em;
    text-transform: uppercase;
    padding: 3px 8px;
    border-radius: 3px;
    margin-bottom: 8px;
  }
  .card-preview h3 {
    font-family: var(--font-display);
    font-size: 18px;
    font-weight: 500;
    margin-bottom: 6px;
    color: var(--ink);
  }
  .card-preview p {
    font-size: 12px;
    color: #555;
    line-height: 1.4;
  }
  @keyframes slideIn {
    from { opacity: 0; transform: translateX(-8px); }
    to { opacity: 1; transform: translateX(0); }
  }

  /* Variante 2: Minimaler Tooltip */
  .tooltip {
    position: absolute;
    left: 42%;
    top: 46%;
    transform: translate(-50%, -100%);
    color: white;
    text-shadow: 0 2px 12px rgba(0,0,0,0.8);
    font-family: var(--font-display);
    font-size: 20px;
    font-weight: 500;
    white-space: nowrap;
    animation: fadeUp 0.3s ease-out;
  }
  @keyframes fadeUp {
    from { opacity: 0; transform: translate(-50%, -80%); }
    to { opacity: 1; transform: translate(-50%, -100%); }
  }

  /* Variante 3: Vollflächiges Overlay */
  .full-overlay {
    position: absolute;
    inset: 0;
    background: rgba(0,0,0,0.5);
    backdrop-filter: blur(6px);
    display: flex;
    align-items: center;
    justify-content: center;
    animation: fadeIn 0.35s ease-out;
  }
  .full-overlay .panel {
    background: rgba(255,255,255,0.98);
    padding: 32px 40px;
    border-radius: 20px;
    max-width: 420px;
    box-shadow: 0 20px 60px rgba(0,0,0,0.4);
    text-align: center;
  }
  .full-overlay .badge {
    display: inline-block;
    background: var(--accent);
    color: white;
    font-family: var(--font-mono);
    font-size: 10px;
    letter-spacing: 0.2em;
    text-transform: uppercase;
    padding: 4px 10px;
    border-radius: 4px;
    margin-bottom: 14px;
  }
  .full-overlay h3 {
    font-family: var(--font-display);
    font-size: 28px;
    font-weight: 500;
    margin-bottom: 10px;
    color: var(--ink);
  }
  .full-overlay p {
    font-size: 14px;
    color: #555;
    line-height: 1.5;
    margin-bottom: 20px;
  }
  .full-overlay .preview-img {
    width: 100%;
    aspect-ratio: 16/10;
    background: linear-gradient(135deg, #A8542F, #2E7D7B);
    border-radius: 8px;
    margin-bottom: 16px;
    display: flex;
    align-items: center;
    justify-content: center;
    color: white;
    font-family: var(--font-mono);
    font-size: 11px;
    letter-spacing: 0.15em;
    opacity: 0.9;
  }
  @keyframes fadeIn {
    from { opacity: 0; }
    to { opacity: 1; }
  }

  .instruction {
    text-align: center;
    color: #999;
    font-size: 12px;
    margin-top: 16px;
    font-family: var(--font-mono);
    letter-spacing: 0.15em;
    text-transform: uppercase;
  }

  @media (max-width: 900px) {
    .card-preview { width: 180px; padding: 12px 14px; }
    .card-preview h3 { font-size: 15px; }
    .card-preview p { font-size: 11px; }
    .tooltip { font-size: 15px; }
    .full-overlay .panel { padding: 20px 24px; max-width: 300px; }
    .full-overlay h3 { font-size: 20px; }
  }"""

    html [] [
        head [
            meta [attr "charset" "UTF-8"]
            title [text "Hover-Preview Varianten · Vergleich"]
            style [raw cssContent]
            link [
                attr "rel" "preconnect"
                attr "href" "https://fonts.googleapis.com"
            ]
            link [
                attr "rel" "preconnect"
                attr "href" "https://fonts.gstatic.com"
                attr "crossorigin" "anonymous"
            ]
            link [
                attr "href" "https://fonts.googleapis.com/css2?family=Newsreader:wght@400;500&family=Hanken+Grotesk:wght@400;500&family=JetBrains+Mono:wght@400;500&display=swap"
                attr "rel" "stylesheet"
            ]
        ]
        body [] [
            h1 [("class", "title")] [
                text "Hover-Preview · drei Varianten im Vergleich"
            ]
            p [("class", "intro")] [
                text "Gleiche Szene, gleiche Kugel-Position (Beispiel: Projekt-Kugel \"Weather-Check\")."
                raw "<br>"
                text "Alle drei Varianten zeigen den Zustand "
                raw "<em>bei Maushover</em>"
                text ". Welche soll ins Projekt?"
            ]
            div [("class", "grid")] [
                // Variante 1
                div [("class", "variant")] [
                    div [("class", "variant-header")] [
                        div [] [
                            div [("class", "variant-label")] [text "Variante 1"]
                            div [("class", "variant-title")] [text "Karte daneben"]
                        ]
                        div [("class", "variant-desc")] [
                            text "Kompakte Card rechts der Kugel · Titel + Badge + kurze Beschreibung aus content.ts · dezent, nicht störend"
                        ]
                    ]
                    div [("class", "scene")] [
                        div [("class", "orb")] [
                            img [
                                attr "src" "orb-01-teal.png"
                                attr "alt" ""
                            ]
                        ]
                        div [("class", "card-preview")] [
                            span [("class", "badge")] [text "GitHub · Public"]
                            element "h3" [] [text "Weather-Check"]
                            p [] [
                                text "Progressive Web App für lokale Wetterdaten mit Live-Radar und Push-Benachrichtigungen."
                            ]
                        ]
                    ]
                ]

                // Variante 2
                div [("class", "variant")] [
                    div [("class", "variant-header")] [
                        div [] [
                            div [("class", "variant-label")] [text "Variante 2"]
                            div [("class", "variant-title")] [text "Minimaler Tooltip"]
                        ]
                        div [("class", "variant-desc")] [
                            text "Nur der Titel schwebt über der Kugel · maximal reduziert · schnell erfassbar · lässt die Bildwirkung ungestört"
                        ]
                    ]
                    div [("class", "scene")] [
                        div [("class", "orb")] [
                            img [
                                attr "src" "orb-01-teal.png"
                                attr "alt" ""
                            ]
                        ]
                        div [("class", "tooltip")] [text "Weather-Check"]
                    ]
                ]

                // Variante 3
                div [("class", "variant")] [
                    div [("class", "variant-header")] [
                        div [] [
                            div [("class", "variant-label")] [text "Variante 3"]
                            div [("class", "variant-title")] [text "Vollflächiges Overlay"]
                        ]
                        div [("class", "variant-desc")] [
                            text "Zentrales Modal mit Preview-Bild + Titel + Beschreibung · prominent · lädt zum Klicken ein · verdeckt aber Szene"
                        ]
                    ]
                    div [("class", "scene")] [
                        div [("class", "orb")] [
                            img [
                                attr "src" "orb-01-teal.png"
                                attr "alt" ""
                            ]
                        ]
                        div [("class", "full-overlay")] [
                            div [("class", "panel")] [
                                div [("class", "preview-img")] [text "PROJEKT-PREVIEW"]
                                span [("class", "badge")] [text "GitHub · Public"]
                                element "h3" [] [text "Weather-Check"]
                                p [] [
                                    text "Progressive Web App für lokale Wetterdaten mit Live-Radar und Push-Benachrichtigungen."
                                ]
                            ]
                        ]
                    ]
                ]
            ]
            p [("class", "instruction")] [
                text "Sag mir welche Variante — dann baue ich sie ins Frontend ein."
            ]
        ]
    ]

[<EntryPoint>]
let main argv =
    let document = buildDocument()
    let htmlString = doctype + "\n" + (render document)
    
    let outputPath = 
        if argv.Length > 0 then argv.[0] 
        else "index.html"
    
    File.WriteAllText(outputPath, htmlString)
    printfn "HTML file generated at: %s" outputPath
    0

// abstraction-provenance: {"artifact_sha256": "c81a1eb9ce56c1f367d6051ae51fa4f14ec9668d2746c8bac862c52ebefb1933", "source_sha256": "02dd111b283ac08d7a9f3fbbe30150fb6db98097ed7bc68f2677c6df9c744bfb", "target_language": "fsharp"}
// index.html — portiert nach fsharp
// Quelle: html, Projects@Vision-Check:Vision-Check/app/index.html
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

open System
open System.IO
open System.Text

type HtmlElement =
    { tag: string
      attributes: Map<string, string>
      children: HtmlNode list }
and HtmlNode =
    | Element of HtmlElement
    | Text of string

let createElement tag attrs children =
    Element { tag = tag; attributes = Map attrs; children = children }

let createText text = Text text

let buildHtmlDocument (root: HtmlElement) =
    let sb = StringBuilder()
    
    let rec writeNode (node: HtmlNode) =
        match node with
        | Text t -> sb.Append(t) |> ignore
        | Element e ->
            sb.AppendFormat("<{0}", e.tag) |> ignore
            e.attributes
            |> Map.iter (fun key value ->
                sb.AppendFormat(" {0}=\"{1}\"", key, value) |> ignore)
            sb.Append(">") |> ignore
            
            e.children |> List.iter writeNode
            
            sb.AppendFormat("</{0}>", e.tag) |> ignore
    
    sb.AppendLine("<!DOCTYPE html>") |> ignore
    writeNode (Element root)
    sb.ToString()

let generateIndexHtml () =
    let head =
        createElement "head" [] [
            createElement "meta" [("charset", "UTF-8")] []
            createElement "meta" [("name", "viewport"); ("content", "width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no")] []
            createElement "meta" [("name", "theme-color"); ("content", "#0a0f1e")] []
            createElement "meta" [("name", "description"); ("content", "Lokale KI-gestützte Bildanalyse für Tiere & Insekten")] []
            createElement "meta" [("name", "apple-mobile-web-app-capable"); ("content", "yes")] []
            createElement "meta" [("name", "apple-mobile-web-app-status-bar-style"); ("content", "black-translucent")] []
            
            createElement "title" [] [createText "Vision-Check"]
            
            createElement "link" [("rel", "manifest"); ("href", "manifest.json")] []
            createElement "link" [("rel", "icon"); ("type", "image/svg+xml"); ("href", "icons/icon.svg")] []
            createElement "link" [("rel", "apple-touch-icon"); ("href", "icons/icon-192.png")] []
            
            // Fonts
            createElement "link" [("rel", "preconnect"); ("href", "https://fonts.googleapis.com")] []
            createElement "link" [("href", "https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;600&display=swap"); ("rel", "stylesheet")] []
            
            // TensorFlow.js + COCO-SSD
            createElement "script" [("src", "https://cdn.jsdelivr.net/npm/@tensorflow/tfjs@4.22.0/dist/tf.min.js"); ("defer", "")] []
            createElement "script" [("src", "https://cdn.jsdelivr.net/npm/@tensorflow-models/coco-ssd@2.2.3/dist/coco-ssd.min.js"); ("defer", "")] []
            
            // App CSS
            createElement "link" [("rel", "stylesheet"); ("href", "css/style.css")] []
        ]
    
    let headerBrand =
        createElement "div" [("class", "header-brand")] [
            createElement "svg" [("viewBox", "0 0 24 24"); ("fill", "none"); ("stroke", "currentColor"); ("stroke-width", "1.8"); ("stroke-linecap", "round"); ("stroke-linejoin", "round")] [
                createElement "circle" [("cx", "12"); ("cy", "12"); ("r", "3")] []
                createElement "path" [("d", "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2z"); ("opacity", ".3")] []
                createElement "path" [("d", "M12 8a4 4 0 0 1 4 4")] []
                createElement "path" [("d", "M8 12a4 4 0 0 1 4-4")] []
                createElement "path" [("d", "M12 16a4 4 0 0 1-4-4")] []
                createElement "path" [("d", "M16 12a4 4 0 0 1-4 4")] []
            ]
            createElement "h1" [] [createText "Vision-Check"]
        ]
    
    let layerIndicator =
        createElement "div" [("style", "display:flex;align-items:center;gap:6px;font-size:11px;color:var(--text-dim)")] [
            createElement "div" [("class", "layer-indicator"); ("title", "Aktive KI-Schichten")] [
                createElement "div" [("class", "layer-dot"); ("data-layer", "0"); ("style", "color:var(--layer-0);background:var(--layer-0)"); ("title", "iNaturalist")] []
                createElement "div" [("class", "layer-dot"); ("data-layer", "1"); ("style", "color:var(--layer-1);background:var(--layer-1)"); ("title", "TF.js COCO-SSD")] []
                createElement "div" [("class", "layer-dot"); ("data-layer", "2"); ("style", "color:var(--layer-2);background:var(--layer-2)"); ("title", "Canvas-Filter")] []
                createElement "div" [("class", "layer-dot"); ("data-layer", "3"); ("style", "color:var(--layer-3-gpt);background:var(--layer-3-gpt)"); ("title", "Cloud APIs")] []
            ]
        ]
    
    let settingsButton =
        createElement "button" [("class", "btn btn-icon"); ("id", "btn-settings"); ("title", "Einstellungen / API-Keys")] [
            createElement "svg" [("width", "16"); ("height", "16"); ("viewBox", "0 0 24 24"); ("fill", "none"); ("stroke", "currentColor"); ("stroke-width", "2")] [
                createElement "circle" [("cx", "12"); ("cy", "12"); ("r", "3")] []
                createElement "path" [("d", "M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z")] []
            ]
        ]
    
    let headerControls =
        createElement "div" [("class", "header-controls")] [
            settingsButton
        ]
    
    let appHeader =
        createElement "header" [("id", "app-header")] [
            headerBrand
            layerIndicator
            headerControls
        ]
    
    // Camera panel
    let cameraPanel =
        createElement "div" [("id", "camera-panel")] [
            createElement "div" [("class", "panel-header")] [
                createElement "span" [("class", "panel-title")] [createText "Kamera / Bild"]
                createElement "div" [("style", "display:flex;align-items:center;gap:8px")] [
                    createElement "span" [("id", "resolution-info"); ("style", "font-size:10px;color:var(--text-dim)")] [createText "–"]
                    createElement "span" [("id", "cam-badge"); ("class", "badge badge-idle")] [createText "Bereit"]
                ]
            ]
            
            createElement "div" [("id", "camera-viewport")] [
                createElement "video" [("id", "video"); ("autoplay", ""); ("playsinline", ""); ("muted", "")] []
                createElement "canvas" [("id", "canvas-overlay")] []
                createElement "canvas" [("id", "snap-canvas"); ("style", "display:none")] []
                createElement "canvas" [("id", "filtered-canvas"); ("style", "display:none")] []
                
                // Pixel-Lupe
                createElement "div" [("id", "pixel-loupe")] [
                    createElement "canvas" [("id", "loupe-canvas"); ("width", "160"); ("height", "160")] []
                    createElement "div" [("id", "loupe-info")] [createText "–"]
                ]
                
                // Start-Overlay
                createElement "div" [("id", "start-overlay"); ("style", "position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:16px;background:rgba(10,15,30,0.8)")] [
                    createElement "svg" [("width", "48"); ("height", "48"); ("viewBox", "0 0 24 24"); ("fill", "none"); ("stroke", "var(--accent)"); ("stroke-width", "1.5")] [
                        createElement "path" [("d", "M23 7l-7 5 7 5V7z")] []
                        createElement "rect" [("x", "1"); ("y", "5"); ("width", "15"); ("height", "14"); ("rx", "2"); ("ry", "2")] []
                    ]
                    createElement "p" [("style", "color:var(--text-muted);font-size:13px;text-align:center")] [createText "Kamera starten oder Bild hochladen"]
                    createElement "div" [("style", "display:flex;gap:8px")] [
                        createElement "button" [("class", "btn btn-primary"); ("id", "btn-start-camera")] [
                            createElement "svg" [("width", "14"); ("height", "14"); ("viewBox", "0 0 24 24"); ("fill", "none"); ("stroke", "currentColor"); ("stroke-width", "2")] [
                                createElement "path" [("d", "M23 7l-7 5 7 5V7z")] []
                                createElement "rect" [("x", "1"); ("y", "5"); ("width", "15"); ("height", "14"); ("rx", "2"); ("ry", "2")] []
                            ]
                            createText "Kamera starten"
                        ]
                        createElement "button" [("class", "btn"); ("id", "btn-upload")] [
                            createElement "svg" [("width", "14"); ("height", "14"); ("viewBox", "0 0 24 24"); ("fill", "none"); ("stroke", "currentColor"); ("stroke-width", "2")] [
                                createElement "path" [("d", "M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4")] []
                                createElement "polyline" [("points", "17 8 12 3 7 8")] []
                                createElement "line" [("x1", "12"); ("y1", "3"); ("x2", "12"); ("y2", "15")] []
                            ]
                            createText "Bild laden"
                        ]
                    ]
                ]
            ]
            
            // Camera controls
            createElement "div" [("id", "camera-controls")] [
                createElement "select" [("id", "camera-select"); ("style", "max-width:160px")] []
                createElement "select" [("id", "resolution-select"); ("style", "max-width:140px")] []
                createElement "div" [("style", "flex:1")] []
                createElement "button" [("class", "btn btn-icon"); ("id", "btn-toggle-loupe"); ("title", "Pixel-Lupe ein/aus")] [
                    createElement "svg" [("width", "14"); ("height", "14"); ("viewBox", "0 0 24 24"); ("fill", "none"); ("stroke", "currentColor"); ("stroke-width", "2")] [
                        createElement "circle" [("cx", "11"); ("cy", "11"); ("r", "8")] []
                        createElement "line" [("x1", "21"); ("y1", "21"); ("x2", "16.65"); ("y2", "16.65")] []
                        createElement "line" [("x1", "11"); ("y1", "8"); ("x2", "11"); ("y2", "14")] []
                        createElement "line" [("x1", "8"); ("y1", "11"); ("x2", "14"); ("y2", "11")] []
                    ]
                ]
                createElement "button" [("class", "btn btn-snap"); ("id", "btn-snap"); ("disabled", "")] [
                    createElement "svg" [("width", "14"); ("height", "14"); ("viewBox", "0 0 24 24"); ("fill", "none"); ("stroke", "currentColor"); ("stroke-width", "2")] [
                        createElement "circle" [("cx", "12"); ("cy", "12"); ("r", "3")] []
                        createElement "path" [("d", "M20 7h-3a2 2 0 0 1-2-2V4a2 2 0 0 0-2-2h-2a2 2 0 0 0-2 2v1a2 2 0 0 1-2 2H4a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2z")] []
                    ]
                    createText "Snapshot"
                ]
            ]
        ]
    
    // Right panel - Filter card
    let filterCard =
        createElement "div" [("class", "card")] [
            createElement "div" [("class", "panel-header")] [
                createElement "span" [("class", "panel-title"); ("style", "color:var(--layer-2)")] [createText "Schicht 2 — Filter"]
                createElement "button" [("class", "btn btn-sm"); ("id", "btn-reset-filters")] [createText "Reset"]
            ]
            createElement "div" [("class", "card-body")] [
                createElement "div" [("class", "slider-row")] [
                    createElement "span" [("class", "slider-label")] [createText "Helligkeit"]
                    createElement "input" [("type", "range"); ("id", "slider-brightness"); ("min", "-80"); ("max", "80"); ("value", "0"); ("step", "1")] []
                    createElement "span" [("class", "slider-value"); ("id", "val-brightness")] [createText "0"]
                ]
                createElement "div" [("class", "slider-row")] [
                    createElement "span" [("class", "slider-label")] [createText "Sättigung"]
                    createElement "input" [("type", "range"); ("id", "slider-saturation"); ("min", "0"); ("max", "3"); ("value", "1.2"); ("step", "0.1")] []
                    createElement "span" [("class", "slider-value"); ("id", "val-saturation")] [createText "1.2"]
                ]
                createElement "div" [("class", "slider-row")] [
                    createElement "span" [("class", "slider-label")] [createText "CLAHE (Kontrast)"]
                    createElement "input" [("type", "range"); ("id", "slider-clahe"); ("min", "1"); ("max", "4"); ("value", "1.5"); ("step", "0.1")] []
                    createElement "span" [("class", "slider-value"); ("id", "val-clahe")] [createText "1.5x"]
                ]
                createElement "div" [("class", "slider-row")] [
                    createElement "span" [("class", "slider-label")] [createText "Schärfe (Unsharp)"]
                    createElement "input" [("type", "range"); ("id", "slider-unsharp"); ("min", "0"); ("max", "5"); ("value", "2"); ("step", "1")] []
                    createElement "span" [("class", "slider-value"); ("id", "val-unsharp")] [createText "2"]
                ]
            ]
        ]
    
    // Snapshot preview
    let snapshotArea =
        createElement "div" [("class", "card"); ("id", "snapshot-area"); ("style", "display:none")] [
            createElement "div" [("class", "panel-header")] [
                createElement "span" [("class", "panel-title")] [createText "Snapshot (gefiltert)"]
                createElement "div" [("style", "display:flex;gap:4px")] [
                    createElement "button" [("class", "btn btn-sm"); ("id", "btn-upload-replace")] [
                        createElement "svg" [("width", "12"); ("height", "12"); ("viewBox", "0 0 24 24"); ("fill", "none"); ("stroke", "currentColor"); ("stroke-width", "2")] [
                            createElement "path" [("d", "M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4")] []
                            createElement "polyline" [("points", "17 8 12 3 7 8")] []
                            createElement "line" [("x1", "12"); ("y1", "3"); ("x2", "12"); ("y2", "15")] []
                        ]
                        createText "Ersetzen"
                    ]
                ]
            ]
            createElement "div" [("class", "card-body"); ("style", "padding:0")] [
                createElement "img" [("id", "snapshot-preview"); ("style", "width:100%;display:block;border-radius:0 0 14px 14px"); ("alt", "Snapshot")] []
            ]
        ]
    
    // Pixel inspector
    let pixelInspector =
        createElement "div" [("class", "card")] [
            createElement "div" [("class", "panel-header")] [
                createElement "span" [("class", "panel-title")] [createText "Pixel-Inspektor"]
                createElement "span" [("style", "font-size:10px;color:var(--text-dim)")] [createText "8× Zoom-Lupe"]
            ]
            createElement "div" [("class", "card-body")] [
                createElement "div" [("id", "pixel-info")] [
                    createElement "div" [("class", "pixel-swatch"); ("id", "pixel-swatch"); ("style", "background:#333")] []
                    createElement "div" [("class", "pixel-values")] [
                        createElement "span" [("id", "pixel-values-text"); ("style", "color:var(--text-dim);font-size:11px")] [createText "Maus über Bild bewegen"]
                    ]
                ]
                createElement "p" [("style", "font-size:10px;color:var(--text-dim);margin-top:8px")] [
                    createText "Lupe-Icon aktivieren → Lupe über Bild fahren"
                ]
            ]
        ]
    
    // Analysis panel tabs
    let tabButtons =
        createElement "div" [("class", "tab-bar")] [
            createElement "button" [("class", "tab active"); ("data-tab", "tab-inat")] [
                createElement "span" [("style", "color:var(--layer-0)")] [createText "● "]
                createText "iNaturalist"
            ]
            createElement "button" [("class", "tab"); ("data-tab", "tab-layer1")] [
                createElement "span" [("style", "color:var(--layer-1)")] [createText "● "]
                createText "Lokal"
            ]
            createElement "button" [("class", "tab"); ("data-tab", "tab-cloud")] [
                createElement "span" [("style", "color:var(--layer-3-gpt)")] [createText "● "]
                createText "Cloud"
            ]
        ]
    
    let tabContents =
        createElement "div" [] [
            createElement "div" [("id", "tab-content-inat"); ("class", "tab-content active"); ("style", "padding:12px")] [
                createElement "div" [("id", "result-layer0")] [
                    createElement "p" [("style", "color:var(--text-dim);font-size:12px")] [createText "iNaturalist — Artenbestimmung nach Snapshot + Analyse"]
                ]
            ]
            createElement "div" [("id", "tab-content-layer1"); ("class", "tab-content"); ("style", "padding:12px")] [
                createElement "div" [("style", "margin-bottom:8px")] [
                    createElement "span" [("class", "badge"); ("style", "color:var(--layer-1);background:rgba(79,209,197,0.1)")] [createText "TF.js COCO-SSD — Live-Erkennung"]
                ]
                createElement "div" [("id", "result-layer1")] [
                    createElement "p" [("style", "color:var(--text-dim);font-size:12px")] [createText "Echtzeit-Detektion läuft nach Kamera-Start"]
                ]
            ]
            createElement "div" [("id", "tab-content-cloud"); ("class", "tab-content"); ("style", "padding:12px")] [
                createElement "div" [("id", "results-container")] [
                    createElement "div" [("id", "result-layer3")] [
                        createElement "p" [("style", "color:var(--text-dim);font-size:12px")] [createText "Cloud-APIs (GPT-4o / Gemini 2.5 / Claude) nach Snapshot + Analyse-Button"]
                    ]
                ]
            ]
        ]
    
    let analyzeButton =
        createElement "div" [("style", "padding:12px;border-top:1px solid var(--border)")] [
            createElement "button" [("class", "btn btn-primary"); ("id", "btn-analyze"); ("disabled", ""); ("style", "width:100%;justify-content:center;padding:10px")] [
                createElement "svg" [("width", "14"); ("height", "14"); ("viewBox", "0 0 24 24"); ("fill", "none"); ("stroke", "currentColor"); ("stroke-width", "2")] [
                    createElement "circle" [("cx", "11"); ("cy", "11"); ("r", "8")] []
                    createElement "line" [("x1", "21"); ("y1", "21"); ("x2", "16.65"); ("y2", "16.65")] []
                ]
                createText "Alle APIs analysieren"
            ]
        ]
    
    let analysisPanel =
        createElement "div" [("class", "card"); ("style", "flex:1")] [
            createElement "div" [("class", "panel-header")] [
                createElement "span" [("class", "panel-title")] [createText "Analyse-Ergebnisse"]
                createElement "div" [("id", "analyze-spinner"); ("class", "spinner"); ("style", "display:none")] []
            ]
            tabButtons
            tabContents
            analyzeButton
        ]
    
    let rightPanel =
        createElement "div" [("id", "right-panel")] [
            filterCard
            snapshotArea
            pixelInspector
            analysisPanel
        ]
    
    // Status bar
    let statusBar =
        createElement "div" [("id", "status-bar")] [
            createElement "div" [("id", "status-dot"); ("class", "status-dot")] []
            createElement "span" [("id", "status-text")] [createText "Initialisiere..."]
        ]
    
    // Board
    let board =
        createElement "div" [("id", "board")] [
            cameraPanel
            rightPanel
            statusBar
        ]
    
    // Settings modal
    let settingsModal =
        createElement "div" [("id", "settings-modal")] [
            createElement "div" [("class", "modal-box"); ("style", "width:560px")] [
                createElement "div" [("class", "modal-title")] [createText "⚙ Einstellungen & API-Keys"]
                
                // Security notice
                createElement "div" [("style", "background:rgba(251,211,141,0.1);border:1px solid rgba(251,211,141,0.3);border-radius:8px;padding:10px 12px;margin-bottom:20px;font-size:11px;color:var(--accent-warn)")] [
                    createText "🔒 Alle API-Keys bleiben ausschließlich lokal in deinem Browser (localStorage). Kein Backend, keine Weiterleitung."
                ]
                
                // OpenAI section
                createElement "div" [("class", "settings-section")] [
                    createElement "div" [("class", "settings-section-title"); ("style", "color:var(--layer-3-gpt)")] [createText "OpenAI — GPT-4o Vision"]
                    createElement "label" [("class", "settings-label")] [createText "API-Key (sk-proj-…)"]
                    createElement "input" [("class", "settings-input"); ("type", "password"); ("id", "openai-key"); ("placeholder", "sk-proj-...")] []
                    createElement "p" [("class", "settings-hint")] [
                        createText "Aus "
                        createElement "a" [("href", "https://platform.openai.com/api-keys"); ("target", "_blank"); ("style", "color:var(--accent)")] [createText "platform.openai.com/api-keys"]
                        createText " — kein CORS-Problem, direkt nutzbar."
                    ]
                ]
                
                // Gemini section
                createElement "div" [("class", "settings-section")] [
                    createElement "div" [("class", "settings-section-title"); ("style", "color:var(--layer-3-gemini)")] [createText "Google Gemini — 2.5 Pro Vision"]
                    createElement "label" [("class", "settings-label")] [createText "API-Key (AIza…)"]
                    createElement "input" [("class", "settings-input"); ("type", "password"); ("id", "gemini-key"); ("placeholder", "AIzaSy...")] []
                    createElement "p" [("class", "settings-hint")] [
                        createText "Aus "
                        createElement "a" [("href", "https://aistudio.google.com/app/apikey"); ("target", "_blank"); ("style", "color:var(--accent)")] [createText "Google AI Studio"]
                        createText " — kein CORS-Problem."
                    ]
                ]
                
                // Claude section
                createElement "div" [("class", "settings-section")] [
                    createElement "div" [("class", "settings-section-title"); ("style", "color:var(--layer-3-claude)")] [createText "Anthropic Claude — Opus 4.8 / Fable 5"]
                    createElement "label" [("class", "settings-label")] [createText "API-Key (sk-ant-…)"]
                    createElement "input" [("class", "settings-input"); ("type", "password"); ("id", "claude-key"); ("placeholder", "sk-ant-...")] []
                    createElement "p" [("class", "settings-hint")] [
                        createText "Aus "
                        createElement "a" [("href", "https://console.anthropic.com"); ("target", "_blank"); ("style", "color:var(--accent)")] [createText "console.anthropic.com"]
                    ]
                    
                    createElement "label" [("class", "settings-label"); ("style", "margin-top:12px")] [createText "Modell"]
                    createElement "select" [("class", "settings-input"); ("id", "claude-model"); ("style", "padding:8px 12px")] [
                        createElement "option" [("value", "claude-opus-4-8")] [createText "claude-opus-4-8 (High-Res Vision)"]
                        createElement "option" [("value", "claude-fable-5")] [createText "claude-fable-5 (High-Res Vision)"]
                    ]
                    
                    createElement "label" [("class", "settings-label"); ("style", "margin-top:12px")] [createText "CORS-Proxy URL "; createElement "span" [("style", "color:var(--accent-warn)")] [createText "(erforderlich für Claude)"]]
                    createElement "input" [("class", "settings-input"); ("type", "url"); ("id", "claude-proxy"); ("placeholder", "https://your-worker.workers.dev")] []
                    createElement "p" [("class", "settings-hint")] [
                        createText "Cloudflare Worker als CORS-Pass-Through nötig (Browser blockiert direkte Anthropic-Calls).\nAnleitung: "
                        createElement "a" [("href", "https://github.com/seveibar/cloudflare-cors-proxy"); ("target", "_blank"); ("style", "color:var(--accent)")] [createText "cloudflare-cors-proxy"]
                        createText " — kostenlos, 100k Req/Tag Free-Tier."
                    ]
                ]
                
                // Feature flags
                createElement "div" [("class", "settings-section")] [
                    createElement "div" [("class", "settings-section-title")] [createText "Funktionen"]
                    
                    createElement "div" [("style", "display:flex;align-items:center;justify-content:space-between;margin-bottom:10px")] [
                        createElement "div" [] [
                            createElement "div" [("style", "font-size:12px;font-weight:600;color:var(--layer-0)")] [createText "iNaturalist (Schicht 0)"]
                            createElement "div" [("style", "font-size:10px;color:var(--text-dim)")] [createText "Kein API-Key nötig — kostenlos"]
                        ]
                        createElement "label" [("class", "toggle-switch")] [
                            createElement "input" [("type", "checkbox"); ("id", "inat-toggle"); ("checked", "")] []
                            createElement "div" [("class", "toggle-track")] []
                            createElement "div" [("class", "toggle-thumb")] []
                        ]
                    ]
                    
                    createElement "div" [("style", "display:flex;align-items:center;justify-content:space-between")] [
                        createElement "div" [] [
                            createElement "div" [("style", "font-size:12px;font-weight:600")] [createText "Auto-Analyse nach Snapshot"]
                            createElement "div" [("style", "font-size:10px;color:var(--text-dim)")] [createText "Sofort alle APIs aufrufen"]
                        ]
                        createElement "label" [("class", "toggle-switch")] [
                            createElement "input" [("type", "checkbox"); ("id", "auto-analyze")] []
                            createElement "div" [("class", "toggle-track")] []
                            createElement "div" [("class", "toggle-thumb")] []
                        ]
                    ]
                ]
                
                // Buttons
                createElement "div" [("style", "display:flex;gap:8px;justify-content:flex-end;margin-top:8px")] [
                    createElement "button" [("class", "btn"); ("id", "settings-close")] [createText "Abbrechen"]
                    createElement "button" [("class", "btn btn-primary"); ("id", "settings-save")] [createText "Speichern"]
                ]
            ]
        ]
    
    // Hidden elements
    let hiddenElements =
        createElement "div" [] [
            createElement "input" [("type", "file"); ("id", "file-input"); ("accept", "image/*"); ("capture", "environment"); ("style", "display:none")] []
            createElement "div" [("id", "upload-zone"); ("style", "display:none")] [createText "Bild hierher ziehen oder klicken"]
        ]
    
    // Scripts
    let scripts =
        createElement "div" [] [
            createElement "script" [("src", "js/settings.js")] []
            createElement "script" [("src", "js/camera.js")] []
            createElement "script" [("src", "js/filters.js")] []
            createElement "script" [("src", "js/cloud-api.js")] []
            createElement "script" [("src", "js/providers.js")] []
            createElement "script" [("src", "js/env-manager.js")] []
            createElement "script" [("src", "js/app.js")] []
        ]
    
    let body =
        createElement "body" [] [
            createElement "div" [("id", "app")] [
                appHeader
                board
            ]
            settingsModal
            hiddenElements
            scripts
        ]
    
    createElement "html" [("lang", "de")] [
        head
        body
    ]

[<EntryPoint>]
let main argv =
    let htmlDoc = generateIndexHtml()
    let htmlContent = buildHtmlDocument htmlDoc
    
    let outputPath = 
        if argv.Length > 0 then argv.[0]
        else "index.html"
    
    File.WriteAllText(outputPath, htmlContent)
    printfn "HTML file generated at %s" outputPath
    0

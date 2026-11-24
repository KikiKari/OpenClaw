// abstraction-provenance: {"artifact_sha256": "6bf1d947dc1b5808cf7a8815fd784aa99c6f6c33b0b1eaf761a2589ed1bc4cb8", "source_sha256": "be7071091b8a4e461f665879c436317756f6591f0bcf132f78e03c8b0bb8eb0d", "target_language": "fsharp"}
// grouped.css — portiert nach fsharp
// Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles/chat/grouped.css
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

open System
open System.IO

type CssRule = {
    Selector: string
    Properties: Map<string, string>
}

type MediaQuery = {
    Condition: string
    Rules: CssRule list
}

type StyleSheet = {
    Rules: CssRule list
    MediaQueries: MediaQuery list
}

let createRule selector properties =
    { Selector = selector; Properties = Map properties }

let createMediaQuery condition rules =
    { Condition = condition; Rules = rules }

let groupedChatLayout : StyleSheet = {
    Rules = [
        // Chat Group Layout - default (assistant/other on left)
        createRule ".chat-group" [
            ("display", "flex")
            ("gap", "10px")
            ("align-items", "flex-start")
            ("margin-bottom", "14px")
            ("margin-left", "4px")
            ("margin-right", "16px")
        ]

        // User messages on right
        createRule ".chat-group.user" [
            ("flex-direction", "row-reverse")
            ("justify-content", "flex-start")
        ]

        createRule ".chat-group-messages" [
            ("display", "flex")
            ("flex-direction", "column")
            ("gap", "2px")
            ("flex", "1 1 auto")
            ("max-width", "min(900px, 68%)")
            ("align-items", "flex-start")
        ]

        // User messages align content right
        createRule ".chat-group.user .chat-group-messages" [
            ("align-items", "flex-end")
        ]

        createRule ".chat-group.user .chat-group-footer" [
            ("justify-content", "flex-end")
        ]

        // Footer at bottom of message group (role + time)
        createRule ".chat-group-footer" [
            ("display", "flex")
            ("gap", "8px")
            ("align-items", "baseline")
            ("margin-top", "6px")
        ]

        createRule ".chat-sender-name" [
            ("font-weight", "500")
            ("font-size", "12px")
            ("color", "var(--muted)")
        ]

        createRule ".chat-group-timestamp" [
            ("font-size", "11px")
            ("color", "var(--muted)")
            ("opacity", "0.7")
        ]

        // Group footer action buttons (TTS, delete)
        createRule ".chat-group-footer button" [
            ("background", "none")
            ("border", "none")
            ("cursor", "pointer")
            ("padding", "4px")
            ("min-width", "24px")
            ("min-height", "24px")
            ("border-radius", "var(--radius-sm, 4px)")
            ("color", "var(--muted)")
            ("opacity", "0")
            ("pointer-events", "none")
            ("transition", "opacity 120ms ease-out, color 120ms ease-out, background 120ms ease-out")
            ("display", "inline-flex")
            ("align-items", "center")
            ("justify-content", "center")
        ]

        createRule ".chat-group:hover .chat-group-footer button" [
            ("opacity", "0.6")
            ("pointer-events", "auto")
        ]

        createRule ".chat-group-footer button:hover" [
            ("opacity", "1 !important")
            ("background", "var(--bg-hover, rgba(255, 255, 255, 0.08)")
        ]

        createRule ".chat-group-footer button svg" [
            ("width", "14px")
            ("height", "14px")
            ("fill", "none")
            ("stroke", "currentColor")
            ("stroke-width", "2")
            ("stroke-linecap", "round")
            ("stroke-linejoin", "round")
        ]

        createRule ".chat-tts-btn--active" [
            ("opacity", "1 !important")
            ("pointer-events", "auto !important")
            ("color", "var(--accent)")
        ]

        createRule ".chat-group-delete:hover" [
            ("color", "var(--danger) !important")
        ]

        // Chat divider (e.g., compaction marker)
        createRule ".chat-divider" [
            ("display", "flex")
            ("align-items", "center")
            ("gap", "10px")
            ("margin", "18px 8px")
            ("color", "var(--muted)")
            ("font-size", "11px")
            ("letter-spacing", "0.08em")
            ("text-transform", "uppercase")
            ("user-select", "none")
        ]

        createRule ".chat-divider__line" [
            ("flex", "1 1 0")
            ("height", "1px")
            ("background", "var(--border)")
            ("opacity", "0.9")
        ]

        createRule ".chat-divider__label" [
            ("padding", "2px 10px")
            ("border", "1px solid var(--border)")
            ("border-radius", "var(--radius-full)")
            ("background", "rgba(255, 255, 255, 0.02)")
        ]

        // Avatar Styles
        createRule ".chat-avatar" [
            ("width", "36px")
            ("height", "36px")
            ("border-radius", "var(--radius-md)")
            ("background", "var(--panel-strong)")
            ("display", "grid")
            ("place-items", "center")
            ("font-weight", "600")
            ("font-size", "13px")
            ("flex-shrink", "0")
            ("align-self", "flex-end")
            ("margin-bottom", "4px")
            ("border", "1px solid var(--border)")
        ]

        createRule ".chat-avatar.user" [
            ("background", "var(--accent-subtle)")
            ("color", "var(--accent)")
            ("border-color", "color-mix(in srgb, var(--accent) 20%, transparent)")
        ]

        createRule ".chat-avatar.assistant" [
            ("background", "var(--secondary)")
            ("color", "var(--muted)")
        ]

        createRule ".chat-avatar.other" [
            ("background", "var(--secondary)")
            ("color", "var(--muted)")
        ]

        createRule ".chat-avatar.tool" [
            ("background", "var(--secondary)")
            ("color", "var(--muted)")
        ]

        // Image avatar support
        createRule "img.chat-avatar" [
            ("display", "block")
            ("object-fit", "cover")
            ("object-position", "center")
        ]

        // Minimal Bubble Design - dynamic width based on content
        createRule ".chat-bubble" [
            ("position", "relative")
            ("display", "block")
            ("border", "1px solid var(--border)")
            ("background", "var(--card)")
            ("border-radius", "var(--radius-lg)")
            ("padding", "10px 14px")
            ("box-shadow", "none")
            ("transition", "background var(--duration-fast) ease-out, border-color var(--duration-fast) ease-out")
            ("width", "auto")
            ("max-width", "100%")
            ("box-sizing", "border-box")
            ("word-wrap", "break-word")
        ]

        createRule ".chat-bubble.has-copy" [
            ("padding-right", "70px")
        ]

        createRule ".chat-bubble-actions" [
            ("position", "absolute")
            ("top", "6px")
            ("right", "8px")
            ("display", "flex")
            ("gap", "4px")
            ("opacity", "0")
            ("pointer-events", "none")
            ("transition", "opacity 120ms ease-out")
        ]

        createRule ".chat-bubble:hover .chat-bubble-actions" [
            ("opacity", "1")
            ("pointer-events", "auto")
        ]

        createRule ".chat-copy-btn, .chat-expand-btn" [
            ("background", "var(--bg)")
            ("color", "var(--muted)")
        ]

        createRule ".chat-copy-btn__icon" [
            ("display", "inline-flex")
            ("width", "14px")
            ("height", "14px")
            ("position", "relative")
        ]

        createRule ".chat-copy-btn__icon svg, .chat-expand-btn__icon svg" [
            ("width", "14px")
            ("height", "14px")
        ]

        createRule ".chat-copy-btn__icon-copy, .chat-copy-btn__icon-check" [
            ("position", "absolute")
            ("top", "0")
            ("left", "0")
            ("transition", "opacity 150ms ease")
        ]

        createRule ".chat-copy-btn__icon-check" [
            ("opacity", "0")
        ]

        createRule ".chat-copy-btn[data-copied=\"1\"] .chat-copy-btn__icon-copy" [
            ("opacity", "0")
        ]

        createRule ".chat-copy-btn[data-copied=\"1\"] .chat-copy-btn__icon-check" [
            ("opacity", "1")
        ]

        createRule ".chat-copy-btn[data-copying=\"1\"]" [
            ("opacity", "0")
            ("pointer-events", "none")
        ]

        createRule ".chat-copy-btn[data-error=\"1\"]" [
            ("border-color", "var(--danger-subtle)")
            ("background", "var(--danger-subtle)")
            ("color", "var(--danger)")
        ]

        createRule ".chat-copy-btn[data-copied=\"1\"]" [
            ("border-color", "var(--ok-subtle)")
            ("background", "var(--ok-subtle)")
            ("color", "var(--ok)")
        ]

        createRule ".chat-copy-btn:focus-visible, .chat-expand-btn:focus-visible" [
            ("outline", "2px solid var(--accent)")
            ("outline-offset", "2px")
        ]

        createRule ".chat-expand-btn__icon" [
            ("display", "inline-flex")
            ("width", "14px")
            ("height", "14px")
        ]

        // Light mode: restore borders
        createRule ":root[data-theme-mode=\"light\"] .chat-bubble" [
            ("border-color", "var(--border)")
            ("box-shadow", "inset 0 1px 0 var(--card-highlight)")
        ]

        createRule ".chat-bubble:hover" [
            ("background", "var(--bg-hover)")
        ]

        // User bubbles have different styling
        createRule ".chat-group.user .chat-bubble" [
            ("background", "var(--accent-subtle)")
            ("border-color", "transparent")
        ]

        createRule ":root[data-theme-mode=\"light\"] .chat-group.user .chat-bubble" [
            ("border-color", "color-mix(in srgb, var(--accent) 20%, transparent)")
            ("background", "var(--accent-subtle)")
        ]

        createRule ".chat-group.user .chat-bubble:hover" [
            ("background", "color-mix(in srgb, var(--accent) 20%, transparent)")
        ]

        // Streaming animation
        createRule ".chat-bubble.streaming" [
            ("animation", "pulsing-border 1.5s ease-out infinite")
        ]

        // Fade-in animation for new messages
        createRule ".chat-bubble.fade-in" [
            ("animation", "fade-in 200ms ease-out")
        ]

        // Message metadata (tokens, cost, model, context %)
        createRule ".msg-meta" [
            ("display", "inline-flex")
            ("align-items", "center")
            ("gap", "8px")
            ("font-size", "11px")
            ("line-height", "1")
            ("color", "var(--muted)")
            ("margin-top", "4px")
            ("flex-wrap", "wrap")
        ]

        createRule ".msg-meta__tokens, .msg-meta__cache, .msg-meta__cost, .msg-meta__ctx, .msg-meta__model" [
            ("display", "inline-flex")
            ("align-items", "center")
            ("gap", "2px")
            ("white-space", "nowrap")
        ]

        createRule ".msg-meta__model" [
            ("background", "var(--bg-hover, rgba(255, 255, 255, 0.06))")
            ("padding", "1px 6px")
            ("border-radius", "var(--radius-sm, 4px)")
            ("font-family", "var(--font-mono, monospace)")
        ]

        createRule ".msg-meta__cost" [
            ("color", "var(--ok)")
        ]

        createRule ".msg-meta__ctx--warn" [
            ("color", "var(--warn)")
        ]

        createRule ".msg-meta__ctx--danger" [
            ("color", "var(--danger)")
        ]

        // Delete confirmation popover
        createRule ".chat-delete-wrap" [
            ("position", "relative")
            ("display", "inline-flex")
        ]

        createRule ".chat-delete-confirm" [
            ("position", "absolute")
            ("bottom", "calc(100% + 6px)")
            ("background", "var(--card, #1a1a1a)")
            ("border", "1px solid var(--border, rgba(255, 255, 255, 0.1))")
            ("border-radius", "var(--radius-md, 8px)")
            ("padding", "12px")
            ("min-width", "200px")
            ("max-width", "calc(100vw - 48px)")
            ("box-shadow", "0 8px 24px rgba(0, 0, 0, 0.4)")
            ("z-index", "100")
            ("animation", "scale-in 0.15s ease-out")
        ]

        createRule ".chat-delete-confirm--left" [
            ("right", "0")
        ]

        createRule ".chat-delete-confirm--right" [
            ("left", "0")
        ]

        createRule ".chat-delete-confirm__text" [
            ("margin", "0 0 8px")
            ("font-size", "13px")
            ("font-weight", "500")
            ("color", "var(--fg, #fff)")
        ]

        createRule ".chat-delete-confirm__remember" [
            ("display", "flex")
            ("align-items", "center")
            ("gap", "6px")
            ("font-size", "11px")
            ("color", "var(--muted, #888)")
            ("margin-bottom", "10px")
            ("cursor", "pointer")
            ("user-select", "none")
        ]

        createRule ".chat-delete-confirm__check" [
            ("width", "14px")
            ("height", "14px")
            ("accent-color", "var(--accent)")
            ("cursor", "pointer")
        ]

        createRule ".chat-delete-confirm__actions" [
            ("display", "flex")
            ("gap", "6px")
            ("justify-content", "flex-end")
        ]

        createRule ".chat-delete-confirm__cancel, .chat-delete-confirm__yes" [
            ("border", "none")
            ("border-radius", "var(--radius-sm, 4px)")
            ("padding", "4px 12px")
            ("font-size", "12px")
            ("font-weight", "500")
            ("cursor", "pointer")
            ("transition", "background 120ms ease-out")
        ]

        createRule ".chat-delete-confirm__cancel" [
            ("background", "var(--bg-hover, rgba(255, 255, 255, 0.08))")
            ("color", "var(--muted, #888)")
        ]

        createRule ".chat-delete-confirm__cancel:hover" [
            ("background", "rgba(255, 255, 255, 0.12)")
        ]

        createRule ".chat-delete-confirm__yes" [
            ("background", "var(--danger)")
            ("color", "#fff")
        ]

        createRule ".chat-delete-confirm__yes:hover" [
            ("background", "#dc2626")
        ]
    ]
    
    MediaQueries = [
        createMediaQuery "(hover: none)" [
            createRule ".chat-bubble-actions" [
                ("opacity", "1")
                ("pointer-events", "auto")
            ]
        ]
        
        createMediaQuery "(max-width: 768px)" [
            createRule ".chat-group" [
                ("margin-left", "0")
                ("margin-right", "0")
            ]
            
            createRule ".chat-group-messages" [
                ("max-width", "82%")
            ]
        ]
        
        createMediaQuery "(max-width: 400px)" [
            createRule ".chat-group-messages" [
                ("max-width", "100%")
            ]
            
            createRule ".chat-avatar, img.chat-avatar" [
                ("display", "none")
            ]
        ]
    ]
}

let formatRule (rule: CssRule) =
    let props = 
        rule.Properties 
        |> Map.toList
        |> List.map (fun (key, value) -> $"  {key}: {value};")
        |> String.concat "\n"
    
    $"{rule.Selector} {{\n{props}\n}}"

let formatMediaQuery (mq: MediaQuery) =
    let rules = 
        mq.Rules
        |> List.map formatRule
        |> String.concat "\n\n"
    
    $"@media {mq.Condition} {{\n{rules}\n}}"

let generateCSS (stylesheet: StyleSheet) =
    let header = "/* =============================================\n   GROUPED CHAT LAYOUT (Slack-style)\n   ============================================= */\n\n"
    
    let rules = 
        stylesheet.Rules
        |> List.map formatRule
        |> String.concat "\n\n"
    
    let mediaQueries = 
        stylesheet.MediaQueries
        |> List.map formatMediaQuery
        |> String.concat "\n\n"
    
    let animations = """
/* Streaming animation */
@keyframes pulsing-border {
  0%,
  100% {
    border-color: var(--border);
  }

  50% {
    border-color: var(--accent);
  }
}

/* Fade-in animation for new messages */
@keyframes fade-in {
  from {
    opacity: 0;
    transform: translateY(4px);
  }

  to {
    opacity: 1;
    transform: translateY(0);
  }
}
"""
    
    $"{header}{rules}\n\n{animations}\n\n{mediaQueries}"

[<EntryPoint>]
let main argv =
    if Array.length argv <> 1 then
        printfn "Usage: %s <output-file>" (System.Reflection.Assembly.GetExecutingAssembly().Location)
        1
    else
        try
            let outputFile = argv.[0]
            let cssContent = generateCSS groupedChatLayout
            File.WriteAllText(outputFile, cssContent)
            printfn $"CSS file generated successfully: {outputFile}"
            0
        with
        | ex ->
            eprintfn $"Error generating CSS file: {ex.Message}"
            1

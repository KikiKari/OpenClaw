// abstraction-provenance: {"artifact_sha256": "716017020fa77c16b66e999d66156cc60b6c4ff42df1c0b9246632fa74e498bd", "source_sha256": "fce23ec10c43acef00ba36b3975889539f87b908bd4cfce77616443d2b5f569e", "target_language": "fsharp"}
// icon-controls.css — portiert nach fsharp
// Quelle: css, Projects@TikTok-Live-Companion:plugin-source/browser-extension/icon-controls.css
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/browser-extension/icon-controls.css
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/browser-extension/icon-controls.css
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/browser-extension/icon-controls.css
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

open System
open System.IO
open System.Collections.Generic

type IconStyle = Plastisch | Glass | Linear

type IconData = {
    Name: string
    PropertyName: string
}

type CSSBuilder() =
    let content = new List<string>()
    
    member this.AddRule(selector: string, properties: (string * string) list) =
        let propStrings = 
            properties 
            |> List.map (fun (name, value) -> sprintf "%s:%s" name value)
            |> String.concat ";"
        content.Add(sprintf "%s {%s;}" selector propStrings)
        
    member this.AddRaw(line: string) =
        content.Add(line)
        
    member this.ToString() = 
        String.Join("\n", content)

let iconData = [
    {Name = "auto-chat-refresh-counter"; PropertyName = "--icon-auto-chat-refresh-counter"}
    {Name = "browser"; PropertyName = "--icon-browser"}
    {Name = "captions"; PropertyName = "--icon-captions"}
    {Name = "chat-counter"; PropertyName = "--icon-chat-counter"}
    {Name = "fullscreen"; PropertyName = "--icon-fullscreen"}
    {Name = "mute"; PropertyName = "--icon-mute"}
    {Name = "off"; PropertyName = "--icon-off"}
    {Name = "on"; PropertyName = "--icon-on"}
    {Name = "pip"; PropertyName = "--icon-pip"}
    {Name = "play"; PropertyName = "--icon-play"}
    {Name = "player"; PropertyName = "--icon-player"}
    {Name = "protection-slider"; PropertyName = "--icon-protection-slider"}
    {Name = "recommendation-counter"; PropertyName = "--icon-recommendation-counter"}
    {Name = "report"; PropertyName = "--icon-report"}
    {Name = "reset"; PropertyName = "--icon-reset"}
    {Name = "settings"; PropertyName = "--icon-settings"}
    {Name = "status"; PropertyName = "--icon-status"}
    {Name = "stop"; PropertyName = "--icon-stop"}
    {Name = "unmute"; PropertyName = "--icon-unmute"}
    {Name = "volume-slider"; PropertyName = "--icon-volume-slider"}
]

let generateIconRules (style: IconStyle) =
    let styleName = 
        match style with
        | Plastisch -> "plastisch"
        | Glass -> "glass"
        | Linear -> "linear"
        
    let selector = sprintf "html[data-icon-style=\"%s\"]" styleName
    
    let properties = 
        iconData
        |> List.map (fun icon -> 
            let value = sprintf "url(\"icons/%s/%s.png\")" styleName icon.Name
            (icon.PropertyName, value))
            
    (selector, properties)

let generateCSS() =
    let css = CSSBuilder()
    
    // Generate icon style rules
    [Plastisch; Glass; Linear]
    |> List.iter (fun style ->
        let (selector, properties) = generateIconRules style
        css.AddRule(selector, properties)
    )
    
    // Add button and input styles
    css.AddRaw("button[data-control-icon]::before,.control-icon::before { content:\"\"; display:inline-block; width:32px; height:32px; flex:0 0 32px; background:var(--control-icon) center/contain no-repeat; vertical-align:middle; margin-inline-end:0; pointer-events:none; }")
    css.AddRaw("button[data-control-icon] { min-height:44px; min-width:44px; font-size:0; display:inline-flex; align-items:center; justify-content:center; }")
    css.AddRaw("button[data-control-icon][hidden] { display:none; }")
    css.AddRaw("input[type=\"checkbox\"] { appearance:none; -webkit-appearance:none; width:44px; height:44px; min-width:44px; border:0; background:var(--icon-off) center/40px no-repeat; cursor:pointer; vertical-align:middle; }")
    css.AddRaw("input[type=\"checkbox\"]:checked { background-image:var(--icon-on); }")
    css.AddRaw("input[type=\"checkbox\"]:focus-visible,button[data-control-icon]:focus-visible { outline:2px solid #1769df; outline-offset:2px; }")
    css.AddRaw("input[type=\"checkbox\"]:disabled { opacity:.45; cursor:default; }")
    css.AddRaw(".control-icon { display:inline-flex; align-items:center; }")
    css.AddRaw("input[type=\"range\"] { min-height:32px; }")
    css.AddRaw(".icon-style-setting { display:flex; align-items:center; gap:8px; }")
    
    // Add control icon mappings
    iconData
    |> List.iter (fun icon ->
        css.AddRule(sprintf "[data-control-icon=\"%s\"]" icon.Name, 
                   ["--control-icon", sprintf "var(%s)" icon.PropertyName])
    )
    
    css.ToString()

[<EntryPoint>]
let main argv =
    if argv.Length <> 1 then
        printfn "Usage: program <output-file>"
        1
    else
        try
            let cssContent = generateCSS()
            File.WriteAllText(argv.[0], cssContent)
            0
        with
        | ex ->
            printfn "Error writing file: %s" ex.Message
            1

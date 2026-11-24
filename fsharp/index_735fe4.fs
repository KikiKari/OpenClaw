// abstraction-provenance: {"artifact_sha256": "729b9c217c97c25308247adf18528223879a40ae13f21b08a67ac3a8318fbc2e", "source_sha256": "735fe4b2c74b10f265f715cd4e85d574f46a7132d2e592703b5e712888470105", "target_language": "fsharp"}
// index.html — portiert nach fsharp
// Quelle: html, OpenClaw@main:index.html
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

open System
open System.IO

type HtmlElement = {
    Tag: string
    Attributes: Map<string, string>
    Children: HtmlNode list
}

and HtmlNode =
    | Element of HtmlElement
    | Text of string

let createElement tag attributes children =
    Element { Tag = tag; Attributes = Map.ofList attributes; Children = children }

let createText text =
    Text text

let doctype = "<!DOCTYPE html>"

let htmlDoc =
    createElement "html" [("lang", "de")] [
        createElement "head" [] [
            createElement "meta" [("charset", "utf-8")] []
            createElement "link" [("rel", "icon"); ("href", "/favicon.ico")] []
            createElement "meta" [("name", "viewport"); ("content", "width=device-width, initial-scale=1")] []
            createElement "meta" [("name", "theme-color"); ("content", "#0b1020")] []
            createElement "meta" [("name", "description"); ("content", "OpenClaw Startseite für Repository, Dokumentation und Frontend-Branch.")] []
            createElement "link" [("rel", "apple-touch-icon"); ("href", "/logo192.png")] []
            Text "    <!--
      manifest.json provides metadata used when your web app is installed on a
      user's mobile device or desktop. See https://developers.google.com/web/fundamentals/web-app-manifest/
    -->"
            createElement "link" [("rel", "manifest"); ("href", "/manifest.json")] []
            createElement "title" [] [createText "OpenClaw"]
        ]
        createElement "body" [] [
            createElement "noscript" [] [createText "You need to enable JavaScript to run this app."]
            createElement "div" [("id", "root")] []
            Text "    <!--
      This HTML file is a template.
      If you open it directly in the browser, you will see an empty page.

      You can add webfonts, meta tags, or analytics to this file.
      The build step will place the bundled scripts into the <body> tag.

      To begin the development, run `npm start` or `yarn start`.
      To create a production bundle, use `npm run build` or `yarn build`.
    -->"
        ]
        createElement "script" [("type", "module"); ("src", "/src/index.jsx")] []
    ]

let rec renderNode (node: HtmlNode) indent : string =
    match node with
    | Text s -> s
    | Element element ->
        let attrs = 
            if element.Attributes.IsEmpty then ""
            else " " + (element.Attributes |> Map.toList |> List.map (fun (k,v) -> sprintf "%s=\"%s\"" k v) |> String.concat " ")
        
        if element.Children.IsEmpty then
            sprintf "%s<%s%s />" indent element.Tag attrs
        else
            let childIndent = indent + "  "
            let childrenHtml = 
                element.Children 
                |> List.map (fun child -> renderNode child childIndent)
                |> String.concat "\n"
            
            if List.forall (function Text _ -> true | _ -> false) element.Children then
                // Wenn alle Kinder Text sind, inline rendern
                let inlineContent = 
                    element.Children 
                    |> List.collect (function Text s -> [s] | _ -> [])
                    |> String.concat ""
                sprintf "%s<%s%s>%s</%s>" indent element.Tag attrs inlineContent element.Tag
            else
                sprintf "%s<%s%s>\n%s\n%s</%s>" indent element.Tag attrs childrenHtml indent element.Tag

let renderHtml (doc: HtmlNode) =
    doctype + "\n" + (renderNode doc "")

let writeToFile filename (content: string) =
    File.WriteAllText(filename, content)

[<EntryPoint>]
let main argv =
    let htmlContent = renderHtml htmlDoc
    let filename = 
        if argv.Length > 0 then argv.[0]
        else "index.html"
    
    writeToFile filename htmlContent
    printfn "HTML file written to %s" filename
    0

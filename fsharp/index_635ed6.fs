// abstraction-provenance: {"artifact_sha256": "5e317ebcfbc064ab25a570c3e8b9d6a3db8a7bfdc38f0fb13f948e968ce9959f", "source_sha256": "635ed6e934aa27ffc7ad156af00126e0797ae1d1c065daddb996e2bddc8cbeb3", "target_language": "fsharp"}
// index.html — portiert nach fsharp
// Quelle: html, workspace@local:skills/github-clones/openclaw/extensions/qa-lab/web/index.html
// auch in: openclaw-css@local:workspace/skills/github-clones/openclaw/extensions/qa-lab/web/index.html
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

type HtmlDocument = {
    Doctype: string
    Root: HtmlElement
}

module Html =
    let createElement tag attributes children =
        Element { Tag = tag; Attributes = Map.ofList attributes; Children = children }

    let createText text =
        Text text

    let createDoctype doctype =
        "<!DOCTYPE " + doctype + ">"

    let rec renderAttributes attrs =
        attrs
        |> Map.toList
        |> List.map (fun (key, value) -> sprintf "%s=\"%s\"" key value)
        |> String.concat " "

    let rec renderNode node =
        match node with
        | Text text -> text
        | Element element ->
            let attrs = 
                if Map.isEmpty element.Attributes then ""
                else " " + renderAttributes element.Attributes
            
            if List.isEmpty element.Children then
                sprintf "<%s%s />" element.Tag attrs
            else
                let childrenHtml = 
                    element.Children
                    |> List.map renderNode
                    |> String.concat ""
                sprintf "<%s%s>%s</%s>" element.Tag attrs childrenHtml element.Tag

    let renderDocument doc =
        let doctype = createDoctype doc.Doctype
        let rootHtml = renderNode (Element doc.Root)
        sprintf "%s\n%s" doctype rootHtml

let createIndexHtml () =
    let head = Html.createElement "head" [] [
        Html.createElement "meta" [("charset", "utf-8")] []
        Html.createElement "meta" [("name", "viewport"); ("content", "width=device-width, initial-scale=1")] []
        Html.createElement "meta" [("name", "color-scheme"); ("content", "light dark")] []
        Html.createElement "title" [] [Html.createText "QA Lab"]
    ]

    let body = Html.createElement "body" [] [
        Html.createElement "div" [("id", "app")] []
        Html.createElement "script" [("type", "module"); ("src", "/src/main.ts")] []
    ]

    let html = Html.createElement "html" [("lang", "en")] [head; body]

    { Doctype = "html"; Root = html }

[<EntryPoint>]
let main argv =
    let document = createIndexHtml()
    let htmlContent = Html.renderDocument document
    
    match argv with
    | [| filename |] ->
        File.WriteAllText(filename, htmlContent)
        printfn "HTML file generated: %s" filename
    | _ ->
        printfn "Usage: program <output_filename>"
        printfn "Generated HTML:"
        printfn "%s" htmlContent
    
    0

// abstraction-provenance: {"artifact_sha256": "a10f2a83f97d620276cbb640bde44e94be1feec635bc4ca0d255b90428917ccc", "source_sha256": "58a64ee7578033eb123e1e7e23612089630a0f786003006c76e9030db1751ffe", "target_language": "fsharp"}
// index-erFv57XC.css — portiert nach fsharp
// Quelle: css, Projects@Weather-Check:Weather-Check/assets/index-erFv57XC.css
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

open System.IO

type CssRule = {
    Selector: string
    Properties: Map<string, string>
}

type CssMediaQuery = {
    Query: string
    Rules: CssRule list
}

type CssDocument = {
    Rules: CssRule list
    MediaQueries: CssMediaQuery list
}

let generateCss (cssDoc: CssDocument) =
    let generateRule (rule: CssRule) =
        let properties = rule.Properties |> Map.toList |> List.map (fun (k, v) -> sprintf "%s: %s;" k v) |> String.concat " "
        sprintf "%s {%s}" rule.Selector properties

    let generateMediaQuery (mq: CssMediaQuery) =
        let rules = mq.Rules |> List.map generateRule |> String.concat " "
        sprintf "@media %s {%s}" mq.Query rules

    let rules = cssDoc.Rules |> List.map generateRule |> String.concat "\n"
    let mediaQueries = cssDoc.MediaQueries |> List.map generateMediaQuery |> String.concat "\n"

    sprintf "%s\n%s" rules mediaQueries

let writeCssToFile (filePath: string) (cssDoc: CssDocument) =
    let cssContent = generateCss cssDoc
    File.WriteAllText(filePath, cssContent)

let cssDoc = {
    Rules = [
        {
            Selector = "@import \"https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap\""
            Properties = Map.empty
        }
        {
            Selector = "*, :before, :after"
            Properties = Map.ofList [
                "--tw-border-spacing-x", "0"
                "--tw-border-spacing-y", "0"
                "--tw-translate-x", "0"
                "--tw-translate-y", "0"
                "--tw-rotate", "0"
                "--tw-skew-x", "0"
                "--tw-skew-y", "0"
                "--tw-scale-x", "1"
                "--tw-scale-y", "1"
                "--tw-pan-x", ""
                "--tw-pan-y", ""
                "--tw-pinch-zoom", ""
                "--tw-scroll-snap-strictness", "proximity"
                "--tw-gradient-from-position", ""
                "--tw-gradient-via-position", ""
                "--tw-gradient-to-position", ""
                "--tw-ordinal", ""
                "--tw-slashed-zero", ""
                "--tw-numeric-figure", ""
                "--tw-numeric-spacing", ""
                "--tw-numeric-fraction", ""
                "--tw-ring-inset", ""
                "--tw-ring-offset-width", "0px"
                "--tw-ring-offset-color", "#fff"
                "--tw-ring-color", "rgb(59 130 246 / .5)"
                "--tw-ring-offset-shadow", "0 0 #0000"
                "--tw-ring-shadow", "0 0 #0000"
                "--tw-shadow", "0 0 #0000"
                "--tw-shadow-colored", "0 0 #0000"
                "--tw-blur", ""
                "--tw-brightness", ""
                "--tw-contrast", ""
                "--tw-grayscale", ""
                "--tw-hue-rotate", ""
                "--tw-invert", ""
                "--tw-saturate", ""
                "--tw-sepia", ""
                "--tw-drop-shadow", ""
                "--tw-backdrop-blur", ""
                "--tw-backdrop-brightness", ""
                "--tw-backdrop-contrast", ""
                "--tw-backdrop-grayscale", ""
                "--tw-backdrop-hue-rotate", ""
                "--tw-backdrop-invert", ""
                "--tw-backdrop-opacity", ""
                "--tw-backdrop-saturate", ""
                "--tw-backdrop-sepia", ""
                "--tw-contain-size", ""
                "--tw-contain-layout", ""
                "--tw-contain-paint", ""
                "--tw-contain-style", ""
            ]
        }
        // Add more rules as needed
    ]
    MediaQueries = [
        {
            Query = "(min-width: 640px)"
            Rules = [
                {
                    Selector = ".sm\\:bottom-0"
                    Properties = Map.ofList ["bottom", "0"]
                }
                // Add more media query rules as needed
            ]
        }
        // Add more media queries as needed
    ]
}

[<EntryPoint>]
let main argv =
    if argv.Length = 0 then
        printfn "Please provide a file path as an argument."
        1
    else
        let filePath = argv.[0]
        writeCssToFile filePath cssDoc
        0

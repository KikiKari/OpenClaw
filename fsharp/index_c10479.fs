// abstraction-provenance: {"artifact_sha256": "cec4c39da0929d5d011cdc6b84edfd69cc6adbdbeeee518ce5e3286ecd0963f0", "source_sha256": "c10479f79ca5554fe399cf2f5d70fb5b32e837c1c7a846eb7dd7c9e9e5319c66", "target_language": "fsharp"}
// index.html — portiert nach fsharp
// Quelle: html, Projects@TikTok-Live-Companion:site/index.html
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:site/index.html
// auch in: Projects@vercel/install-and-configure-vercel-w-98sxlo:site/index.html
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

open System
open System.IO
open System.Xml.Linq

let createHtmlDocument () =
    let html = 
        XDocument(
            XDeclaration("1.0", "UTF-8", null),
            XElement(XName.Get("html"),
                XAttribute(XName.Get("lang"), "de"),
                XElement(XName.Get("head"),
                    XElement(XName.Get("meta"), 
                        XAttribute(XName.Get("charset"), "UTF-8")),
                    XElement(XName.Get("meta"), 
                        XAttribute(XName.Get("name"), "viewport"),
                        XAttribute(XName.Get("content"), "width=device-width, initial-scale=1.0")),
                    XElement(XName.Get("meta"), 
                        XAttribute(XName.Get("name"), "description"),
                        XAttribute(XName.Get("content"), "Dokumentation für TikTok LIVE Companion 0.8.2 – Chat-TTS, Zuschauerstatistik, Songerkennung und Stream-Informationen direkt im Browser.")),
                    XElement(XName.Get("meta"), 
                        XAttribute(XName.Get("name"), "theme-color"),
                        XAttribute(XName.Get("content"), "#ffffff")),
                    XElement(XName.Get("link"), 
                        XAttribute(XName.Get("rel"), "icon"),
                        XAttribute(XName.Get("type"), "image/png"),
                        XAttribute(XName.Get("href"), "/branding/staenderglobus-ios.png")),
                    XElement(XName.Get("link"), 
                        XAttribute(XName.Get("rel"), "apple-touch-icon"),
                        XAttribute(XName.Get("href"), "/branding/staenderglobus-ios.png")),
                    XElement(XName.Get("title"), "TikTok LIVE Companion – Dokumentation")
                ),
                XElement(XName.Get("body"),
                    XElement(XName.Get("div"), 
                        XAttribute(XName.Get("id"), "root")),
                    XElement(XName.Get("script"), 
                        XAttribute(XName.Get("type"), "module"),
                        XAttribute(XName.Get("src"), "/src/main.tsx"))
                )
            )
        )
    html

let writeHtmlToFile (filePath: string) =
    let doc = createHtmlDocument()
    use writer = new StreamWriter(filePath)
    doc.Save(writer, SaveOptions.None)

[<EntryPoint>]
let main argv =
    let filePath = 
        if argv.Length > 0 then argv.[0]
        else "index.html"
    
    writeHtmlToFile filePath
    0

// abstraction-provenance: {"artifact_sha256": "ef6585ae5bbef9369956046d91cb70ce96131cfa7df62e176927c98bc4b15d40", "source_sha256": "9245a78489adb3949ae2a56f5e0987a465142b9a8ee97bddaca453f5011daef8", "target_language": "fsharp"}
// index.html — portiert nach fsharp
// Quelle: html, Projects@Program-Derivation:public/index.html
// auch in: Projects@Vision-Check:public/index.html
// auch in: Projects@Weather-Check:public/index.html
// auch in: Projects@abstractions:public/index.html
// auch in: 5 weiteren Fundstellen
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

open System
open System.IO
open System.Xml.Linq

let createHtmlDocument () =
    let htmlNs = XNamespace.Get("http://www.w3.org/1999/xhtml")
    
    let docType = "<!DOCTYPE html>"
    
    let metaCharset = XElement(htmlNs + "meta", XAttribute("charset", "utf-8"))
    let metaViewport = XElement(htmlNs + "meta", 
                        XAttribute("name", "viewport"),
                        XAttribute("content", "width=device-width, initial-scale=1"))
    let metaRefresh = XElement(htmlNs + "meta",
                       XAttribute("http-equiv", "refresh"),
                       XAttribute("content", "0; url=3d.html"))
    let title = XElement(htmlNs + "title", "Weiterleitung zur 3D-Ansicht")
    let linkCanonical = XElement(htmlNs + "link",
                         XAttribute("rel", "canonical"),
                         XAttribute("href", "3d.html"))
    let script = XElement(htmlNs + "script", "location.replace('3d.html');")
    
    let head = XElement(htmlNs + "head",
                metaCharset,
                metaViewport,
                metaRefresh,
                title,
                linkCanonical,
                script)
    
    let bodyContent = XElement(htmlNs + "a",
                       XAttribute("href", "3d.html"),
                       "3D-Ansicht öffnen")
    let body = XElement(htmlNs + "body",
                XElement(htmlNs + "p", bodyContent))
    
    let html = XElement(htmlNs + "html",
                XAttribute(XNamespace.Xmlns + "html", "http://www.w3.org/1999/xhtml"),
                XAttribute("lang", "de"),
                head,
                body)
    
    (docType, html)

let writeHtmlToFile filePath =
    let (docType, htmlElement) = createHtmlDocument()
    let htmlString = htmlElement.ToString()
    
    // Entferne den XML-Header, da wir <!DOCTYPE html> verwenden
    let xmlHeader = "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
    let cleanedHtml = 
        if htmlString.StartsWith(xmlHeader) then
            htmlString.Substring(xmlHeader.Length).TrimStart()
        else
            htmlString
    
    let fullHtml = docType + Environment.NewLine + cleanedHtml
    
    File.WriteAllText(filePath, fullHtml)

[<EntryPoint>]
let main argv =
    let filePath = 
        if argv.Length > 0 then argv.[0]
        else "index.html"
    
    writeHtmlToFile filePath
    0

// abstraction-provenance: {"artifact_sha256": "1e07f02d15290b14d12718c3ab0fc80401dfd118b0d8be0501e387181d528c4f", "source_sha256": "5f1051ecfd7f7a7dbdb89449a4e356b1ff5b7daa5e21e2c82defb13ede719988", "target_language": "fsharp"}
// index.html — portiert nach fsharp
// Quelle: html, OpenClaw@gateway1:skills/scripting-utils/references/tcl/index.html
// auch in: OpenClaw@gateway2:skills/scripting-utils/references/tcl/index.html
// auch in: workspace@local:git/skills/scripting-utils/references/tcl/index.html
// auch in: workspace@local:skills/scripting-utils/references/tcl/index.html
// auch in: 4 weiteren Fundstellen
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

open System
open System.IO
open System.Xml

let createHtmlDocument (outputPath: string) =
    let doc = new XmlDocument()
    
    // Create DOCTYPE
    let doctype = doc.CreateDocumentType("HTML", "-//W3C//DTD HTML 4.01 Transitional//EN", null, null)
    doc.AppendChild(doctype) |> ignore
    
    // Create root element
    let html = doc.CreateElement("html")
    doc.AppendChild(html) |> ignore
    
    // Create head
    let head = doc.CreateElement("head")
    html.AppendChild(head) |> ignore
    
    let title = doc.CreateElement("title")
    title.InnerText <- "Tcl/Tk 8.6 Manual"
    head.AppendChild(title) |> ignore
    
    let meta = doc.CreateElement("meta")
    let attr1 = doc.CreateAttribute("name")
    attr1.Value <- "viewport"
    let attr2 = doc.CreateAttribute("content")
    attr2.Value <- "width=device-width, initial-scale=1"
    meta.Attributes.Append(attr1) |> ignore
    meta.Attributes.Append(attr2) |> ignore
    head.AppendChild(meta) |> ignore
    
    let link = doc.CreateElement("link")
    let attr3 = doc.CreateAttribute("rel")
    attr3.Value <- "stylesheet"
    let attr4 = doc.CreateAttribute("href")
    attr4.Value <- "/devsite.css"
    let attr5 = doc.CreateAttribute("type")
    attr5.Value <- "text/css"
    let attr6 = doc.CreateAttribute("media")
    attr6.Value <- "all"
    link.Attributes.Append(attr3) |> ignore
    link.Attributes.Append(attr4) |> ignore
    link.Attributes.Append(attr5) |> ignore
    link.Attributes.Append(attr6) |> ignore
    head.AppendChild(link) |> ignore
    
    // Create body
    let body = doc.CreateElement("body")
    let attr7 = doc.CreateAttribute("bgcolor")
    attr7.Value <- "white"
    let attr8 = doc.CreateAttribute("text")
    attr8.Value <- "black"
    body.Attributes.Append(attr7) |> ignore
    body.Attributes.Append(attr8) |> ignore
    html.AppendChild(body) |> ignore
    
    // First table
    let table1 = doc.CreateElement("table")
    let attr9 = doc.CreateAttribute("border")
    attr9.Value <- "0"
    let attr10 = doc.CreateAttribute("cellpadding")
    attr10.Value <- "0"
    let attr11 = doc.CreateAttribute("cellspacing")
    attr11.Value <- "0"
    let attr12 = doc.CreateAttribute("width")
    attr12.Value <- "780"
    table1.Attributes.Append(attr9) |> ignore
    table1.Attributes.Append(attr10) |> ignore
    table1.Attributes.Append(attr11) |> ignore
    table1.Attributes.Append(attr12) |> ignore
    body.AppendChild(table1) |> ignore
    
    let tr1 = doc.CreateElement("tr")
    table1.AppendChild(tr1) |> ignore
    
    let td1 = doc.CreateElement("td")
    let attr13 = doc.CreateAttribute("valign")
    attr13.Value <- "top"
    let attr14 = doc.CreateAttribute("align")
    attr14.Value <- "left"
    td1.Attributes.Append(attr13) |> ignore
    td1.Attributes.Append(attr14) |> ignore
    tr1.AppendChild(td1) |> ignore
    
    let a1 = doc.CreateElement("a")
    let attr15 = doc.CreateAttribute("href")
    attr15.Value <- "/"
    a1.Attributes.Append(attr15) |> ignore
    td1.AppendChild(a1) |> ignore
    
    let img1 = doc.CreateElement("img")
    let attr16 = doc.CreateAttribute("src")
    attr16.Value <- "/images/plume.png"
    let attr17 = doc.CreateAttribute("width")
    attr17.Value <- "60"
    let attr18 = doc.CreateAttribute("height")
    attr18.Value <- "55"
    let attr19 = doc.CreateAttribute("border")
    attr19.Value <- "0"
    let attr20 = doc.CreateAttribute("alt")
    attr20.Value <- "Tcl Home"
    img1.Attributes.Append(attr16) |> ignore
    img1.Attributes.Append(attr17) |> ignore
    img1.Attributes.Append(attr18) |> ignore
    img1.Attributes.Append(attr19) |> ignore
    img1.Attributes.Append(attr20) |> ignore
    a1.AppendChild(img1) |> ignore
    
    let img2 = doc.CreateElement("img")
    let attr21 = doc.CreateAttribute("src")
    attr21.Value <- "/images/Developer.gif"
    let attr22 = doc.CreateAttribute("width")
    attr22.Value <- "355"
    let attr23 = doc.CreateAttribute("height")
    attr23.Value <- "55"
    let attr24 = doc.CreateAttribute("border")
    attr24.Value <- "0"
    let attr25 = doc.CreateAttribute("alt")
    attr25.Value <- "Tcl Home"
    let attr26 = doc.CreateAttribute("title")
    attr26.Value <- "Tcl Developer Xchange"
    img2.Attributes.Append(attr21) |> ignore
    img2.Attributes.Append(attr22) |> ignore
    img2.Attributes.Append(attr23) |> ignore
    img2.Attributes.Append(attr24) |> ignore
    img2.Attributes.Append(attr25) |> ignore
    img2.Attributes.Append(attr26) |> ignore
    a1.AppendChild(img2) |> ignore
    
    let td2 = doc.CreateElement("td")
    let attr27 = doc.CreateAttribute("valign")
    attr27.Value <- "top"
    let attr28 = doc.CreateAttribute("align")
    attr28.Value <- "right"
    td2.Attributes.Append(attr27) |> ignore
    td2.Attributes.Append(attr28) |> ignore
    tr1.AppendChild(td2) |> ignore
    
    let a2 = doc.CreateElement("a")
    let attr29 = doc.CreateAttribute("href")
    attr29.Value <- "/siteinfo.html"
    a2.Attributes.Append(attr29) |> ignore
    td2.AppendChild(a2) |> ignore
    
    let font = doc.CreateElement("font")
    let attr30 = doc.CreateAttribute("size")
    attr30.Value <- "1"
    font.Attributes.Append(attr30) |> ignore
    font.InnerText <- "Hosted by"
    a2.AppendChild(font) |> ignore
    
    let br1 = doc.CreateElement("br")
    td2.AppendChild(br1) |> ignore
    
    let a3 = doc.CreateElement("a")
    let attr31 = doc.CreateAttribute("href")
    attr31.Value <- "http://www.ActiveState.com/products/tcl"
    a3.Attributes.Append(attr31) |> ignore
    td2.AppendChild(a3) |> ignore
    
    let img3 = doc.CreateElement("img")
    let attr32 = doc.CreateAttribute("src")
    attr32.Value <- "/images/aslogo.gif"
    let attr33 = doc.CreateAttribute("border")
    attr33.Value <- "0"
    let attr34 = doc.CreateAttribute("alt")
    attr34.Value <- "ActiveState"
    let attr35 = doc.CreateAttribute("title")
    attr35.Value <- "This site is hosted by ActiveState"
    img3.Attributes.Append(attr32) |> ignore
    img3.Attributes.Append(attr33) |> ignore
    img3.Attributes.Append(attr34) |> ignore
    img3.Attributes.Append(attr35) |> ignore
    a3.AppendChild(img3) |> ignore
    
    // Global navigation
    let div1 = doc.CreateElement("div")
    let attr36 = doc.CreateAttribute("id")
    attr36.Value <- "globalnav"
    div1.Attributes.Append(attr36) |> ignore
    body.AppendChild(div1) |> ignore
    
    let ul1 = doc.CreateElement("ul")
    div1.AppendChild(ul1) |> ignore
    
    let navItems = [
        ("HOME", "/")
        ("ABOUT TCL/TK", "/about/")
        ("SOFTWARE", "/software/tcltk/")
        ("CORE DEVELOPMENT", "/community/coreteam/")
        ("COMMUNITY", "/community/")
        ("DOCUMENTATION", "/doc/")
    ]
    
    for (text, href) in navItems do
        let li = doc.CreateElement("li")
        ul1.AppendChild(li) |> ignore
        let a = doc.CreateElement("a")
        let attr = doc.CreateAttribute("href")
        attr.Value <- href
        a.Attributes.Append(attr) |> ignore
        if text = "DOCUMENTATION" then
            let classAttr = doc.CreateAttribute("class")
            classAttr.Value <- "here"
            a.Attributes.Append(classAttr) |> ignore
        a.InnerText <- text
        li.AppendChild(a) |> ignore
    
    // Clear break
    let br2 = doc.CreateElement("br")
    let attr37 = doc.CreateAttribute("clear")
    attr37.Value <- "all"
    br2.Attributes.Append(attr37) |> ignore
    body.AppendChild(br2) |> ignore
    
    // Divider DIV
    let div2 = doc.CreateElement("DIV")
    let style1 = doc.CreateAttribute("style")
    style1.Value <- "border-top: 2px solid #3163CE; width: 780px"
    div2.Attributes.Append(style1) |> ignore
    body.AppendChild(div2) |> ignore
    
    // Second table
    let table2 = doc.CreateElement("table")
    let attr38 = doc.CreateAttribute("border")
    attr38.Value <- "0"
    let attr39 = doc.CreateAttribute("cellpadding")
    attr39.Value <- "2"
    let attr40 = doc.CreateAttribute("cellspacing")
    attr40.Value <- "0"
    let attr41 = doc.CreateAttribute("width")
    attr41.Value <- "780"
    table2.Attributes.Append(attr38) |> ignore
    table2.Attributes.Append(attr39) |> ignore
    table2.Attributes.Append(attr40) |> ignore
    table2.Attributes.Append(attr41) |> ignore
    body.AppendChild(table2) |> ignore
    
    let tr2 = doc.CreateElement("tr")
    table2.AppendChild(tr2) |> ignore
    
    let td3 = doc.CreateElement("td")
    let attr42 = doc.CreateAttribute("align")
    attr42.Value <- "left"
    let attr43 = doc.CreateAttribute("valign")
    attr43.Value <- "middle"
    td3.Attributes.Append(attr42) |> ignore
    td3.Attributes.Append(attr43) |> ignore
    tr2.AppendChild(td3) |> ignore
    
    // Search form
    let div3 = doc.CreateElement("div")
    let style2 = doc.CreateAttribute("style")
    style2.Value <- "display:table-cell; vertical-align:middle; margin:0px"
    div3.Attributes.Append(style2) |> ignore
    td3.AppendChild(div3) |> ignore
    
    let form = doc.CreateElement("FORM")
    let attr44 = doc.CreateAttribute("method")
    attr44.Value <- "GET"
    let attr45 = doc.CreateAttribute("action")
    attr45.Value <- "https://www.google.com/search"
    form.Attributes.Append(attr44) |> ignore
    form.Attributes.Append(attr45) |> ignore
    div3.AppendChild(form) |> ignore
    
    let a4 = doc.CreateElement("A")
    let attr46 = doc.CreateAttribute("HREF")
    attr46.Value <- "https://www.google.com/"
    a4.Attributes.Append(attr46) |> ignore
    form.AppendChild(a4) |> ignore
    
    let img4 = doc.CreateElement("IMG")
    let attr47 = doc.CreateAttribute("src")
    attr47.Value <- "/images/Search.gif"
    let attr48 = doc.CreateAttribute("border")
    attr48.Value <- "0"
    let attr49 = doc.CreateAttribute("ALT")
    attr49.Value <- "Google SiteSearch"
    img4.Attributes.Append(attr47) |> ignore
    img4.Attributes.Append(attr48) |> ignore
    img4.Attributes.Append(attr49) |> ignore
    a4.AppendChild(img4) |> ignore
    
    let input1 = doc.CreateElement("INPUT")
    let attr50 = doc.CreateAttribute("TYPE")
    attr50.Value <- "text"
    let attr51 = doc.CreateAttribute("name")
    attr51.Value <- "q"
    let attr52 = doc.CreateAttribute("size")
    attr52.Value <- "20"
    let attr53 = doc.CreateAttribute("maxlength")
    attr53.Value <- "255"
    let attr54 = doc.CreateAttribute("value")
    attr54.Value <- ""
    input1.Attributes.Append(attr50) |> ignore
    input1.Attributes.Append(attr51) |> ignore
    input1.Attributes.Append(attr52) |> ignore
    input1.Attributes.Append(attr53) |> ignore
    input1.Attributes.Append(attr54) |> ignore
    form.AppendChild(input1) |> ignore
    
    let input2 = doc.CreateElement("INPUT")
    let attr55 = doc.CreateAttribute("type")
    attr55.Value <- "image"
    let attr56 = doc.CreateAttribute("value")
    attr56.Value <- "submit"
    let attr57 = doc.CreateAttribute("name")
    attr57.Value <- "btnG"
    let attr58 = doc.CreateAttribute("src")
    attr58.Value <- "/images/Go.gif"
    input2.Attributes.Append(attr55) |> ignore
    input2.Attributes.Append(attr56) |> ignore
    input2.Attributes.Append(attr57) |> ignore
    input2.Attributes.Append(attr58) |> ignore
    form.AppendChild(input2) |> ignore
    
    let input3 = doc.CreateElement("input")
    let attr59 = doc.CreateAttribute("type")
    attr59.Value <- "hidden"
    let attr60 = doc.CreateAttribute("name")
    attr60.Value <- "ie"
    let attr61 = doc.CreateAttribute("value")
    attr61.Value <- "UTF-8"
    input3.Attributes.Append(attr59) |> ignore
    input3.Attributes.Append(attr60) |> ignore
    input3.Attributes.Append(attr61) |> ignore
    form.AppendChild(input3) |> ignore
    
    let input4 = doc.CreateElement("input")
    let attr62 = doc.CreateAttribute("type")
    attr62.Value <- "hidden"
    let attr63 = doc.CreateAttribute("name")
    attr63.Value <- "oe"
    let attr64 = doc.CreateAttribute("value")
    attr64.Value <- "UTF-8"
    input4.Attributes.Append(attr62) |> ignore
    input4.Attributes.Append(attr63) |> ignore
    input4.Attributes.Append(attr64) |> ignore
    form.AppendChild(input4) |> ignore
    
    let input5 = doc.CreateElement("input")
    let attr65 = doc.CreateAttribute("type")
    attr65.Value <- "hidden"
    let attr66 = doc.CreateAttribute("name")
    attr66.Value <- "domains"
    let attr67 = doc.CreateAttribute("value")
    attr67.Value <- "tcl.tk"
    input5.Attributes.Append(attr65) |> ignore
    input5.Attributes.Append(attr66) |> ignore
    input5.Attributes.Append(attr67) |> ignore
    form.AppendChild(input5) |> ignore
    
    let input6 = doc.CreateElement("input")
    let attr68 = doc.CreateAttribute("type")
    attr68.Value <- "hidden"
    let attr69 = doc.CreateAttribute("name")
    attr69.Value <- "sitesearch"
    let attr70 = doc.CreateAttribute("value")
    attr70.Value <- "tcl.tk"
    input6.Attributes.Append(attr68) |> ignore
    input6.Attributes.Append(attr69) |> ignore
    input6.Attributes.Append(attr70) |> ignore
    form.AppendChild(input6) |> ignore
    
    let td4 = doc.CreateElement("td")
    let attr71 = doc.CreateAttribute("align")
    attr71.Value <- "right"
    td4.Attributes.Append(attr71) |> ignore
    tr2.AppendChild(td4) |> ignore
    
    let p1 = doc.CreateElement("p")
    let attr72 = doc.CreateAttribute("class")
    attr72.Value <- "banner"
    p1.Attributes.Append(attr72) |> ignore
    p1.InnerText <- "Tcl/Tk 8.6 Manual"
    td4.AppendChild(p1) |> ignore
    
    // Yellow divider
    let div4 = doc.CreateElement("DIV")
    let style3 = doc.CreateAttribute("style")
    style3.Value <- "border-top: 1px solid #FFCE00; margin-bottom: 2px; width: 780px"
    div4.Attributes.Append(style3) |> ignore
    body.AppendChild(div4) |> ignore
    
    // Third table
    let table3 = doc.CreateElement("table")
    let attr73 = doc.CreateAttribute("border")
    attr73.Value <- "0"
    let attr74 = doc.CreateAttribute("cellpadding")
    attr74.Value <- "0"
    let attr75 = doc.CreateAttribute("cellspacing")
    attr75.Value <- "0"
    let attr76 = doc.CreateAttribute("width")
    attr76.Value <- "780"
    table3.Attributes.Append(attr73) |> ignore
    table3.Attributes.Append(attr74) |> ignore
    table3.Attributes.Append(attr75) |> ignore
    table3.Attributes.Append(attr76) |> ignore
    body.AppendChild(table3) |> ignore
    
    let tr3 = doc.CreateElement("tr")
    table3.AppendChild(tr3) |> ignore
    
    let td5 = doc.CreateElement("td")
    tr3.AppendChild(td5) |> ignore
    
    let dl = doc.CreateElement("DL")
    let attr77 = doc.CreateAttribute("class")
    attr77.Value <- "keylist"
    dl.Attributes.Append(attr77) |> ignore
    td5.AppendChild(dl) |> ignore
    
    let manualEntries = [
        ("Tcl/Tk Applications", "UserCmd/contents.htm", "The interpreters which implement Tcl and Tk.")
        ("Tcl Commands", "TclCmd/contents.htm", "The commands which the <B>tclsh</B> interpreter implements.")
        ("Tk Commands", "TkCmd/contents.htm", "The additional commands which the <B>wish</B> interpreter implements.")
        ("[incr Tcl] Package Commands", "ItclCmd/contents.htm", "The additional commands provided by the [incr Tcl] package.")
        ("SQLite Package Commands", "SqliteCmd/contents.htm", "The additional commands provided by the SQLite package.")
        ("TDBC Package Commands", "TdbcCmd/contents.htm", "The additional commands provided by the TDBC package.")
        ("tdbc::mysql Package Commands", "TdbcmysqlCmd/contents.htm", "The additional commands provided by the tdbc::mysql package.")
        ("tdbc::odbc Package Commands", "TdbcodbcCmd/contents.htm", "The additional commands provided by the tdbc::odbc package.")
        ("tdbc::postgres Package Commands", "TdbcpostgresCmd/contents.htm", "The additional commands provided by the tdbc::postgres package.")
        ("tdbc::sqlite3 Package Commands", "TdbcsqliteCmd/contents.htm", "The additional commands provided by the tdbc::sqlite3 package.")
        ("Thread Package Commands", "ThreadCmd/contents.htm", "The additional commands provided by the Thread package.")
        ("Tcl Library", "TclLib/contents.htm", "The C functions which a Tcl extended C program may use.")
        ("Tk Library", "TkLib/contents.htm", "The additional C functions which a Tk extended C program may use.")
        ("[incr Tcl] Package Library", "ItclLib/contents.htm", "The additional C functions provided by the [incr Tcl] package.")
        ("TDBC Package Library", "TdbcLib/contents.htm", "The additional C functions provided by the TDBC package.")
        ("Keywords", "Keywords/contents.htm", "The keywords from the Tcl/Tk man pages.")
    ]
    
    for (title, href, description) in manualEntries do
        let dt = doc.CreateElement("DT")
        dl.AppendChild(dt) |> ignore
        let a = doc.CreateElement("A")
        let attr = doc.CreateAttribute("HREF")
        attr.Value <- href
        a.Attributes.Append(attr) |> ignore
        a.InnerXml <- title
        dt.AppendChild(a) |> ignore
        
        let dd = doc.CreateElement("DD")
        dd.InnerXml <- description
        dl.AppendChild(dd) |> ignore
    
    // Commented out tutorial section
    let comment = doc.CreateComment("\n<DT><A HREF=\"tutorial/tcltutorial.html\">Tcl Tutorial</A></DT>\n<DD>Tutorial for Tcl features.</DD>\n")
    dl.AppendChild(comment) |> ignore
    
    // Clear break
    let br3 = doc.CreateElement("br")
    let attr78 = doc.CreateAttribute("clear")
    attr78.Value <- "all"
    br3.Attributes.Append(attr78) |> ignore
    td5.AppendChild(br3) |> ignore
    
    // Footer
    let p2 = doc.CreateElement("p")
    let attr79 = doc.CreateAttribute("align")
    attr79.Value <- "center"
    let attr80 = doc.CreateAttribute("class")
    attr80.Value <- "footer"
    p2.Attributes.Append(attr79) |> ignore
    p2.Attributes.Append(attr80) |> ignore
    td5.AppendChild(p2) |> ignore
    
    let small = doc.CreateElement("small")
    p2.AppendChild(small) |> ignore
    
    let b = doc.CreateElement("b")
    small.AppendChild(b) |> ignore
    b.InnerText <- "This is the main Tcl Developer Xchange site, www.tcl-lang.org ."
    
    let nbsp1 = doc.CreateTextNode("\n\t\t&nbsp;&nbsp;\n")
    p2.AppendChild(nbsp1) |> ignore
    
    let a5 = doc.CreateElement("a")
    let attr81 = doc.CreateAttribute("href")
    attr81.Value <- "/siteinfo.html"
    a5.Attributes.Append(attr81) |> ignore
    a5.InnerText <- "About this Site"
    p2.AppendChild(a5) |> ignore
    
    let nbsp2 = doc.CreateTextNode(" |\n")
    p2.AppendChild(nbsp2) |> ignore
    
    let a6 = doc.CreateElement("a")
    let attr82 = doc.CreateAttribute("href")
    attr82.Value <- "/cdn-cgi/l/email-protection#7a0d1f18171b090e1f083a0e191657161b141d5415081d"
    a6.Attributes.Append(attr82) |> ignore
    
    let span = doc.CreateElement("span")
    let attr83 = doc.CreateAttribute("class")
    attr83.Value <- "__cf_email__"
    let attr84 = doc.CreateAttribute("data-cfemail")
    attr84.Value <- "95e2f0f7f8f4e6e1f0e7d5e1f6f9b8f9f4fbf2bbfae7f2"
    span.Attributes.Append(attr83) |> ignore
    span.Attributes.Append(attr84) |> ignore
    span.InnerText <- "[email&#160;protected]"
    a6.AppendChild(span) |> ignore
    p2.AppendChild(a6) |> ignore
    
    let br4 = doc.CreateElement("br")
    p2.AppendChild(br4) |> ignore
    
    let footerLinks = [
        ("Home", "/")
        ("About Tcl/Tk", "/about/")
        ("Software", "/software/tcltk/")
        ("Core Development", "/community/coreteam/")
        ("Community", "/community/")
        ("Documentation", "/doc/")
    ]
    
    for i in 0 .. footerLinks.Length - 1 do
        let (text, href) = footerLinks.[i]
        let a = doc.CreateElement("a")
        let attr = doc.CreateAttribute("href")
        attr.Value <- href
        a.Attributes.Append(attr) |> ignore
        a.InnerText <- text
        p2.AppendChild(a) |> ignore
        if i < footerLinks.Length - 1 then
            let separator = doc.CreateTextNode(" | \n")
            p2.AppendChild(separator) |> ignore
    
    // Script at the end
    let script = doc.CreateElement("script")
    let attr85 = doc.CreateAttribute("data-cfasync")
    attr85.Value <- "false"
    let attr86 = doc.CreateAttribute("src")
    attr86.Value <- "/cdn-cgi/scripts/5c5dd728/cloudflare-static/email-decode.min.js"
    let attr87 = doc.CreateAttribute("defer")
    script.Attributes.Append(attr85) |> ignore
    script.Attributes.Append(attr86) |> ignore
    script.Attributes.Append(attr87) |> ignore
    body.AppendChild(script) |> ignore
    
    // Save to file
    use writer = new XmlTextWriter(outputPath, System.Text.Encoding.UTF8)
    writer.Formatting <- Formatting.Indented
    writer.Indentation <- 4
    doc.Save(writer)

// Main function
[<EntryPoint>]
let main argv =
    let outputPath = if argv.Length > 0 then argv.[0] else "index.html"
    createHtmlDocument outputPath
    0

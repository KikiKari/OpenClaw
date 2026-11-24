// abstraction-provenance: {"artifact_sha256": "c6f95d01359e01da7e3dbe74019c5c0c326928459400d8baf23d70e432e22eb6", "source_sha256": "58ad2830d3e11b79c54044cfe5a82e7e3fd2a9b1ca1f65c546ff6e92e821c6f3", "target_language": "fsharp"}
// index.html — portiert nach fsharp
// Quelle: html, Projects@Telegram-Monitor:public/index.html
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

open System
open System.IO
open System.Text

type HtmlElement =
    | Element of string * HtmlAttribute list * HtmlElement list
    | Text of string
    | RawHtml of string

and HtmlAttribute = Attr of string * string

module Html =
    let tag name attrs children = Element(name, attrs, children)
    let text s = Text(s)
    let raw s = RawHtml(s)
    
    let attr name value = Attr(name, value)
    
    let css s = RawHtml(s)
    
    let render (element: HtmlElement) : string =
        let sb = StringBuilder()
        
        let rec renderElement indent element =
            match element with
            | Text t -> sb.Append(t) |> ignore
            let escape s =
                s.Replace("&", "&amp;")
                 .Replace("<", "&lt;")
                 .Replace(">", "&gt;")
                 .Replace("\"", "&quot;")
            match element with
            | Text t -> sb.Append(escape t) |> ignore
            | RawHtml h -> sb.Append(h) |> ignore
            | Element(name, attrs, children) ->
                sb.Append("<").Append(name) |> ignore
                for (Attr(attrName, attrValue)) in attrs do
                    sb.Append(" ").Append(attrName).Append("=\"")
                      .Append(attrValue.Replace("\"", "&quot;")).Append("\"") |> ignore
                if List.isEmpty children then
                    sb.Append("/>") |> ignore
                else
                    sb.Append(">") |> ignore
                    for child in children do
                        renderElement (indent + "  ") child
                    sb.Append("</").Append(name).Append(">") |> ignore
        
        renderElement "" element
        sb.ToString()

[<EntryPoint>]
let main argv =
    let outFile = 
        if argv.Length > 0 then argv.[0]
        else "index.html"
    
    let htmlDoc = 
        Html.tag "html" [Html.attr "lang" "de"] [
            Html.tag "head" [] [
                Html.raw "<meta charset=\"utf-8\">"
                Html.raw "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
                Html.tag "title" [] [Html.text "Telegram Monitor — lokaler Beobachtungs-Companion"]
                Html.raw "<meta name=\"description\" content=\"Beobachtet öffentliche Telegram-Kanäle und TikTok-Konten auf dem eigenen Rechner und meldet den Livegang. Keine Cloud, keine Anmeldung.\">"
                Html.raw "<meta name=\"theme-color\" content=\"#2481cc\">"
                Html.raw "<meta property=\"og:title\" content=\"Telegram Monitor\">"
                Html.raw "<meta property=\"og:description\" content=\"Lokaler Beobachtungs-Companion. Docker, PWA, Meldung beim Livegang.\">"
                Html.raw "<meta property=\"og:type\" content=\"website\">"
                
                Html.tag "style" [] [
                    Html.raw """
  :root{
    --bg:#ffffff; --soft:#f6f7f9; --line:#e3e6ea; --text:#16191d; --muted:#5f6773;
    --tg:#2481cc; --tg-soft:#e8f2fb; --tt:#fe2c55;
    --ok:#15803d; --ok-soft:#e7f6ec; --warn:#b45309; --warn-soft:#fdf3e3;
    color-scheme: light;
  }
  @media (prefers-color-scheme: dark){
    :root{ --bg:#0f1115; --soft:#171a21; --line:#262b36; --text:#f2f4f8; --muted:#9aa3b2;
           --tg-soft:#132a3d; --ok-soft:#12261a; --warn-soft:#2c2110; color-scheme: dark; }
  }
  *{box-sizing:border-box}
  body{margin:0;background:var(--bg);color:var(--text);
       font:16px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif}
  .wrap{max-width:820px;margin:0 auto;padding:0 20px 72px}
  header{padding:64px 0 40px;border-bottom:1px solid var(--line);margin-bottom:8px}
  h1{font-size:34px;line-height:1.2;margin:0 0 12px;letter-spacing:-.02em}
  .lede{font-size:18px;color:var(--muted);margin:0 0 22px;max-width:60ch}
  h2{font-size:13px;margin:44px 0 14px;text-transform:uppercase;letter-spacing:.06em;
     color:var(--muted);font-weight:650}
  h3{font-size:17px;margin:26px 0 6px}
  p{margin:0 0 14px;max-width:68ch}
  .badges{display:flex;gap:7px;flex-wrap:wrap;margin-bottom:22px}
  .badge{font-size:12px;font-weight:650;padding:4px 11px;border-radius:99px;
         background:var(--soft);color:var(--muted);border:1px solid var(--line)}
  .badge.on{background:var(--ok-soft);color:var(--ok);border-color:transparent}
  .cta{display:flex;gap:10px;flex-wrap:wrap}
  .btn{display:inline-block;font-weight:650;font-size:15px;padding:11px 20px;
       border-radius:9px;text-decoration:none;border:1px solid var(--line);
       background:var(--bg);color:var(--text)}
  .btn.primary{background:var(--tg);border-color:var(--tg);color:#fff}
  .btn:hover{border-color:var(--tg)}
  .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:14px}
  .card{border:1px solid var(--line);border-radius:12px;padding:16px 18px;background:var(--bg)}
  .card h3{margin-top:0;font-size:15.5px}
  .card p{font-size:14px;color:var(--muted);margin:0}
  ol.steps{list-style:none;counter-reset:s;padding:0;margin:0}
  ol.steps li{counter-increment:s;position:relative;padding:0 0 20px 40px;
              border-left:2px solid var(--line);margin-left:11px}
  ol.steps li:last-child{border-left-color:transparent;padding-bottom:0}
  ol.steps li::before{content:counter(s);position:absolute;left:-13px;top:0;
       width:24px;height:24px;border-radius:50%;background:var(--tg);color:#fff;
       display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:700}
  ol.steps b{display:block;margin-bottom:3px}
  ol.steps p{font-size:14.5px;color:var(--muted);margin:0 0 8px}
  code{background:var(--soft);padding:2px 7px;border-radius:5px;font-size:13.5px;
       font-family:ui-monospace,SFMono-Regular,Menlo,monospace;word-break:break-word}
  pre{background:var(--soft);border:1px solid var(--line);border-radius:10px;
      padding:13px 15px;overflow-x:auto;margin:0 0 14px}
  pre code{background:none;padding:0;font-size:13.5px;line-height:1.7}
  table{width:100%;border-collapse:collapse;font-size:14.5px;margin:0 0 16px}
  th,td{text-align:left;padding:9px 11px;border-bottom:1px solid var(--line);vertical-align:top}
  th{color:var(--muted);font-size:12px;text-transform:uppercase;letter-spacing:.04em;font-weight:650}
  .note{border-left:3px solid var(--warn);background:var(--warn-soft);
        border-radius:0 9px 9px 0;padding:13px 16px;margin:0 0 16px;font-size:14.5px}
  .note b{display:block;margin-bottom:3px}
  a{color:var(--tg)}
  footer{margin-top:52px;padding-top:22px;border-top:1px solid var(--line);
         font-size:13.5px;color:var(--muted)}
"""
                ]
            ]
            
            Html.tag "body" [] [
                Html.tag "div" [Html.attr "class" "wrap"] [
                    
                    Html.tag "header" [] [
                        Html.tag "h1" [] [Html.text "Telegram Monitor"]
                        Html.tag "p" [Html.attr "class" "lede"] [
                            Html.text "Beobachtet öffentliche Telegram-Kanäle und TikTok-Konten auf"
                            Html.text " deinem eigenen Rechner und meldet sich, wenn jemand live geht. Keine Cloud,"
                            Html.text " kein Konto, keine App-Installation auf dem Telefon nötig."
                        ]
                        
                        Html.tag "div" [Html.attr "class" "badges"] [
                            Html.tag "span" [Html.attr "class" "badge on"] [Html.text "Standardbibliothek"]
                            Html.tag "span" [Html.attr "class" "badge on"] [Html.text "Docker"]
                            Html.tag "span" [Html.attr "class" "badge on"] [Html.text "installierbar als App"]
                            Html.tag "span" [Html.attr "class" "badge on"] [Html.text "Browser-Erweiterung"]
                            Html.tag "span" [Html.attr "class" "badge"] [Html.text "Windows · macOS · Linux"]
                        ]
                        
                        Html.tag "div" [Html.attr "class" "cta"] [
                            Html.tag "a" [Html.attr "class" "btn primary"; Html.attr "href" "https://github.com/KikiKari/Projects/tree/Telegram-Monitor"] [Html.text "Quelltext auf GitHub"]
                            Html.tag "a" [Html.attr "class" "btn"; Html.attr "href" "/viewer"] [Html.text "Live-Viewer öffnen"]
                        ]
                    ]
                    
                    Html.tag "h2" [] [Html.text "Was es tut"]
                    Html.tag "div" [Html.attr "class" "grid"] [
                        Html.tag "div" [Html.attr "class" "card"] [
                            Html.tag "h3" [] [Html.text "Beobachten"]
                            Html.tag "p" [] [
                                Html.text "Fragt jeden Kanal im eingestellten Turnus ab und sammelt den Verlauf auf"
                                Html.text " der Platte — neueste Beiträge oben, anders als in Telegram selbst."
                            ]
                        ]
                        Html.tag "div" [Html.attr "class" "card"] [
                            Html.tag "h3" [] [Html.text "Erkennen"]
                            Html.tag "p" [] [
                                Html.text "Vergleicht den Zustand mit dem letzten Durchlauf. Gemeldet wird nur ein"
                                Html.text " echter Wechsel; ein fehlgeschlagener Abruf gilt nicht als „offline\"."
                            ]
                        ]
                        Html.tag "div" [Html.attr "class" "card"] [
                            Html.tag "h3" [] [Html.text "Melden"]
                            Html.tag "p" [] [
                                Html.text "Drei Wege gleichzeitig: Ereignisprotokoll, Systemmeldung und Webhook."
                                Html.text " Fällt einer aus, steht der Wechsel trotzdem mit Zeitstempel fest."
                            ]
                        ]
                    ]
                    
                    Html.tag "h2" [] [Html.text "Drei Zugänge, ein Monitor"]
                    Html.tag "table" [] [
                        Html.tag "tr" [] [
                            Html.tag "th" [] [Html.text "Zugang"]
                            Html.tag "th" [] [Html.text "wofür"]
                        ]
                        Html.tag "tr" [] [
                            Html.tag "td" [] [
                                Html.tag "b" [] [Html.text "Installierte App"]
                            ]
                            Html.tag "td" [] [
                                Html.text "Vollständige Oberfläche mit allen Reitern, eigenes Fenster ohne"
                                Html.text " Adressleiste, Symbol im Startmenü"
                            ]
                        ]
                        Html.tag "tr" [] [
                            Html.tag "td" [] [
                                Html.tag "b" [] [Html.text "Browser-Erweiterung"]
                            ]
                            Html.tag "td" [] [
                                Html.text "Meldung beim Livegang, ohne dass ein Tab offen sein muss"
                            ]
                        ]
                        Html.tag "tr" [] [
                            Html.tag "td" [] [
                                Html.tag "b" [] [Html.text "Live-Viewer"]
                            ]
                            Html.tag "td" [] [
                                Html.text "Bettet den offiziellen Player ein — ohne Anmeldung, ohne Geschenk-"
                                Html.text " oder Kauf-Oberfläche. "
                                Html.tag "a" [Html.attr "href" "/viewer"] [Html.text "Hier direkt ausprobieren."]
                            ]
                        ]
                    ]
                    
                    Html.tag "h2" [] [Html.text "Einrichten"]
                    Html.tag "ol" [Html.attr "class" "steps"] [
                        Html.tag "li" [] [
                            Html.tag "b" [] [Html.text "Repository holen"]
                            Html.tag "p" [] [Html.text "Branch "; Html.tag "code" [] [Html.text "Telegram-Monitor"]; Html.text " auschecken."]
                            Html.tag "pre" [] [
                                Html.tag "code" [] [
                                    Html.text "git clone -b Telegram-Monitor https://github.com/KikiKari/Projects.git"
                                    Html.raw "\n"
                                    Html.text "cd Projects"
                                ]
                            ]
                        ]
                        Html.tag "li" [] [
                            Html.tag "b" [] [Html.text "Dauerhaft starten"]
                            Html.tag "p" [] [
                                Html.text "Bindet an "; Html.tag "code" [] [Html.text "127.0.0.1:8765"]; Html.text ", der Verlauf liegt im Volume"
                                Html.text " "; Html.tag "code" [] [Html.text "monitor-data"]; Html.text " und überlebt jedes Neubauen. Unter Windows"
                                Html.text " genügt ein Doppelklick auf "; Html.tag "code" [] [Html.text "Telegram Monitor - Docker.cmd"]; Html.text "."
                            ]
                            Html.tag "pre" [] [
                                Html.tag "code" [] [Html.text "docker compose up -d --build"]
                            ]
                        ]
                        Html.tag "li" [] [
                            Html.tag "b" [] [Html.text "Ohne Docker"]
                            Html.tag "p" [] [
                                Html.text "Der Kern braucht nur die Standardbibliothek — nichts zu installieren."
                            ]
                            Html.tag "pre" [] [
                                Html.tag "code" [] [Html.text "python server.py --poll-interval 120"]
                            ]
                        ]
                        Html.tag "li" [] [
                            Html.tag "b" [] [Html.text "Als App einrichten"]
                            Html.tag "p" [] [
                                Html.text "In der geöffneten Oberfläche auf "; Html.tag "b" [] [Html.text "Als App installieren"]; Html.text " klicken."
                                Html.text " Danach liegt der Monitor als eigenes Programm im Startmenü."
                            ]
                        ]
                        Html.tag "li" [] [
                            Html.tag "b" [] [Html.text "Aufs Telefon bringen"]
                            Html.tag "p" [] [
                                Html.text "Über das eigene VPN freigeben, dann die "; Html.tag "code" [] [Html.text "https"]; Html.text "-Adresse auf"
                                Html.text " dem Telefon öffnen und dort installieren. Eine "; Html.tag "code" [] [Html.text ".apk"]; Html.text " gibt es"
                                Html.text " nicht und wird auch nicht gebraucht."
                            ]
                            Html.tag "pre" [] [
                                Html.tag "code" [] [Html.text "tailscale serve --bg 8765"]
                            ]
                        ]
                    ]
                    
                    Html.tag "h2" [] [Html.text "Was hier nicht läuft"]
                    Html.tag "div" [Html.attr "class" "note"] [
                        Html.tag "b" [] [Html.text "Diese Seite ist nur die Visitenkarte."]
                        Html.tag "p" [] [
                            Html.text "Der Monitor selbst läuft "; Html.tag "i" [] [Html.text "nicht"]; Html.text " im Web. Sein Kern ist ein"
                            Html.text " Hintergrundprozess, der dauerhaft abfragt und Zustand auf die Platte"
                            Html.text " schreibt — beides gibt es in einer serverlosen Umgebung nicht. Ausgeliefert"
                            Html.text " werden hier nur diese Seite und der Viewer, der ohnehin ohne Server"
                            Html.text " auskommt. Beobachtet wird auf deinem Rechner."
                        ]
                    ]
                    
                    Html.tag "h2" [] [Html.text "Grenzen"]
                    Html.tag "p" [] [
                        Html.text "Gelesen wird ausschließlich, was öffentlich abrufbar ist. Anmeldeschranken"
                        Html.text " und Zugriffssperren werden nicht umgangen — wo es offizielle Einbettungen"
                        Html.text " gibt, werden die genommen. Private Telegram-Konten liefern nur Name und Bio;"
                        Html.text " das ist eine Einschränkung von Telegram, kein Fehler."
                    ]
                    Html.tag "p" [] [
                        Html.text "Der Turnus bleibt höflich: ein bis fünf Minuten. Sekundentakt bringt selten"
                        Html.text " mehr Information und handelt eine Sperre ein."
                    ]
                    
                    Html.tag "footer" [] [
                        Html.text "Läuft lokal, gehört dir. Das wiederverwendbare Muster dahinter steckt im Skill"
                        Html.tag "code" [] [Html.text "lokaler-companion"]
                        Html.text "."
                    ]
                ]
            ]
        ]
    
    let fullDoc = 
        "<!DOCTYPE html>\n" + (Html.render htmlDoc)
    
    File.WriteAllText(outFile, fullDoc)
    0

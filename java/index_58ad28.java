// abstraction-provenance: {"artifact_sha256": "c1eb6a3272a1976af24dd5dd49f8c8079bd44c5c203c7c94df00c035626412b6", "source_sha256": "58ad2830d3e11b79c54044cfe5a82e7e3fd2a9b1ca1f65c546ff6e92e821c6f3", "target_language": "java"}
// index.html — portiert nach java
// Quelle: html, Projects@Telegram-Monitor:public/index.html
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.List;

public class IndexGenerator {

    public static void main(String[] args) {
        if (args.length != 1) {
            System.err.println("Usage: java IndexGenerator <output-file>");
            System.exit(1);
        }

        String outputFile = args[0];
        
        try (PrintWriter writer = new PrintWriter(new OutputStreamWriter(
                new FileOutputStream(outputFile), StandardCharsets.UTF_8))) {
            
            generateHtml(writer);
            
        } catch (IOException e) {
            System.err.println("Error writing file: " + e.getMessage());
            System.exit(1);
        }
    }

    private static void generateHtml(PrintWriter out) {
        out.println("<!DOCTYPE html>");
        out.println("<html lang=\"de\">");
        out.println("<head>");
        out.println("<meta charset=\"utf-8\">");
        out.println("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">");
        out.println("<title>Telegram Monitor — lokaler Beobachtungs-Companion</title>");
        out.println("<meta name=\"description\" content=\"Beobachtet öffentliche Telegram-Kanäle und TikTok-Konten auf dem eigenen Rechner und meldet den Livegang. Keine Cloud, keine Anmeldung.\">");
        out.println("<meta name=\"theme-color\" content=\"#2481cc\">");
        out.println("<meta property=\"og:title\" content=\"Telegram Monitor\">");
        out.println("<meta property=\"og:description\" content=\"Lokaler Beobachtungs-Companion. Docker, PWA, Meldung beim Livegang.\">");
        out.println("<meta property=\"og:type\" content=\"website\">");
        out.println("<style>");
        out.println("  :root{");
        out.println("    --bg:#ffffff; --soft:#f6f7f9; --line:#e3e6ea; --text:#16191d; --muted:#5f6773;");
        out.println("    --tg:#2481cc; --tg-soft:#e8f2fb; --tt:#fe2c55;");
        out.println("    --ok:#15803d; --ok-soft:#e7f6ec; --warn:#b45309; --warn-soft:#fdf3e3;");
        out.println("    color-scheme: light;");
        out.println("  }");
        out.println("  @media (prefers-color-scheme: dark){");
        out.println("    :root{ --bg:#0f1115; --soft:#171a21; --line:#262b36; --text:#f2f4f8; --muted:#9aa3b2;");
        out.println("           --tg-soft:#132a3d; --ok-soft:#12261a; --warn-soft:#2c2110; color-scheme: dark; }");
        out.println("  }");
        out.println("  *{box-sizing:border-box}");
        out.println("  body{margin:0;background:var(--bg);color:var(--text);");
        out.println("       font:16px/1.6 -apple-system,BlinkMacSystemFont,\"Segoe UI\",Roboto,sans-serif}");
        out.println("  .wrap{max-width:820px;margin:0 auto;padding:0 20px 72px}");
        out.println("  header{padding:64px 0 40px;border-bottom:1px solid var(--line);margin-bottom:8px}");
        out.println("  h1{font-size:34px;line-height:1.2;margin:0 0 12px;letter-spacing:-.02em}");
        out.println("  .lede{font-size:18px;color:var(--muted);margin:0 0 22px;max-width:60ch}");
        out.println("  h2{font-size:13px;margin:44px 0 14px;text-transform:uppercase;letter-spacing:.06em;");
        out.println("     color:var(--muted);font-weight:650}");
        out.println("  h3{font-size:17px;margin:26px 0 6px}");
        out.println("  p{margin:0 0 14px;max-width:68ch}");
        out.println("  .badges{display:flex;gap:7px;flex-wrap:wrap;margin-bottom:22px}");
        out.println("  .badge{font-size:12px;font-weight:650;padding:4px 11px;border-radius:99px;");
        out.println("         background:var(--soft);color:var(--muted);border:1px solid var(--line)}");
        out.println("  .badge.on{background:var(--ok-soft);color:var(--ok);border-color:transparent}");
        out.println("  .cta{display:flex;gap:10px;flex-wrap:wrap}");
        out.println("  .btn{display:inline-block;font-weight:650;font-size:15px;padding:11px 20px;");
        out.println("       border-radius:9px;text-decoration:none;border:1px solid var(--line);");
        out.println("       background:var(--bg);color:var(--text)}");
        out.println("  .btn.primary{background:var(--tg);border-color:var(--tg);color:#fff}");
        out.println("  .btn:hover{border-color:var(--tg)}");
        out.println("  .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:14px}");
        out.println("  .card{border:1px solid var(--line);border-radius:12px;padding:16px 18px;background:var(--bg)}");
        out.println("  .card h3{margin-top:0;font-size:15.5px}");
        out.println("  .card p{font-size:14px;color:var(--muted);margin:0}");
        out.println("  ol.steps{list-style:none;counter-reset:s;padding:0;margin:0}");
        out.println("  ol.steps li{counter-increment:s;position:relative;padding:0 0 20px 40px;");
        out.println("              border-left:2px solid var(--line);margin-left:11px}");
        out.println("  ol.steps li:last-child{border-left-color:transparent;padding-bottom:0}");
        out.println("  ol.steps li::before{content:counter(s);position:absolute;left:-13px;top:0;");
        out.println("       width:24px;height:24px;border-radius:50%;background:var(--tg);color:#fff;");
        out.println("       display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:700}");
        out.println("  ol.steps b{display:block;margin-bottom:3px}");
        out.println("  ol.steps p{font-size:14.5px;color:var(--muted);margin:0 0 8px}");
        out.println("  code{background:var(--soft);padding:2px 7px;border-radius:5px;font-size:13.5px;");
        out.println("       font-family:ui-monospace,SFMono-Regular,Menlo,monospace;word-break:break-word}");
        out.println("  pre{background:var(--soft);border:1px solid var(--line);border-radius:10px;");
        out.println("      padding:13px 15px;overflow-x:auto;margin:0 0 14px}");
        out.println("  pre code{background:none;padding:0;font-size:13.5px;line-height:1.7}");
        out.println("  table{width:100%;border-collapse:collapse;font-size:14.5px;margin:0 0 16px}");
        out.println("  th,td{text-align:left;padding:9px 11px;border-bottom:1px solid var(--line);vertical-align:top}");
        out.println("  th{color:var(--muted);font-size:12px;text-transform:uppercase;letter-spacing:.04em;font-weight:650}");
        out.println("  .note{border-left:3px solid var(--warn);background:var(--warn-soft);");
        out.println("        border-radius:0 9px 9px 0;padding:13px 16px;margin:0 0 16px;font-size:14.5px}");
        out.println("  .note b{display:block;margin-bottom:3px}");
        out.println("  a{color:var(--tg)}");
        out.println("  footer{margin-top:52px;padding-top:22px;border-top:1px solid var(--line);");
        out.println("         font-size:13.5px;color:var(--muted)}");
        out.println("</style>");
        out.println("</head>");
        out.println("<body>");
        out.println("<div class=\"wrap\">");
        out.println();
        out.println("<header>");
        out.println("  <h1>Telegram Monitor</h1>");
        out.println("  <p class=\"lede\">Beobachtet öffentliche Telegram-Kanäle und TikTok-Konten auf");
        out.println("     deinem eigenen Rechner und meldet sich, wenn jemand live geht. Keine Cloud,");
        out.println("     kein Konto, keine App-Installation auf dem Telefon nötig.</p>");
        out.println("  <div class=\"badges\">");
        out.println("    <span class=\"badge on\">Standardbibliothek</span>");
        out.println("    <span class=\"badge on\">Docker</span>");
        out.println("    <span class=\"badge on\">installierbar als App</span>");
        out.println("    <span class=\"badge on\">Browser-Erweiterung</span>");
        out.println("    <span class=\"badge\">Windows · macOS · Linux</span>");
        out.println("  </div>");
        out.println("  <div class=\"cta\">");
        out.println("    <a class=\"btn primary\" href=\"https://github.com/KikiKari/Projects/tree/Telegram-Monitor\">Quelltext auf GitHub</a>");
        out.println("    <a class=\"btn\" href=\"/viewer\">Live-Viewer öffnen</a>");
        out.println("  </div>");
        out.println("</header>");
        out.println();
        out.println("<h2>Was es tut</h2>");
        out.println("<div class=\"grid\">");
        out.println("  <div class=\"card\">");
        out.println("    <h3>Beobachten</h3>");
        out.println("    <p>Fragt jeden Kanal im eingestellten Turnus ab und sammelt den Verlauf auf");
        out.println("       der Platte — neueste Beiträge oben, anders als in Telegram selbst.</p>");
        out.println("  </div>");
        out.println("  <div class=\"card\">");
        out.println("    <h3>Erkennen</h3>");
        out.println("    <p>Vergleicht den Zustand mit dem letzten Durchlauf. Gemeldet wird nur ein");
        out.println("       echter Wechsel; ein fehlgeschlagener Abruf gilt nicht als „offline\".</p>");
        out.println("  </div>");
        out.println("  <div class=\"card\">");
        out.println("    <h3>Melden</h3>");
        out.println("    <p>Drei Wege gleichzeitig: Ereignisprotokoll, Systemmeldung und Webhook.");
        out.println("       Fällt einer aus, steht der Wechsel trotzdem mit Zeitstempel fest.</p>");
        out.println("  </div>");
        out.println("</div>");
        out.println();
        out.println("<h2>Drei Zugänge, ein Monitor</h2>");
        out.println("<table>");
        out.println("  <tr><th>Zugang</th><th>wofür</th></tr>");
        out.println("  <tr><td><b>Installierte App</b></td>");
        out.println("      <td>Vollständige Oberfläche mit allen Reitern, eigenes Fenster ohne");
        out.println("          Adressleiste, Symbol im Startmenü</td></tr>");
        out.println("  <tr><td><b>Browser-Erweiterung</b></td>");
        out.println("      <td>Meldung beim Livegang, ohne dass ein Tab offen sein muss</td></tr>");
        out.println("  <tr><td><b>Live-Viewer</b></td>");
        out.println("      <td>Bettet den offiziellen Player ein — ohne Anmeldung, ohne Geschenk-");
        out.println("          oder Kauf-Oberfläche. <a href=\"/viewer\">Hier direkt ausprobieren.</a></td></tr>");
        out.println("</table>");
        out.println();
        out.println("<h2>Einrichten</h2>");
        out.println("<ol class=\"steps\">");
        out.println("  <li>");
        out.println("    <b>Repository holen</b>");
        out.println("    <p>Branch <code>Telegram-Monitor</code> auschecken.</p>");
        out.println("<pre><code>git clone -b Telegram-Monitor https://github.com/KikiKari/Projects.git");
        out.println("cd Projects</code></pre>");
        out.println("  </li>");
        out.println("  <li>");
        out.println("    <b>Dauerhaft starten</b>");
        out.println("    <p>Bindet an <code>127.0.0.1:8765</code>, der Verlauf liegt im Volume");
        out.println("       <code>monitor-data</code> und überlebt jedes Neubauen. Unter Windows");
        out.println("       genügt ein Doppelklick auf <code>Telegram Monitor - Docker.cmd</code>.</p>");
        out.println("<pre><code>docker compose up -d --build</code></pre>");
        out.println("  </li>");
        out.println("  <li>");
        out.println("    <b>Ohne Docker</b>");
        out.println("    <p>Der Kern braucht nur die Standardbibliothek — nichts zu installieren.</p>");
        out.println("<pre><code>python server.py --poll-interval 120</code></pre>");
        out.println("  </li>");
        out.println("  <li>");
        out.println("    <b>Als App einrichten</b>");
        out.println("    <p>In der geöffneten Oberfläche auf <b>Als App installieren</b> klicken.");
        out.println("       Danach liegt der Monitor als eigenes Programm im Startmenü.</p>");
        out.println("  </li>");
        out.println("  <li>");
        out.println("    <b>Aufs Telefon bringen</b>");
        out.println("    <p>Über das eigene VPN freigeben, dann die <code>https</code>-Adresse auf");
        out.println("       dem Telefon öffnen und dort installieren. Eine <code>.apk</code> gibt es");
        out.println("       nicht und wird auch nicht gebraucht.</p>");
        out.println("<pre><code>tailscale serve --bg 8765</code></pre>");
        out.println("  </li>");
        out.println("</ol>");
        out.println();
        out.println("<h2>Was hier nicht läuft</h2>");
        out.println("<div class=\"note\">");
        out.println("  <b>Diese Seite ist nur die Visitenkarte.</b>");
        out.println("  Der Monitor selbst läuft <i>nicht</i> im Web. Sein Kern ist ein");
        out.println("  Hintergrundprozess, der dauerhaft abfragt und Zustand auf die Platte");
        out.println("  schreibt — beides gibt es in einer serverlosen Umgebung nicht. Ausgeliefert");
        out.println("  werden hier nur diese Seite und der Viewer, der ohnehin ohne Server");
        out.println("  auskommt. Beobachtet wird auf deinem Rechner.");
        out.println("</div>");
        out.println();
        out.println("<h2>Grenzen</h2>");
        out.println("<p>Gelesen wird ausschließlich, was öffentlich abrufbar ist. Anmeldeschranken");
        out.println("   und Zugriffssperren werden nicht umgangen — wo es offizielle Einbettungen");
        out.println("   gibt, werden die genommen. Private Telegram-Konten liefern nur Name und Bio;");
        out.println("   das ist eine Einschränkung von Telegram, kein Fehler.</p>");
        out.println("<p>Der Turnus bleibt höflich: ein bis fünf Minuten. Sekundentakt bringt selten");
        out.println("   mehr Information und handelt eine Sperre ein.</p>");
        out.println();
        out.println("<footer>");
        out.println("  Läuft lokal, gehört dir. Das wiederverwendbare Muster dahinter steckt im Skill");
        out.println("  <code>lokaler-companion</code>.");
        out.println("</footer>");
        out.println();
        out.println("</div>");
        out.println("</body>");
        out.println("</html>");
    }
}

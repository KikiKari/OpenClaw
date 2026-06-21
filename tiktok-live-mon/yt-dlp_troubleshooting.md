> **Runtime-Hinweis (2026-06-21):** Diese Datei ist Hintergrund-/Upstream-Referenz, nicht der aktive Laufzeitvertrag. Der aktive Extractor nutzt exakte Account-Selektoren, akzeptiert nur beobachtete HTTPS-TikTok-CDN-`.flv`-Antworten mit HTTP `2xx`, verändert keine signierten URLs, klassifiziert eingeschränkte LIVE-Sessions als `restricted` mit Exit `1` und wird über `tiktok_dispatch.py` lokal oder agent-gesteuert mit `exec host=node` ausgeführt.
>

# yt-dlp Dokumentation - TikTok Probleme & Lösungen

**Quellen:** GitHub Issues (`#15970`, `#11921`), FAQ (`wiki/FAQ`), Reddit-Diskussionen
**Schlüsselprobleme:**
1.  `HTTP Error 400: Bad Request`
2.  `The channel is not currently live` (obwohl live erkannt)
3.  `impersonation` Fehler
4.  Cookies/Authentifizierungsprobleme
5.  Veraltete Versionen

## Mögliche Lösungsansätze

### 1. `HTTP Error 400: Bad Request` & `impersonation`

*   **Ursache:** yt-dlp versucht, wie ein Browser zu agieren, aber notwendige Header oder Konfigurationen fehlen. TikTok könnte die Anfrage blockieren.
*   **Lösungsansätze:**
    *   **Aktualisiere yt-dlp:** Benutze die neueste Version (`yt-dlp -U`).
    *   **User-Agent / Header:** Füge `--user-agent "DEINE_BROWSER_USER_AGENT"` hinzu. Die genaue User-Agent-String deines Browsers kann recherchiert werden (z.B. "my user agent" in Google).
    *   **Cookies:**
        *   Exportiere Cookies von einer *frischen* Browsersitzung (`--cookies-from-browser chrome`, `--cookies cookies.txt`).
        *   Stelle sicher, dass das Cookie-Format korrekt ist (Mozilla/Netscape Format, korrekte Zeilenumbrüche).
    *   **Impersonation:** Untersuche die yt-dlp Optionen für `impersonate`, falls relevante Targets verfügbar sind.
    *   **Service-Verfügbarkeit:** Prüfe, ob TikTok selbst Probleme hat oder die API-Endpunkte geändert wurden.

### 2. `The channel is not currently live`

*   **Ursache:** Kann auf Probleme mit der Erkennung des Live-Status oder Probleme mit der API-Antwort hindeuten. Kann auch mit Authentifizierungsproblemen zusammenhängen.
*   **Lösungsansätze:**
    *   Erneuter Versuch nach kurzer Wartezeit.
    *   Siehe Lösungen für `HTTP Error 400` (User-Agent, Cookies).

### 3. Veraltete Versionen

*   **Problem:** Dynamische Seiten wie TikTok ändern ihre Struktur häufig. Veraltete Versionen von yt-dlp haben Probleme, diese Änderungen zu verarbeiten.
*   **Lösung:** Immer die aktuellste Version von yt-dlp verwenden.

### 4. Stream-URL Extraktion

*   **Problem:** Extrahierte URLs sind zu lang, unvollständig oder abgelaufen.
*   **Hinweis:** yt-dlp extrahiert oft Links mit vielen Parametern. Die Verwendung von `--force-keyframes-at-cuts` oder anderen Formatierungsoptionen kann helfen, wenn es um das Schneiden von Videos geht, ist aber für Live-Streams weniger relevant.
*   **Alternativen:** Die Dokumentation erwähnt `streamlink` und `ffmpeg` als Alternativen oder Ergänzungen für bestimmte Szenarien.

### Generelle Tipps

*   **Verbose Output:** Verwende `-vU` für detaillierte Logs.
*   **Download Archive:** `--download-archive ARCHIVE.txt` um bereits heruntergeladene Videos zu überspringen.
*   **Format Selection:** Nutze `-f` oder `-S` für spezifische Formatwahlen (z.B. `vcodec:h264,fps,res:720,acodec:m4a`).

**Fazit:**
Die Probleme mit yt-dlp und TikTok sind oft auf Änderungen auf der TikTok-Seite zurückzuführen, die eine Anpassung von yt-dlp erfordern. User-Agent, Cookies und die Aktualisierung des Tools sind meist Schlüssel zur Lösung.

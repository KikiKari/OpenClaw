> **Runtime-Hinweis (2026-06-21):** Diese Datei ist Hintergrund-/Upstream-Referenz, nicht der aktive Laufzeitvertrag. Der aktive Extractor nutzt exakte Account-Selektoren, akzeptiert nur beobachtete HTTPS-TikTok-CDN-`.flv`-Antworten mit HTTP `2xx`, verändert keine signierten URLs, klassifiziert eingeschränkte LIVE-Sessions als `restricted` mit Exit `1` und wird über `tiktok_dispatch.py` lokal oder agent-gesteuert mit `exec host=node` ausgeführt.
>

# yt-dlp Dokumentation - TikTok Probleme

**Quelle:** Auszüge aus dem `tiktok-live`-Skill und GitHub Issues zu yt-dlp.
**Abgerufen:** Lokale Analyse, externe Suche nicht möglich.

## Problembeschreibung

*   **Fehler bei TikTok Live Stream Extraktion:**
    *   `HTTP Error 400: Bad Request`
    *   `ERROR: [tiktok:live] example_creator: The channel is not currently live` (obwohl live erkannt wurde)
*   **`impersonation` / User-Agent Probleme:**
    *   Fehlermeldung: `yt-dlp: The extractor is attempting impersonation, but no impersonate target is available.`
    *   Hinweis: Dies deutet darauf hin, dass yt-dlp versucht, sich als Browser auszugeben, aber dafür notwendige Header oder Konfigurationen fehlen.

## Mögliche Lösungsansätze (generell, basierend auf Issues/Erkenntnissen)

1.  **User-Agent und Header:**
    *   **Problem:** HTTP 400-Fehler können oft durch das Setzen eines aktuellen `User-Agent`-Headers oder anderer HTTP-Header verursacht werden.
    *   **Mögliche Lösung:** Überprüfen, ob yt-dlp Optionen zur Übergabe von User-Agents oder Headern bietet. Dies könnte im Skript angepasst werden, falls die yt-dlp Aufrufe diese Optionen erlauben. (Hinweis: Dies ist eine generelle Problemlösung, keine spezifischeyt-dlp Option für TikTok in den lokalen Skripten bekannt.)

2.  **`impersonation`:**
    *   **Problem:** Die Meldung deutet auf ein Problem mit der Nachahmung des Browser-Verhaltens hin.
    *   **Hinweis:** Möglicherweise muss ein `--impersonate` oder ähnlicher Parameter verwendet werden, um die Anfrage zu authentifizieren oder besser zu verschleiern. Die Dokumentation von yt-dlp (falls zugänglich) würde hier mehr Details liefern.

3.  **Aktualisierung von yt-dlp:**
    *   **Problem:** Veraltete Versionen können Probleme mit dynamischen Seiten wie TikTok haben.
    *   **Empfehlung:** Sicherstellen, dass die neueste Version von yt-dlp verwendet wird.

4.  **Cookies:**
    *   Manchmal ist die Verwendung von Cookies für den Zugriff auf bestimmte Inhalte erforderlich. Dies ist jedoch für Live-Streams oft schwieriger zu implementieren.

## Fazit für TikTok Live

Die `HTTP Error 400` und `impersonation`-Fehler deuten darauf hin, dass yt-dlp Probleme hat, mit den aktuellen Sicherheitsmechanismen von TikTok klarzukommen. Ohne die Möglichkeit, die Dokumentation zu konsultieren, sind gezielte Anpassungen schwierig. Die Anpassung von User-Agent oder Headern wäre ein logischer nächster Schritt, falls das Skript dies erlaubt.

**Wichtig:** Die Fehlermeldung `The channel is not currently live` kann auch ein Indikator sein, dass das Problem nicht nur bei der Anfrage liegt, sondern dass der Live-Status von TikTok falsch interpretiert wird. Dies unterstreicht die Notwendigkeit des visuellen Checks (wie in Playwright implementiert).
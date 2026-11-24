// abstraction-provenance: {"artifact_sha256": "67b60954afa4512b80759b429cee30a85b0f4e9407eb285a36c35bf2f089155c", "source_sha256": "c10479f79ca5554fe399cf2f5d70fb5b32e837c1c7a846eb7dd7c9e9e5319c66", "target_language": "c"}
// index.html — portiert nach c
// Quelle: html, Projects@TikTok-Live-Companion:site/index.html
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:site/index.html
// auch in: Projects@vercel/install-and-configure-vercel-w-98sxlo:site/index.html
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>

void write_html_document(const char* filename) {
    FILE* file = fopen(filename, "w");
    if (file == NULL) {
        perror("Fehler beim Öffnen der Datei");
        exit(EXIT_FAILURE);
    }

    fprintf(file, "<!doctype html>\n");
    fprintf(file, "<html lang=\"de\">\n");
    fprintf(file, "  <head>\n");
    fprintf(file, "    <meta charset=\"UTF-8\" />\n");
    fprintf(file, "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />\n");
    fprintf(file, "    <meta name=\"description\" content=\"Dokumentation für TikTok LIVE Companion 0.8.2 – Chat-TTS, Zuschauerstatistik, Songerkennung und Stream-Informationen direkt im Browser.\" />\n");
    fprintf(file, "    <meta name=\"theme-color\" content=\"#ffffff\" />\n");
    fprintf(file, "    <link rel=\"icon\" type=\"image/png\" href=\"/branding/staenderglobus-ios.png\" />\n");
    fprintf(file, "    <link rel=\"apple-touch-icon\" href=\"/branding/staenderglobus-ios.png\" />\n");
    fprintf(file, "    <title>TikTok LIVE Companion – Dokumentation</title>\n");
    fprintf(file, "  </head>\n");
    fprintf(file, "  <body>\n");
    fprintf(file, "    <div id=\"root\"></div>\n");
    fprintf(file, "    <script type=\"module\" src=\"/src/main.tsx\"></script>\n");
    fprintf(file, "  </body>\n");
    fprintf(file, "</html>\n");

    fclose(file);
}

int main(int argc, char* argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Verwendung: %s <dateiname>\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    write_html_document(argv[1]);
    return EXIT_SUCCESS;
}

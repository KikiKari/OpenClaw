// abstraction-provenance: {"artifact_sha256": "9b8a2b6751a9fab8db1d918adf37b46ede412c3e4f42b11369b6a136c67a36de", "source_sha256": "c10479f79ca5554fe399cf2f5d70fb5b32e837c1c7a846eb7dd7c9e9e5319c66", "target_language": "cpp"}
// index.html — portiert nach cpp
// Quelle: html, Projects@TikTok-Live-Companion:site/index.html
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:site/index.html
// auch in: Projects@vercel/install-and-configure-vercel-w-98sxlo:site/index.html
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <fstream>
#include <string>

int main(int argc, char* argv[]) {
    if (argc != 2) {
        std::cerr << "Verwendung: " << argv[0] << " <ausgabedatei>" << std::endl;
        return 1;
    }

    std::ofstream datei(argv[1]);
    if (!datei.is_open()) {
        std::cerr << "Fehler beim Öffnen der Datei: " << argv[1] << std::endl;
        return 1;
    }

    datei << "<!doctype html>\n";
    datei << "<html lang=\"de\">\n";
    datei << "  <head>\n";
    datei << "    <meta charset=\"UTF-8\" />\n";
    datei << "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />\n";
    datei << "    <meta name=\"description\" content=\"Dokumentation für TikTok LIVE Companion 0.8.2 – Chat-TTS, Zuschauerstatistik, Songerkennung und Stream-Informationen direkt im Browser.\" />\n";
    datei << "    <meta name=\"theme-color\" content=\"#ffffff\" />\n";
    datei << "    <link rel=\"icon\" type=\"image/png\" href=\"/branding/staenderglobus-ios.png\" />\n";
    datei << "    <link rel=\"apple-touch-icon\" href=\"/branding/staenderglobus-ios.png\" />\n";
    datei << "    <title>TikTok LIVE Companion – Dokumentation</title>\n";
    datei << "  </head>\n";
    datei << "  <body>\n";
    datei << "    <div id=\"root\"></div>\n";
    datei << "    <script type=\"module\" src=\"/src/main.tsx\"></script>\n";
    datei << "  </body>\n";
    datei << "</html>\n";

    datei.close();
    return 0;
}

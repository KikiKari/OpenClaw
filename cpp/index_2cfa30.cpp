// abstraction-provenance: {"artifact_sha256": "9743c7fe837bc6c572417e3db9496b4a8c493f3836cbca3498763b399142ac77", "source_sha256": "2cfa301efe20d60c29e0e9f0746e5a99d405ea44a5d03839c72e6b525451fe07", "target_language": "cpp"}
// index.html — portiert nach cpp
// Quelle: html, Projects@TikTok-Live-Companion-Android:site/index.html
// auch in: Projects@TikTok-Live-Companion-iOS:site/index.html
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
    datei << "    <meta name=\"description\" content=\"Dokumentation für TikTok LIVE Companion 0.8.0 – Chat-TTS, Zuschauerstatistik, Songerkennung und Stream-Informationen direkt im Browser.\" />\n";
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

// abstraction-provenance: {"artifact_sha256": "a335d3efb157bc4778e42c61bb8dd49e35b177c7d720945bc10a8df7fab08187", "source_sha256": "735fe4b2c74b10f265f715cd4e85d574f46a7132d2e592703b5e712888470105", "target_language": "cpp"}
// index.html — portiert nach cpp
// Quelle: html, OpenClaw@main:index.html
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

    datei << "<!DOCTYPE html>\n";
    datei << "<html lang=\"de\">\n";
    datei << "  <head>\n";
    datei << "    <meta charset=\"utf-8\" />\n";
    datei << "    <link rel=\"icon\" href=\"/favicon.ico\" />\n";
    datei << "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />\n";
    datei << "    <meta name=\"theme-color\" content=\"#0b1020\" />\n";
    datei << "    <meta\n";
    datei << "      name=\"description\"\n";
    datei << "      content=\"OpenClaw Startseite für Repository, Dokumentation und Frontend-Branch.\"\n";
    datei << "    />\n";
    datei << "    <link rel=\"apple-touch-icon\" href=\"/logo192.png\" />\n";
    datei << "    <!--\n";
    datei << "      manifest.json provides metadata used when your web app is installed on a\n";
    datei << "      user's mobile device or desktop. See https://developers.google.com/web/fundamentals/web-app-manifest/\n";
    datei << "    -->\n";
    datei << "    <link rel=\"manifest\" href=\"/manifest.json\" />\n";
    datei << "    <title>OpenClaw</title>\n";
    datei << "  </head>\n";
    datei << "  <body>\n";
    datei << "    <noscript>You need to enable JavaScript to run this app.</noscript>\n";
    datei << "    <div id=\"root\"></div>\n";
    datei << "    <!--\n";
    datei << "      This HTML file is a template.\n";
    datei << "      If you open it directly in the browser, you will see an empty page.\n";
    datei << "\n";
    datei << "      You can add webfonts, meta tags, or analytics to this file.\n";
    datei << "      The build step will place the bundled scripts into the <body> tag.\n";
    datei << "\n";
    datei << "      To begin the development, run `npm start` or `yarn start`.\n";
    datei << "      To create a production bundle, use `npm run build` or `yarn build`.\n";
    datei << "    -->\n";
    datei << "  </body>\n";
    datei << "  <script type=\"module\" src=\"/src/index.jsx\"></script>\n";
    datei << "</html>\n";

    datei.close();
    return 0;
}

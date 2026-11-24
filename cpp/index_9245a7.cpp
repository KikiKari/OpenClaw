// abstraction-provenance: {"artifact_sha256": "80369b4df8df893206e5f5afdce722d2fb4b95e580caa5d8b89af2356b6c142f", "source_sha256": "9245a78489adb3949ae2a56f5e0987a465142b9a8ee97bddaca453f5011daef8", "target_language": "cpp"}
// index.html — portiert nach cpp
// Quelle: html, Projects@Program-Derivation:public/index.html
// auch in: Projects@Vision-Check:public/index.html
// auch in: Projects@Weather-Check:public/index.html
// auch in: Projects@abstractions:public/index.html
// auch in: 5 weiteren Fundstellen
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <fstream>
#include <string>

void writeHTMLDocument(const std::string& filename) {
    std::ofstream file(filename);
    if (!file.is_open()) {
        std::cerr << "Fehler beim Öffnen der Datei: " << filename << std::endl;
        return;
    }

    file << "<!DOCTYPE html>\n";
    file << "<html lang=\"de\">\n";
    file << "<head>\n";
    file << "<meta charset=\"utf-8\">\n";
    file << "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n";
    file << "<meta http-equiv=\"refresh\" content=\"0; url=3d.html\">\n";
    file << "<title>Weiterleitung zur 3D-Ansicht</title>\n";
    file << "<link rel=\"canonical\" href=\"3d.html\">\n";
    file << "<script>location.replace('3d.html');</script>\n";
    file << "</head>\n";
    file << "<body>\n";
    file << "<p><a href=\"3d.html\">3D-Ansicht öffnen</a></p>\n";
    file << "</body>\n";
    file << "</html>\n";

    file.close();
}

int main(int argc, char* argv[]) {
    if (argc != 2) {
        std::cerr << "Verwendung: " << argv[0] << " <dateiname>\n";
        return 1;
    }

    writeHTMLDocument(argv[1]);
    return 0;
}

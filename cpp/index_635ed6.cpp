// abstraction-provenance: {"artifact_sha256": "40528cf56dc4cf26bbab714f9923c0b2a375d53076cf33568d5eb20049cc498d", "source_sha256": "635ed6e934aa27ffc7ad156af00126e0797ae1d1c065daddb996e2bddc8cbeb3", "target_language": "cpp"}
// index.html — portiert nach cpp
// Quelle: html, workspace@local:skills/github-clones/openclaw/extensions/qa-lab/web/index.html
// auch in: openclaw-css@local:workspace/skills/github-clones/openclaw/extensions/qa-lab/web/index.html
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <fstream>
#include <string>

void generateHTML(const std::string& filename) {
    std::ofstream file(filename);
    
    if (!file.is_open()) {
        std::cerr << "Error: Could not open file " << filename << std::endl;
        return;
    }
    
    file << "<!doctype html>\n";
    file << "<html lang=\"en\">\n";
    file << "  <head>\n";
    file << "    <meta charset=\"utf-8\" />\n";
    file << "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />\n";
    file << "    <meta name=\"color-scheme\" content=\"light dark\" />\n";
    file << "    <title>QA Lab</title>\n";
    file << "  </head>\n";
    file << "  <body>\n";
    file << "    <div id=\"app\"></div>\n";
    file << "    <script type=\"module\" src=\"/src/main.ts\"></script>\n";
    file << "  </body>\n";
    file << "</html>\n";
    
    file.close();
}

int main(int argc, char* argv[]) {
    if (argc != 2) {
        std::cerr << "Usage: " << argv[0] << " <output_filename>" << std::endl;
        return 1;
    }
    
    generateHTML(argv[1]);
    return 0;
}

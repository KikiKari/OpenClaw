// abstraction-provenance: {"artifact_sha256": "fd7e671067364c0dd3636badd9dc04a4f02930eab5b07597292a89afbbd2a538", "source_sha256": "daf22c296c801d3d533083361cc59fbdc22e5bfe528aa4bad1973b54cc5448a4", "target_language": "cpp"}
// index.css — portiert nach cpp
// Quelle: css, OpenClaw@main:src/index.css
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <fstream>
#include <string>

void writeCSS(const std::string& filename) {
    std::ofstream file(filename);
    
    if (!file.is_open()) {
        std::cerr << "Error: Could not open file " << filename << std::endl;
        return;
    }
    
    // Write body styles
    file << "body {\n";
    file << "  margin: 0;\n";
    file << "  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',\n";
    file << "    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',\n";
    file << "    sans-serif;\n";
    file << "  -webkit-font-smoothing: antialiased;\n";
    file << "  -moz-osx-font-smoothing: grayscale;\n";
    file << "}\n\n";
    
    // Write code styles
    file << "code {\n";
    file << "  font-family: source-code-pro, Menlo, Monaco, Consolas, 'Courier New',\n";
    file << "    monospace;\n";
    file << "}\n";
    
    file.close();
}

int main(int argc, char* argv[]) {
    if (argc != 2) {
        std::cerr << "Usage: " << argv[0] << " <output_filename>" << std::endl;
        return 1;
    }
    
    std::string filename = argv[1];
    writeCSS(filename);
    
    return 0;
}

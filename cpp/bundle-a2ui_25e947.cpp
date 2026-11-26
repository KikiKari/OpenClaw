// abstraction-provenance: {"artifact_sha256": "a13b520937484a0698b97c36883d7197d8fce14a602ee4cdf65c905eb43fecd2", "source_sha256": "25e94789e3af346018b091c7c4d6d65632394c19fcf9eaaeac876efbe534149a", "target_language": "cpp"}
// bundle-a2ui.sh — portiert nach cpp
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/bundle-a2ui.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <cstdlib>
#include <iostream>
#include <filesystem>
#include <unistd.h>

namespace fs = std::filesystem;

int main(int argc, char* argv[]) {
    // Bestimme das Verzeichnis des Skripts
    fs::path script_path = fs::canonical(fs::path(argv[0]));
    fs::path root_dir = script_path.parent_path().parent_path();
    
    // Konstruiere den Pfad zum Node.js-Skript
    fs::path node_script = root_dir / "scripts" / "bundle-a2ui.mjs";
    
    // Baue den Befehl für den Aufruf von node
    std::string command = "node \"" + node_script.string() + "\"";
    
    // Füge alle Argumente hinzu
    for (int i = 1; i < argc; ++i) {
        command += " \"";
        command += argv[i];
        command += "\"";
    }
    
    // Führe den Befehl aus
    int result = std::system(command.c_str());
    
    // Gib den Exit-Code des aufgerufenen Programms zurück
    if (WIFEXITED(result)) {
        return WEXITSTATUS(result);
    } else {
        return 1;
    }
}

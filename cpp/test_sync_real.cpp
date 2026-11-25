// abstraction-provenance: {"artifact_sha256": "5715b554c1887621089f65a3b36ad96097e71ccc1801e4ebc9648afd04c67562", "source_sha256": "f8c56b5aecfa8cd091cc5fe50697c5613148d19f0d4e0eb311bf6d129c600018", "target_language": "cpp"}
// test_sync_real.py — portiert nach cpp
// Quelle: python, OpenClaw@gateway1:scripts/test_sync_real.py
// auch in: OpenClaw@gateway2:scripts/test_sync_real.py
// auch in: workspace@local:scripts/test_sync_real.py
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <string>
#include <filesystem>
#include <cstdlib>

// Funktion zum Aufrufen des Python-Skripts (da die eigentliche Logik in Python implementiert ist)
bool sync_to_git(const std::string& skill, bool dry_run = false) {
    std::string command = "/home/openclaw/.openclaw/workspace/scripts/sync_clawhub_git.py " + skill;
    if (dry_run) {
        command += " --dry-run";
    }
    
    int result = std::system(command.c_str());
    return result == 0;
}

void log(const std::string& message) {
    std::cout << message << std::endl;
}

int main() {
    // Test: db-maintainer ClawHub → Git (ECHT)
    std::cout << "=== TEST: db-maintainer sync (REAL) ===" << std::endl;
    std::string skill = "db-maintainer";
    bool result = sync_to_git(skill, false);
    std::cout << "Result: " << (result ? "SUCCESS" : "FAILED") << std::endl;

    // Prüfe Ergebnis
    std::string target = "/home/openclaw/.openclaw/workspace/git/skills/db-maintainer";
    if (std::filesystem::exists(target)) {
        std::cout << "\n✅ Git-Repo erstellt: " << target << std::endl;
        
        for (const auto& entry : std::filesystem::recursive_directory_iterator(target)) {
            std::string path = entry.path();
            size_t level = std::count(path.begin() + target.length(), path.end(), '/');
            std::string indent(level * 2, ' ');
            
            if (entry.is_directory()) {
                std::cout << indent << entry.path().filename().string() << "/" << std::endl;
            } else {
                std::cout << indent << entry.path().filename().string() << std::endl;
            }
        }
    }
    
    return 0;
}

// abstraction-provenance: {"artifact_sha256": "d18ef475633e0af3469b7463441895c1e9ed1a9cfac77dc272c308b8553ff141", "source_sha256": "e86a7b42e9bd3c3d2f9321883c9d29b0e6b2774e4eb99056dd5093ca64b5b5c8", "target_language": "cpp"}
// sync_bulk.py — portiert nach cpp
// Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/sync_bulk.py
// auch in: OpenClaw@gateway2:skills/sync-utils/scripts/sync_bulk.py
// auch in: workspace@local:git/skills/sync-utils/scripts/sync_bulk.py
// auch in: workspace@local:skills/sync-utils/scripts/sync_bulk.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <filesystem>
#include <set>
#include <string>
#include <algorithm>
#include <exception>
#include <chrono>
#include <iomanip>
#include <sstream>
#include <map>
#include <vector>
#include <cstdlib>

// Forward declarations for imported functions
bool sync_to_git(const std::string& skill, bool dry_run);
bool sync_to_clawhub(const std::string& skill, bool dry_run);
void log(const std::string& message, const std::string& level = "INFO");
bool validate_skill(const std::filesystem::path& path);

namespace fs = std::filesystem;

const fs::path CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills";
const fs::path GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills";

std::string get_current_time() {
    auto now = std::chrono::system_clock::now();
    auto time_t = std::chrono::system_clock::to_time_t(now);
    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()) % 1000;
    
    std::stringstream ss;
    ss << std::put_time(std::localtime(&time_t), "%Y-%m-%d %H:%M:%S");
    ss << '.' << std::setfill('0') << std::setw(3) << ms.count();
    return ss.str();
}

void log(const std::string& message, const std::string& level) {
    std::cout << "[" << get_current_time() << "] [" << level << "] " << message << std::endl;
}

bool validate_skill(const fs::path& path) {
    // Placeholder implementation - replace with actual validation logic
    return fs::exists(path) && fs::is_directory(path);
}

bool sync_to_git(const std::string& skill, bool dry_run) {
    // Placeholder implementation - replace with actual sync logic
    if (!dry_run) {
        log("Actually syncing " + skill + " to Git");
    }
    return true;
}

bool sync_to_clawhub(const std::string& skill, bool dry_run) {
    // Placeholder implementation - replace with actual sync logic
    if (!dry_run) {
        log("Actually syncing " + skill + " to ClawHub");
    }
    return true;
}

double get_latest_mtime(const fs::path& dir) {
    double latest = 0;
    for (const auto& entry : fs::recursive_directory_iterator(dir)) {
        if (entry.is_regular_file()) {
            // Skip .git directories
            std::string path_str = entry.path().string();
            if (path_str.find("/.git/") != std::string::npos || 
                path_str.substr(path_str.length() - 5) == "/.git") {
                continue;
            }
            
            auto ftime = fs::last_write_time(entry.path());
            auto sctp = std::chrono::time_point_cast<std::chrono::system_clock::duration>(
                ftime - fs::file_time_type::clock::now() + std::chrono::system_clock::now());
            auto timestamp = std::chrono::duration<double>(sctp.time_since_epoch()).count();
            
            if (timestamp > latest) {
                latest = timestamp;
            }
        }
    }
    return latest;
}

struct SyncResults {
    std::vector<std::string> synced;
    std::vector<std::string> skipped;
    std::vector<std::string> failed;
};

void sync_all_skills(bool dry_run = true) {
    // Alle Skills finden
    std::set<std::string> all_skills;
    
    if (fs::exists(CLAWHUB_DIR)) {
        for (const auto& entry : fs::directory_iterator(CLAWHUB_DIR)) {
            if (entry.is_directory() && !entry.path().filename().string().starts_with(".")) {
                all_skills.insert(entry.path().filename().string());
            }
        }
    }
    
    if (fs::exists(GIT_DIR)) {
        for (const auto& entry : fs::directory_iterator(GIT_DIR)) {
            if (entry.is_directory() && !entry.path().filename().string().starts_with(".")) {
                all_skills.insert(entry.path().filename().string());
            }
        }
    }
    
    log("Bulk Sync: " + std::to_string(all_skills.size()) + " Skills gefunden");
    
    SyncResults results;
    
    for (const auto& skill : all_skills) {
        fs::path clawhub_path = CLAWHUB_DIR / skill;
        fs::path git_path = GIT_DIR / skill;
        
        try {
            // Nur in ClawHub → zu Git
            if (fs::exists(clawhub_path) && !fs::exists(git_path)) {
                if (validate_skill(clawhub_path)) {
                    log("Syncing " + skill + " to Git...");
                    if (sync_to_git(skill, dry_run)) {
                        results.synced.push_back(skill + " → Git");
                    } else {
                        results.failed.push_back(skill);
                    }
                } else {
                    results.skipped.push_back(skill + " (validation failed)");
                }
            }
            // Nur in Git → zu ClawHub
            else if (fs::exists(git_path) && !fs::exists(clawhub_path)) {
                if (validate_skill(git_path)) {
                    log("Syncing " + skill + " to ClawHub...");
                    if (sync_to_clawhub(skill, dry_run)) {
                        results.synced.push_back(skill + " → ClawHub");
                    } else {
                        results.failed.push_back(skill);
                    }
                } else {
                    results.skipped.push_back(skill + " (validation failed)");
                }
            }
            // In beiden - prüfe ob Update nötig
            else if (fs::exists(clawhub_path) && fs::exists(git_path)) {
                // Vereinfachte Prüfung
                double clawhub_mtime = get_latest_mtime(clawhub_path);
                double git_mtime = get_latest_mtime(git_path);
                
                if (std::abs(clawhub_mtime - git_mtime) > 60) {
                    if (clawhub_mtime > git_mtime) {
                        log("Updating " + skill + " in Git...");
                        if (sync_to_git(skill, dry_run)) {
                            results.synced.push_back(skill + " → Git (update)");
                        } else {
                            results.failed.push_back(skill);
                        }
                    } else {
                        log("Updating " + skill + " in ClawHub...");
                        if (sync_to_clawhub(skill, dry_run)) {
                            results.synced.push_back(skill + " → ClawHub (update)");
                        } else {
                            results.failed.push_back(skill);
                        }
                    }
                } else {
                    results.skipped.push_back(skill + " (already synced)");
                }
            }
        } catch (const std::exception& e) {
            log("Error processing " + skill + ": " + e.what(), "ERROR");
            results.failed.push_back(skill);
        }
    }
    
    // Zusammenfassung
    std::cout << "\n" << std::string(60, '=') << std::endl;
    std::cout << "Bulk Sync " << (dry_run ? "DRY-RUN" : "EXECUTED") << " - Zusammenfassung" << std::endl;
    std::cout << std::string(60, '=') << std::endl;
    std::cout << "✅ Synchronisiert: " << results.synced.size() << std::endl;
    for (const auto& item : results.synced) {
        std::cout << "   - " << item << std::endl;
    }
    std::cout << "\n⏭️  Übersprungen: " << results.skipped.size() << std::endl;
    if (results.skipped.size() <= 10) {
        for (const auto& item : results.skipped) {
            std::cout << "   - " << item << std::endl;
        }
    } else {
        std::cout << "   - " << results.skipped.size() << " Skills (bereits synchron oder Validierung fehlgeschlagen)" << std::endl;
    }
    std::cout << "\n❌ Fehlgeschlagen: " << results.failed.size() << std::endl;
    for (const auto& item : results.failed) {
        std::cout << "   - " << item << std::endl;
    }
    std::cout << std::string(60, '=') << std::endl;
}

int main(int argc, char* argv[]) {
    bool dry_run = false;
    bool execute = false;
    
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--dry-run") {
            dry_run = true;
        } else if (arg == "--execute") {
            execute = true;
        } else if (arg == "-h" || arg == "--help") {
            std::cout << "Bulk Sync für alle Skills\n"
                      << "Usage: " << argv[0] << " [--dry-run] [--execute]\n"
                      << "  --dry-run   Nur Änderungen anzeigen\n"
                      << "  --execute   Sync ausführen\n"
                      << "  -h, --help  Diese Hilfe anzeigen\n";
            return 0;
        }
    }
    
    if (!dry_run && !execute) {
        std::cerr << "Bitte --dry-run oder --execute angeben" << std::endl;
        return 1;
    }
    
    sync_all_skills(dry_run);
    return 0;
}

// abstraction-provenance: {"artifact_sha256": "7264a0a0512e1d24d4f13ddaf1f4874d54f234641d3e3124b63f475ed2e0ebbe", "source_sha256": "6dcc2c07911eedad64d93e999a1605091bebc0ed6eadad479df838626620545d", "target_language": "cpp"}
// sync_agent_cron.py — portiert nach cpp
// Quelle: python, OpenClaw@gateway1:scripts/sync_agent_cron.py
// auch in: OpenClaw@gateway2:scripts/sync_agent_cron.py
// auch in: workspace@local:scripts/sync_agent_cron.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <filesystem>
#include <string>
#include <vector>
#include <set>
#include <map>
#include <fstream>
#include <sstream>
#include <chrono>
#include <iomanip>
#include <algorithm>
#include <exception>
#include <cstdlib>
#include <cstdio>
#include <cmath>

namespace fs = std::filesystem;

const fs::path CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills";
const fs::path GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills";
const fs::path LOG_FILE = "/home/openclaw/.openclaw/workspace/logs/sync-agent.log";

std::string current_time_string() {
    auto now = std::chrono::system_clock::now();
    auto time_t = std::chrono::system_clock::to_time_t(now);
    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()) % 1000;
    
    std::stringstream ss;
    ss << std::put_time(std::localtime(&time_t), "%Y-%m-%d %H:%M:%S");
    ss << '.' << std::setfill('0') << std::setw(3) << ms.count();
    return ss.str();
}

double file_mtime(const fs::path& path) {
    try {
        double max_time = 0;
        bool found = false;
        
        if (fs::exists(path)) {
            for (const auto& entry : fs::recursive_directory_iterator(path)) {
                if (entry.is_regular_file()) {
                    std::string path_str = entry.path().string();
                    if (path_str.find("/.git/") == std::string::npos && 
                        path_str.substr(path_str.length() - 4) != "/.git") {
                        auto ftime = fs::last_write_time(entry);
                        auto sctp = std::chrono::time_point_cast<std::chrono::system_clock::duration>(
                            ftime - std::filesystem::file_time_type::clock::now() + std::chrono::system_clock::now()
                        );
                        auto time = std::chrono::system_clock::to_time_t(sctp);
                        double current_time = static_cast<double>(time);
                        if (!found || current_time > max_time) {
                            max_time = current_time;
                            found = true;
                        }
                    }
                }
            }
        }
        return found ? max_time : 0;
    } catch (...) {
        return 0;
    }
}

void write_to_log(const std::string& message, const std::string& level = "INFO") {
    std::string timestamp = current_time_string().substr(0, 19); // Entferne Millisekunden für das Log
    std::string entry = "[" + timestamp + "] [" + level + "] " + message;
    std::cout << entry << std::endl;
    
    std::ofstream log_file(LOG_FILE, std::ios::app);
    if (log_file.is_open()) {
        log_file << entry << std::endl;
        log_file.close();
    }
}

// Dummy Funktionen für sync_to_git, sync_to_clawhub und validate_skill
// In einer echten Implementierung würden diese Funktionen aus einer externen Bibliothek kommen
bool sync_to_git(const std::string& skill, bool dry_run = false) {
    // Dummy implementation
    return true;
}

bool sync_to_clawhub(const std::string& skill, bool dry_run = false) {
    // Dummy implementation
    return true;
}

bool validate_skill(const fs::path& skill_path) {
    // Dummy implementation
    return true;
}

void execute_command(const std::string& command) {
    int result = std::system(command.c_str());
    if (result != 0) {
        write_to_log("Command failed: " + command, "ERROR");
    }
}

int main() {
    write_to_log("======================================================================");
    write_to_log("CLAWHUB ↔ GIT SYNC AGENT - CRON LAUF");
    write_to_log("Zeitstempel: " + current_time_string());
    write_to_log("======================================================================");

    // Sammle Skill-Verzeichnisse
    std::set<std::string> clawhub_skills;
    std::set<std::string> git_skills;
    
    if (fs::exists(CLAWHUB_DIR)) {
        for (const auto& entry : fs::directory_iterator(CLAWHUB_DIR)) {
            if (entry.is_directory() && !entry.path().filename().string().starts_with(".")) {
                clawhub_skills.insert(entry.path().filename().string());
            }
        }
    }
    
    if (fs::exists(GIT_DIR)) {
        for (const auto& entry : fs::directory_iterator(GIT_DIR)) {
            if (entry.is_directory() && !entry.path().filename().string().starts_with(".")) {
                git_skills.insert(entry.path().filename().string());
            }
        }
    }

    // DRY-RUN: Erkenne Änderungen
    write_to_log("\n[DRY-RUN] Analysiere Änderungen...");

    std::map<std::string, std::vector<std::string>> changes_detected_simple;
    std::map<std::string, std::vector<std::pair<std::string, double>>> changes_detected_complex;
    
    changes_detected_simple["new_in_clawhub"];
    changes_detected_simple["new_in_git"];
    changes_detected_complex["clawhub_newer"];
    changes_detected_complex["git_newer"];
    changes_detected_simple["synced"];

    // 1. Neue Skills
    std::set_difference(
        clawhub_skills.begin(), clawhub_skills.end(),
        git_skills.begin(), git_skills.end(),
        std::back_inserter(changes_detected_simple["new_in_clawhub"])
    );
    
    std::set_difference(
        git_skills.begin(), git_skills.end(),
        clawhub_skills.begin(), clawhub_skills.end(),
        std::back_inserter(changes_detected_simple["new_in_git"])
    );

    // 2. Existierende prüfen
    std::set<std::string> in_both;
    std::set_intersection(
        clawhub_skills.begin(), clawhub_skills.end(),
        git_skills.begin(), git_skills.end(),
        std::inserter(in_both, in_both.begin())
    );

    for (const auto& skill : in_both) {
        double c_mtime = file_mtime(CLAWHUB_DIR / skill);
        double g_mtime = file_mtime(GIT_DIR / skill);
        double diff = c_mtime - g_mtime;

        if (std::abs(diff) > 60) {
            if (diff > 0) {
                changes_detected_complex["clawhub_newer"].push_back({skill, diff});
            } else {
                changes_detected_complex["git_newer"].push_back({skill, std::abs(diff)});
            }
        } else {
            changes_detected_simple["synced"].push_back(skill);
        }
    }

    // Sortieren
    std::sort(changes_detected_simple["new_in_clawhub"].begin(), changes_detected_simple["new_in_clawhub"].end());
    std::sort(changes_detected_simple["new_in_git"].begin(), changes_detected_simple["new_in_git"].end());

    // Report
    size_t total_changes = changes_detected_simple["new_in_clawhub"].size() +
                           changes_detected_simple["new_in_git"].size() +
                           changes_detected_complex["clawhub_newer"].size() +
                           changes_detected_complex["git_newer"].size();
                           
    write_to_log("Neu in ClawHub: " + std::to_string(changes_detected_simple["new_in_clawhub"].size()));
    write_to_log("Neu in Git: " + std::to_string(changes_detected_simple["new_in_git"].size()));
    write_to_log("ClawHub neuer: " + std::to_string(changes_detected_complex["clawhub_newer"].size()));
    write_to_log("Git neuer: " + std::to_string(changes_detected_complex["git_newer"].size()));
    write_to_log("Synchron: " + std::to_string(changes_detected_simple["synced"].size()));

    if (total_changes == 0) {
        write_to_log("\n✅ Keine Änderungen erkannt. Sync nicht nötig.");
        write_to_log("======================================================================");
        return 0;
    }

    write_to_log("\n🔄 " + std::to_string(total_changes) + " Änderungen erkannt - starte Synchronisation...");

    // ECHTE SYNCHRONISATION
    std::map<std::string, std::vector<std::string>> results;
    results["synced_to_git"];
    results["synced_to_clawhub"];
    results["up_to_date"];
    results["errors"];

    // 1. NEU in ClawHub → zu Git
    for (const auto& skill : changes_detected_simple["new_in_clawhub"]) {
        try {
            if (validate_skill(CLAWHUB_DIR / skill)) {
                write_to_log("→ Synchronisiere " + skill + " zu Git...");
                if (sync_to_git(skill, false)) {
                    fs::path git_path = GIT_DIR / skill;
                    fs::current_path(git_path);
                    execute_command("git init -q 2>/dev/null");
                    execute_command("git add . -f 2>/dev/null");
                    
                    auto now = std::chrono::system_clock::now();
                    auto time_t = std::chrono::system_clock::to_time_t(now);
                    std::stringstream ss;
                    ss << std::put_time(std::localtime(&time_t), "%Y-%m-%d %H:%M");
                    std::string dt = ss.str();
                    
                    execute_command("git commit -m \"Initial: " + skill + "\" -q 2>/dev/null");
                    results["synced_to_git"].push_back(skill);
                    write_to_log("  ✓ " + skill + " synchronisiert");
                }
            } else {
                results["errors"].push_back(skill + " (invalid)");
            }
        } catch (const std::exception& e) {
            write_to_log("  ✗ ERROR: " + skill + " - " + e.what(), "ERROR");
            results["errors"].push_back(skill);
        }
    }

    // 2. NEU in Git → zu ClawHub
    for (const auto& skill : changes_detected_simple["new_in_git"]) {
        try {
            if (validate_skill(GIT_DIR / skill)) {
                write_to_log("→ Synchronisiere " + skill + " zu ClawHub...");
                if (sync_to_clawhub(skill, false)) {
                    results["synced_to_clawhub"].push_back(skill);
                    write_to_log("  ✓ " + skill + " synchronisiert");
                }
            } else {
                results["errors"].push_back(skill + " (invalid)");
            }
        } catch (const std::exception& e) {
            write_to_log("  ✗ ERROR: " + skill + " - " + e.what(), "ERROR");
            results["errors"].push_back(skill);
        }
    }

    // 3. Updates
    for (const auto& pair : changes_detected_complex["clawhub_newer"]) {
        const std::string& skill = pair.first;
        double diff = pair.second;
        
        try {
            write_to_log("→ Update " + skill + " (ClawHub +" + std::to_string(static_cast<int>(diff)) + "s neuer)...");
            if (sync_to_git(skill, false)) {
                fs::path git_path = GIT_DIR / skill;
                fs::current_path(git_path);
                execute_command("git add . -f 2>/dev/null");
                
                auto now = std::chrono::system_clock::now();
                auto time_t = std::chrono::system_clock::to_time_t(now);
                std::stringstream ss;
                ss << std::put_time(std::localtime(&time_t), "%Y-%m-%d %H:%M");
                std::string dt = ss.str();
                
                execute_command("git commit -m \"Sync from ClawHub: " + dt + "\" -q 2>/dev/null");
                results["synced_to_git"].push_back(skill);
                write_to_log("  ✓ " + skill + " aktualisiert");
            }
        } catch (const std::exception& e) {
            write_to_log("  ✗ ERROR: " + skill + " - " + e.what(), "ERROR");
            results["errors"].push_back(skill);
        }
    }

    for (const auto& pair : changes_detected_complex["git_newer"]) {
        const std::string& skill = pair.first;
        double diff = pair.second;
        
        try {
            write_to_log("→ Update " + skill + " (Git +" + std::to_string(static_cast<int>(diff)) + "s neuer)...");
            if (sync_to_clawhub(skill, false)) {
                results["synced_to_clawhub"].push_back(skill);
                write_to_log("  ✓ " + skill + " aktualisiert");
            }
        } catch (const std::exception& e) {
            write_to_log("  ✗ ERROR: " + skill + " - " + e.what(), "ERROR");
            results["errors"].push_back(skill);
        }
    }

    results["up_to_date"] = changes_detected_simple["synced"];

    // ZUSAMMENFASSUNG
    write_to_log("\n======================================================================");
    write_to_log("SYNCHRONISATION ABGESCHLOSSEN");
    write_to_log("======================================================================");
    write_to_log("Zu Git synchronisiert:     " + std::to_string(results["synced_to_git"].size()));
    write_to_log("Zu ClawHub synchronisiert: " + std::to_string(results["synced_to_clawhub"].size()));
    write_to_log("Bereits aktuell:           " + std::to_string(results["up_to_date"].size()));
    write_to_log("Fehler:                    " + std::to_string(results["errors"].size()));
    
    if (!results["errors"].empty()) {
        std::string error_list;
        for (const auto& error : results["errors"]) {
            if (!error_list.empty()) error_list += ", ";
            error_list += error;
        }
        write_to_log("  Fehlerhafte: " + error_list);
    }
    write_to_log("======================================================================");

    // State speichern
    fs::path STATE_FILE = "/home/openclaw/.openclaw/workspace/db/sync_state.json";
    fs::create_directories(STATE_FILE.parent_path());

    std::ofstream state_file(STATE_FILE);
    if (state_file.is_open()) {
        state_file << "{\n";
        state_file << "  \"last_run\": \"" << current_time_string() << "\",\n";
        state_file << "  \"results\": {\n";
        state_file << "    \"synced_to_git\": [";
        for (size_t i = 0; i < results["synced_to_git"].size(); ++i) {
            if (i > 0) state_file << ",";
            state_file << "\"" << results["synced_to_git"][i] << "\"";
        }
        state_file << "],\n";
        state_file << "    \"synced_to_clawhub\": [";
        for (size_t i = 0; i < results["synced_to_clawhub"].size(); ++i) {
            if (i > 0) state_file << ",";
            state_file << "\"" << results["synced_to_clawhub"][i] << "\"";
        }
        state_file << "],\n";
        state_file << "    \"up_to_date\": [";
        for (size_t i = 0; i < results["up_to_date"].size(); ++i) {
            if (i > 0) state_file << ",";
            state_file << "\"" << results["up_to_date"][i] << "\"";
        }
        state_file << "],\n";
        state_file << "    \"errors\": [";
        for (size_t i = 0; i < results["errors"].size(); ++i) {
            if (i > 0) state_file << ",";
            state_file << "\"" << results["errors"][i] << "\"";
        }
        state_file << "]\n";
        state_file << "  },\n";
        state_file << "  \"changes_detected\": {\n";
        state_file << "    \"new_in_clawhub\": " << changes_detected_simple["new_in_clawhub"].size() << ",\n";
        state_file << "    \"new_in_git\": " << changes_detected_simple["new_in_git"].size() << ",\n";
        state_file << "    \"clawhub_newer\": " << changes_detected_complex["clawhub_newer"].size() << ",\n";
        state_file << "    \"git_newer\": " << changes_detected_complex["git_newer"].size() << ",\n";
        state_file << "    \"synced\": " << changes_detected_simple["synced"].size() << "\n";
        state_file << "  }\n";
        state_file << "}\n";
        state_file.close();
        write_to_log("State gespeichert: " + STATE_FILE.string());
    }

    return 0;
}

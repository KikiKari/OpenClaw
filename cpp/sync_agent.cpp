// abstraction-provenance: {"artifact_sha256": "e416357e14e51320ddf1f523a3af98d1ffb1a5c6a8b618bc409d61048dab5e02", "source_sha256": "b470dd345a01d0a6c2fec8e2dd8ccd0a3b59e67f44ce1aa0e6f4d9c34420b355", "target_language": "cpp"}
// sync_agent.py — portiert nach cpp
// Quelle: python, OpenClaw@gateway2:skills/clawhub-git-sync-agent/scripts/sync_agent.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <map>
#include <set>
#include <filesystem>
#include <sstream>
#include <algorithm>
#include <stdexcept>
#include <chrono>
#include <iomanip>
#include <cstdlib>
#include <memory>

// Include sync functions from external library (assuming they are available as C++ functions)
extern "C" {
    bool sync_to_git(const std::string& skill_name, bool dry_run);
    bool sync_to_clawhub(const std::string& skill_name, bool dry_run);
    void log_message(const std::string& message, const std::string& level = "INFO");
    bool validate_skill(const std::string& skill_path);
    std::string get_file_hash(const std::string& file_path);
    std::vector<std::pair<std::string, std::string>> iter_sync_files(const std::string& skill_dir);
    extern const std::set<std::string> RESERVED_SKILL_NAMES;
}

namespace fs = std::filesystem;

const fs::path CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills";
const fs::path GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills";
const fs::path STATE_FILE = "/home/openclaw/.openclaw/workspace/db/sync_state.json";

void log(const std::string& message, const std::string& level = "INFO") {
    log_message(message, level);
}

std::map<std::string, std::string> load_state() {
    std::map<std::string, std::string> state;
    if (fs::exists(STATE_FILE)) {
        std::ifstream file(STATE_FILE);
        if (file.is_open()) {
            std::string line;
            while (std::getline(file, line)) {
                // Simplified parsing - in real implementation would need proper JSON parsing
                size_t pos = line.find(": ");
                if (pos != std::string::npos) {
                    state[line.substr(0, pos)] = line.substr(pos + 2);
                }
            }
        }
    }
    return state;
}

void save_state(const std::map<std::string, std::string>& state) {
    // Ensure parent directory exists
    if (!fs::is_directory(STATE_FILE.parent_path())) {
        fs::create_directories(STATE_FILE.parent_path());
    }
    
    std::ofstream file(STATE_FILE);
    if (file.is_open()) {
        for (const auto& pair : state) {
            file << pair.first << ": " << pair.second << "\n";
        }
    }
}

std::set<std::string> get_all_skills() {
    std::set<std::string> skills;
    
    // Get ClawHub skills
    if (fs::exists(CLAWHUB_DIR)) {
        for (const auto& entry : fs::directory_iterator(CLAWHUB_DIR)) {
            if (entry.is_directory() && 
                !entry.path().filename().string().starts_with(".") &&
                RESERVED_SKILL_NAMES.find(entry.path().filename().string()) == RESERVED_SKILL_NAMES.end()) {
                
                fs::path skill_md = entry.path() / "SKILL.md";
                if (fs::exists(skill_md)) {
                    skills.insert(entry.path().filename().string());
                }
            }
        }
    }
    
    // Get Git skills
    if (fs::exists(GIT_DIR)) {
        for (const auto& entry : fs::directory_iterator(GIT_DIR)) {
            if (entry.is_directory() && 
                !entry.path().filename().string().starts_with(".") &&
                RESERVED_SKILL_NAMES.find(entry.path().filename().string()) == RESERVED_SKILL_NAMES.end()) {
                
                fs::path skill_md = entry.path() / "SKILL.md";
                if (fs::exists(skill_md)) {
                    skills.insert(entry.path().filename().string());
                }
            }
        }
    }
    
    return skills;
}

void init_git_repo(const fs::path& skill_path, const std::string& skill_name) {
    fs::path git_dir = skill_path / ".git";
    if (!fs::exists(git_dir)) {
        fs::current_path(skill_path);
        int result = system("git init > /dev/null 2>&1");
        result = system("git add . > /dev/null 2>&1");
        
        std::string commit_cmd = "git commit -m \"Initial commit: " + skill_name + " skill\" > /dev/null 2>&1";
        result = system(commit_cmd.c_str());
        
        log("Git initialized for " + skill_name);
    }
}

std::map<std::string, std::string> get_hashes(const fs::path& skill_dir) {
    std::map<std::string, std::string> hashes;
    auto files = iter_sync_files(skill_dir.string());
    
    for (const auto& file_pair : files) {
        hashes[file_pair.second] = get_file_hash(file_pair.first);
    }
    
    return hashes;
}

std::vector<std::string> preview_changes(const fs::path& source_dir, const fs::path& target_dir) {
    std::vector<std::string> changes;
    auto files = iter_sync_files(source_dir.string());
    
    for (const auto& file_pair : files) {
        fs::path src_file = file_pair.first;
        std::string rel_path = file_pair.second;
        fs::path tgt_file = target_dir / rel_path;
        
        if (!fs::exists(tgt_file)) {
            changes.push_back("ADD " + rel_path);
        } else {
            std::string src_hash = get_file_hash(src_file.string());
            std::string tgt_hash = get_file_hash(tgt_file.string());
            
            if (src_hash != tgt_hash) {
                changes.push_back("UPDATE " + rel_path);
            }
        }
    }
    
    return changes;
}

double newest_mtime(const fs::path& skill_dir) {
    double max_mtime = 0.0;
    auto files = iter_sync_files(skill_dir.string());
    
    for (const auto& file_pair : files) {
        std::error_code ec;
        auto mtime = fs::last_write_time(file_pair.first, ec);
        if (!ec) {
            auto duration = mtime.time_since_epoch();
            double seconds = std::chrono::duration<double>(duration).count();
            if (seconds > max_mtime) {
                max_mtime = seconds;
            }
        }
    }
    
    return max_mtime;
}

std::string sync_skill_bidirectional(const std::string& skill_name) {
    fs::path clawhub_path = CLAWHUB_DIR / skill_name;
    fs::path git_path = GIT_DIR / skill_name;
    
    // Case 1: Only in ClawHub → to Git
    if (fs::exists(clawhub_path) && !fs::exists(git_path)) {
        log("NEW in ClawHub: " + skill_name + " → syncing to Git");
        if (sync_to_git(skill_name, false)) {
            init_git_repo(git_path, skill_name);
            return "synced_to_git";
        }
    }
    // Case 2: Only in Git → to ClawHub
    else if (fs::exists(git_path) && !fs::exists(clawhub_path)) {
        log("NEW in Git: " + skill_name + " → syncing to ClawHub");
        if (sync_to_clawhub(skill_name, false)) {
            return "synced_to_clawhub";
        }
    }
    // Case 3: In both present
    else if (fs::exists(clawhub_path) && fs::exists(git_path)) {
        if (!validate_skill(clawhub_path.string())) {
            log("Validation failed for ClawHub skill: " + skill_name, "ERROR");
            return "error";
        }
        if (!validate_skill(git_path.string())) {
            log("Validation failed for Git skill: " + skill_name, "ERROR");
            return "error";
        }

        auto clawhub_changes = preview_changes(clawhub_path, git_path);
        auto git_changes = preview_changes(git_path, clawhub_path);

        if (clawhub_changes.empty() && git_changes.empty()) {
            log("Content is identical for: " + skill_name);
            return "no_change";
        }

        if (!clawhub_changes.empty() && git_changes.empty()) {
            log("Content difference detected for: " + skill_name);
            log("UPDATE: " + skill_name + " ClawHub content is newer or different → syncing to Git");
            if (sync_to_git(skill_name, false)) {
                fs::current_path(git_path);
                system("git add . > /dev/null 2>&1");
                
                auto now = std::chrono::system_clock::now();
                auto time_t = std::chrono::system_clock::to_time_t(now);
                std::stringstream ss;
                ss << std::put_time(std::localtime(&time_t), "%Y-%m-%d %H:%M");
                
                std::string commit_cmd = "git commit -m \"Sync from ClawHub content diff: " + ss.str() + "\" > /dev/null 2>&1";
                system(commit_cmd.c_str());
                return "updated_git";
            }
            log("Failed to sync " + skill_name + " to Git after content diff", "ERROR");
            return "error";
        }

        if (git_changes.empty() && !clawhub_changes.empty()) {
            log("Content difference detected for: " + skill_name);
            log("UPDATE: " + skill_name + " Git content is newer or different → syncing to ClawHub");
            if (sync_to_clawhub(skill_name, false)) {
                return "updated_clawhub";
            }
            log("Failed to sync " + skill_name + " to ClawHub after content diff", "ERROR");
            return "error";
        }

        log("Content difference detected for: " + skill_name);
        if (newest_mtime(clawhub_path) >= newest_mtime(git_path)) {
            log("UPDATE: " + skill_name + " ClawHub content is newer or different → syncing to Git");
            if (sync_to_git(skill_name, false)) {
                fs::current_path(git_path);
                system("git add . > /dev/null 2>&1");
                
                auto now = std::chrono::system_clock::now();
                auto time_t = std::chrono::system_clock::to_time_t(now);
                std::stringstream ss;
                ss << std::put_time(std::localtime(&time_t), "%Y-%m-%d %H:%M");
                
                std::string commit_cmd = "git commit -m \"Sync from ClawHub content diff: " + ss.str() + "\" > /dev/null 2>&1";
                system(commit_cmd.c_str());
                return "updated_git";
            }
        } else {
            log("UPDATE: " + skill_name + " Git content is newer or different → syncing to ClawHub");
            if (sync_to_clawhub(skill_name, false)) {
                return "updated_clawhub";
            }
        }

        log("Failed to resolve content diff for " + skill_name, "ERROR");
        return "error";
    }
    
    return "no_change";
}

int main() {
    log("=== ClawHub ↔ Git Sync Agent gestartet ===");
    
    // Load previous state
    auto state = load_state();
    auto all_skills = get_all_skills();
    log("Gefundene Skills: " + std::to_string(all_skills.size()));
    
    // Dry-Run Phase: only report changes, no actual modifications
    log("--- Dry-Run Phase Start ---");
    for (const auto& skill : all_skills) {
        // Perform dry-run sync in both directions to capture potential changes
        sync_to_git(skill, true);
        sync_to_clawhub(skill, true);
    }
    log("--- Dry-Run Phase End ---");
    
    std::map<std::string, std::vector<std::string>> results = {
        {"synced_to_git", {}},
        {"synced_to_clawhub", {}},
        {"updated_git", {}},
        {"updated_clawhub", {}},
        {"no_change", {}},
        {"errors", {}}
    };
    
    // Actual Sync Phase
    for (const auto& skill : all_skills) {
        try {
            std::string result = sync_skill_bidirectional(skill);
            results[result].push_back(skill);
        } catch (const std::exception& e) {
            log("ERROR syncing " + skill + ": " + e.what(), "ERROR");
            results["errors"].push_back(skill);
        }
    }
    
    // Zusammenfassung
    log("\n=== SYNC ZUSAMMENFASSUNG ===");
    log("Neu in Git: " + std::to_string(results["synced_to_git"].size()) + " - ");
    for (const auto& item : results["synced_to_git"]) log(item + " ");
    
    log("\nNeu in ClawHub: " + std::to_string(results["synced_to_clawhub"].size()) + " - ");
    for (const auto& item : results["synced_to_clawhub"]) log(item + " ");
    
    log("\nGit aktualisiert: " + std::to_string(results["updated_git"].size()) + " - ");
    for (const auto& item : results["updated_git"]) log(item + " ");
    
    log("\nClawHub aktualisiert: " + std::to_string(results["updated_clawhub"].size()) + " - ");
    for (const auto& item : results["updated_clawhub"]) log(item + " ");
    
    log("\nKeine Änderung: " + std::to_string(results["no_change"].size()));
    log("Fehler: " + std::to_string(results["errors"].size()) + " - ");
    for (const auto& item : results["errors"]) log(item + " ");
    
    // State speichern
    // In a real implementation, this would properly update the JSON structure
    save_state(state);
    
    log("=== Sync Agent beendet ===\n");
    
    return 0;
}

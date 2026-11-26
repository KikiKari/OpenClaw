// abstraction-provenance: {"artifact_sha256": "0a8a0a343a33dc3b4240cd3e5cba849045962de25aebbdb5174d6d687a71193a", "source_sha256": "5ea1a8c9a13631404f27bfdb1410099cd81f89038616abac4b49bd62666db56a", "target_language": "cpp"}
// secret-scan.mjs — portiert nach cpp
// Quelle: javascript, Onboarding@main:scripts/secret-scan.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <set>
#include <regex>
#include <filesystem>
#include <cstdlib>

namespace fs = std::filesystem;

const std::set<std::string> skipped = {
    "node_modules",
    ".next",
    ".git",
    ".pytest_cache",
    "__pycache__",
    "media-production/raw",
    "media-production/private"
};

const std::vector<std::regex> patterns = {
    std::regex(R"(sk-(?:proj|svcacct|ant|or-v1|admin)-[A-Za-z0-9_-]{20,})"),
    std::regex(R"((?:nvapi|lin_api|ntn|vcp)_[A-Za-z0-9_-]{20,})"),
    std::regex(R"(ELEVENLABS_API_KEY\s*=\s*["']?[A-Za-z0-9]{20,})"),
    std::regex(R"(WAVESPEED_API_KEY\s*=\s*["']?[A-Za-z0-9]{20,})")
};

std::vector<std::string> findings;

bool shouldSkip(const std::string& relativePath) {
    if (relativePath == ".env") return true;
    if (relativePath.substr(0, 5) == ".env." && relativePath != ".env.example") return true;
    
    for (const auto& skip : skipped) {
        if (relativePath == skip) return true;
        if (relativePath.substr(0, skip.length() + 1) == skip + "/") return true;
        
        size_t pos = relativePath.find("/" + skip + "/");
        if (pos != std::string::npos) return true;
        
        pos = relativePath.find("/" + skip);
        if (pos != std::string::npos && pos + skip.length() + 1 == relativePath.length()) return true;
    }
    
    return false;
}

void walk(const fs::path& dir, const std::string& relative = "") {
    try {
        for (const auto& entry : fs::directory_iterator(dir)) {
            std::string filename = entry.path().filename().string();
            std::string rel = relative.empty() ? filename : (relative + "/" + filename);
            
            if (shouldSkip(rel)) continue;
            
            if (fs::is_directory(entry.status())) {
                walk(entry.path(), rel);
            } else if (entry.file_size() < 2000000) {
                std::ifstream file(entry.path());
                if (file.is_open()) {
                    std::stringstream buffer;
                    buffer << file.rdbuf();
                    std::string content = buffer.str();
                    
                    for (const auto& pattern : patterns) {
                        if (std::regex_search(content, pattern)) {
                            findings.push_back(rel);
                            break;
                        }
                    }
                }
            }
        }
    } catch (...) {
        // Ignore errors during directory traversal
    }
}

int main() {
    fs::path root = fs::current_path().parent_path();
    walk(root);
    
    if (!findings.empty()) {
        std::set<std::string> uniqueFindings(findings.begin(), findings.end());
        std::cerr << "Secret-Scan fehlgeschlagen: ";
        bool first = true;
        for (const auto& finding : uniqueFindings) {
            if (!first) std::cerr << ", ";
            std::cerr << finding;
            first = false;
        }
        std::cerr << std::endl;
        return 1;
    }
    
    std::cout << "Secret-Scan bestanden." << std::endl;
    return 0;
}

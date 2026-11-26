// abstraction-provenance: {"artifact_sha256": "023344e2e95f174b8a4160f939e19e7fd1de281b2163bf46345d6feeb5c4a0fb", "source_sha256": "13f974bf78b140bc88bd9f3afe27c500660ef59498ed533c38c18bca0c6f6331", "target_language": "cpp"}
// changelog-to-html.sh — portiert nach cpp
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/changelog-to-html.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <regex>
#include <filesystem>
#include <cstdlib>

namespace fs = std::filesystem;

// Function to extract the section for a specific version from the changelog
std::string extract_version_section(const std::string& version, const std::string& file) {
    std::ifstream ifs(file);
    if (!ifs.is_open()) {
        std::cerr << "Error: Could not open file '" << file << "'" << std::endl;
        exit(1);
    }

    std::string line;
    bool found = false;
    std::ostringstream content;
    std::regex version_header("^##[[:space:]]+" + version + "([[:space:]].*|$)");

    while (std::getline(ifs, line)) {
        if (line.substr(0, 3) == "## ") {
            if (std::regex_match(line, version_header)) {
                found = true;
                continue;
            } else if (found) {
                break;
            }
        }
        if (found) {
            content << line << "\n";
        }
    }

    return content.str();
}

// Convert markdown-like syntax to HTML
std::string markdown_to_html(const std::string& text) {
    std::string result = text;

    // Headers
    result = std::regex_replace(result, std::regex("^##### (.*)$"), "<h5>$1</h5>");
    result = std::regex_replace(result, std::regex("^#### (.*)$"), "<h4>$1</h4>");
    result = std::regex_replace(result, std::regex("^### (.*)$"), "<h3>$1</h3>");
    result = std::regex_replace(result, std::regex("^## (.*)$"), "<h2>$1</h2>");

    // List items with bold text
    result = std::regex_replace(result, std::regex("^\\- \\*\\*([^*]*)\\*\\*(.*)$"), "<li><strong>$1</strong>$2</li>");

    // Regular list items
    result = std::regex_replace(result, std::regex("^\\- ([^*].*)$"), "<li>$1</li>");

    // Bold text
    result = std::regex_replace(result, std::regex("\\*\\*([^*]*)\\*\\*"), "<strong>$1</strong>");

    // Inline code
    result = std::regex_replace(result, std::regex("`([^`]*)`"), "<code>$1</code>");

    // Links
    result = std::regex_replace(result, std::regex("\\[([^\\]]*)\\]\\(([^\\)]*)\\)"), "<a href=\"$2\">$1</a>");

    return result;
}

int main(int argc, char* argv[]) {
    std::string VERSION;
    std::string CHANGELOG_FILE;

    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <version> [changelog_file]" << std::endl;
        return 1;
    }

    VERSION = argv[1];
    if (argc > 2) {
        CHANGELOG_FILE = argv[2];
    } else {
        fs::path script_dir = fs::canonical(fs::path(argv[0])).parent_path();
        std::vector<std::string> paths_to_try = {
            (script_dir / "../CHANGELOG.md").string(),
            "CHANGELOG.md",
            "../CHANGELOG.md"
        };

        for (const auto& path : paths_to_try) {
            if (fs::exists(path)) {
                CHANGELOG_FILE = path;
                break;
            }
        }

        if (CHANGELOG_FILE.empty()) {
            std::cerr << "Error: Could not find CHANGELOG.md" << std::endl;
            return 1;
        }
    }

    if (!fs::exists(CHANGELOG_FILE)) {
        std::cerr << "Error: Changelog file '" << CHANGELOG_FILE << "' not found" << std::endl;
        return 1;
    }

    std::string version_content = extract_version_section(VERSION, CHANGELOG_FILE);

    if (version_content.empty()) {
        std::cout << "<h2>OpenClaw " << VERSION << "</h2>" << std::endl;
        std::cout << "<p>Latest OpenClaw update.</p>" << std::endl;
        std::cout << "<p><a href=\"https://github.com/openclaw/openclaw/blob/main/CHANGELOG.md\">View full changelog</a></p>" << std::endl;
        return 0;
    }

    std::cout << "<h2>OpenClaw " << VERSION << "</h2>" << std::endl;

    std::istringstream iss(version_content);
    std::string line;
    bool in_list = false;

    while (std::getline(iss, line)) {
        if (line[0] == '-') {
            if (!in_list) {
                std::cout << "<ul>" << std::endl;
                in_list = true;
            }
            std::cout << markdown_to_html(line) << std::endl;
        } else {
            if (in_list) {
                std::cout << "</ul>" << std::endl;
                in_list = false;
            }
            if (!line.empty()) {
                std::cout << markdown_to_html(line) << std::endl;
            }
        }
    }

    if (in_list) {
        std::cout << "</ul>" << std::endl;
    }

    std::cout << "<p><a href=\"https://github.com/openclaw/openclaw/blob/main/CHANGELOG.md\">View full changelog</a></p>" << std::endl;

    return 0;
}

// abstraction-provenance: {"artifact_sha256": "a6842609b8d9aaa170ec7357a8cc17130b20d21bae54f5df9c4d594ed6af3c95", "source_sha256": "3e3cdceba2daa893e260551c8c5f09937f94be1153307185c7fc7c24c0896750", "target_language": "cpp"}
// quick_validate.py — portiert nach cpp
// Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/quick_validate.py
// auch in: OpenClaw@gateway2:skills/skill-creator/scripts/quick_validate.py
// auch in: workspace@local:git/skills/skill-creator/scripts/quick_validate.py
// auch in: workspace@local:skills/github-clones/openclaw/skills/skill-creator/scripts/quick_validate.py
// auch in: 1 weiteren Fundstellen
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <map>
#include <set>
#include <regex>
#include <filesystem>
#include <cstdlib>

namespace fs = std::filesystem;

const size_t MAX_SKILL_NAME_LENGTH = 64;

std::string read_file(const fs::path& path) {
    std::ifstream file(path);
    if (!file.is_open()) {
        throw std::runtime_error("Could not open file: " + path.string());
    }
    std::stringstream buffer;
    buffer << file.rdbuf();
    return buffer.str();
}

std::vector<std::string> split_lines(const std::string& text) {
    std::vector<std::string> lines;
    std::istringstream stream(text);
    std::string line;
    while (std::getline(stream, line)) {
        lines.push_back(line);
    }
    return lines;
}

std::string extract_frontmatter(const std::string& content) {
    auto lines = split_lines(content);
    if (lines.empty() || lines[0].find("---") == std::string::npos) {
        return "";
    }
    for (size_t i = 1; i < lines.size(); ++i) {
        if (lines[i].find("---") != std::string::npos) {
            std::string result;
            for (size_t j = 1; j < i; ++j) {
                result += lines[j] + "\n";
            }
            return result;
        }
    }
    return "";
}

std::map<std::string, std::string> parse_simple_frontmatter(const std::string& frontmatter_text) {
    std::map<std::string, std::string> parsed;
    std::istringstream stream(frontmatter_text);
    std::string line;
    std::string current_key;
    
    while (std::getline(stream, line)) {
        // Trim whitespace
        size_t start = line.find_first_not_of(" \t");
        if (start == std::string::npos) continue;
        size_t end = line.find_last_not_of(" \t");
        std::string trimmed = line.substr(start, end - start + 1);
        
        // Skip empty lines or comments
        if (trimmed.empty() || trimmed[0] == '#') continue;
        
        bool is_indented = (line[0] == ' ' || line[0] == '\t');
        if (is_indented) {
            if (current_key.empty()) {
                throw std::runtime_error("Invalid frontmatter format");
            }
            std::string& current_value = parsed[current_key];
            if (!current_value.empty()) {
                current_value += "\n";
            }
            current_value += trimmed;
            continue;
        }
        
        size_t colon_pos = trimmed.find(':');
        if (colon_pos == std::string::npos) {
            throw std::runtime_error("Invalid frontmatter format");
        }
        
        std::string key = trimmed.substr(0, colon_pos);
        // Trim key
        start = key.find_first_not_of(" \t");
        if (start != std::string::npos) {
            end = key.find_last_not_of(" \t");
            key = key.substr(start, end - start + 1);
        } else {
            key.clear();
        }
        
        if (key.empty()) {
            throw std::runtime_error("Invalid frontmatter format");
        }
        
        std::string value = trimmed.substr(colon_pos + 1);
        // Trim value
        start = value.find_first_not_of(" \t");
        if (start != std::string::npos) {
            end = value.find_last_not_of(" \t");
            value = value.substr(start, end - start + 1);
        } else {
            value.clear();
        }
        
        // Remove quotes if present
        if ((value.length() >= 2) && 
            ((value[0] == '"' && value[value.length()-1] == '"') ||
             (value[0] == '\'' && value[value.length()-1] == '\''))) {
            value = value.substr(1, value.length() - 2);
        }
        
        parsed[key] = value;
        current_key = key;
    }
    
    return parsed;
}

std::pair<bool, std::string> validate_skill(const fs::path& skill_path) {
    fs::path skill_md = skill_path / "SKILL.md";
    if (!fs::exists(skill_md)) {
        return {false, "SKILL.md not found"};
    }
    
    std::string content;
    try {
        content = read_file(skill_md);
    } catch (const std::exception& e) {
        return {false, "Could not read SKILL.md: " + std::string(e.what())};
    }
    
    std::string frontmatter_text = extract_frontmatter(content);
    if (frontmatter_text.empty()) {
        return {false, "Invalid frontmatter format"};
    }
    
    std::map<std::string, std::string> frontmatter;
    try {
        frontmatter = parse_simple_frontmatter(frontmatter_text);
    } catch (const std::exception& e) {
        return {false, "Invalid YAML in frontmatter: " + std::string(e.what())};
    }
    
    std::set<std::string> allowed_properties = {"name", "description", "license", "allowed-tools", "metadata"};
    
    std::set<std::string> unexpected_keys;
    for (const auto& pair : frontmatter) {
        if (allowed_properties.find(pair.first) == allowed_properties.end()) {
            unexpected_keys.insert(pair.first);
        }
    }
    
    if (!unexpected_keys.empty()) {
        std::string allowed_str, unexpected_str;
        for (const auto& prop : allowed_properties) {
            if (!allowed_str.empty()) allowed_str += ", ";
            allowed_str += prop;
        }
        for (const auto& key : unexpected_keys) {
            if (!unexpected_str.empty()) unexpected_str += ", ";
            unexpected_str += key;
        }
        return {false, "Unexpected key(s) in SKILL.md frontmatter: " + unexpected_str + ". Allowed properties are: " + allowed_str};
    }
    
    if (frontmatter.find("name") == frontmatter.end()) {
        return {false, "Missing 'name' in frontmatter"};
    }
    if (frontmatter.find("description") == frontmatter.end()) {
        return {false, "Missing 'description' in frontmatter"};
    }
    
    std::string name = frontmatter.at("name");
    // Trim name
    size_t start = name.find_first_not_of(" \t");
    if (start != std::string::npos) {
        size_t end = name.find_last_not_of(" \t");
        name = name.substr(start, end - start + 1);
    } else {
        name.clear();
    }
    
    if (!name.empty()) {
        std::regex name_regex("^[a-z0-9-]+$");
        if (!std::regex_match(name, name_regex)) {
            return {false, "Name '" + name + "' should be hyphen-case (lowercase letters, digits, and hyphens only)"};
        }
        if (name.front() == '-' || name.back() == '-' || name.find("--") != std::string::npos) {
            return {false, "Name '" + name + "' cannot start/end with hyphen or contain consecutive hyphens"};
        }
        if (name.length() > MAX_SKILL_NAME_LENGTH) {
            return {false, "Name is too long (" + std::to_string(name.length()) + " characters). Maximum is " + std::to_string(MAX_SKILL_NAME_LENGTH) + " characters."};
        }
    }
    
    std::string description = frontmatter.at("description");
    // Trim description
    start = description.find_first_not_of(" \t");
    if (start != std::string::npos) {
        size_t end = description.find_last_not_of(" \t");
        description = description.substr(start, end - start + 1);
    } else {
        description.clear();
    }
    
    if (!description.empty()) {
        if (description.find('<') != std::string::npos || description.find('>') != std::string::npos) {
            return {false, "Description cannot contain angle brackets (< or >)"};
        }
        if (description.length() > 1024) {
            return {false, "Description is too long (" + std::to_string(description.length()) + " characters). Maximum is 1024 characters."};
        }
    }
    
    return {true, "Skill is valid!"};
}

int main(int argc, char* argv[]) {
    if (argc != 2) {
        std::cout << "Usage: quick_validate <skill_directory>" << std::endl;
        return 1;
    }
    
    auto [valid, message] = validate_skill(argv[1]);
    std::cout << message << std::endl;
    return valid ? 0 : 1;
}

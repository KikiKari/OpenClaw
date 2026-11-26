// abstraction-provenance: {"artifact_sha256": "56228718c0b6a5564099f12952fdbbe04a8d2f45a6e2994f005046a8647651ca", "source_sha256": "646ce6bf1521c1200f2204aa19a05521f8f53d734ec8c000b61f4290f2a05074", "target_language": "cpp"}
// changelog.sh — portiert nach cpp
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/changelog.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <sstream>
#include <regex>
#include <set>
#include <algorithm>
#include <cstdlib>

class ChangelogProcessor {
private:
    std::string pr_number;
    std::string changelog_path = "CHANGELOG.md";

public:
    ChangelogProcessor(const std::string& pr) : pr_number(pr) {}

    void normalize_pr_changelog_entries() {
        if (!file_exists(changelog_path)) {
            return;
        }

        std::string content = read_file(changelog_path);
        std::vector<std::string> lines = split_string(content, '\n');
        
        std::regex pr_pattern("(?:\\(#" + pr_number + "\\)|openclaw#" + pr_number + ")", std::regex_constants::icase);
        
        move_entries_to_unreleased(lines, pr_pattern);
        
        std::string updated_content = join_strings(lines, "\n");
        if (updated_content != content) {
            write_file(changelog_path, updated_content);
        }
    }

private:
    bool file_exists(const std::string& path) {
        std::ifstream file(path);
        return file.good();
    }

    std::string read_file(const std::string& path) {
        std::ifstream file(path);
        std::stringstream buffer;
        buffer << file.rdbuf();
        return buffer.str();
    }

    void write_file(const std::string& path, const std::string& content) {
        std::ofstream file(path);
        file << content;
    }

    std::vector<std::string> split_string(const std::string& str, char delimiter) {
        std::vector<std::string> result;
        std::stringstream ss(str);
        std::string item;
        
        while (std::getline(ss, item, delimiter)) {
            result.push_back(item);
        }
        
        // Handle trailing newline
        if (!str.empty() && str.back() == delimiter) {
            result.push_back("");
        }
        
        return result;
    }

    std::string join_strings(const std::vector<std::string>& vec, const std::string& delimiter) {
        std::string result;
        for (size_t i = 0; i < vec.size(); ++i) {
            result += vec[i];
            if (i < vec.size() - 1) {
                result += delimiter;
            }
        }
        return result;
    }

    int find_active_section_index(const std::vector<std::string>& arr) {
        for (size_t i = 0; i < arr.size(); ++i) {
            if (trim(arr[i]) == "## Unreleased") {
                return static_cast<int>(i);
            }
        }
        return -1;
    }

    int find_section_end(const std::vector<std::string>& arr, int start) {
        std::regex pattern("^## ");
        for (size_t i = start + 1; i < arr.size(); ++i) {
            if (std::regex_search(arr[i], pattern)) {
                return static_cast<int>(i);
            }
        }
        return static_cast<int>(arr.size());
    }

    int ensure_active_section(std::vector<std::string>& arr) {
        int active_index = find_active_section_index(arr);
        if (active_index != -1) {
            return active_index;
        }

        std::regex pattern("^## ");
        int insert_at = -1;
        for (size_t i = 1; i < arr.size(); ++i) {
            if (std::regex_search(arr[i], pattern)) {
                insert_at = static_cast<int>(i);
                break;
            }
        }
        
        if (insert_at == -1) {
            insert_at = static_cast<int>(arr.size());
        }

        std::vector<std::string> block = {"## Unreleased", "", "### Changes", ""};
        if (insert_at > 0 && !arr[insert_at - 1].empty()) {
            block.insert(block.begin(), "");
        }
        
        arr.insert(arr.begin() + insert_at, block.begin(), block.end());
        return find_active_section_index(arr);
    }

    struct Context {
        std::string major;
        std::string minor;
    };

    Context context_for(const std::vector<std::string>& arr, int index) {
        Context ctx;
        std::regex minor_pattern("^### ");
        std::regex major_pattern("^## ");
        
        for (int i = index; i >= 0; --i) {
            const std::string& line = arr[i];
            if (ctx.minor.empty() && std::regex_search(line, minor_pattern)) {
                ctx.minor = trim(line);
            }
            if (std::regex_search(line, major_pattern)) {
                ctx.major = trim(line);
                break;
            }
        }
        return ctx;
    }

    int ensure_subsection(std::vector<std::string>& arr, const std::string& subsection) {
        int active_index = ensure_active_section(arr);
        int active_end = find_section_end(arr, active_index);
        std::string desired = (!subsection.empty() && subsection.substr(0, 4) == "### ") ? subsection : "### Changes";
        
        std::regex pattern("^### ");
        for (int i = active_index + 1; i < active_end; ++i) {
            if (trim(arr[i]) == desired) {
                return i;
            }
        }

        int insert_at = active_end;
        while (insert_at > active_index + 1 && arr[insert_at - 1].empty()) {
            insert_at--;
        }
        
        std::vector<std::string> block = {"", desired, ""};
        arr.insert(arr.begin() + insert_at, block.begin(), block.end());
        return insert_at + 1;
    }

    int section_tail_insert_index(const std::vector<std::string>& arr, int subsection_index) {
        std::regex pattern("^### |^## ");
        int next_heading = static_cast<int>(arr.size());
        
        for (size_t i = subsection_index + 1; i < arr.size(); ++i) {
            if (std::regex_search(arr[i], pattern)) {
                next_heading = static_cast<int>(i);
                break;
            }
        }

        int insert_at = next_heading;
        while (insert_at > subsection_index + 1 && arr[insert_at - 1].empty()) {
            insert_at--;
        }
        return insert_at;
    }

    std::string trim(const std::string& str) {
        size_t first = str.find_first_not_of(' ');
        if (first == std::string::npos) return "";
        size_t last = str.find_last_not_of(' ');
        return str.substr(first, (last - first + 1));
    }

    struct MovedEntry {
        std::string line;
        std::string subsection;
        int index;
    };

    void move_entries_to_unreleased(std::vector<std::string>& lines, const std::regex& pr_pattern) {
        ensure_active_section(lines);

        std::vector<MovedEntry> moved;
        for (size_t i = 0; i < lines.size(); ++i) {
            if (!std::regex_search(lines[i], pr_pattern)) {
                continue;
            }
            
            Context ctx = context_for(lines, static_cast<int>(i));
            if (ctx.major == "## Unreleased") {
                continue;
            }
            
            MovedEntry entry;
            entry.line = lines[i];
            entry.subsection = ctx.minor.empty() ? "### Changes" : ctx.minor;
            entry.index = static_cast<int>(i);
            moved.push_back(entry);
        }

        if (moved.empty()) {
            return;
        }

        std::set<int> remove_indexes;
        for (const auto& entry : moved) {
            remove_indexes.insert(entry.index);
        }

        std::vector<std::string> next_lines;
        for (size_t i = 0; i < lines.size(); ++i) {
            if (remove_indexes.find(static_cast<int>(i)) == remove_indexes.end()) {
                next_lines.push_back(lines[i]);
            }
        }

        for (const auto& entry : moved) {
            int subsection_index = ensure_subsection(next_lines, entry.subsection);
            int insert_at = section_tail_insert_index(next_lines, subsection_index);

            std::regex heading_pattern("^### |^## ");
            int next_heading = static_cast<int>(next_lines.size());
            for (size_t i = subsection_index + 1; i < next_lines.size(); ++i) {
                if (std::regex_search(next_lines[i], heading_pattern)) {
                    next_heading = static_cast<int>(i);
                    break;
                }
            }

            bool already_present = false;
            for (int i = subsection_index + 1; i < next_heading; ++i) {
                if (next_lines[i] == entry.line) {
                    already_present = true;
                    break;
                }
            }
            
            if (!already_present) {
                next_lines.insert(next_lines.begin() + insert_at, entry.line);
            }
        }

        lines = next_lines;
    }
};

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <pr_number>" << std::endl;
        return 1;
    }

    std::string pr_number = argv[1];
    ChangelogProcessor processor(pr_number);
    processor.normalize_pr_changelog_entries();

    return 0;
}

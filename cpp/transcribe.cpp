// abstraction-provenance: {"artifact_sha256": "9a7bfc0386fa2aab589b5d2eb033e77bb22f726ec3d4a5b616fceaff99f51b61", "source_sha256": "9c8abc93c198b77f804a6837db7baf1e85c902dc35a853c8086222a89f83fc89", "target_language": "cpp"}
// transcribe.sh — portiert nach cpp
// Quelle: shell, workspace@local:skills/github-clones/openclaw/skills/openai-whisper-api/scripts/transcribe.sh
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <filesystem>
#include <cstdlib>
#include <cstdio>
#include <memory>
#include <stdexcept>

namespace fs = std::filesystem;

void usage() {
    std::cerr << R"(Usage:
  transcribe <audio-file> [--model whisper-1] [--out /path/to/out.txt] [--language en] [--prompt "hint"] [--json]
)";
    std::exit(2);
}

std::string getEnv(const std::string& name) {
    const char* value = std::getenv(name.c_str());
    return value ? std::string(value) : "";
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        usage();
    }

    std::string first_arg = argv[1];
    if (first_arg == "-h" || first_arg == "--help") {
        usage();
    }

    std::string in = first_arg;
    
    std::string model = "whisper-1";
    std::string out = "";
    std::string language = "";
    std::string prompt = "";
    std::string response_format = "text";

    for (int i = 2; i < argc; ) {
        std::string arg = argv[i];
        if (arg == "--model" && i + 1 < argc) {
            model = argv[i + 1];
            i += 2;
        } else if (arg == "--out" && i + 1 < argc) {
            out = argv[i + 1];
            i += 2;
        } else if (arg == "--language" && i + 1 < argc) {
            language = argv[i + 1];
            i += 2;
        } else if (arg == "--prompt" && i + 1 < argc) {
            prompt = argv[i + 1];
            i += 2;
        } else if (arg == "--json") {
            response_format = "json";
            i += 1;
        } else {
            std::cerr << "Unknown arg: " << arg << std::endl;
            usage();
        }
    }

    if (!fs::exists(in)) {
        std::cerr << "File not found: " << in << std::endl;
        std::exit(1);
    }

    std::string api_key = getEnv("OPENAI_API_KEY");
    if (api_key.empty()) {
        std::cerr << "Missing OPENAI_API_KEY" << std::endl;
        std::exit(1);
    }

    if (out.empty()) {
        std::string base = in.substr(0, in.find_last_of('.'));
        if (response_format == "json") {
            out = base + ".json";
        } else {
            out = base + ".txt";
        }
    }

    fs::create_directories(fs::path(out).parent_path());

    std::string api_base = getEnv("OPENAI_BASE_URL");
    if (api_base.empty()) {
        api_base = "https://api.openai.com/v1";
    } else {
        // Remove trailing slash if present
        if (api_base.back() == '/') {
            api_base.pop_back();
        }
    }

    // Build curl command
    std::string cmd = "curl -sS \"" + api_base + "/audio/transcriptions\" "
                     "-H \"Authorization: Bearer " + api_key + "\" "
                     "-H \"Accept: application/json\" "
                     "-F \"file=@" + in + "\" "
                     "-F \"model=" + model + "\" "
                     "-F \"response_format=" + response_format + "\" ";
    
    if (!language.empty()) {
        cmd += "-F \"language=" + language + "\" ";
    }
    
    if (!prompt.empty()) {
        cmd += "-F \"prompt=" + prompt + "\" ";
    }
    
    cmd += ">\"" + out + "\"";

    int result = std::system(cmd.c_str());
    if (result != 0) {
        std::exit(1);
    }

    std::cout << out << std::endl;
    
    return 0;
}

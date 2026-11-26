// abstraction-provenance: {"artifact_sha256": "9eab40b7526352acd9d6ea43435f340e400dc600a3ca8702ab3c1e01bebf24c6", "source_sha256": "a26da3d1befb1a302d385e0a3c85117de3ec06543d5017cf1d706e7f0602be0f", "target_language": "cpp"}
// spawn_agent.py — portiert nach cpp
// Quelle: python, OpenClaw@gateway1:skills/sub-agents-utils/scripts/spawn_agent.py
// auch in: workspace@local:git/skills/sub-agents-utils/scripts/spawn_agent.py
// auch in: workspace@local:skills/sub-agents-utils/scripts/spawn_agent.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <string>
#include <vector>
#include <fstream>
#include <sstream>
#include <map>
#include <set>
#include <stdexcept>
#include <filesystem>
#include <cstdlib>
#include <nlohmann/json.hpp>

using json = nlohmann::json;
namespace fs = std::filesystem;

class ConfigException : public std::runtime_error {
public:
    ConfigException(const std::string& msg) : std::runtime_error(msg) {}
};

std::vector<std::string> loadModels() {
    const char* configEnv = std::getenv("OPENCLAW_CONFIG");
    fs::path configPath = configEnv ? fs::path(configEnv) : fs::path("/home/openclaw/.openclaw/openclaw.json");
    
    try {
        if (!fs::exists(configPath)) {
            throw ConfigException("Configuration file does not exist: " + configPath.string());
        }
        
        std::ifstream file(configPath);
        if (!file.is_open()) {
            throw ConfigException("Cannot open configuration file: " + configPath.string());
        }
        
        json config;
        file >> config;
        
        auto modelConfig = config.at("agents").at("defaults").at("model");
        std::vector<std::string> candidates;
        
        candidates.push_back(modelConfig.at("primary").get<std::string>());
        for (const auto& fallback : modelConfig.at("fallbacks")) {
            candidates.push_back(fallback.get<std::string>());
        }
        
        std::set<std::string> uniqueModels;
        std::vector<std::string> models;
        
        for (const auto& model : candidates) {
            if (!model.empty() && model.find("anthropic/") != 0) {
                if (uniqueModels.find(model) == uniqueModels.end()) {
                    uniqueModels.insert(model);
                    models.push_back(model);
                }
            }
        }
        
        if (models.empty()) {
            throw ConfigException("No generally available models found in " + configPath.string());
        }
        
        return models;
    } catch (const json::exception& e) {
        throw ConfigException("Model configuration cannot be loaded: " + configPath.string() + ": " + e.what());
    } catch (const std::exception& e) {
        throw ConfigException("Model configuration cannot be loaded: " + configPath.string() + ": " + e.what());
    }
}

const std::vector<std::string> MODELS = loadModels();

class SubAgentSpawner {
public:
    static json getSpawnConfig(
        const std::string& task,
        const std::string& label = "",
        const std::string& model = "",
        const std::string& thinking = "",
        int timeout = 0,
        bool thread = false,
        const std::string& mode = "run"
    ) {
        json config;
        config["task"] = task;
        
        if (!label.empty()) {
            config["label"] = label;
        }
        
        if (!model.empty()) {
            auto it = std::find(MODELS.begin(), MODELS.end(), model);
            if (it != MODELS.end()) {
                config["model"] = model;
            }
        }
        
        if (!thinking.empty()) {
            config["thinking"] = thinking;
        }
        
        if (timeout > 0) {
            config["runTimeoutSeconds"] = timeout;
        }
        
        if (thread) {
            config["thread"] = true;
            if (mode == "run") {
                config["mode"] = "session"; // thread requires session mode
            }
        } else {
            config["mode"] = mode;
        }
        
        return config;
    }
    
    static void printSpawnCommand(const json& config) {
        std::cout << "\n🛠️  Tool-Aufruf:" << std::endl;
        std::cout << "==================================================" << std::endl;
        std::cout << "sessions_spawn(" << std::endl;
        
        for (auto it = config.begin(); it != config.end(); ++it) {
            if (it.value().is_string()) {
                std::cout << "    " << it.key() << "=\"" << it.value().get<std::string>() << "\"" << std::endl;
            } else {
                std::cout << "    " << it.key() << "=" << it.value().dump() << std::endl;
            }
        }
        
        std::cout << ")" << std::endl;
        std::cout << "==================================================" << std::endl;
    }
    
    static void printSlashCommand(const json& config) {
        std::string task = config.value("task", "");
        std::string label = config.value("label", "agent");
        std::string model = config.value("model", "");
        
        std::string cmd = "/subagents spawn " + label + " \"" + task + "\"";
        
        if (!model.empty()) {
            cmd += " --model " + model;
        }
        
        if (config.contains("thinking") && !config["thinking"].is_null()) {
            cmd += " --thinking " + config["thinking"].get<std::string>();
        }
        
        std::cout << "\n💬 Slash Command:" << std::endl;
        std::cout << "==================================================" << std::endl;
        std::cout << cmd << std::endl;
        std::cout << "==================================================" << std::endl;
    }
};

void showHelp() {
    std::cout << R"(Sub-Agent Spawn Helper

Beispiele:
  spawn_agent --task "Analyze logs" 
  spawn_agent --task "Code review" --model openai/gpt-5.6-sol --timeout 1800
  spawn_agent --task "Batch process" --label "batch-worker" --thread
)";
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "Fehler: --task/-t ist erforderlich" << std::endl;
        return 1;
    }
    
    std::string task, label, model, thinking, output = "tool", mode = "run";
    int timeout = 900;
    bool thread = false;
    
    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];
        
        if (arg == "--help" || arg == "-h") {
            showHelp();
            return 0;
        }
        else if (arg == "--task" || arg == "-t") {
            if (i + 1 < argc) {
                task = argv[++i];
            } else {
                std::cerr << "Fehler: --task erfordert einen Wert" << std::endl;
                return 1;
            }
        }
        else if (arg == "--label" || arg == "-l") {
            if (i + 1 < argc) {
                label = argv[++i];
            } else {
                std::cerr << "Fehler: --label erfordert einen Wert" << std::endl;
                return 1;
            }
        }
        else if (arg == "--model" || arg == "-m") {
            if (i + 1 < argc) {
                model = argv[++i];
                // Prüfe ob das Modell gültig ist
                if (std::find(MODELS.begin(), MODELS.end(), model) == MODELS.end()) {
                    std::cerr << "Fehler: Ungültiges Modell: " << model << std::endl;
                    std::cerr << "Verfügbare Modelle:";
                    for (const auto& m : MODELS) {
                        std::cerr << " " << m;
                    }
                    std::cerr << std::endl;
                    return 1;
                }
            } else {
                std::cerr << "Fehler: --model erfordert einen Wert" << std::endl;
                return 1;
            }
        }
        else if (arg == "--thinking") {
            if (i + 1 < argc) {
                thinking = argv[++i];
                if (thinking != "low" && thinking != "medium" && thinking != "high") {
                    std::cerr << "Fehler: --thinking muss eines sein von: low, medium, high" << std::endl;
                    return 1;
                }
            } else {
                std::cerr << "Fehler: --thinking erfordert einen Wert" << std::endl;
                return 1;
            }
        }
        else if (arg == "--timeout") {
            if (i + 1 < argc) {
                try {
                    timeout = std::stoi(argv[++i]);
                } catch (...) {
                    std::cerr << "Fehler: --timeout erfordert eine Zahl" << std::endl;
                    return 1;
                }
            } else {
                std::cerr << "Fehler: --timeout erfordert einen Wert" << std::endl;
                return 1;
            }
        }
        else if (arg == "--thread") {
            thread = true;
        }
        else if (arg == "--mode") {
            if (i + 1 < argc) {
                mode = argv[++i];
                if (mode != "run" && mode != "session") {
                    std::cerr << "Fehler: --mode muss eines sein von: run, session" << std::endl;
                    return 1;
                }
            } else {
                std::cerr << "Fehler: --mode erfordert einen Wert" << std::endl;
                return 1;
            }
        }
        else if (arg == "--output" || arg == "-o") {
            if (i + 1 < argc) {
                output = argv[++i];
                if (output != "tool" && output != "slash" && output != "json") {
                    std::cerr << "Fehler: --output muss eines sein von: tool, slash, json" << std::endl;
                    return 1;
                }
            } else {
                std::cerr << "Fehler: --output erfordert einen Wert" << std::endl;
                return 1;
            }
        }
    }
    
    if (task.empty()) {
        std::cerr << "Fehler: --task/-t ist erforderlich" << std::endl;
        return 1;
    }
    
    try {
        json config = SubAgentSpawner::getSpawnConfig(task, label, model, thinking, timeout, thread, mode);
        
        std::cout << "✅ Sub-Agent Konfiguration:" << std::endl;
        std::cout << config.dump(2) << std::endl;
        
        if (output == "tool") {
            SubAgentSpawner::printSpawnCommand(config);
        } else if (output == "slash") {
            SubAgentSpawner::printSlashCommand(config);
        } else if (output == "json") {
            std::cout << "\n📄 JSON:" << std::endl;
            std::cout << config.dump() << std::endl;
            
            // Speichere als Datei
            std::string fileName = "/tmp/subagent_" + (label.empty() ? "spawn" : label) + ".json";
            std::ofstream outFile(fileName);
            if (outFile.is_open()) {
                outFile << config.dump(2);
                outFile.close();
                std::cout << "💾 Gespeichert: " << fileName << std::endl;
            } else {
                std::cerr << "Warnung: Kann Datei nicht speichern: " << fileName << std::endl;
            }
        }
    } catch (const std::exception& e) {
        std::cerr << "Fehler: " << e.what() << std::endl;
        return 1;
    }
    
    return 0;
}

// abstraction-provenance: {"artifact_sha256": "41e15cec4a77eaf1cc2fc9a4eb03fe7e53b7685d1f6de2b201a91baab88dc1a6", "source_sha256": "b97ad7dc26be724af240b4c0c98ec196e729e0702664b99c65e0e3c435a1b5af", "target_language": "cpp"}
// sync-local.ps1 — portiert nach cpp
// Quelle: powershell, Onboarding@main:scripts/sync-local.ps1
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <string>
#include <vector>
#include <filesystem>
#include <chrono>
#include <thread>
#include <cstdlib>
#include <cstdio>
#include <memory>
#include <stdexcept>
#include <sstream>
#include <algorithm>
#include <regex>

namespace fs = std::filesystem;

class GitSync {
private:
    std::string branch;
    int intervalSeconds;
    std::string composeFile;
    bool once;
    std::string repoRoot;

    void log(const std::string& msg) {
        auto now = std::chrono::system_clock::now();
        auto time_t = std::chrono::system_clock::to_time_t(now);
        auto local_time = *std::localtime(&time_t);
        
        char buffer[9];
        std::strftime(buffer, sizeof(buffer), "%H:%M:%S", &local_time);
        
        std::cout << "[" << buffer << "] " << msg << std::endl;
    }

    std::string exec(const std::string& cmd) {
        std::array<char, 128> buffer;
        std::string result;
        std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(cmd.c_str(), "r"), pclose);
        if (!pipe) {
            throw std::runtime_error("popen() failed!");
        }
        while (fgets(buffer.data(), buffer.size(), pipe.get()) != nullptr) {
            result += buffer.data();
        }
        return result;
    }

    int execNoCapture(const std::string& cmd) {
        return std::system(cmd.c_str());
    }

    std::vector<std::string> splitString(const std::string& str, char delimiter) {
        std::vector<std::string> tokens;
        std::stringstream ss(str);
        std::string token;
        while (std::getline(ss, token, delimiter)) {
            // Trim whitespace
            token.erase(0, token.find_first_not_of(" \t\r\n"));
            token.erase(token.find_last_not_of(" \t\r\n") + 1);
            if (!token.empty()) {
                tokens.push_back(token);
            }
        }
        return tokens;
    }

    void invokeCompose(const std::vector<std::string>& composeArgs) {
        std::string cmd = "docker compose -f " + composeFile;
        for (const auto& arg : composeArgs) {
            cmd += " " + arg;
        }
        
        int exitCode = execNoCapture(cmd);
        if (exitCode != 0) {
            log("WARNUNG: docker compose " + cmd.substr(17) + " fehlgeschlagen (Exit " + std::to_string(exitCode) + ")");
        }
    }

public:
    GitSync(const std::string& branch, int intervalSeconds, const std::string& composeFile, bool once)
        : branch(branch), intervalSeconds(intervalSeconds), composeFile(composeFile), once(once) {
        
        // Get script directory and navigate to parent
        char buffer[256];
        ssize_t len = readlink("/proc/self/exe", buffer, sizeof(buffer)-1);
        if (len != -1) {
            buffer[len] = '\0';
            fs::path scriptPath(buffer);
            repoRoot = scriptPath.parent_path().parent_path().string();
        } else {
            repoRoot = fs::current_path().string();
        }
    }

    void run() {
        // Change to repository root
        fs::current_path(repoRoot);

        // Ensure target branch is checked out
        std::string current = exec("git rev-parse --abbrev-ref HEAD");
        current.erase(std::remove(current.begin(), current.end(), '\n'), current.end());
        current.erase(std::remove(current.begin(), current.end(), '\r'), current.end());

        if (current != branch) {
            log("Wechsle von '" + current + "' auf '" + branch + "' …");
            execNoCapture("git fetch origin " + branch);
            int result = execNoCapture("git switch " + branch + " 2>/dev/null");
            if (result != 0) {
                execNoCapture("git switch -c " + branch + " --track \"origin/" + branch + "\"");
            }
            if (result != 0) {
                throw std::runtime_error("Branch '" + branch + "' konnte nicht ausgecheckt werden.");
            }
        }

        log("Sync aktiv: origin/" + branch + " -> " + repoRoot + " (Intervall " + 
            std::to_string(intervalSeconds) + "s, Compose: " + composeFile + ")");

        while (true) {
            int fetchResult = execNoCapture("git fetch origin " + branch + " --quiet");
            if (fetchResult != 0) {
                log("Fetch fehlgeschlagen (Netzwerk?) — nächster Versuch in " + 
                    std::to_string(intervalSeconds) + "s");
            } else {
                std::string local = exec("git rev-parse HEAD");
                local.erase(std::remove(local.begin(), local.end(), '\n'), local.end());
                local.erase(std::remove(local.begin(), local.end(), '\r'), local.end());

                std::string remote = exec("git rev-parse origin/" + branch);
                remote.erase(std::remove(remote.begin(), remote.end(), '\n'), remote.end());
                remote.erase(std::remove(remote.begin(), remote.end(), '\r'), remote.end());

                if (local != remote) {
                    int ancestorCheck = execNoCapture("git merge-base --is-ancestor " + 
                                                     local + " " + remote);
                    if (ancestorCheck != 0) {
                        log("ACHTUNG: Lokaler Stand ist von origin/" + branch + 
                            " abgewichen (lokale Commits?). Kein automatischer Merge — bitte manuell auflösen.");
                    } else {
                        std::string diffOutput = exec("git diff --name-only " + local + ".." + remote);
                        std::vector<std::string> changed = splitString(diffOutput, '\n');
                        
                        // Remove empty strings
                        changed.erase(std::remove_if(changed.begin(), changed.end(), 
                                      [](const std::string& s) { return s.empty(); }), 
                                      changed.end());

                        execNoCapture("git merge --ff-only " + remote + " --quiet");
                        
                        std::string localShort = local.substr(0, 7);
                        std::string remoteShort = remote.substr(0, 7);
                        log("Aktualisiert " + localShort + " -> " + remoteShort + 
                            " (" + std::to_string(changed.size()) + " Datei(en))");

                        bool frontendDeps = false;
                        bool backendImage = false;
                        bool composeChanged = false;

                        for (const auto& file : changed) {
                            if (file == "package.json" || file == "package-lock.json") {
                                frontendDeps = true;
                            }
                            
                            if (file.rfind("backend/", 0) == 0) {
                                std::regex backendPattern("^backend/(Dockerfile|requirements.*\\.txt)$");
                                if (std::regex_match(file, backendPattern)) {
                                    backendImage = true;
                                }
                            }
                            
                            if (file == composeFile) {
                                composeChanged = true;
                            }
                        }

                        if (composeChanged) {
                            log("Compose-Datei geändert — erzeuge Dev-Stack neu …");
                            invokeCompose({"up", "-d"});
                        }
                        
                        if (backendImage) {
                            log("Backend-Dependencies/Dockerfile geändert — baue nur das Backend neu …");
                            invokeCompose({"up", "-d", "--build", "backend"});
                        }
                        
                        if (frontendDeps) {
                            log("Frontend-Dependencies geändert — starte Frontend neu (npm install läuft im Container) …");
                            invokeCompose({"restart", "frontend"});
                        }
                        
                        if (!(composeChanged || backendImage || frontendDeps)) {
                            log("Nur Quellcode/Assets — Hot-Reload übernimmt, kein Build nötig.");
                        }
                    }
                }
            }

            if (once) break;
            std::this_thread::sleep_for(std::chrono::seconds(intervalSeconds));
        }
    }
};

int main(int argc, char* argv[]) {
    std::string branch = "claude/onboarding-persistent-sandbox-vjfmcx";
    int intervalSeconds = 20;
    std::string composeFile = "docker-compose.dev.yml";
    bool once = false;

    // Simple argument parsing
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "-Branch" && i + 1 < argc) {
            branch = argv[++i];
        } else if (arg == "-IntervalSeconds" && i + 1 < argc) {
            intervalSeconds = std::stoi(argv[++i]);
        } else if (arg == "-ComposeFile" && i + 1 < argc) {
            composeFile = argv[++i];
        } else if (arg == "-Once") {
            once = true;
        }
    }

    try {
        GitSync sync(branch, intervalSeconds, composeFile, once);
        sync.run();
    } catch (const std::exception& e) {
        std::cerr << "Fehler: " << e.what() << std::endl;
        return 1;
    }

    return 0;
}

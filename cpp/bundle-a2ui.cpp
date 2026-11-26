// abstraction-provenance: {"artifact_sha256": "a229436ad11a0cac2cb32aef867e931f94565ff2ed614331f7ab9560703ba3e1", "source_sha256": "30b068d00de57f3979f795548c3348e1511fda4cab0dd01eb16a7d91c71fbb9d", "target_language": "cpp"}
// bundle-a2ui.mjs — portiert nach cpp
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/bundle-a2ui.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <filesystem>
#include <fstream>
#include <iostream>
#include <vector>
#include <string>
#include <algorithm>
#include <cstdlib>
#include <memory>
#include <sstream>
#include <iomanip>
#include <openssl/sha.h>
#include <cstdio>

namespace fs = std::filesystem;

class BundleA2UI {
private:
    static inline const std::string rootDir = fs::current_path().string();
    static inline const std::string hashFile = rootDir + "/src/canvas-host/a2ui/.bundle.hash";
    static inline const std::string outputFile = rootDir + "/src/canvas-host/a2ui/a2ui.bundle.js";
    static inline const std::string a2uiRendererDir = rootDir + "/vendor/a2ui/renderers/lit";
    static inline const std::string a2uiAppDir = rootDir + "/apps/shared/OpenClawKit/Tools/CanvasA2UI";
    
    static inline const std::vector<std::string> inputPaths = {
        rootDir + "/package.json",
        rootDir + "/pnpm-lock.yaml",
        a2uiRendererDir,
        a2uiAppDir
    };
    
    static inline const std::vector<std::string> ignoredBundleHashInputPrefixes = {
        "vendor/a2ui/renderers/lit/dist"
    };

public:
    static void fail(const std::string& message) {
        std::cerr << message << std::endl;
        std::cerr << "A2UI bundling failed. Re-run with: pnpm canvas:a2ui:bundle" << std::endl;
        std::cerr << "If this persists, verify pnpm deps and try again." << std::endl;
        std::exit(1);
    }

    static bool pathExists(const std::string& targetPath) {
        return fs::exists(targetPath);
    }

    static std::string normalizePath(const std::string& filePath) {
        std::string result = filePath;
        std::replace(result.begin(), result.end(), '\\', '/');
        return result;
    }

    static bool isBundleHashInputPath(const std::string& filePath, const std::string& repoRoot = rootDir) {
        std::string relativePath = normalizePath(fs::relative(filePath, repoRoot).string());
        for (const auto& ignoredPath : ignoredBundleHashInputPrefixes) {
            if (relativePath == ignoredPath || 
                (relativePath.length() > ignoredPath.length() && 
                 relativePath.substr(0, ignoredPath.length()) == ignoredPath &&
                 relativePath[ignoredPath.length()] == '/')) {
                return false;
            }
        }
        return true;
    }

    static std::vector<std::string> getLocalRolldownCliCandidates(const std::string& repoRoot = rootDir) {
        return {
            repoRoot + "/node_modules/rolldown/bin/cli.mjs",
            repoRoot + "/node_modules/.pnpm/node_modules/rolldown/bin/cli.mjs",
            repoRoot + "/node_modules/.pnpm/rolldown@1.0.0-rc.12/node_modules/rolldown/bin/cli.mjs"
        };
    }

    static void walkFiles(const std::string& entryPath, std::vector<std::string>& files) {
        if (!isBundleHashInputPath(entryPath)) {
            return;
        }
        
        if (!fs::is_directory(entryPath)) {
            files.push_back(entryPath);
            return;
        }
        
        for (const auto& entry : fs::directory_iterator(entryPath)) {
            walkFiles(entry.path().string(), files);
        }
    }

    static std::vector<std::string> listTrackedInputFiles() {
        std::vector<std::string> relativeInputPaths;
        for (const auto& inputPath : inputPaths) {
            relativeInputPaths.push_back(normalizePath(fs::relative(inputPath, rootDir).string()));
        }
        
        std::string command = "git ls-files -- ";
        for (const auto& path : relativeInputPaths) {
            command += "\"" + path + "\" ";
        }
        
        FILE* pipe = popen(command.c_str(), "r");
        if (!pipe) {
            return {};
        }
        
        std::vector<std::string> result;
        char buffer[4096];
        while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
            std::string line(buffer);
            line.erase(std::remove(line.begin(), line.end(), '\n'), line.end());
            if (!line.empty()) {
                result.push_back(rootDir + "/" + line);
            }
        }
        pclose(pipe);
        
        std::vector<std::string> filtered;
        for (const auto& filePath : result) {
            if (isBundleHashInputPath(filePath)) {
                filtered.push_back(filePath);
            }
        }
        return filtered;
    }

    static std::string readFile(const std::string& filePath) {
        std::ifstream file(filePath, std::ios::binary);
        std::stringstream buffer;
        buffer << file.rdbuf();
        return buffer.str();
    }

    static std::string computeHash() {
        auto files = listTrackedInputFiles();
        if (files.empty()) {
            for (const auto& inputPath : inputPaths) {
                walkFiles(inputPath, files);
            }
        }
        
        std::sort(files.begin(), files.end(), [](const std::string& left, const std::string& right) {
            return normalizePath(left) < normalizePath(right);
        });

        unsigned char hash[SHA256_DIGEST_LENGTH];
        SHA256_CTX sha256;
        SHA256_Init(&sha256);
        
        for (const auto& filePath : files) {
            std::string relativePath = normalizePath(fs::relative(filePath, rootDir).string());
            SHA256_Update(&sha256, relativePath.c_str(), relativePath.length());
            SHA256_Update(&sha256, "\0", 1);
            
            std::string content = readFile(filePath);
            SHA256_Update(&sha256, content.c_str(), content.length());
            SHA256_Update(&sha256, "\0", 1);
        }
        
        SHA256_Final(hash, &sha256);
        
        std::stringstream ss;
        for (int i = 0; i < SHA256_DIGEST_LENGTH; i++) {
            ss << std::hex << std::setw(2) << std::setfill('0') << (int)hash[i];
        }
        return ss.str();
    }

    static int runCommand(const std::string& command) {
        return std::system(command.c_str());
    }

    static void runPnpm(const std::vector<std::string>& pnpmArgs) {
        std::string command = "pnpm";
        for (const auto& arg : pnpmArgs) {
            command += " " + arg;
        }
        if (runCommand(command) != 0) {
            std::exit(1);
        }
    }

    static void main() {
        bool hasRendererDir = pathExists(a2uiRendererDir);
        bool hasAppDir = pathExists(a2uiAppDir);
        bool hasOutputFile = pathExists(outputFile);
        
        if (!hasRendererDir || !hasAppDir) {
            if (hasOutputFile) {
                std::cout << "A2UI sources missing; keeping prebuilt bundle." << std::endl;
                return;
            }
            
            const char* sparseProfile = std::getenv("OPENCLAW_SPARSE_PROFILE");
            const char* skipMissing = std::getenv("OPENCLAW_A2UI_SKIP_MISSING");
            
            if (sparseProfile || (skipMissing && std::string(skipMissing) == "1")) {
                std::cerr << "A2UI sources missing; skipping bundle because OPENCLAW_A2UI_SKIP_MISSING=1 or OPENCLAW_SPARSE_PROFILE is set." << std::endl;
                return;
            }
            
            fail("A2UI sources missing and no prebuilt bundle found at: " + outputFile);
        }

        std::string currentHash = computeHash();
        if (pathExists(hashFile)) {
            std::ifstream hashFileStream(hashFile);
            std::string previousHash;
            std::getline(hashFileStream, previousHash);
            
            if (previousHash == currentHash && hasOutputFile) {
                std::cout << "A2UI bundle up to date; skipping." << std::endl;
                return;
            }
        }

        runPnpm({"-s", "exec", "tsc", "-p", a2uiRendererDir + "/tsconfig.json"});

        auto localRolldownCliCandidates = getLocalRolldownCliCandidates(rootDir);
        std::string localRolldownCli;
        
        for (const auto& candidate : localRolldownCliCandidates) {
            if (pathExists(candidate)) {
                localRolldownCli = candidate;
                break;
            }
        }

        if (!localRolldownCli.empty()) {
            std::string command = "node \"" + localRolldownCli + "\" -c \"" + a2uiAppDir + "/rolldown.config.mjs\"";
            if (runCommand(command) != 0) {
                std::exit(1);
            }
        } else {
            runPnpm({"-s", "exec", "rolldown", "-c", a2uiAppDir + "/rolldown.config.mjs"});
        }

        std::ofstream hashFileStream(hashFile);
        hashFileStream << currentHash << std::endl;
    }
};

int main(int argc, char* argv[]) {
    try {
        BundleA2UI::main();
    } catch (const std::exception& e) {
        BundleA2UI::fail(e.what());
    }
    return 0;
}

// abstraction-provenance: {"artifact_sha256": "e101f8eab345890872abc673d443d790dcbf19251b24cb0e21715cac5a9fa7a9", "source_sha256": "e31da3d72f8d806a159d6709f37f55500c7f16939f04c094f2ab46a959e70c57", "target_language": "cpp"}
// translation-worker-node5.ps1 — portiert nach cpp
// Quelle: powershell, workspace@local:skills/multi-nodes-utils/scripts/translation-worker-node5.ps1
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <string>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <iomanip>
#include <stdexcept>
#include <cstdlib>
#include <cstring>
#include <openssl/sha.h>

namespace fs = std::filesystem;

class TranslationWorker {
private:
    std::string action;
    std::string workerPath;
    std::string expectedHash = "9f8e810dd49f30fbc05064a98faf280d1f2480fdb8f125115ad006d486cd555b";
    
    std::string getHomeDirectory() {
        const char* home = std::getenv("USERPROFILE");
        if (!home) {
            home = std::getenv("HOME");
        }
        if (!home) {
            throw std::runtime_error("Could not determine home directory");
        }
        return std::string(home);
    }
    
    std::string calculateSHA256(const std::string& filepath) {
        std::ifstream file(filepath, std::ios::binary);
        if (!file) {
            throw std::runtime_error("Could not open file for hashing: " + filepath);
        }
        
        SHA256_CTX sha256;
        SHA256_Init(&sha256);
        
        char buffer[8192];
        while (file.read(buffer, sizeof(buffer)) || file.gcount() > 0) {
            SHA256_Update(&sha256, buffer, file.gcount());
        }
        
        unsigned char hash[SHA256_DIGEST_LENGTH];
        SHA256_Final(hash, &sha256);
        
        std::stringstream ss;
        for (int i = 0; i < SHA256_DIGEST_LENGTH; i++) {
            ss << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(hash[i]);
        }
        
        return ss.str();
    }
    
    bool isSymlink(const std::string& path) {
#ifdef _WIN32
        DWORD attributes = GetFileAttributesA(path.c_str());
        return (attributes != INVALID_FILE_ATTRIBUTES) && (attributes & FILE_ATTRIBUTE_REPARSE_POINT);
#else
        return fs::is_symlink(fs::path(path));
#endif
    }
    
    std::string findPython() {
        const char* paths[] = {
            "/usr/bin/python3",
            "/usr/bin/python",
            "/usr/local/bin/python3",
            "/usr/local/bin/python",
            "C:\\Python\\python.exe",
            "C:\\Python3\\python.exe"
        };
        
        for (const auto& path : paths) {
            if (fs::exists(path)) {
                return std::string(path);
            }
        }
        
        const char* envPath = std::getenv("PATH");
        if (envPath) {
            std::string pathStr(envPath);
            std::istringstream iss(pathStr);
            std::string dir;
            while (std::getline(iss, dir, ':')) {
                std::string pythonPath = dir + "/python";
                if (fs::exists(pythonPath)) {
                    return pythonPath;
                }
                pythonPath = dir + "/python3";
                if (fs::exists(pythonPath)) {
                    return pythonPath;
                }
            }
        }
        
        throw std::runtime_error("Python executable not found");
    }

public:
    TranslationWorker(const std::string& action) : action(action) {
        if (action != "prepare" && action != "run") {
            throw std::invalid_argument("Action must be 'prepare' or 'run'");
        }
        
        std::string homeDir = getHomeDirectory();
        workerPath = homeDir + "/.openclaw/workers/translation_worker.py";
#ifdef _WIN32
        size_t pos = 0;
        while ((pos = workerPath.find("/", pos)) != std::string::npos) {
            workerPath.replace(pos, 1, "\\");
            pos += 1;
        }
#endif
    }
    
    void validateWorker() {
        // Windows does not use chmod. The Python worker and Python 3 must already be
        // installed locally; no credentials are copied or placed on a command line.
        
        if (!fs::exists(workerPath)) {
            throw std::runtime_error("Worker missing: " + workerPath);
        }
        
        if (!fs::is_regular_file(workerPath)) {
            throw std::runtime_error("Worker is not a regular file: " + workerPath);
        }
        
        if (isSymlink(workerPath)) {
            throw std::runtime_error("Worker link rejected");
        }
        
        std::string actualHash = calculateSHA256(workerPath);
        if (actualHash != expectedHash) {
            throw std::runtime_error("Worker checksum mismatch");
        }
    }
    
    int execute() {
        validateWorker();
        
        if (action == "prepare") {
            std::cout << "Worker verified: " << workerPath << std::endl;
            return 0;
        }
        
        std::string pythonPath = findPython();
        
        std::string command = pythonPath + " \"" + workerPath + "\"";
        int result = std::system(command.c_str());
        
        return result;
    }
};

int main(int argc, char* argv[]) {
    try {
        if (argc != 2) {
            std::cerr << "Usage: " << argv[0] << " <prepare|run>" << std::endl;
            return 1;
        }
        
        std::string action(argv[1]);
        TranslationWorker worker(action);
        return worker.execute();
        
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }
}

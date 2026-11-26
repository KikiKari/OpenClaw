// abstraction-provenance: {"artifact_sha256": "6812047a39dae02a16b3a96e9a7c0416bed4e06f3b854b0877de5b82b8bfd8ae", "source_sha256": "d97d27f12d9366bc18a828ca10d87d4ac159681dec9d4b6606e4827761c6ea72", "target_language": "cpp"}
// changed-extensions.mjs — portiert nach cpp
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/changed-extensions.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <algorithm>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <memory>
#include <regex>
#include <set>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

#ifdef _WIN32
#include <windows.h>
#else
#include <sys/wait.h>
#include <unistd.h>
#endif

namespace fs = std::filesystem;

// Constants - these would need to be defined based on your project structure
const std::string BUNDLED_PLUGIN_PATH_PREFIX = "extensions/";
const std::string BUNDLED_PLUGIN_ROOT_DIR = "extensions";

class GitHelper {
private:
    std::string repoRoot;

public:
    GitHelper(const std::string& scriptDir) {
        fs::path scriptPath(scriptDir);
        repoRoot = fs::absolute(scriptPath / ".." / "..").string();
    }

    std::string runGit(const std::vector<std::string>& args, bool throwOnError = true) {
        std::vector<std::string> fullArgs = {"git"};
        fullArgs.insert(fullArgs.end(), args.begin(), args.end());
        
        std::string output;
        int exitCode = executeCommand(fullArgs, output);
        
        if (exitCode != 0 && throwOnError) {
            throw std::runtime_error("Git command failed");
        }
        
        return output;
    }

private:
    int executeCommand(const std::vector<std::string>& cmd, std::string& output) {
#ifdef _WIN32
        std::string commandLine;
        for (size_t i = 0; i < cmd.size(); ++i) {
            if (i > 0) commandLine += " ";
            commandLine += "\"" + cmd[i] + "\"";
        }

        SECURITY_ATTRIBUTES sa;
        sa.nLength = sizeof(SECURITY_ATTRIBUTES);
        sa.lpSecurityDescriptor = NULL;
        sa.bInheritHandle = TRUE;

        HANDLE hReadPipe, hWritePipe;
        if (!CreatePipe(&hReadPipe, &hWritePipe, &sa, 0))
            return -1;

        STARTUPINFO si;
        PROCESS_INFORMATION pi;
        ZeroMemory(&si, sizeof(si));
        si.cb = sizeof(si);
        si.dwFlags = STARTF_USESTDHANDLES;
        si.hStdError = hWritePipe;
        si.hStdOutput = hWritePipe;
        si.hStdInput = NULL;

        ZeroMemory(&pi, sizeof(pi));

        // Create a copy of commandLine that can be modified
        std::string cmdCopy = commandLine;
        if (!CreateProcess(NULL, &cmdCopy[0], NULL, NULL, TRUE, 0, NULL, repoRoot.c_str(), &si, &pi)) {
            CloseHandle(hWritePipe);
            CloseHandle(hReadPipe);
            return -1;
        }

        CloseHandle(hWritePipe);

        char buffer[4096];
        DWORD bytesRead;
        while (ReadFile(hReadPipe, buffer, sizeof(buffer), &bytesRead, NULL) && bytesRead > 0) {
            output.append(buffer, bytesRead);
        }

        WaitForSingleObject(pi.hProcess, INFINITE);
        DWORD exitCode;
        GetExitCodeProcess(pi.hProcess, &exitCode);

        CloseHandle(hReadPipe);
        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);

        return static_cast<int>(exitCode);
#else
        // Unix implementation
        std::string command = "cd \"" + repoRoot + "\" && ";
        for (size_t i = 0; i < cmd.size(); ++i) {
            if (i > 0) command += " ";
            command += "\"" + cmd[i] + "\"";
        }
        command += " 2>&1";

        FILE* pipe = popen(command.c_str(), "r");
        if (!pipe) return -1;

        char buffer[4096];
        while (fgets(buffer, sizeof(buffer), pipe)) {
            output += buffer;
        }

        int exitCode = WEXITSTATUS(pclose(pipe));
        return exitCode;
#endif
    }
};

std::string normalizeRelative(const std::string& inputPath) {
#ifdef _WIN32
    std::string result = inputPath;
    std::replace(result.begin(), result.end(), '\\', '/');
    return result;
#else
    return inputPath;
#endif
}

bool hasGitCommit(GitHelper& gitHelper, const std::string& ref) {
    if (ref.empty() || std::regex_match(ref, std::regex("^0+$"))) {
        return false;
    }

    try {
        gitHelper.runGit({"rev-parse", "--verify", ref + "^{commit}"}, false);
        return true;
    } catch (...) {
        return false;
    }
}

std::string resolveChangedPathsBase(GitHelper& gitHelper, 
                                   const std::string& base, 
                                   const std::string& head, 
                                   const std::string& fallbackBaseRef) {
    if (!base.empty() && hasGitCommit(gitHelper, base)) {
        return base;
    }

    if (!fallbackBaseRef.empty()) {
        std::string remoteBaseRef = fallbackBaseRef;
        if (remoteBaseRef.find("origin/") != 0) {
            remoteBaseRef = "origin/" + remoteBaseRef;
        }
        
        if (hasGitCommit(gitHelper, remoteBaseRef)) {
            try {
                std::string mergeBase = gitHelper.runGit({"merge-base", remoteBaseRef, head});
                // Trim whitespace
                mergeBase.erase(0, mergeBase.find_first_not_of(" \t\n\r"));
                mergeBase.erase(mergeBase.find_last_not_of(" \t\n\r") + 1);
                
                if (hasGitCommit(gitHelper, mergeBase)) {
                    return mergeBase;
                }
            } catch (...) {
                // Continue to error handling
            }
        }
    }

    if (base.empty()) {
        throw std::runtime_error("A git base revision is required to list changed extensions.");
    }

    throw std::runtime_error("Git base revision is unavailable locally: " + base);
}

std::vector<std::string> listChangedPaths(GitHelper& gitHelper, const std::string& base, const std::string& head) {
    if (base.empty()) {
        throw std::runtime_error("A git base revision is required to list changed extensions.");
    }

    std::string result = gitHelper.runGit({"diff", "--name-only", base, head});
    
    std::vector<std::string> paths;
    std::istringstream iss(result);
    std::string line;
    
    while (std::getline(iss, line)) {
        // Trim whitespace
        line.erase(0, line.find_first_not_of(" \t\n\r"));
        line.erase(line.find_last_not_of(" \t\n\r") + 1);
        
        if (!line.empty()) {
            paths.push_back(line);
        }
    }
    
    return paths;
}

bool hasExtensionPackage(const std::string& repoRoot, const std::string& extensionId) {
    fs::path packagePath = fs::path(repoRoot) / BUNDLED_PLUGIN_ROOT_DIR / extensionId / "package.json";
    return fs::exists(packagePath);
}

std::vector<std::string> listAvailableExtensionIds(const std::string& repoRoot) {
    fs::path extensionsDir = fs::path(repoRoot) / BUNDLED_PLUGIN_ROOT_DIR;
    if (!fs::exists(extensionsDir)) {
        return {};
    }

    std::vector<std::string> extensionIds;
    
    for (const auto& entry : fs::directory_iterator(extensionsDir)) {
        if (entry.is_directory()) {
            std::string extensionId = entry.path().filename().string();
            if (hasExtensionPackage(repoRoot, extensionId)) {
                extensionIds.push_back(extensionId);
            }
        }
    }
    
    std::sort(extensionIds.begin(), extensionIds.end());
    return extensionIds;
}

std::vector<std::string> detectChangedExtensionIds(const std::vector<std::string>& changedPaths, 
                                                   const std::string& repoRoot) {
    std::set<std::string> extensionIds;
    
    std::string escapedPrefix = BUNDLED_PLUGIN_PATH_PREFIX;
    // Escape forward slashes for regex
    size_t pos = 0;
    while ((pos = escapedPrefix.find("/", pos)) != std::string::npos) {
        escapedPrefix.replace(pos, 1, "\\/");
        pos += 2;
    }
    
    std::regex extensionRegex("^" + escapedPrefix + "([^/]+)(?:/|$)");
    std::regex pairedCoreRegex("^src/([^/]+)(?:/|$)");

    for (const auto& rawPath : changedPaths) {
        std::string relativePath = normalizeRelative(rawPath);
        // Trim whitespace
        relativePath.erase(0, relativePath.find_first_not_of(" \t\n\r"));
        relativePath.erase(relativePath.find_last_not_of(" \t\n\r") + 1);
        
        if (relativePath.empty()) {
            continue;
        }

        std::smatch extensionMatch;
        if (std::regex_search(relativePath, extensionMatch, extensionRegex)) {
            std::string extensionId = extensionMatch[1].str();
            if (hasExtensionPackage(repoRoot, extensionId)) {
                extensionIds.insert(extensionId);
            }
            continue;
        }

        std::smatch pairedCoreMatch;
        if (std::regex_search(relativePath, pairedCoreMatch, pairedCoreRegex)) {
            if (hasExtensionPackage(repoRoot, pairedCoreMatch[1].str())) {
                extensionIds.insert(pairedCoreMatch[1].str());
            }
        }
    }

    std::vector<std::string> result(extensionIds.begin(), extensionIds.end());
    std::sort(result.begin(), result.end());
    return result;
}

std::vector<std::string> listChangedExtensionIds(const std::string& scriptDir,
                                                 const std::string& base = "",
                                                 const std::string& head = "HEAD",
                                                 const std::string& fallbackBaseRef = "",
                                                 const std::string& unavailableBaseBehavior = "error") {
    GitHelper gitHelper(scriptDir);
    
    try {
        std::string resolvedBase = resolveChangedPathsBase(gitHelper, base, head, fallbackBaseRef);
        std::vector<std::string> changedPaths = listChangedPaths(gitHelper, resolvedBase, head);
        
        fs::path repoRootPath(fs::path(scriptDir) / ".." / "..");
        std::string repoRoot = fs::absolute(repoRootPath).string();
        
        return detectChangedExtensionIds(changedPaths, repoRoot);
    } catch (const std::exception& e) {
        if (unavailableBaseBehavior == "all") {
            fs::path repoRootPath(fs::path(scriptDir) / ".." / "..");
            std::string repoRoot = fs::absolute(repoRootPath).string();
            return listAvailableExtensionIds(repoRoot);
        }
        if (unavailableBaseBehavior == "empty") {
            return {};
        }
        throw;
    }
}

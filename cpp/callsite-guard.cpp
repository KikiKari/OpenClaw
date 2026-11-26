// abstraction-provenance: {"artifact_sha256": "488f8cdfc6747767938521d59330ebc35f6f9023570701df410af72829123b44", "source_sha256": "b6d33ba222e838d8ea4e8f134b161c60019978c5abaa86299906dfe095635a2b", "target_language": "cpp"}
// callsite-guard.mjs — portiert nach cpp
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/callsite-guard.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <filesystem>
#include <fstream>
#include <functional>
#include <iostream>
#include <string>
#include <vector>
#include <algorithm>
#include <sstream>

namespace fs = std::filesystem;

// Forward declarations for utility functions that would need to be implemented
std::vector<std::string> collectTypeScriptFilesFromRoots(
    const std::vector<std::string>& sourceRoots,
    const std::vector<std::string>& extraTestSuffixes);

std::string resolveRepoRoot(const std::string& importMetaUrl);
std::vector<std::string> resolveSourceRoots(
    const std::string& repoRoot,
    const std::vector<std::string>& sourceRoots);

struct CallsiteGuardParams {
    std::string importMetaUrl;
    std::vector<std::string> sourceRoots;
    std::vector<std::string> extraTestSuffixes;
    std::function<bool(const std::string&)> skipRelativePath;
    std::function<std::vector<int>(const std::string&, const std::string&)> findCallLines;
    std::function<bool(const std::string&)> allowCallsite;
    std::string header;
    std::string footer;
    bool sortViolations = true;
};

void runCallsiteGuard(const CallsiteGuardParams& params) {
    std::string repoRoot = resolveRepoRoot(params.importMetaUrl);
    std::vector<std::string> sourceRoots = resolveSourceRoots(repoRoot, params.sourceRoots);
    std::vector<std::string> files = collectTypeScriptFilesFromRoots(sourceRoots, params.extraTestSuffixes);
    std::vector<std::string> violations;

    for (const auto& filePath : files) {
        fs::path relativePath = fs::relative(filePath, repoRoot);
        std::string relPath = relativePath.generic_string();
        
        if (params.skipRelativePath && params.skipRelativePath(relPath)) {
            continue;
        }
        
        std::ifstream fileStream(filePath);
        std::stringstream buffer;
        buffer << fileStream.rdbuf();
        std::string content = buffer.str();
        
        std::vector<int> lines = params.findCallLines(content, filePath);
        for (int line : lines) {
            std::string callsite = relPath + ":" + std::to_string(line);
            if (params.allowCallsite && params.allowCallsite(callsite)) {
                continue;
            }
            violations.push_back(callsite);
        }
    }

    if (violations.empty()) {
        return;
    }

    std::cerr << params.header << std::endl;
    
    if (params.sortViolations) {
        std::sort(violations.begin(), violations.end());
    }
    
    for (const auto& violation : violations) {
        std::cerr << "- " << violation << std::endl;
    }
    
    if (!params.footer.empty()) {
        std::cerr << params.footer << std::endl;
    }
    
    exit(1);
}

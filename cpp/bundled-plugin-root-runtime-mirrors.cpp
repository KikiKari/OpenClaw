// abstraction-provenance: {"artifact_sha256": "3bd427d12ab676d8d674d49b144d612372eb5418c365c2ea059b5d370981bd49", "source_sha256": "ea352b99923506af9c3ce8c6a36ed51f94a6d895a48b5e6aeebdb0322ed9e62d", "target_language": "cpp"}
// bundled-plugin-root-runtime-mirrors.mjs — portiert nach cpp
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-root-runtime-mirrors.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <filesystem>
#include <fstream>
#include <iostream>
#include <map>
#include <set>
#include <sstream>
#include <string>
#include <vector>
#include <regex>
#include <algorithm>
#include <nlohmann/json.hpp>

using json = nlohmann::json;
namespace fs = std::filesystem;

const std::set<std::string> JS_EXTENSIONS = {".cjs", ".js", ".mjs"};

std::map<std::string, std::string> collectRuntimeDependencySpecs(const json& packageJson = json{}) {
    std::map<std::string, std::string> result;
    
    auto processDeps = [&result](const json& deps) {
        if (deps.is_object()) {
            for (auto& el : deps.items()) {
                if (el.value().is_string() && !el.value().get<std::string>().empty()) {
                    result[el.key()] = el.value();
                }
            }
        }
    };
    
    if (packageJson.contains("dependencies")) {
        processDeps(packageJson["dependencies"]);
    }
    if (packageJson.contains("optionalDependencies")) {
        processDeps(packageJson["optionalDependencies"]);
    }
    
    return result;
}

std::string packageNameFromSpecifier(const std::string& specifier) {
    if (specifier.empty() ||
        specifier[0] == '.' ||
        specifier[0] == '/' ||
        specifier.substr(0, 5) == "node:" ||
        specifier[0] == '#') {
        return "";
    }
    
    size_t firstSlash = specifier.find('/');
    size_t secondSlash = std::string::npos;
    
    if (firstSlash != std::string::npos) {
        secondSlash = specifier.find('/', firstSlash + 1);
    }
    
    if (firstSlash == std::string::npos) {
        return specifier;
    }
    
    std::string first = specifier.substr(0, firstSlash);
    if (first[0] == '@' && secondSlash != std::string::npos) {
        return specifier.substr(0, secondSlash);
    } else if (first[0] == '@') {
        return "";
    } else {
        return first;
    }
}

json readJson(const std::string& filePath) {
    std::ifstream file(filePath);
    json j;
    file >> j;
    return j;
}

std::vector<std::string> collectPackageJsonPaths(const std::string& rootDir) {
    std::vector<std::string> paths;
    
    if (!fs::exists(rootDir)) {
        return paths;
    }
    
    for (const auto& entry : fs::directory_iterator(rootDir)) {
        if (entry.is_directory()) {
            std::string packageJsonPath = entry.path() / "package.json";
            if (fs::exists(packageJsonPath)) {
                paths.push_back(packageJsonPath);
            }
        }
    }
    
    std::sort(paths.begin(), paths.end());
    return paths;
}

struct BundledSpecInfo {
    std::vector<std::string> conflicts;
    std::vector<std::string> pluginIds;
    std::string spec;
};

std::map<std::string, BundledSpecInfo> collectBundledPluginRuntimeDependencySpecs(const std::string& bundledPluginsDir) {
    std::map<std::string, BundledSpecInfo> specs;
    
    for (const auto& packageJsonPath : collectPackageJsonPaths(bundledPluginsDir)) {
        json packageJson = readJson(packageJsonPath);
        std::string pluginId = fs::path(packageJsonPath).parent_path().filename().string();
        
        auto runtimeDeps = collectRuntimeDependencySpecs(packageJson);
        for (const auto& pair : runtimeDeps) {
            const std::string& name = pair.first;
            const std::string& spec = pair.second;
            
            if (specs.find(name) != specs.end()) {
                auto& existing = specs[name];
                if (existing.spec != spec) {
                    existing.conflicts.push_back(pluginId + ":" + spec);
                } else if (std::find(existing.pluginIds.begin(), existing.pluginIds.end(), pluginId) == existing.pluginIds.end()) {
                    existing.pluginIds.push_back(pluginId);
                }
                continue;
            }
            
            BundledSpecInfo info;
            info.spec = spec;
            info.pluginIds.push_back(pluginId);
            specs[name] = info;
        }
    }
    
    return specs;
}

std::vector<std::string> walkJavaScriptFiles(const std::string& rootDir) {
    std::vector<std::string> files;
    
    if (!fs::exists(rootDir)) {
        return files;
    }
    
    std::vector<std::string> queue = {rootDir};
    
    while (!queue.empty()) {
        std::string current = queue.back();
        queue.pop_back();
        
        for (const auto& entry : fs::directory_iterator(current)) {
            std::string fullPath = entry.path().string();
            
            if (entry.is_directory()) {
                // Skip extensions directory
                bool skip = false;
                fs::path p(fullPath);
                for (auto it = p.begin(); it != p.end(); ++it) {
                    if (it->string() == "extensions") {
                        skip = true;
                        break;
                    }
                }
                
                if (!skip) {
                    queue.push_back(fullPath);
                }
                continue;
            }
            
            if (entry.is_regular_file()) {
                std::string ext = entry.path().extension().string();
                if (JS_EXTENSIONS.find(ext) != JS_EXTENSIONS.end()) {
                    files.push_back(fullPath);
                }
            }
        }
    }
    
    std::sort(files.begin(), files.end());
    return files;
}

std::set<std::string> extractModuleSpecifiers(const std::string& source) {
    std::set<std::string> specifiers;
    
    std::regex patterns[] = {
        std::regex(R"(\bfrom\s*["']([^"']+)["'])"),
        std::regex(R"(\bimport\s*["']([^"']+)["'])"),
        std::regex(R"(\bimport\s*\(\s*["']([^"']+)["']\s*\))"),
        std::regex(R"(\brequire\s*\(\s*["']([^"']+)["']\s*\))")
    };
    
    for (const auto& pattern : patterns) {
        std::sregex_iterator iter(source.begin(), source.end(), pattern);
        std::sregex_iterator end;
        
        for (; iter != end; ++iter) {
            std::smatch match = *iter;
            if (match.size() > 1 && !match[1].str().empty()) {
                specifiers.insert(match[1].str());
            }
        }
    }
    
    return specifiers;
}

struct MirrorInfo {
    std::set<std::string> importers;
    std::vector<std::string> pluginIds;
    std::string spec;
};

std::map<std::string, MirrorInfo> collectRootDistBundledRuntimeMirrors(
    const std::string& distDir,
    const std::map<std::string, BundledSpecInfo>& bundledSpecs) {
    
    std::map<std::string, MirrorInfo> mirrors;
    
    for (const auto& filePath : walkJavaScriptFiles(distDir)) {
        std::ifstream file(filePath);
        std::stringstream buffer;
        buffer << file.rdbuf();
        std::string source = buffer.str();
        
        // Convert filePath to relative path with forward slashes
        fs::path relPath = fs::relative(filePath, distDir);
        std::string relativePath = relPath.string();
        std::replace(relativePath.begin(), relativePath.end(), '\\', '/');
        
        for (const auto& specifier : extractModuleSpecifiers(source)) {
            std::string dependencyName = packageNameFromSpecifier(specifier);
            if (dependencyName.empty() || bundledSpecs.find(dependencyName) == bundledSpecs.end()) {
                continue;
            }
            
            const auto& bundledSpec = bundledSpecs.at(dependencyName);
            if (mirrors.find(dependencyName) != mirrors.end()) {
                mirrors[dependencyName].importers.insert(relativePath);
                continue;
            }
            
            MirrorInfo info;
            info.importers.insert(relativePath);
            info.pluginIds = bundledSpec.pluginIds;
            info.spec = bundledSpec.spec;
            mirrors[dependencyName] = info;
        }
    }
    
    return mirrors;
}

std::vector<std::string> collectBundledPluginRootRuntimeMirrorErrors(
    const json& rootPackageJson,
    const std::map<std::string, BundledSpecInfo>& bundledRuntimeDependencySpecs,
    const std::map<std::string, MirrorInfo>& requiredRootMirrors) {
    
    auto rootRuntimeDeps = collectRuntimeDependencySpecs(rootPackageJson);
    std::vector<std::string> errors;
    
    for (const auto& pair : bundledRuntimeDependencySpecs) {
        const std::string& dependencyName = pair.first;
        const BundledSpecInfo& record = pair.second;
        
        for (const auto& conflict : record.conflicts) {
            size_t colonPos = conflict.find(':');
            std::string pluginId, spec;
            if (colonPos != std::string::npos) {
                pluginId = conflict.substr(0, colonPos);
                spec = conflict.substr(colonPos + 1);
            } else {
                pluginId = conflict;
            }
            
            std::string pluginIdsStr;
            for (size_t i = 0; i < record.pluginIds.size(); ++i) {
                if (i > 0) pluginIdsStr += ", ";
                pluginIdsStr += record.pluginIds[i];
            }
            
            errors.push_back("bundled runtime dependency '" + dependencyName + 
                           "' has conflicting plugin specs: " + pluginIdsStr + 
                           " use '" + record.spec + "', " + pluginId + " uses '" + spec + "'.");
        }
    }
    
    for (const auto& pair : requiredRootMirrors) {
        const std::string& dependencyName = pair.first;
        const MirrorInfo& mirror = pair.second;
        
        std::vector<std::string> importersVec(mirror.importers.begin(), mirror.importers.end());
        std::sort(importersVec.begin(), importersVec.end());
        std::string importerLabel;
        for (size_t i = 0; i < importersVec.size(); ++i) {
            if (i > 0) importerLabel += ", ";
            importerLabel += importersVec[i];
        }
        
        std::vector<std::string> pluginIdsSorted = mirror.pluginIds;
        std::sort(pluginIdsSorted.begin(), pluginIdsSorted.end());
        std::string pluginLabel;
        for (size_t i = 0; i < pluginIdsSorted.size(); ++i) {
            if (i > 0) pluginLabel += ", ";
            pluginLabel += pluginIdsSorted[i];
        }
        
        std::string rootSpec;
        if (rootRuntimeDeps.find(dependencyName) != rootRuntimeDeps.end()) {
            rootSpec = rootRuntimeDeps.at(dependencyName);
        }
        
        if (rootSpec.empty()) {
            errors.push_back("root dist imports bundled plugin runtime dependency '" + 
                           dependencyName + "' from " + importerLabel + 
                           "; mirror '" + dependencyName + ": " + mirror.spec + 
                           "' in root package.json (declared by " + pluginLabel + ").");
            continue;
        }
        
        if (rootSpec != mirror.spec) {
            errors.push_back("root dist imports bundled plugin runtime dependency '" + 
                           dependencyName + "' from " + importerLabel + 
                           "; root package.json has '" + rootSpec + 
                           "' but plugin manifest declares '" + mirror.spec + 
                           "' (" + pluginLabel + ").");
        }
    }
    
    return errors;
}

// abstraction-provenance: {"artifact_sha256": "f97dcae601296061db914425db59bc12f08fb7b5f1d4c4e2d6af4345552a02b9", "source_sha256": "0f2bb155d699e769ad3eb99a6500cc6dbb27948a57f7493a3b98c731200853d4", "target_language": "cpp"}
// test-extension.mjs — portiert nach cpp
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-extension.mjs
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <vector>
#include <string>
#include <filesystem>
#include <cstdlib>

// Mock implementations for the imported modules
namespace error_format {
    std::string formatErrorMessage(const std::exception& error) {
        return error.what();
    }
}

namespace extension_test_plan {
    struct TestPlan {
        bool hasTests;
        int testFileCount;
        std::string extensionDir;
        std::string extensionId;
        std::string config;
        std::vector<std::string> roots;
    };

    TestPlan resolveExtensionTestPlan(const std::string& cwd, const std::string& targetArg) {
        // Simplified implementation - in reality this would be more complex
        TestPlan plan;
        plan.hasTests = true;
        plan.testFileCount = 1;
        plan.extensionDir = targetArg.empty() ? "default" : targetArg;
        plan.extensionId = targetArg.empty() ? "default" : targetArg;
        plan.config = "vitest.config.js";
        plan.roots = {"/path/to/tests"};
        return plan;
    }
}

namespace vitest_batch_runner {
    bool isDirectScriptRun() {
        // In C++ we assume we're always running directly
        return true;
    }

    int runVitestBatch(const std::vector<std::string>& args, 
                       const std::string& config,
                       const std::vector<std::string>& targets) {
        // Simplified implementation - in reality this would execute vitest
        std::cout << "[test-extension] Running vitest with config: " << config << std::endl;
        return 0;
    }
}

void printUsage() {
    std::cerr << "Usage: test-extension <extension-name|path> [vitest args...]" << std::endl;
}

void printNoTestsMessage(const extension_test_plan::TestPlan& plan) {
    std::cout << "[test-extension] No tests found for " << plan.extensionDir << ". Skipping." << std::endl;
}

int run(const std::vector<std::string>& argv) {
    std::vector<std::string> rawArgs(argv.begin() + 1, argv.end());
    
    // Check for help flags
    for (const auto& arg : rawArgs) {
        if (arg == "--help" || arg == "-h") {
            printUsage();
            return 0;
        }
    }

    // Filter out -- arguments
    std::vector<std::string> passthroughArgs;
    for (const auto& arg : rawArgs) {
        if (arg != "--") {
            passthroughArgs.push_back(arg);
        }
    }

    std::string targetArg;
    if (!passthroughArgs.empty() && !passthroughArgs[0].starts_with("-")) {
        targetArg = passthroughArgs[0];
        passthroughArgs.erase(passthroughArgs.begin());
    }

    extension_test_plan::TestPlan plan;
    try {
        plan = extension_test_plan::resolveExtensionTestPlan(std::filesystem::current_path().string(), targetArg);
    } catch (const std::exception& error) {
        printUsage();
        std::cerr << error_format::formatErrorMessage(error) << std::endl;
        return 1;
    }

    if (!plan.hasTests) {
        printNoTestsMessage(plan);
        return 0;
    }

    std::cout << "[test-extension] Running " << plan.testFileCount 
              << " test files for " << plan.extensionId << std::endl;
              
    int exitCode = vitest_batch_runner::runVitestBatch(
        passthroughArgs,
        plan.config,
        plan.roots
    );
    
    return exitCode;
}

int main(int argc, char* argv[]) {
    std::vector<std::string> args(argv, argv + argc);
    
    if (vitest_batch_runner::isDirectScriptRun()) {
        return run(args);
    }
    
    return 0;
}

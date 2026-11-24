// abstraction-provenance: {"artifact_sha256": "0ceea3f06367f70a6943263f0dde78c4d2cb2677b6e19a649b9b501bf060300e", "source_sha256": "0f2bb155d699e769ad3eb99a6500cc6dbb27948a57f7493a3b98c731200853d4", "target_language": "c"}
// test-extension.mjs — portiert nach c
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-extension.mjs
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>

// Mock structures to represent the JavaScript objects
typedef struct {
    char* extensionDir;
    char* extensionId;
    int hasTests;
    int testFileCount;
    char* config;
    char** roots;
    int rootsCount;
} TestPlan;

// Function prototypes (would need actual implementations)
void formatErrorMessage(char* error, char* output);
TestPlan* resolveExtensionTestPlan(const char* cwd, const char* targetArg);
int isDirectScriptRun();
int runVitestBatch(char** args, int argsCount, const char* config, char** env, char** targets, int targetsCount);

void printUsage() {
    fprintf(stderr, "Usage: pnpm test:extension <extension-name|path> [vitest args...]\n");
    fprintf(stderr, "       node scripts/test-extension.mjs [extension-name|path] [vitest args...]\n");
}

void printNoTestsMessage(TestPlan* plan) {
    printf("[test-extension] No tests found for %s. Skipping.\n", plan->extensionDir);
}

int main(int argc, char *argv[]) {
    // Convert argv to match JS process.argv structure (skip first arg)
    int rawArgsCount = argc - 1;
    char** rawArgs = argv + 1;
    
    // Check for help flags
    for (int i = 0; i < rawArgsCount; i++) {
        if (strcmp(rawArgs[i], "--help") == 0 || strcmp(rawArgs[i], "-h") == 0) {
            printUsage();
            return 0;
        }
    }
    
    // Filter out "--" arguments
    char** passthroughArgs = malloc(rawArgsCount * sizeof(char*));
    int passthroughArgsCount = 0;
    
    for (int i = 0; i < rawArgsCount; i++) {
        if (strcmp(rawArgs[i], "--") != 0) {
            passthroughArgs[passthroughArgsCount++] = rawArgs[i];
        }
    }
    
    char* targetArg = NULL;
    // Shift first non-flag argument as targetArg
    if (passthroughArgsCount > 0 && passthroughArgs[0][0] != '-') {
        targetArg = passthroughArgs[0];
        // Move remaining args down
        for (int i = 1; i < passthroughArgsCount; i++) {
            passthroughArgs[i-1] = passthroughArgs[i];
        }
        passthroughArgsCount--;
    }
    
    TestPlan* plan = NULL;
    // This would need proper error handling in real implementation
    char cwd[1024];
    getcwd(cwd, sizeof(cwd));
    
    // In a real implementation, this would handle errors appropriately
    plan = resolveExtensionTestPlan(cwd, targetArg);
    
    if (plan == NULL) {
        printUsage();
        // Error handling would go here
        free(passthroughArgs);
        return 1;
    }
    
    if (!plan->hasTests) {
        printNoTestsMessage(plan);
        free(passthroughArgs);
        // Cleanup plan memory
        return 0;
    }
    
    printf("[test-extension] Running %d test files for %s\n", plan->testFileCount, plan->extensionId);
    
    extern char **environ;
    int exitCode = runVitestBatch(passthroughArgs, passthroughArgsCount, plan->config, environ, plan->roots, plan->rootsCount);
    
    free(passthroughArgs);
    // Cleanup plan memory
    
    exit(exitCode);
}

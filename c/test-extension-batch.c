// abstraction-provenance: {"artifact_sha256": "c3012a5c5d09c096036d1ebf011335ae3069e941048e12e703b47f90d81eefde", "source_sha256": "fe4ef822110d5a3d05561b87f0634182183de94f1130dc41ba19fd74bdff1653", "target_language": "c"}
// test-extension-batch.mjs — portiert nach c
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-extension-batch.mjs
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

// Mock implementations for the imported functions
// In a real implementation, these would be properly defined or linked

typedef struct {
    char** extensionIds;
    int count;
    char** passthroughArgs;
    int passthroughCount;
} ParsedArgs;

typedef struct {
    int hasTests;
    int testFileCount;
    int extensionCount;
    // planGroups would contain more detailed information in reality
} BatchPlan;

void printUsage() {
    fprintf(stderr, "Usage: pnpm test:extensions:batch <extension[,extension...]> [vitest args...]\n");
    fprintf(stderr, "       node scripts/test-extension-batch.mjs <extension[,extension...]> [vitest args...]\n");
}

ParsedArgs parseExtensionIds(char* args[], int argc) {
    ParsedArgs result = {0};
    
    // Count how many args don't start with "-"
    int nonFlagArgs = 0;
    for (int i = 0; i < argc && args[i][0] != '-'; i++) {
        nonFlagArgs++;
    }
    
    // Allocate memory for extension IDs
    result.extensionIds = malloc(nonFlagArgs * sizeof(char*));
    result.count = 0;
    
    // Parse comma-separated extension IDs
    for (int i = 0; i < nonFlagArgs; i++) {
        char* token = strtok(args[i], ",");
        while (token != NULL) {
            // Trim whitespace and add if not empty
            while (*token == ' ' || *token == '\t') token++;
            if (*token != '\0') {
                result.extensionIds[result.count] = strdup(token);
                result.count++;
            }
            token = strtok(NULL, ",");
        }
    }
    
    // Remaining args are passthrough
    result.passthroughArgs = &args[nonFlagArgs];
    result.passthroughCount = argc - nonFlagArgs;
    
    return result;
}

BatchPlan resolveExtensionBatchPlan(const char* cwd, char** extensionIds, int count) {
    // This is a mock implementation
    BatchPlan plan = {0};
    plan.hasTests = 1; // Assume we have tests
    plan.testFileCount = count; // Dummy value
    plan.extensionCount = count;
    return plan;
}

int runVitestBatch(char** vitestArgs, int vitestArgCount, const char* config, char** env, char** targets) {
    // This is a mock implementation that just prints what would be run
    printf("[test-extension-batch] Would run vitest with config: %s\n", config);
    return 0;
}

int isDirectScriptRun() {
    // In C, this would typically always be true when run as a script
    return 1;
}

int main(int argc, char* argv[]) {
    if (isDirectScriptRun()) {
        // Skip program name
        argc--;
        argv++;
        
        // Check for help flags
        for (int i = 0; i < argc; i++) {
            if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
                printUsage();
                return 0;
            }
        }
        
        // Filter out "--" arguments
        char** filteredArgs = malloc(argc * sizeof(char*));
        int filteredCount = 0;
        for (int i = 0; i < argc; i++) {
            if (strcmp(argv[i], "--") != 0) {
                filteredArgs[filteredCount++] = argv[i];
            }
        }
        
        ParsedArgs parsed = parseExtensionIds(filteredArgs, filteredCount);
        
        if (parsed.count == 0) {
            printUsage();
            free(filteredArgs);
            return 1;
        }
        
        BatchPlan batchPlan = resolveExtensionBatchPlan(".", parsed.extensionIds, parsed.count);
        
        if (!batchPlan.hasTests) {
            printf("[test-extension-batch] No tests found for the requested extensions. Skipping.\n");
            
            // Cleanup
            for (int i = 0; i < parsed.count; i++) {
                free(parsed.extensionIds[i]);
            }
            free(parsed.extensionIds);
            free(filteredArgs);
            return 0;
        }
        
        printf("[test-extension-batch] Running %d test files across %d extensions\n", 
               batchPlan.testFileCount, batchPlan.extensionCount);
        
        // In a real implementation, you'd iterate through planGroups here
        // For now, we'll just simulate one group
        printf("[test-extension-batch] config1: ");
        for (int i = 0; i < parsed.count; i++) {
            printf("%s", parsed.extensionIds[i]);
            if (i < parsed.count - 1) printf(", ");
        }
        printf(" (%d files)\n", batchPlan.testFileCount);
        
        int exitCode = runVitestBatch(parsed.passthroughArgs, parsed.passthroughCount, 
                                     "config1", environ, NULL);
        
        if (exitCode != 0) {
            // Cleanup before exit
            for (int i = 0; i < parsed.count; i++) {
                free(parsed.extensionIds[i]);
            }
            free(parsed.extensionIds);
            free(filteredArgs);
            return exitCode;
        }
        
        // Cleanup
        for (int i = 0; i < parsed.count; i++) {
            free(parsed.extensionIds[i]);
        }
        free(parsed.extensionIds);
        free(filteredArgs);
    }
    
    return 0;
}

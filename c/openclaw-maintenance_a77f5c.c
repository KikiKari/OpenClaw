// abstraction-provenance: {"artifact_sha256": "2070b23f2422886a6d3d78d660beda4e6baba3e3192937cc124409bdac2130ed", "source_sha256": "a77f5c2629fe7fafac268cfbf2f0b3e77a194322aee8f9c06967eb6c33db043e", "target_language": "c"}
// openclaw-maintenance.sh — portiert nach c
// Quelle: shell, OpenClaw@gateway2:scripts/openclaw-maintenance.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define MAX_CMD_LEN 1024

int main() {
    char *openclaw_bin = getenv("OPENCLAW_BIN");
    if (openclaw_bin == NULL) {
        char *home = getenv("HOME");
        if (home == NULL) {
            fprintf(stderr, "ERROR: Neither OPENCLAW_BIN nor HOME is set\n");
            return 1;
        }
        
        static char default_path[512];
        snprintf(default_path, sizeof(default_path), "%s/.local/bin/openclaw", home);
        openclaw_bin = default_path;
    }

    if (access(openclaw_bin, X_OK) != 0) {
        fprintf(stderr, "ERROR: OpenClaw binary not found: %s\n", openclaw_bin);
        return 1;
    }

    char cmd[MAX_CMD_LEN];

    // Print version
    snprintf(cmd, sizeof(cmd), "%s --version", openclaw_bin);
    printf("Using OpenClaw: ");
    fflush(stdout);
    system(cmd);

    // === 1. Service-/Config-Drift ===
    snprintf(cmd, sizeof(cmd), "%s doctor", openclaw_bin);
    system(cmd);

    // === 2. Plugin-Stage (Registry refresh only; updates are explicit/manual) ===
    snprintf(cmd, sizeof(cmd), "%s plugins registry --refresh", openclaw_bin);
    system(cmd);
    
    char *run_plugin_update = getenv("RUN_PLUGIN_UPDATE");
    if (run_plugin_update && strcmp(run_plugin_update, "1") == 0) {
        snprintf(cmd, sizeof(cmd), "%s plugins update --all", openclaw_bin);
        system(cmd);
    } else {
        printf("Skipping plugin update. Run with RUN_PLUGIN_UPDATE=1 to enable.\n");
    }

    // === 3. Tasks ===
    snprintf(cmd, sizeof(cmd), "%s tasks maintenance --apply", openclaw_bin);
    system(cmd);

    // === 4. Sessions – alle Agents auf einmal ===
    snprintf(cmd, sizeof(cmd), "%s sessions cleanup --enforce --all-agents", openclaw_bin);
    system(cmd);

    // === 5. Memory – status/index decken alle Agents ab ===
    snprintf(cmd, sizeof(cmd), "%s memory status --deep --fix", openclaw_bin);
    system(cmd);
    
    snprintf(cmd, sizeof(cmd), "%s memory index --force", openclaw_bin);
    system(cmd);

    // === 6. Memory promote – MUSS pro Agent ===
    const char *agents[] = {"main", "knecht", "docs", "ops-hub", "cron"};
    for (int i = 0; i < 5; i++) {
        snprintf(cmd, sizeof(cmd), "%s memory promote --apply --agent %s", openclaw_bin, agents[i]);
        system(cmd);
    }

    // === 7. Secrets ===
    snprintf(cmd, sizeof(cmd), "%s secrets reload", openclaw_bin);
    system(cmd);

    return 0;
}

// abstraction-provenance: {"artifact_sha256": "83aab18ff745e37815aa9636ce5618e651600eaf8df0d1f38a5fab793ab52353", "source_sha256": "2a9ca592fdc915cfb281aa77dde9f07ffd3de83ce5abb8d87c77d46668d75dd6", "target_language": "c"}
// openclaw-maintenance.sh — portiert nach c
// Quelle: shell, OpenClaw@gateway1:scripts/openclaw-maintenance.sh
// auch in: workspace@local:scripts/openclaw-maintenance.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Function to execute a command and return its exit status
int run_command(const char* command) {
    printf("Executing: %s\n", command);
    int result = system(command);
    if (result != 0) {
        fprintf(stderr, "Command failed with exit code %d: %s\n", result, command);
    }
    return result;
}

// Function to execute the memory promote command for each agent
int run_memory_promote_for_agents() {
    const char* agents[] = {"main", "knecht", "docs", "ops-hub", "cron"};
    size_t agent_count = sizeof(agents) / sizeof(agents[0]);
    
    for (size_t i = 0; i < agent_count; i++) {
        char command[256];
        snprintf(command, sizeof(command), "openclaw memory promote --apply --agent \"%s\"", agents[i]);
        int result = run_command(command);
        if (result != 0) {
            return result;
        }
    }
    return 0;
}

int main() {
    int result = 0;
    
    // === 1. Service-/Config-Drift ===
    result = run_command("openclaw doctor");
    if (result != 0) return result;
    
    // === 2. Plugin-Stage (aktive Varianten, NICHT plugins doctor) ===
    result = run_command("openclaw plugins registry --refresh");
    if (result != 0) return result;
    
    result = run_command("openclaw plugins update --all");
    if (result != 0) return result;
    
    // === 3. Tasks ===
    result = run_command("openclaw tasks maintenance --apply");
    if (result != 0) return result;
    
    // === 4. Sessions – alle Agents auf einmal ===
    result = run_command("openclaw sessions cleanup --enforce --all-agents");
    if (result != 0) return result;
    
    // === 5. Memory – status/index decken alle Agents ab ===
    result = run_command("openclaw memory status --deep --fix");
    if (result != 0) return result;
    
    result = run_command("openclaw memory index --force");
    if (result != 0) return result;
    
    // === 6. Memory promote – MUSS pro Agent ===
    result = run_memory_promote_for_agents();
    if (result != 0) return result;
    
    // === 7. Secrets ===
    result = run_command("openclaw secrets reload");
    if (result != 0) return result;
    
    return 0;
}

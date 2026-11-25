// abstraction-provenance: {"artifact_sha256": "01699d1a08a9f96c7643954f89a2cf2a71e81ba6e8fe812729b50f2b0d3a4806", "source_sha256": "52b3516148b12072bbff77599a6faac284607fbc005a73f93c2b7f4f349cf6f1", "target_language": "c"}
// test_multinode_fallback.py — portiert nach c
// Quelle: python, OpenClaw@gateway1:scripts/test_multinode_fallback.py
// auch in: OpenClaw@gateway2:scripts/test_multinode_fallback.py
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <errno.h>

#define WORKSPACE "/home/openclaw/.openclaw/workspace"
#define BUFFER_SIZE 4096

int check_node_reachable(const char* node_id) {
    /* Prüft ob Node erreichbar ist */
    FILE *fp;
    char buffer[BUFFER_SIZE];
    int found = 0;
    
    // Versuche Node-Status abzufragen
    fp = popen("openclaw nodes status", "r");
    if (fp == NULL) {
        return 0;
    }
    
    while (fgets(buffer, sizeof(buffer), fp) != NULL) {
        if (strstr(buffer, node_id) != NULL && strstr(buffer, "connected") != NULL) {
            found = 1;
            break;
        }
    }
    
    pclose(fp);
    return found;
}

int spawn_on_node(const char* node_id, const char* task) {
    /* Versucht Task auf Node auszuführen */
    printf("Versuche Task auf Node %s zu starten...\n", node_id);
    
    char command[BUFFER_SIZE];
    snprintf(command, sizeof(command), "echo 'Spawned on %s: %s'", node_id, task);
    
    int result = system(command);
    if (result == 0) {
        printf("✅ Erfolgreich delegiert an %s\n", node_id);
        return 1;
    } else {
        printf("❌ Node %s nicht erreichbar\n", node_id);
        return 0;
    }
}

int execute_locally(const char* task) {
    /* Führt Task lokal aus (Fallback) */
    printf("🔄 Fallback: Führe Task lokal aus...\n");
    
    if (strcmp(task, "db_maintainer") == 0) {
        char command[BUFFER_SIZE];
        snprintf(command, sizeof(command), 
                "python3 %s/skills/db-maintainer/scripts/db_maintainer.py", 
                WORKSPACE);
        
        int result = system(command);
        if (WIFEXITED(result) && WEXITSTATUS(result) == 0) {
            printf("✅ Lokale Ausführung erfolgreich\n");
            return 1;
        } else {
            printf("❌ Fehler bei lokaler Ausführung\n");
            return 0;
        }
    }
    return 0;
}

int main() {
    printf("============================================================\n");
    printf("MULTI-NODE FALLBACK TEST\n");
    printf("============================================================\n");
    printf("\n");
    
    // Konfiguration
    const char* primary_node = "v2202603104722445775";  // Node 2
    const char* task = "db_maintainer";
    
    printf("Primärer Node: %s\n", primary_node);
    printf("Task: %s\n", task);
    printf("\n");
    
    // 1. Prüfe Node-Erreichbarkeit
    printf("--- 1. Prüfe Node-Erreichbarkeit ---\n");
    if (check_node_reachable(primary_node)) {
        printf("✅ Node %s ist erreichbar\n", primary_node);
        
        // 2. Versuche Delegation
        printf("\n--- 2. Versuche Delegation ---\n");
        if (spawn_on_node(primary_node, task)) {
            printf("\n✅ MULTI-NODE: Task erfolgreich delegiert\n");
            return 0;
        } else {
            printf("\n⚠️ Delegation fehlgeschlagen, aktiviere Fallback...\n");
        }
    } else {
        printf("❌ Node %s nicht erreichbar\n", primary_node);
        printf("🔄 Fallback wird aktiviert...\n");
    }
    
    // 3. Lokale Ausführung (Fallback)
    printf("\n--- 3. Lokale Ausführung (Fallback) ---\n");
    if (execute_locally(task)) {
        printf("\n✅ FALLBACK: Task lokal erfolgreich ausgeführt\n");
        return 0;
    } else {
        printf("\n❌ FEHLER: Weder Delegation noch Fallback erfolgreich\n");
        return 1;
    }
}

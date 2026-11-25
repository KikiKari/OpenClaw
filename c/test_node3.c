// abstraction-provenance: {"artifact_sha256": "5677e0119a9ab1f77c6b7e57d9b9b0307de4901d5f1f56e27ab291ecd110306f", "source_sha256": "151279ec3dae16c8f81904c36418b5f9c6040036a0a98adef5ec52bfea0b57ab", "target_language": "c"}
// test_node3.sh — portiert nach c
// Quelle: shell, OpenClaw@gateway1:scripts/test_node3.sh
// auch in: OpenClaw@gateway2:scripts/test_node3.sh
// auch in: workspace@local:scripts/test_node3.sh
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <signal.h>
#include <errno.h>

// Signal-Handler für Timeout
void timeout_handler(int sig) {
    // Nichts tun, nur zum Unterbrechen von sleep()
}

int main() {
    // Test Node 3 Connection
    // Setze Umgebungsvariable
    if (setenv("OPENCLAW_ALLOW_INSECURE_PRIVATE_WS", "1", 1) != 0) {
        perror("Fehler beim Setzen der Umgebungsvariable");
        return 1;
    }
    
    printf("Starting node connection test...\n");
    
    // Erstelle einen neuen Prozess
    pid_t pid = fork();
    
    if (pid == -1) {
        perror("fork fehlgeschlagen");
        return 1;
    }
    
    if (pid == 0) {
        // Kindprozess: führe den Befehl aus
        execl("/usr/local/bin/openclaw", "openclaw", "node", "run", 
              "--host", "152.53.145.65", "--port", "18789", (char *)NULL);
        // Wenn execl fehlschlägt
        perror("execl fehlgeschlagen");
        exit(127);
    } else {
        // Elternprozess: setze Timeout
        // Setze Signal-Handler für Alarm
        signal(SIGALRM, timeout_handler);
        alarm(15);
        
        int status;
        pid_t result = waitpid(pid, &status, 0);
        
        // Deaktiviere den Alarm
        alarm(0);
        
        if (result == -1) {
            if (errno == EINTR) {
                // Timeout erreicht, beende den Kindprozess
                kill(pid, SIGTERM);
                printf("Timeout erreicht\n");
                return 1;
            } else {
                perror("waitpid fehlgeschlagen");
                return 1;
            }
        }
        
        // Bestimme Exit-Code
        int exit_code = 0;
        if (WIFEXITED(status)) {
            exit_code = WEXITSTATUS(status);
        } else if (WIFSIGNALED(status)) {
            exit_code = 128 + WTERMSIG(status);
        }
        
        printf("Exit code: %d\n", exit_code);
        return exit_code;
    }
}

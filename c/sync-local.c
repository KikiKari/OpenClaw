// abstraction-provenance: {"artifact_sha256": "81830a8785b00ba3c94168a9e027fe1164df96d40069f431904f47c394355a69", "source_sha256": "b97ad7dc26be724af240b4c0c98ec196e729e0702664b99c65e0e3c435a1b5af", "target_language": "c"}
// sync-local.ps1 — portiert nach c
// Quelle: powershell, Onboarding@main:scripts/sync-local.ps1
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <time.h>
#include <stdbool.h>

#define MAX_BUFFER 1024
#define MAX_CHANGED_FILES 100

// Globale Konfiguration
char *branch = "claude/onboarding-persistent-sandbox-vjfmcx";
int interval_seconds = 20;
char *compose_file = "docker-compose.dev.yml";
bool once_flag = false;

// Hilfsfunktionen für String-Manipulation
char* trim_whitespace(char *str) {
    char *end;
    while(*str == ' ' || *str == '\t') str++;
    if(*str == 0) return str;
    end = str + strlen(str) - 1;
    while(end > str && (*end == ' ' || *end == '\t' || *end == '\n')) end--;
    *(end+1) = 0;
    return str;
}

void log_msg(const char *msg) {
    time_t now;
    time(&now);
    struct tm *tm_info = localtime(&now);
    char buffer[64];
    strftime(buffer, sizeof(buffer), "%H:%M:%S", tm_info);
    printf("[%s] %s\n", buffer, msg);
}

int execute_command(const char *cmd, char *output, size_t output_size) {
    FILE *fp;
    int status = 0;
    
    fp = popen(cmd, "r");
    if (fp == NULL) {
        perror("Fehler beim Ausführen des Befehls");
        return -1;
    }
    
    if (output != NULL) {
        if (fgets(output, output_size, fp) != NULL) {
            trim_whitespace(output);
        } else {
            output[0] = '\0';
        }
    }
    
    status = pclose(fp);
    return WEXITSTATUS(status);
}

void invoke_compose(char **args, int arg_count) {
    char cmd[MAX_BUFFER] = "docker compose -f ";
    strcat(cmd, compose_file);
    
    for (int i = 0; i < arg_count; i++) {
        strcat(cmd, " ");
        strcat(cmd, args[i]);
    }
    
    int result = system(cmd);
    if (result != 0) {
        char warn_msg[MAX_BUFFER];
        snprintf(warn_msg, sizeof(warn_msg), 
                 "WARNUNG: docker compose Befehl fehlgeschlagen (Exit %d)", result);
        log_msg(warn_msg);
    }
}

bool file_in_list(const char *filename, const char **list, int list_size) {
    for (int i = 0; i < list_size; i++) {
        if (strcmp(filename, list[i]) == 0) {
            return true;
        }
    }
    return false;
}

bool matches_backend_pattern(const char *filename) {
    if (strncmp(filename, "backend/", 8) == 0) {
        if (strcmp(filename + 8, "Dockerfile") == 0) {
            return true;
        }
        if (strncmp(filename + 8, "requirements", 12) == 0 &&
            strstr(filename + 8, ".txt") != NULL) {
            return true;
        }
    }
    return false;
}

int main(int argc, char *argv[]) {
    // Parameterverarbeitung
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-Branch") == 0 && i + 1 < argc) {
            branch = argv[++i];
        } else if (strcmp(argv[i], "-IntervalSeconds") == 0 && i + 1 < argc) {
            interval_seconds = atoi(argv[++i]);
        } else if (strcmp(argv[i], "-ComposeFile") == 0 && i + 1 < argc) {
            compose_file = argv[++i];
        } else if (strcmp(argv[i], "-Once") == 0) {
            once_flag = true;
        }
    }
    
    // In das Repo-Verzeichnis wechseln (gehen wir davon aus, dass das Skript im scripts-Ordner liegt)
    chdir("..");
    
    // Aktuellen Branch ermitteln
    char current_branch[MAX_BUFFER];
    if (execute_command("git rev-parse --abbrev-ref HEAD", current_branch, sizeof(current_branch)) != 0) {
        log_msg("Fehler beim Ermitteln des aktuellen Branches");
        return 1;
    }
    
    // Wenn nicht der gewünschte Branch ausgecheckt ist, wechseln
    if (strcmp(trim_whitespace(current_branch), branch) != 0) {
        char switch_msg[MAX_BUFFER];
        snprintf(switch_msg, sizeof(switch_msg), 
                 "Wechsle von '%s' auf '%s' …", trim_whitespace(current_branch), branch);
        log_msg(switch_msg);
        
        char fetch_cmd[MAX_BUFFER];
        snprintf(fetch_cmd, sizeof(fetch_cmd), "git fetch origin %s", branch);
        system(fetch_cmd);
        
        char switch_cmd[MAX_BUFFER];
        snprintf(switch_cmd, sizeof(switch_cmd), "git switch %s 2>/dev/null", branch);
        int result = system(switch_cmd);
        
        if (result != 0) {
            char create_cmd[MAX_BUFFER];
            snprintf(create_cmd, sizeof(create_cmd), "git switch -c %s --track \"origin/%s\"", branch, branch);
            if (system(create_cmd) != 0) {
                log_msg("Branch konnte nicht ausgecheckt werden.");
                return 1;
            }
        }
    }
    
    // Sync-Loop
    char sync_msg[MAX_BUFFER];
    snprintf(sync_msg, sizeof(sync_msg), 
             "Sync aktiv: origin/%s -> . (Intervall %ds, Compose: %s)", 
             branch, interval_seconds, compose_file);
    log_msg(sync_msg);
    
    while (1) {
        // Fetch vom Remote
        if (system("git fetch origin") != 0) {
            char fail_msg[MAX_BUFFER];
            snprintf(fail_msg, sizeof(fail_msg), 
                     "Fetch fehlgeschlagen (Netzwerk?) — nächster Versuch in %ds", interval_seconds);
            log_msg(fail_msg);
        } else {
            // Lokalen und Remote-Commit ermitteln
            char local_commit[MAX_BUFFER], remote_commit[MAX_BUFFER];
            if (execute_command("git rev-parse HEAD", local_commit, sizeof(local_commit)) != 0 ||
                execute_command("git rev-parse FETCH_HEAD", remote_commit, sizeof(remote_commit)) != 0) {
                log_msg("Fehler beim Ermitteln der Commit-Hashes");
                goto next_iteration;
            }
            
            trim_whitespace(local_commit);
            trim_whitespace(remote_commit);
            
            // Prüfen ob Änderungen vorliegen
            if (strcmp(local_commit, remote_commit) != 0) {
                // Prüfen ob lokaler Commit Vorfahre des Remotes ist
                char ancestor_cmd[MAX_BUFFER];
                snprintf(ancestor_cmd, sizeof(ancestor_cmd), 
                         "git merge-base --is-ancestor %s %s", local_commit, remote_commit);
                
                if (system(ancestor_cmd) != 0) {
                    log_msg("ACHTUNG: Lokaler Stand ist von origin abgewichen. Kein automatischer Merge — bitte manuell auflösen.");
                } else {
                    // Geänderte Dateien ermitteln
                    char diff_cmd[MAX_BUFFER];
                    snprintf(diff_cmd, sizeof(diff_cmd), 
                             "git diff --name-only %s..%s", local_commit, remote_commit);
                    
                    FILE *fp = popen(diff_cmd, "r");
                    if (fp == NULL) {
                        log_msg("Fehler beim Ausführen von git diff");
                        goto next_iteration;
                    }
                    
                    char changed_files[MAX_CHANGED_FILES][MAX_BUFFER];
                    int changed_count = 0;
                    char line[MAX_BUFFER];
                    
                    while (fgets(line, sizeof(line), fp) != NULL && changed_count < MAX_CHANGED_FILES) {
                        trim_whitespace(line);
                        strcpy(changed_files[changed_count++], line);
                    }
                    pclose(fp);
                    
                    // Merge durchführen
                    char merge_cmd[MAX_BUFFER];
                    snprintf(merge_cmd, sizeof(merge_cmd), 
                             "git merge --ff-only %s --quiet", remote_commit);
                    system(merge_cmd);
                    
                    char update_msg[MAX_BUFFER];
                    char local_short[8], remote_short[8];
                    strncpy(local_short, local_commit, 7);
                    local_short[7] = '\0';
                    strncpy(remote_short, remote_commit, 7);
                    remote_short[7] = '\0';
                    
                    snprintf(update_msg, sizeof(update_msg), 
                             "Aktualisiert %s -> %s (%d Datei(en))", 
                             local_short, remote_short, changed_count);
                    log_msg(update_msg);
                    
                    // Änderungen analysieren
                    bool frontend_deps_changed = false;
                    bool backend_image_changed = false;
                    bool compose_changed = false;
                    
                    const char *frontend_files[] = {"package.json", "package-lock.json"};
                    
                    for (int i = 0; i < changed_count; i++) {
                        if (file_in_list(changed_files[i], frontend_files, 2)) {
                            frontend_deps_changed = true;
                        } else if (matches_backend_pattern(changed_files[i])) {
                            backend_image_changed = true;
                        } else if (strcmp(changed_files[i], compose_file) == 0) {
                            compose_changed = true;
                        }
                    }
                    
                    // Aktionen basierend auf Änderungen ausführen
                    if (compose_changed) {
                        log_msg("Compose-Datei geändert — erzeuge Dev-Stack neu …");
                        char *args[] = {"up", "-d"};
                        invoke_compose(args, 2);
                    }
                    
                    if (backend_image_changed) {
                        log_msg("Backend-Dependencies/Dockerfile geändert — baue nur das Backend neu …");
                        char *args[] = {"up", "-d", "--build", "backend"};
                        invoke_compose(args, 4);
                    }
                    
                    if (frontend_deps_changed) {
                        log_msg("Frontend-Dependencies geändert — starte Frontend neu (npm install läuft im Container) …");
                        char *args[] = {"restart", "frontend"};
                        invoke_compose(args, 2);
                    }
                    
                    if (!(compose_changed || backend_image_changed || frontend_deps_changed)) {
                        log_msg("Nur Quellcode/Assets — Hot-Reload übernimmt, kein Build nötig.");
                    }
                }
            }
        }
        
next_iteration:
        if (once_flag) break;
        sleep(interval_seconds);
    }
    
    return 0;
}

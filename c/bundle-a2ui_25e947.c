// abstraction-provenance: {"artifact_sha256": "6b3087266700f580321e6e7c1f8c34d3f3f1a4a5fe557689c4883c9f5b511eb5", "source_sha256": "25e94789e3af346018b091c7c4d6d65632394c19fcf9eaaeac876efbe534149a", "target_language": "c"}
// bundle-a2ui.sh — portiert nach c
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/bundle-a2ui.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <libgen.h>
#include <limits.h>

int main(int argc, char *argv[]) {
    // Bestimme das Verzeichnis des Skripts
    char script_path[PATH_MAX];
    ssize_t len = readlink("/proc/self/exe", script_path, sizeof(script_path) - 1);
    if (len != -1) {
        script_path[len] = '\0';
    } else {
        // Fallback: verwenden argv[0] falls readlink fehlschlägt
        if (realpath(argv[0], script_path) == NULL) {
            fprintf(stderr, "Fehler: Konnte Pfad nicht auflösen\n");
            return 1;
        }
    }

    // Ermittle das Verzeichnis des Skripts
    char *dir = dirname(script_path);
    
    // Gehe zum übergeordneten Verzeichnis
    if (chdir(dir) != 0 || chdir("..") != 0) {
        perror("chdir");
        return 1;
    }
    
    // Ermittle das aktuelle Arbeitsverzeichnis
    char cwd[PATH_MAX];
    if (getcwd(cwd, sizeof(cwd)) == NULL) {
        perror("getcwd");
        return 1;
    }
    
    // Baue den Pfad zur Node.js-Datei
    char node_script[PATH_MAX];
    int result = snprintf(node_script, sizeof(node_script), "%s/scripts/bundle-a2ui.mjs", cwd);
    if (result < 0 || result >= (int)sizeof(node_script)) {
        fprintf(stderr, "Fehler: Pfad zu lang\n");
        return 1;
    }
    
    // Baue das Argumenten-Array für execvp
    // argv[0] = "node", argv[1] = node_script, argv[2..] = original arguments
    char **new_argv = malloc((argc + 2) * sizeof(char*));
    if (!new_argv) {
        fprintf(stderr, "Speicherfehler\n");
        return 1;
    }
    
    new_argv[0] = "node";
    new_argv[1] = node_script;
    
    // Kopiere die restlichen Argumente
    for (int i = 1; i < argc; i++) {
        new_argv[i + 1] = argv[i];
    }
    new_argv[argc + 1] = NULL;
    
    // Führe node mit dem Skript aus
    execvp("node", new_argv);
    
    // Wenn execvp zurückkehrt, ist ein Fehler aufgetreten
    perror("execvp");
    free(new_argv);
    return 1;
}

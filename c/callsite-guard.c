// abstraction-provenance: {"artifact_sha256": "d3e99772ec420cc6c1dd65bcab9353b996a51a439508211123678b0e8fa62e0e", "source_sha256": "b6d33ba222e838d8ea4e8f134b161c60019978c5abaa86299906dfe095635a2b", "target_language": "c"}
// callsite-guard.mjs — portiert nach c
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/callsite-guard.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <unistd.h>
#include <sys/stat.h>
#include <errno.h>

// Plattformabhängige Pfade
#ifdef _WIN32
#define PATH_SEPARATOR "\\"
#define PATH_SEPARATOR_CHAR '\\'
#else
#define PATH_SEPARATOR "/"
#define PATH_SEPARATOR_CHAR '/'
#endif

// Maximale Pfadlänge
#define MAX_PATH_LENGTH 4096

// Struktur für Parameter
typedef struct {
    const char* repo_root;
    char** source_roots;
    int source_roots_count;
    char** extra_test_suffixes;
    int extra_test_suffixes_count;
    int (*skip_relative_path)(const char*);
    char** (*find_call_lines)(const char*, const char*);
    int find_call_lines_count;
    int (*allow_callsite)(const char*);
    const char* header;
    const char* footer;
    int sort_violations;
} CallsiteGuardParams;

// Hilfsfunktion zur Stringersetzung (ähnlich JavaScript replaceAll)
char* str_replace_all(const char* orig, const char* rep, const char* with) {
    char *result; // Ergebnisstring
    const char *ins;    // Einfügepunkt
    char *tmp;    // Temporärer Arbeitszeiger
    int len_rep = strlen(rep);
    int len_with = strlen(with);
    int count = 0; // Anzahl der Vorkommen
    int diff = len_with - len_rep;

    // Zähle Vorkommen von rep in orig
    ins = orig;
    for (count = 0; (tmp = strstr(ins, rep)); ++count) {
        ins = tmp + len_rep;
    }

    // Berechne Länge des neuen Strings
    tmp = result = malloc(strlen(orig) + (diff * count) + 1);

    if (!result) return NULL;

    // Kopiere und ersetze
    while (count--) {
        ins = strstr(orig, rep);
        len_ins = ins - orig;
        strncpy(tmp, orig, len_ins);
        tmp += len_ins;
        strcpy(tmp, with);
        tmp += len_with;
        orig = ins + len_rep;
    }
    strcpy(tmp, orig);
    return result;
}

// Hilfsfunktion zum Konvertieren von Pfadtrennzeichen
char* convert_path_separators(const char* path) {
    char* converted = strdup(path);
    if (!converted) return NULL;
    
    for (int i = 0; converted[i]; i++) {
        if (converted[i] == PATH_SEPARATOR_CHAR) {
            converted[i] = '/';
        }
    }
    return converted;
}

// Hilfsfunktion zum Überprüfen, ob ein Pfad eine bestimmte Endung hat
int has_suffix(const char* path, const char* suffix) {
    size_t path_len = strlen(path);
    size_t suffix_len = strlen(suffix);
    if (suffix_len > path_len) return 0;
    return strcmp(path + path_len - suffix_len, suffix) == 0;
}

// Hilfsfunktion zum Überprüfen, ob ein Pfad eine Testendung hat
int is_test_file(const char* path) {
    return has_suffix(path, ".test.ts") || 
           has_suffix(path, ".spec.ts") || 
           has_suffix(path, ".test.tsx") || 
           has_suffix(path, ".spec.tsx");
}

// Rekursive Funktion zum Sammeln von TypeScript-Dateien
void collect_typescript_files(const char* dir_path, char*** files, int* file_count, char*** extra_suffixes, int suffix_count) {
    DIR* dir = opendir(dir_path);
    if (!dir) {
        fprintf(stderr, "Fehler beim Öffnen des Verzeichnisses: %s\n", dir_path);
        return;
    }

    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }

        char full_path[MAX_PATH_LENGTH];
        snprintf(full_path, sizeof(full_path), "%s%s%s", dir_path, PATH_SEPARATOR, entry->d_name);

        struct stat statbuf;
        if (stat(full_path, &statbuf) == -1) {
            perror("stat");
            continue;
        }

        if (S_ISDIR(statbuf.st_mode)) {
            collect_typescript_files(full_path, files, file_count, extra_suffixes, suffix_count);
        } else if (S_ISREG(statbuf.st_mode)) {
            // Prüfe auf .ts oder .tsx Endung
            if (has_suffix(full_path, ".ts") || has_suffix(full_path, ".tsx")) {
                // Prüfe zusätzliche Suffixe
                int is_extra = 0;
                for (int i = 0; i < suffix_count; i++) {
                    if (has_suffix(full_path, extra_suffixes[i])) {
                        is_extra = 1;
                        break;
                    }
                }
                
                // Füge hinzu, wenn es kein Testfile ist ODER ein extra Suffix hat
                if (!is_test_file(full_path) || is_extra) {
                    *files = realloc(*files, (*file_count + 1) * sizeof(char*));
                    if (*files) {
                        (*files)[*file_count] = strdup(full_path);
                        (*file_count)++;
                    }
                }
            }
        }
    }
    closedir(dir);
}

// Vergleichsfunktion für qsort
int compare_strings(const void *a, const void *b) {
    return strcmp(*(const char **)a, *(const char **)b);
}

// Hauptfunktion
int run_callsite_guard(CallsiteGuardParams* params) {
    // Sammle alle TypeScript-Dateien
    char** files = NULL;
    int file_count = 0;
    
    for (int i = 0; i < params->source_roots_count; i++) {
        collect_typescript_files(params->source_roots[i], &files, &file_count, 
                                params->extra_test_suffixes, params->extra_test_suffixes_count);
    }

    char** violations = NULL;
    int violation_count = 0;

    for (int i = 0; i < file_count; i++) {
        char* file_path = files[i];
        
        // Berechne relativen Pfad
        char* rel_path_raw = file_path;
        if (strstr(file_path, params->repo_root) == file_path) {
            rel_path_raw = file_path + strlen(params->repo_root);
            // Entferne führende Schrägstriche
            while (*rel_path_raw == PATH_SEPARATOR_CHAR) rel_path_raw++;
        }
        
        char* rel_path = convert_path_separators(rel_path_raw);
        
        // Prüfe skip_relative_path
        if (params->skip_relative_path && params->skip_relative_path(rel_path)) {
            free(rel_path);
            continue;
        }
        
        // Lese Dateiinhalt
        FILE* f = fopen(file_path, "rb");
        if (!f) {
            fprintf(stderr, "Fehler beim Öffnen der Datei: %s\n", file_path);
            free(rel_path);
            continue;
        }
        
        // Bestimme Dateigröße
        fseek(f, 0, SEEK_END);
        long fsize = ftell(f);
        fseek(f, 0, SEEK_SET);
        
        char* content = malloc(fsize + 1);
        if (!content) {
            fclose(f);
            free(rel_path);
            continue;
        }
        
        fread(content, 1, fsize, f);
        content[fsize] = '\0';
        fclose(f);
        
        // Finde Call-Linien
        char** lines = params->find_call_lines(content, file_path);
        if (lines) {
            for (int j = 0; lines[j] != NULL; j++) {
                // Erstelle Callsite
                int callsite_len = strlen(rel_path) + 1 + strlen(lines[j]) + 1;
                char* callsite = malloc(callsite_len);
                if (callsite) {
                    snprintf(callsite, callsite_len, "%s:%s", rel_path, lines[j]);
                    
                    // Prüfe allowCallsite
                    if (params->allow_callsite && params->allow_callsite(callsite)) {
                        free(callsite);
                        continue;
                    }
                    
                    // Füge zu Verletzungen hinzu
                    violations = realloc(violations, (violation_count + 1) * sizeof(char*));
                    if (violations) {
                        violations[violation_count] = callsite;
                        violation_count++;
                    } else {
                        free(callsite);
                    }
                }
            }
            
            // Freigabe der Zeilen (angenommen sie wurden dynamisch allokiert)
            for (int j = 0; lines[j] != NULL; j++) {
                free(lines[j]);
            }
            free(lines);
        }
        
        free(content);
        free(rel_path);
    }
    
    // Gebe alle Dateipfade frei
    for (int i = 0; i < file_count; i++) {
        free(files[i]);
    }
    free(files);

    // Prüfe auf Verletzungen
    if (violation_count == 0) {
        // Freigabe der Verletzungen
        for (int i = 0; i < violation_count; i++) {
            free(violations[i]);
        }
        free(violations);
        return 0; // Erfolg
    }

    // Ausgabe der Header
    if (params->header) {
        fprintf(stderr, "%s\n", params->header);
    }
    
    // Sortiere falls nötig
    if (params->sort_violations != 0) { // Standardmäßig sortieren
        qsort(violations, violation_count, sizeof(char*), compare_strings);
    }
    
    // Ausgabe der Verletzungen
    for (int i = 0; i < violation_count; i++) {
        fprintf(stderr, "- %s\n", violations[i]);
    }
    
    // Ausgabe des Footers
    if (params->footer) {
        fprintf(stderr, "%s\n", params->footer);
    }
    
    // Freigabe der Verletzungen
    for (int i = 0; i < violation_count; i++) {
        free(violations[i]);
    }
    free(violations);
    
    exit(1); // Beende mit Fehlercode
}

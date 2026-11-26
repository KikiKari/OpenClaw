// abstraction-provenance: {"artifact_sha256": "a8f31bbed11545ac7ca497ed0900b1dc74dc4c1a4b3bf62a568057ec8bbe90c7", "source_sha256": "646ce6bf1521c1200f2204aa19a05521f8f53d734ec8c000b61f4290f2a05074", "target_language": "c"}
// changelog.sh — portiert nach c
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/changelog.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <regex.h>
#include <libgen.h>

#define MAX_LINE_LENGTH 4096
#define MAX_LINES 10000

typedef struct {
    char *line;
    int index;
    char *subsection;
} MovedEntry;

int file_exists(const char *filename) {
    struct stat buffer;
    return (stat(filename, &buffer) == 0);
}

char* read_file(const char *filename) {
    FILE *file = fopen(filename, "rb");
    if (!file) {
        return NULL;
    }
    
    fseek(file, 0, SEEK_END);
    long length = ftell(file);
    fseek(file, 0, SEEK_SET);
    
    char *content = malloc(length + 1);
    fread(content, 1, length, file);
    content[length] = '\0';
    
    fclose(file);
    return content;
}

void write_file(const char *filename, const char *content) {
    FILE *file = fopen(filename, "wb");
    if (file) {
        fwrite(content, 1, strlen(content), file);
        fclose(file);
    }
}

char** split_lines(char *content, int *count) {
    char **lines = malloc(MAX_LINES * sizeof(char*));
    *count = 0;
    
    char *line = strtok(content, "\n");
    while (line != NULL && *count < MAX_LINES - 1) {
        lines[*count] = strdup(line);
        (*count)++;
        line = strtok(NULL, "\n");
    }
    lines[*count] = NULL;
    return lines;
}

void free_lines(char **lines) {
    for (int i = 0; lines[i] != NULL; i++) {
        free(lines[i]);
    }
    free(lines);
}

int find_active_section_index(char **lines) {
    for (int i = 0; lines[i] != NULL; i++) {
        if (strcmp(lines[i], "## Unreleased") == 0) {
            return i;
        }
    }
    return -1;
}

int find_section_end(char **lines, int start) {
    for (int i = start + 1; lines[i] != NULL; i++) {
        if (strncmp(lines[i], "## ", 3) == 0) {
            return i;
        }
    }
    return -1;
}

int ensure_active_section(char ***lines_ptr, int *line_count) {
    char **lines = *lines_ptr;
    int active_index = find_active_section_index(lines);
    if (active_index != -1) {
        return active_index;
    }
    
    int insert_at = 0;
    for (int i = 1; lines[i] != NULL; i++) {
        if (strncmp(lines[i], "## ", 3) == 0) {
            insert_at = i;
            break;
        }
    }
    
    if (insert_at == 0) {
        for (int i = 0; lines[i] != NULL; i++) {
            insert_at = i + 1;
        }
    }
    
    char *new_lines[MAX_LINES];
    int new_count = 0;
    
    for (int i = 0; i < insert_at; i++) {
        new_lines[new_count++] = strdup(lines[i]);
    }
    
    if (insert_at > 0 && strcmp(lines[insert_at - 1], "") != 0) {
        new_lines[new_count++] = strdup("");
    }
    
    new_lines[new_count++] = strdup("## Unreleased");
    new_lines[new_count++] = strdup("");
    new_lines[new_count++] = strdup("### Changes");
    new_lines[new_count++] = strdup("");
    
    for (int i = insert_at; lines[i] != NULL; i++) {
        new_lines[new_count++] = strdup(lines[i]);
    }
    
    new_lines[new_count] = NULL;
    
    free_lines(lines);
    *lines_ptr = malloc((new_count + 1) * sizeof(char*));
    for (int i = 0; i < new_count; i++) {
        (*lines_ptr)[i] = strdup(new_lines[i]);
    }
    (*lines_ptr)[new_count] = NULL;
    *line_count = new_count;
    
    for (int i = 0; i < new_count; i++) {
        free(new_lines[i]);
    }
    
    return find_active_section_index(*lines_ptr);
}

void context_for(char **lines, int index, char **major, char **minor) {
    *major = NULL;
    *minor = NULL;
    
    for (int i = index; i >= 0; i--) {
        if (!*minor && strncmp(lines[i], "### ", 4) == 0) {
            *minor = strdup(lines[i]);
        }
        if (strncmp(lines[i], "## ", 3) == 0) {
            *major = strdup(lines[i]);
            break;
        }
    }
}

int ensure_subsection(char ***lines_ptr, int *line_count, const char *subsection) {
    char **lines = *lines_ptr;
    int active_index = ensure_active_section(&lines, line_count);
    int active_end = find_section_end(lines, active_index);
    
    if (active_end == -1) {
        for (int i = 0; lines[i] != NULL; i++) {
            active_end = i + 1;
        }
    }
    
    const char *desired = (subsection && strncmp(subsection, "### ", 4) == 0) ? subsection : "### Changes";
    
    for (int i = active_index + 1; i < active_end; i++) {
        if (strcmp(lines[i], desired) == 0) {
            return i;
        }
    }
    
    int insert_at = active_end;
    while (insert_at > active_index + 1 && strcmp(lines[insert_at - 1], "") == 0) {
        insert_at--;
    }
    
    char *new_lines[MAX_LINES];
    int new_count = 0;
    
    for (int i = 0; i < insert_at; i++) {
        new_lines[new_count++] = strdup(lines[i]);
    }
    
    new_lines[new_count++] = strdup("");
    new_lines[new_count++] = strdup(desired);
    new_lines[new_count++] = strdup("");
    
    for (int i = insert_at; lines[i] != NULL; i++) {
        new_lines[new_count++] = strdup(lines[i]);
    }
    
    new_lines[new_count] = NULL;
    
    free_lines(lines);
    *lines_ptr = malloc((new_count + 1) * sizeof(char*));
    for (int i = 0; i < new_count; i++) {
        (*lines_ptr)[i] = strdup(new_lines[i]);
    }
    (*lines_ptr)[new_count] = NULL;
    *line_count = new_count;
    
    for (int i = 0; i < new_count; i++) {
        free(new_lines[i]);
    }
    
    return insert_at + 1;
}

int section_tail_insert_index(char **lines, int subsection_index) {
    int next_heading = 0;
    for (int i = 0; lines[i] != NULL; i++) {
        next_heading = i + 1;
    }
    
    for (int i = subsection_index + 1; lines[i] != NULL; i++) {
        if (strncmp(lines[i], "### ", 4) == 0 || strncmp(lines[i], "## ", 3) == 0) {
            next_heading = i;
            break;
        }
    }
    
    int insert_at = next_heading;
    while (insert_at > subsection_index + 1 && strcmp(lines[insert_at - 1], "") == 0) {
        insert_at--;
    }
    return insert_at;
}

int regex_match(const char *string, const char *pattern) {
    regex_t regex;
    int ret = regcomp(&regex, pattern, REG_EXTENDED | REG_ICASE);
    if (ret != 0) {
        regfree(&regex);
        return 0;
    }
    
    ret = regexec(&regex, string, 0, NULL, 0);
    regfree(&regex);
    return (ret == 0) ? 1 : 0;
}

void normalize_pr_changelog_entries(const char *pr) {
    const char *changelog_path = "CHANGELOG.md";
    
    if (!file_exists(changelog_path)) {
        return;
    }
    
    char *original = read_file(changelog_path);
    if (!original) {
        return;
    }
    
    int line_count;
    char **lines = split_lines(original, &line_count);
    
    char pr_pattern[256];
    snprintf(pr_pattern, sizeof(pr_pattern), "(#%s|openclaw#%s)", pr, pr);
    
    ensure_active_section(&lines, &line_count);
    
    MovedEntry moved[MAX_LINES];
    int moved_count = 0;
    
    for (int i = 0; lines[i] != NULL; i++) {
        if (!regex_match(lines[i], pr_pattern)) {
            continue;
        }
        
        char *major = NULL;
        char *minor = NULL;
        context_for(lines, i, &major, &minor);
        
        if (major && strcmp(major, "## Unreleased") == 0) {
            free(major);
            if (minor) free(minor);
            continue;
        }
        
        moved[moved_count].line = strdup(lines[i]);
        moved[moved_count].index = i;
        moved[moved_count].subsection = minor ? strdup(minor) : strdup("### Changes");
        moved_count++;
        
        if (major) free(major);
    }
    
    if (moved_count == 0) {
        free_lines(lines);
        free(original);
        return;
    }
    
    int remove_indexes[MAX_LINES];
    int remove_count = 0;
    
    for (int i = 0; i < moved_count; i++) {
        remove_indexes[remove_count++] = moved[i].index;
    }
    
    char *next_lines_str = malloc(strlen(original) * 2);
    next_lines_str[0] = '\0';
    
    for (int i = 0; lines[i] != NULL; i++) {
        int should_remove = 0;
        for (int j = 0; j < remove_count; j++) {
            if (remove_indexes[j] == i) {
                should_remove = 1;
                break;
            }
        }
        if (!should_remove) {
            strcat(next_lines_str, lines[i]);
            strcat(next_lines_str, "\n");
        }
    }
    
    char **next_lines = split_lines(next_lines_str, &line_count);
    
    for (int i = 0; i < moved_count; i++) {
        int subsection_index = ensure_subsection(&next_lines, &line_count, moved[i].subsection);
        int insert_at = section_tail_insert_index(next_lines, subsection_index);
        
        int next_heading = line_count;
        for (int j = subsection_index + 1; next_lines[j] != NULL; j++) {
            if (strncmp(next_lines[j], "### ", 4) == 0 || strncmp(next_lines[j], "## ", 3) == 0) {
                next_heading = j;
                break;
            }
        }
        
        int already_present = 0;
        for (int j = subsection_index + 1; j < next_heading && next_lines[j] != NULL; j++) {
            if (strcmp(next_lines[j], moved[i].line) == 0) {
                already_present = 1;
                break;
            }
        }
        
        if (!already_present) {
            char *new_lines_str = malloc(strlen(original) * 2);
            new_lines_str[0] = '\0';
            
            for (int j = 0; j < insert_at; j++) {
                strcat(new_lines_str, next_lines[j]);
                strcat(new_lines_str, "\n");
            }
            
            strcat(new_lines_str, moved[i].line);
            strcat(new_lines_str, "\n");
            
            for (int j = insert_at; next_lines[j] != NULL; j++) {
                strcat(new_lines_str, next_lines[j]);
                strcat(new_lines_str, "\n");
            }
            
            free_lines(next_lines);
            next_lines = split_lines(new_lines_str, &line_count);
        }
    }
    
    char *updated = malloc(strlen(original) * 2);
    updated[0] = '\0';
    
    for (int i = 0; next_lines[i] != NULL; i++) {
        strcat(updated, next_lines[i]);
        strcat(updated, "\n");
    }
    
    if (strcmp(updated, original) != 0) {
        write_file(changelog_path, updated);
    }
    
    for (int i = 0; i < moved_count; i++) {
        free(moved[i].line);
        free(moved[i].subsection);
    }
    
    free_lines(lines);
    free_lines(next_lines);
    free(next_lines_str);
    free(updated);
    free(original);
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <pr_number> [contributor]\n", argv[0]);
        return 1;
    }
    
    normalize_pr_changelog_entries(argv[1]);
    return 0;
}

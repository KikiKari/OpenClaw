// abstraction-provenance: {"artifact_sha256": "ad78533f32f33c4b2e8d8e47002b4502e269d05d32bb06fe519e5e4c9120c215", "source_sha256": "13f974bf78b140bc88bd9f3afe27c500660ef59498ed533c38c18bca0c6f6331", "target_language": "c"}
// changelog-to-html.sh — portiert nach c
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/changelog-to-html.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <libgen.h>
#include <stdbool.h>

#define MAX_LINE_LENGTH 1024
#define MAX_PATH_LENGTH 1024

void usage(const char *program_name) {
    fprintf(stderr, "Usage: %s <version> [changelog_file]\n", program_name);
}

void error_exit(const char *message) {
    fprintf(stderr, "Error: %s\n", message);
    exit(1);
}

bool file_exists(const char *filename) {
    return access(filename, F_OK) == 0;
}

char *find_changelog_file(const char *script_dir) {
    static char path[MAX_PATH_LENGTH];
    
    snprintf(path, sizeof(path), "%s/../CHANGELOG.md", script_dir);
    if (file_exists(path)) {
        return path;
    }
    
    if (file_exists("CHANGELOG.md")) {
        return "CHANGELOG.md";
    }
    
    if (file_exists("../CHANGELOG.md")) {
        return "../CHANGELOG.md";
    }
    
    return NULL;
}

char *extract_version_section(const char *version, const char *filename) {
    FILE *file = fopen(filename, "r");
    if (!file) {
        return NULL;
    }
    
    static char result[10000]; // Static buffer for simplicity
    result[0] = '\0';
    
    char line[MAX_LINE_LENGTH];
    bool found = false;
    bool finished = false;
    
    while (fgets(line, sizeof(line), file) && !finished) {
        // Remove newline
        line[strcspn(line, "\n")] = 0;
        
        if (strncmp(line, "## ", 3) == 0) {
            if (!found) {
                // Check if this is our target version
                char version_header[256];
                snprintf(version_header, sizeof(version_header), "## %s", version);
                
                // Also check with space after version number
                char version_header_space[256];
                snprintf(version_header_space, sizeof(version_header_space), "## %s ", version);
                
                if (strcmp(line, version_header) == 0 || 
                    strncmp(line, version_header_space, strlen(version_header_space)) == 0 ||
                    strncmp(line, version_header, strlen(version_header)) == 0) {
                    found = true;
                    continue; // Skip the header line itself
                }
            } else {
                // We've found another version section, so we're done
                finished = true;
                continue;
            }
        }
        
        if (found) {
            strcat(result, line);
            strcat(result, "\n");
        }
    }
    
    fclose(file);
    
    if (!found) {
        result[0] = '\0';
    }
    
    return result[0] ? result : NULL;
}

void markdown_to_html(const char *text) {
    char output[MAX_LINE_LENGTH * 2];
    strcpy(output, text);
    
    // Handle headers
    if (strncmp(output, "##### ", 6) == 0) {
        printf("<h5>%s</h5>\n", output + 6);
        return;
    }
    if (strncmp(output, "#### ", 5) == 0) {
        printf("<h4>%s</h4>\n", output + 5);
        return;
    }
    if (strncmp(output, "### ", 4) == 0) {
        printf("<h3>%s</h3>\n", output + 4);
        return;
    }
    if (strncmp(output, "## ", 3) == 0) {
        printf("<h2>%s</h2>\n", output + 3);
        return;
    }
    
    // Handle list items with bold
    if (strncmp(output, "- **", 4) == 0) {
        char *bold_start = output + 3;  // Point to **
        char *bold_end = strstr(bold_start + 2, "**");
        if (bold_end) {
            *bold_end = '\0';
            printf("<li><strong>%s</strong>%s</li>\n", bold_start + 2, bold_end + 2);
            return;
        }
    }
    
    // Handle regular list items
    if (strncmp(output, "- ", 2) == 0) {
        printf("<li>%s</li>\n", output + 2);
        return;
    }
    
    // Handle bold text
    char *bold_start = strstr(output, "**");
    while (bold_start) {
        char *bold_end = strstr(bold_start + 2, "**");
        if (bold_end) {
            *bold_start = '\0';
            *bold_end = '\0';
            printf("%s<strong>%s</strong>%s", output, bold_start + 2, bold_end + 2);
            return;
        }
        break;
    }
    
    // Handle inline code
    char *code_start = strchr(output, '`');
    while (code_start) {
        char *code_end = strchr(code_start + 1, '`');
        if (code_end) {
            *code_start = '\0';
            *code_end = '\0';
            printf("%s<code>%s</code>%s", output, code_start + 1, code_end + 1);
            return;
        }
        break;
    }
    
    // Handle links [text](url)
    char *link_start = strchr(output, '[');
    while (link_start) {
        char *link_middle = strchr(link_start + 1, ']');
        if (link_middle && *(link_middle + 1) == '(') {
            char *link_end = strchr(link_middle + 2, ')');
            if (link_end) {
                *link_start = '\0';
                *link_middle = '\0';
                *link_end = '\0';
                printf("%s<a href=\"%s\">%s</a>%s", output, link_middle + 2, link_start + 1, link_end + 1);
                return;
            }
        }
        break;
    }
    
    // Plain text
    if (strlen(output) > 0) {
        printf("%s\n", output);
    }
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        usage(argv[0]);
        return 1;
    }
    
    const char *version = argv[1];
    const char *changelog_file = argc > 2 ? argv[2] : NULL;
    
    char script_dir[MAX_PATH_LENGTH];
    strcpy(script_dir, argv[0]);
    dirname(script_dir);
    
    if (!changelog_file) {
        changelog_file = find_changelog_file(script_dir);
        if (!changelog_file) {
            error_exit("Could not find CHANGELOG.md");
        }
    }
    
    if (!file_exists(changelog_file)) {
        fprintf(stderr, "Error: Changelog file '%s' not found\n", changelog_file);
        return 1;
    }
    
    char *version_content = extract_version_section(version, changelog_file);
    
    if (!version_content || strlen(version_content) == 0) {
        printf("<h2>OpenClaw %s</h2>\n", version);
        printf("<p>Latest OpenClaw update.</p>\n");
        printf("<p><a href=\"https://github.com/openclaw/openclaw/blob/main/CHANGELOG.md\">View full changelog</a></p>\n");
        return 0;
    }
    
    printf("<h2>OpenClaw %s</h2>\n", version);
    
    char line[MAX_LINE_LENGTH];
    bool in_list = false;
    char *content_ptr = version_content;
    
    while (*content_ptr) {
        char *line_end = strchr(content_ptr, '\n');
        if (!line_end) {
            line_end = content_ptr + strlen(content_ptr);
        }
        
        int line_length = line_end - content_ptr;
        if (line_length >= MAX_LINE_LENGTH) {
            line_length = MAX_LINE_LENGTH - 1;
        }
        
        strncpy(line, content_ptr, line_length);
        line[line_length] = '\0';
        
        // Remove trailing newline/carriage return
        char *cr = strchr(line, '\r');
        if (cr) *cr = '\0';
        
        if (line[0] == '-') {
            if (!in_list) {
                printf("<ul>\n");
                in_list = true;
            }
            markdown_to_html(line);
        } else {
            if (in_list) {
                printf("</ul>\n");
                in_list = false;
            }
            if (strlen(line) > 0) {
                markdown_to_html(line);
            }
        }
        
        content_ptr = line_end;
        if (*content_ptr == '\n') {
            content_ptr++;
        }
    }
    
    if (in_list) {
        printf("</ul>\n");
    }
    
    printf("<p><a href=\"https://github.com/openclaw/openclaw/blob/main/CHANGELOG.md\">View full changelog</a></p>\n");
    
    return 0;
}

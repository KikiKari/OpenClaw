// abstraction-provenance: {"artifact_sha256": "30b2ab0c33e7eed9921d906dae87d023763ad5d4a5d1e6e49e708b4d4ae2d76a", "source_sha256": "3e3cdceba2daa893e260551c8c5f09937f94be1153307185c7fc7c24c0896750", "target_language": "c"}
// quick_validate.py — portiert nach c
// Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/quick_validate.py
// auch in: OpenClaw@gateway2:skills/skill-creator/scripts/quick_validate.py
// auch in: workspace@local:git/skills/skill-creator/scripts/quick_validate.py
// auch in: workspace@local:skills/github-clones/openclaw/skills/skill-creator/scripts/quick_validate.py
// auch in: 1 weiteren Fundstellen
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <ctype.h>

#define MAX_SKILL_NAME_LENGTH 64
#define MAX_LINE_LENGTH 1024
#define MAX_DESCRIPTION_LENGTH 1024

typedef struct {
    char *name;
    char *description;
    char *license;
    char *allowed_tools;
    char *metadata;
} FrontMatter;

void free_frontmatter(FrontMatter *fm) {
    if (fm->name) free(fm->name);
    if (fm->description) free(fm->description);
    if (fm->license) free(fm->license);
    if (fm->allowed_tools) free(fm->allowed_tools);
    if (fm->metadata) free(fm->metadata);
    fm->name = NULL;
    fm->description = NULL;
    fm->license = NULL;
    fm->allowed_tools = NULL;
    fm->metadata = NULL;
}

char* trim_whitespace(char *str) {
    while (isspace((unsigned char)*str)) str++;
    if (*str == '\0') return str;
    
    char *end = str + strlen(str) - 1;
    while (end > str && isspace((unsigned char)*end)) end--;
    *(end + 1) = '\0';
    return str;
}

bool starts_with(const char *str, const char *prefix) {
    return strncmp(str, prefix, strlen(prefix)) == 0;
}

bool ends_with(const char *str, const char *suffix) {
    size_t str_len = strlen(str);
    size_t suffix_len = strlen(suffix);
    if (suffix_len > str_len) return false;
    return strcmp(str + str_len - suffix_len, suffix) == 0;
}

char* strdup_or_null(const char *src) {
    if (!src) return NULL;
    char *dup = malloc(strlen(src) + 1);
    if (dup) strcpy(dup, src);
    return dup;
}

char* extract_frontmatter(const char *content) {
    const char *start = strstr(content, "---\n");
    if (!start) return NULL;
    start += 4;
    
    const char *end = strstr(start, "\n---");
    if (!end) return NULL;
    
    size_t length = end - start;
    char *result = malloc(length + 1);
    if (!result) return NULL;
    
    strncpy(result, start, length);
    result[length] = '\0';
    return result;
}

bool parse_yaml_line(const char *line, char **key, char **value) {
    char *colon = strchr(line, ':');
    if (!colon) return false;
    
    *key = strndup(line, colon - line);
    *value = strdup(colon + 1);
    
    if (!*key || !*value) {
        free(*key);
        free(*value);
        return false;
    }
    
    *key = trim_whitespace(*key);
    *value = trim_whitespace(*value);
    
    if ((*value)[0] == '"' && (*value)[strlen(*value)-1] == '"') {
        memmove(*value, *value+1, strlen(*value)-2);
        (*value)[strlen(*value)-1] = '\0';
    } else if ((*value)[0] == '\'' && (*value)[strlen(*value)-1] == '\'') {
        memmove(*value, *value+1, strlen(*value)-2);
        (*value)[strlen(*value)-1] = '\0';
    }
    
    return true;
}

bool parse_simple_frontmatter(const char *frontmatter_text, FrontMatter *fm) {
    memset(fm, 0, sizeof(FrontMatter));
    
    char *text_copy = strdup(frontmatter_text);
    if (!text_copy) return false;
    
    char *saveptr;
    char *line = strtok_r(text_copy, "\n", &saveptr);
    char *last_key = NULL;
    
    while (line != NULL) {
        char *trimmed = trim_whitespace(line);
        if (trimmed[0] == '\0' || trimmed[0] == '#') {
            line = strtok_r(NULL, "\n", &saveptr);
            continue;
        }
        
        bool is_indented = line[0] != '\0' && isspace((unsigned char)line[0]);
        if (is_indented) {
            if (!last_key) {
                free(text_copy);
                free_frontmatter(fm);
                return false;
            }
            
            trim_whitespace(trimmed);
            char **target = NULL;
            if (strcmp(last_key, "name") == 0) target = &fm->name;
            else if (strcmp(last_key, "description") == 0) target = &fm->description;
            else if (strcmp(last_key, "license") == 0) target = &fm->license;
            else if (strcmp(last_key, "allowed-tools") == 0) target = &fm->allowed_tools;
            else if (strcmp(last_key, "metadata") == 0) target = &fm->metadata;
            
            if (target && *target) {
                size_t new_len = strlen(*target) + strlen(trimmed) + 2;
                char *new_val = realloc(*target, new_len);
                if (!new_val) {
                    free(text_copy);
                    free_frontmatter(fm);
                    return false;
                }
                *target = new_val;
                strcat(*target, "\n");
                strcat(*target, trimmed);
            }
            line = strtok_r(NULL, "\n", &saveptr);
            continue;
        }
        
        char *key, *value;
        if (!parse_yaml_line(trimmed, &key, &value)) {
            free(text_copy);
            free_frontmatter(fm);
            return false;
        }
        
        last_key = key;
        if (strcmp(key, "name") == 0) {
            fm->name = value;
        } else if (strcmp(key, "description") == 0) {
            fm->description = value;
        } else if (strcmp(key, "license") == 0) {
            fm->license = value;
        } else if (strcmp(key, "allowed-tools") == 0) {
            fm->allowed_tools = value;
        } else if (strcmp(key, "metadata") == 0) {
            fm->metadata = value;
        } else {
            free(key);
            free(value);
        }
        free(key);
        
        line = strtok_r(NULL, "\n", &saveptr);
    }
    
    free(text_copy);
    return true;
}

bool file_exists(const char *filename) {
    FILE *file = fopen(filename, "r");
    if (file) {
        fclose(file);
        return true;
    }
    return false;
}

char* read_file(const char *filename) {
    FILE *file = fopen(filename, "rb");
    if (!file) return NULL;
    
    if (fseek(file, 0, SEEK_END) != 0) {
        fclose(file);
        return NULL;
    }
    
    long length = ftell(file);
    if (length < 0) {
        fclose(file);
        return NULL;
    }
    
    if (fseek(file, 0, SEEK_SET) != 0) {
        fclose(file);
        return NULL;
    }
    
    char *content = malloc(length + 1);
    if (!content) {
        fclose(file);
        return NULL;
    }
    
    size_t read_length = fread(content, 1, length, file);
    if (read_length != (size_t)length) {
        free(content);
        fclose(file);
        return NULL;
    }
    
    content[length] = '\0';
    fclose(file);
    return content;
}

bool validate_name(const char *name, char *error_msg, size_t error_size) {
    if (!name || strlen(name) == 0) return true;
    
    for (size_t i = 0; i < strlen(name); i++) {
        if (!isalnum((unsigned char)name[i]) && name[i] != '-') {
            snprintf(error_msg, error_size, 
                     "Name '%s' should be hyphen-case (lowercase letters, digits, and hyphens only)", name);
            return false;
        }
        if (isupper((unsigned char)name[i])) {
            snprintf(error_msg, error_size, 
                     "Name '%s' should be hyphen-case (lowercase letters, digits, and hyphens only)", name);
            return false;
        }
    }
    
    if (name[0] == '-' || name[strlen(name)-1] == '-') {
        snprintf(error_msg, error_size, 
                 "Name '%s' cannot start/end with hyphen or contain consecutive hyphens", name);
        return false;
    }
    
    if (strstr(name, "--")) {
        snprintf(error_msg, error_size, 
                 "Name '%s' cannot start/end with hyphen or contain consecutive hyphens", name);
        return false;
    }
    
    if (strlen(name) > MAX_SKILL_NAME_LENGTH) {
        snprintf(error_msg, error_size, 
                 "Name is too long (%zu characters). Maximum is %d characters.", 
                 strlen(name), MAX_SKILL_NAME_LENGTH);
        return false;
    }
    
    return true;
}

bool validate_description(const char *description, char *error_msg, size_t error_size) {
    if (!description) return true;
    
    if (strlen(description) > MAX_DESCRIPTION_LENGTH) {
        snprintf(error_msg, error_size, 
                 "Description is too long (%zu characters). Maximum is %d characters.", 
                 strlen(description), MAX_DESCRIPTION_LENGTH);
        return false;
    }
    
    if (strchr(description, '<') || strchr(description, '>')) {
        snprintf(error_msg, error_size, "Description cannot contain angle brackets (< or >)");
        return false;
    }
    
    return true;
}

bool validate_skill(const char *skill_path, char *message, size_t message_size) {
    char skill_md_path[1024];
    snprintf(skill_md_path, sizeof(skill_md_path), "%s/SKILL.md", skill_path);
    
    if (!file_exists(skill_md_path)) {
        snprintf(message, message_size, "SKILL.md not found");
        return false;
    }
    
    char *content = read_file(skill_md_path);
    if (!content) {
        snprintf(message, message_size, "Could not read SKILL.md");
        return false;
    }
    
    char *frontmatter_text = extract_frontmatter(content);
    if (!frontmatter_text) {
        free(content);
        snprintf(message, message_size, "Invalid frontmatter format");
        return false;
    }
    
    FrontMatter fm;
    if (!parse_simple_frontmatter(frontmatter_text, &fm)) {
        free(content);
        free(frontmatter_text);
        snprintf(message, message_size, "Invalid YAML in frontmatter: unsupported syntax");
        return false;
    }
    
    free(content);
    free(frontmatter_text);
    
    if (!fm.name) {
        free_frontmatter(&fm);
        snprintf(message, message_size, "Missing 'name' in frontmatter");
        return false;
    }
    
    if (!fm.description) {
        free_frontmatter(&fm);
        snprintf(message, message_size, "Missing 'description' in frontmatter");
        return false;
    }
    
    char error_msg[1024];
    if (!validate_name(fm.name, error_msg, sizeof(error_msg))) {
        free_frontmatter(&fm);
        snprintf(message, message_size, "%s", error_msg);
        return false;
    }
    
    if (!validate_description(fm.description, error_msg, sizeof(error_msg))) {
        free_frontmatter(&fm);
        snprintf(message, message_size, "%s", error_msg);
        return false;
    }
    
    free_frontmatter(&fm);
    snprintf(message, message_size, "Skill is valid!");
    return true;
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        printf("Usage: %s <skill_directory>\n", argv[0]);
        return 1;
    }
    
    char message[1024];
    bool valid = validate_skill(argv[1], message, sizeof(message));
    printf("%s\n", message);
    return valid ? 0 : 1;
}

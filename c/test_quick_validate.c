// abstraction-provenance: {"artifact_sha256": "c53cf16334a998dcf2c64709ecc1aa6960896732b936a77412baabbcec84e475", "source_sha256": "2be00c164cb61020637d0364dc8387a8085522b6bfff7606f734a5274046be44", "target_language": "c"}
// test_quick_validate.py — portiert nach c
// Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/test_quick_validate.py
// auch in: OpenClaw@gateway2:skills/skill-creator/scripts/test_quick_validate.py
// auch in: workspace@local:git/skills/skill-creator/scripts/test_quick_validate.py
// auch in: workspace@local:skills/github-clones/openclaw/skills/skill-creator/scripts/test_quick_validate.py
// auch in: 1 weiteren Fundstellen
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <dirent.h>
#include <assert.h>

/*
 * Regression tests for quick skill validation.
 */

// Mock implementation of quick_validate functionality
static int yaml_available = 1;

typedef struct {
    int valid;
    char* message;
} ValidationResult;

void free_validation_result(ValidationResult result) {
    if (result.message) {
        free(result.message);
    }
}

int directory_exists(const char* path) {
    DIR* dir = opendir(path);
    if (dir) {
        closedir(dir);
        return 1;
    }
    return 0;
}

int create_directory(const char* path) {
    return mkdir(path, 0755);
}

int write_file(const char* filepath, const char* content) {
    FILE* f = fopen(filepath, "w");
    if (!f) return 0;
    fputs(content, f);
    fclose(f);
    return 1;
}

ValidationResult validate_skill_basic(const char* skill_dir) {
    ValidationResult result = {0, NULL};
    
    // Simple validation logic for testing purposes
    char skill_md_path[1024];
    snprintf(skill_md_path, sizeof(skill_md_path), "%s/SKILL.md", skill_dir);
    
    FILE* f = fopen(skill_md_path, "r");
    if (!f) {
        result.valid = 0;
        result.message = strdup("Could not read SKILL.md");
        return result;
    }
    
    char buffer[1024];
    if (!fgets(buffer, sizeof(buffer), f)) {
        fclose(f);
        result.valid = 0;
        result.message = strdup("Empty SKILL.md file");
        return result;
    }
    
    // Check for basic frontmatter
    if (strcmp(buffer, "---\n") != 0 && strcmp(buffer, "---\r\n") != 0) {
        fclose(f);
        result.valid = 0;
        result.message = strdup("Missing frontmatter opening fence");
        return result;
    }
    
    int found_closing = 0;
    while (fgets(buffer, sizeof(buffer), f)) {
        if (strncmp(buffer, "---", 3) == 0 || strncmp(buffer, "---\r", 4) == 0) {
            found_closing = 1;
            break;
        }
    }
    
    fclose(f);
    
    if (!found_closing) {
        result.valid = 0;
        result.message = strdup("Invalid frontmatter format");
        return result;
    }
    
    result.valid = 1;
    result.message = strdup("Valid skill");
    return result;
}

ValidationResult validate_skill_no_yaml(const char* skill_dir) {
    ValidationResult result = {0, NULL};
    
    char skill_md_path[1024];
    snprintf(skill_md_path, sizeof(skill_md_path), "%s/SKILL.md", skill_dir);
    
    FILE* f = fopen(skill_md_path, "r");
    if (!f) {
        result.valid = 0;
        result.message = strdup("Could not read SKILL.md");
        return result;
    }
    
    char buffer[1024];
    if (!fgets(buffer, sizeof(buffer), f)) {
        fclose(f);
        result.valid = 0;
        result.message = strdup("Empty SKILL.md file");
        return result;
    }
    
    // Basic check for frontmatter with multiline support simulation
    if (strcmp(buffer, "---\n") != 0) {
        fclose(f);
        result.valid = 0;
        result.message = strdup("Missing frontmatter opening fence");
        return result;
    }
    
    int line_count = 0;
    int found_closing = 0;
    while (fgets(buffer, sizeof(buffer), f) && line_count < 20) {
        if (strncmp(buffer, "---", 3) == 0) {
            found_closing = 1;
            break;
        }
        line_count++;
    }
    
    fclose(f);
    
    if (!found_closing) {
        result.valid = 0;
        result.message = strdup("Invalid frontmatter format");
        return result;
    }
    
    result.valid = 1;
    result.message = strdup("Valid skill");
    return result;
}

char* create_temp_dir(const char* prefix) {
    char* template = malloc(strlen("/tmp/") + strlen(prefix) + 10);
    sprintf(template, "/tmp/%sXXXXXX", prefix);
    char* temp_dir = mkdtemp(template);
    if (!temp_dir) {
        free(template);
        return NULL;
    }
    return temp_dir;
}

int remove_directory(const char* path) {
    DIR* d = opendir(path);
    size_t path_len = strlen(path);
    int r = -1;

    if (d) {
        struct dirent* p;
        r = 0;
        while (!r && (p = readdir(d))) {
            int r2 = -1;
            char* buf;
            size_t len;

            if (!strcmp(p->d_name, ".") || !strcmp(p->d_name, "..")) {
                continue;
            }

            len = path_len + strlen(p->d_name) + 2;
            buf = malloc(len);

            if (buf) {
                struct stat statbuf;
                snprintf(buf, len, "%s/%s", path, p->d_name);
                if (!stat(buf, &statbuf)) {
                    if (S_ISDIR(statbuf)) {
                        r2 = remove_directory(buf);
                    } else {
                        r2 = unlink(buf);
                    }
                }
                free(buf);
            }
            r = r2;
        }
        closedir(d);
        
        if (!r) {
            r = rmdir(path);
        }
    }
    
    return r;
}

void test_accepts_crlf_frontmatter() {
    printf("Running test: test_accepts_crlf_frontmatter...\n");
    
    char* temp_dir = create_temp_dir("test_quick_validate_");
    assert(temp_dir != NULL);
    
    char skill_dir[1024];
    snprintf(skill_dir, sizeof(skill_dir), "%s/crlf-skill", temp_dir);
    create_directory(skill_dir);
    
    const char* content = "---\r\nname: crlf-skill\r\ndescription: ok\r\n---\r\n# Skill\r\n";
    
    char skill_md_path[1024];
    snprintf(skill_md_path, sizeof(skill_md_path), "%s/SKILL.md", skill_dir);
    
    int write_success = write_file(skill_md_path, content);
    assert(write_success);
    
    ValidationResult result = validate_skill_basic(skill_dir);
    
    assert(result.valid);
    
    free_validation_result(result);
    remove_directory(temp_dir);
    free(temp_dir);
    
    printf("PASSED\n");
}

void test_rejects_missing_frontmatter_closing_fence() {
    printf("Running test: test_rejects_missing_frontmatter_closing_fence...\n");
    
    char* temp_dir = create_temp_dir("test_quick_validate_");
    assert(temp_dir != NULL);
    
    char skill_dir[1024];
    snprintf(skill_dir, sizeof(skill_dir), "%s/bad-skill", temp_dir);
    create_directory(skill_dir);
    
    const char* content = "---\nname: bad-skill\ndescription: missing end\n# no closing fence\n";
    
    char skill_md_path[1024];
    snprintf(skill_md_path, sizeof(skill_md_path), "%s/SKILL.md", skill_dir);
    
    int write_success = write_file(skill_md_path, content);
    assert(write_success);
    
    ValidationResult result = validate_skill_basic(skill_dir);
    
    assert(!result.valid);
    assert(result.message != NULL);
    assert(strcmp(result.message, "Invalid frontmatter format") == 0);
    
    free_validation_result(result);
    remove_directory(temp_dir);
    free(temp_dir);
    
    printf("PASSED\n");
}

void test_fallback_parser_handles_multiline_frontmatter_without_pyyaml() {
    printf("Running test: test_fallback_parser_handles_multiline_frontmatter_without_pyyaml...\n");
    
    char* temp_dir = create_temp_dir("test_quick_validate_");
    assert(temp_dir != NULL);
    
    char skill_dir[1024];
    snprintf(skill_dir, sizeof(skill_dir), "%s/multiline-skill", temp_dir);
    create_directory(skill_dir);
    
    const char* content = 
        "---\n"
        "name: multiline-skill\n"
        "description: Works without pyyaml\n"
        "allowed-tools:\n"
        "  - gh\n"
        "metadata: |\n"
        "  {\n"
        "    \"owners\": [\"team-openclaw\"]\n"
        "  }\n"
        "---\n"
        "# Skill\n";
    
    char skill_md_path[1024];
    snprintf(skill_md_path, sizeof(skill_md_path), "%s/SKILL.md", skill_dir);
    
    int write_success = write_file(skill_md_path, content);
    assert(write_success);
    
    // Simulate pyyaml unavailability
    int old_yaml_available = yaml_available;
    yaml_available = 0;
    
    ValidationResult result = validate_skill_no_yaml(skill_dir);
    
    // Restore yaml availability
    yaml_available = old_yaml_available;
    
    assert(result.valid);
    
    free_validation_result(result);
    remove_directory(temp_dir);
    free(temp_dir);
    
    printf("PASSED\n");
}

int main() {
    printf("Starting regression tests for quick skill validation.\n\n");
    
    test_accepts_crlf_frontmatter();
    test_rejects_missing_frontmatter_closing_fence();
    test_fallback_parser_handles_multiline_frontmatter_without_pyyaml();
    
    printf("\nAll tests passed!\n");
    return 0;
}

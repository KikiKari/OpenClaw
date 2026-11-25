// abstraction-provenance: {"artifact_sha256": "01466935320df2580a8bfd7c51939f05c57fde472b7e36860cd07fd502a23321", "source_sha256": "9c8abc93c198b77f804a6837db7baf1e85c902dc35a853c8086222a89f83fc89", "target_language": "c"}
// transcribe.sh — portiert nach c
// Quelle: shell, workspace@local:skills/github-clones/openclaw/skills/openai-whisper-api/scripts/transcribe.sh
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <errno.h>

void usage() {
    fprintf(stderr, "Usage:\n  transcribe.sh <audio-file> [--model whisper-1] [--out /path/to/out.txt] [--language en] [--prompt \"hint\"] [--json]\n");
    exit(2);
}

int file_exists(const char *filename) {
    struct stat buffer;
    return (stat(filename, &buffer) == 0);
}

char* get_dirname(const char *path) {
    char *result = strdup(path);
    char *last_slash = strrchr(result, '/');
    if (last_slash != NULL) {
        *last_slash = '\0';
    } else {
        strcpy(result, ".");
    }
    return result;
}

char* get_basename_no_ext(const char *path) {
    char *result = strdup(path);
    char *last_slash = strrchr(result, '/');
    char *base = (last_slash != NULL) ? last_slash + 1 : result;
    
    char *dot = strrchr(base, '.');
    if (dot != NULL) {
        *dot = '\0';
    }
    
    return result;
}

int main(int argc, char *argv[]) {
    if (argc < 2 || strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "--help") == 0) {
        usage();
    }

    const char *in_file = argv[1];
    const char *model = "whisper-1";
    const char *out_file = NULL;
    const char *language = NULL;
    const char *prompt = NULL;
    const char *response_format = "text";

    int i = 2;
    while (i < argc) {
        if (strcmp(argv[i], "--model") == 0 && i + 1 < argc) {
            model = argv[i + 1];
            i += 2;
        } else if (strcmp(argv[i], "--out") == 0 && i + 1 < argc) {
            out_file = argv[i + 1];
            i += 2;
        } else if (strcmp(argv[i], "--language") == 0 && i + 1 < argc) {
            language = argv[i + 1];
            i += 2;
        } else if (strcmp(argv[i], "--prompt") == 0 && i + 1 < argc) {
            prompt = argv[i + 1];
            i += 2;
        } else if (strcmp(argv[i], "--json") == 0) {
            response_format = "json";
            i += 1;
        } else {
            fprintf(stderr, "Unknown arg: %s\n", argv[i]);
            usage();
        }
    }

    if (!file_exists(in_file)) {
        fprintf(stderr, "File not found: %s\n", in_file);
        return 1;
    }

    const char *api_key = getenv("OPENAI_API_KEY");
    if (api_key == NULL || strlen(api_key) == 0) {
        fprintf(stderr, "Missing OPENAI_API_KEY\n");
        return 1;
    }

    char *out_path_allocated = NULL;
    if (out_file == NULL) {
        char *base_name = get_basename_no_ext(in_file);
        size_t len = strlen(base_name) + strlen(response_format) + 2;
        out_path_allocated = malloc(len);
        snprintf(out_path_allocated, len, "%s.%s", base_name, response_format);
        free(base_name);
        out_file = out_path_allocated;
    }

    char *dir_name = get_dirname(out_file);
    mkdir(dir_name, 0755);
    free(dir_name);

    const char *api_base_env = getenv("OPENAI_BASE_URL");
    const char *api_base = (api_base_env != NULL) ? api_base_env : "https://api.openai.com/v1";
    
    size_t api_url_len = strlen(api_base) + 25;
    char *api_url = malloc(api_url_len);
    snprintf(api_url, api_url_len, "%s/audio/transcriptions", api_base);

    // Build curl command
    size_t cmd_size = 2048 + strlen(api_url) + strlen(api_key) + strlen(in_file) + 
                      strlen(model) + strlen(response_format);
    if (language) cmd_size += strlen(language) + 20;
    if (prompt) cmd_size += strlen(prompt) + 20;
    
    char *cmd = malloc(cmd_size);
    int offset = snprintf(cmd, cmd_size,
        "curl -sS \"%s\" "
        "-H \"Authorization: Bearer %s\" "
        "-H \"Accept: application/json\" "
        "-F \"file=@%s\" "
        "-F \"model=%s\" "
        "-F \"response_format=%s\"",
        api_url, api_key, in_file, model, response_format);

    if (language && strlen(language) > 0) {
        offset += snprintf(cmd + offset, cmd_size - offset, " -F \"language=%s\"", language);
    }

    if (prompt && strlen(prompt) > 0) {
        offset += snprintf(cmd + offset, cmd_size - offset, " -F \"prompt=%s\"", prompt);
    }

    offset += snprintf(cmd + offset, cmd_size - offset, " >\"%s\"", out_file);

    int result = system(cmd);
    
    if (result == 0) {
        printf("%s\n", out_file);
    }

    free(cmd);
    free(api_url);
    if (out_path_allocated) {
        free(out_path_allocated);
    }

    return (result == 0) ? 0 : 1;
}

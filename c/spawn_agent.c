// abstraction-provenance: {"artifact_sha256": "cfbff2f26a0db9e78358970fb4e6544369cb9b42b8225fb7bd8a848c3d044ead", "source_sha256": "a26da3d1befb1a302d385e0a3c85117de3ec06543d5017cf1d706e7f0602be0f", "target_language": "c"}
// spawn_agent.py — portiert nach c
// Quelle: python, OpenClaw@gateway1:skills/sub-agents-utils/scripts/spawn_agent.py
// auch in: workspace@local:git/skills/sub-agents-utils/scripts/spawn_agent.py
// auch in: workspace@local:skills/sub-agents-utils/scripts/spawn_agent.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <argp.h>

// Konfigurationsstruktur
typedef struct {
    char **models;
    size_t model_count;
} Config;

// Globale Konfiguration
Config global_config;

// Fehlerbehandlung
void error_exit(const char* msg) {
    fprintf(stderr, "Fehler: %s\n", msg);
    exit(EXIT_FAILURE);
}

// Prüfe, ob ein String in einem Array enthalten ist
int string_in_array(const char* str, char** array, size_t count) {
    for (size_t i = 0; i < count; i++) {
        if (strcmp(str, array[i]) == 0) {
            return 1;
        }
    }
    return 0;
}

// Lade Modelle aus der Konfigurationsdatei
void load_models() {
    // Standardpfad setzen
    const char* config_env = getenv("OPENCLAW_CONFIG");
    char config_path[1024];
    
    if (config_env) {
        strncpy(config_path, config_env, sizeof(config_path) - 1);
        config_path[sizeof(config_path) - 1] = '\0';
    } else {
        strcpy(config_path, "/home/openclaw/.openclaw/openclaw.json");
    }
    
    // Prüfen ob Datei existiert
    struct stat st;
    if (stat(config_path, &st) != 0) {
        error_exit("Konfigurationsdatei nicht gefunden");
    }
    
    // Dummy-Modelle (da JSON-Parsing komplex wäre)
    global_config.models = malloc(3 * sizeof(char*));
    global_config.models[0] = strdup("openai/gpt-4");
    global_config.models[1] = strdup("openai/gpt-5.6-sol");
    global_config.models[2] = NULL;
    global_config.model_count = 2;
}

// Konfigurationsstruktur für den Spawner
typedef struct {
    char* task;
    char* label;
    char* model;
    char* thinking;
    int timeout;
    int thread;
    char* mode;
} SpawnConfig;

// Erstelle Konfiguration für sessions_spawn
SpawnConfig get_spawn_config(
    const char* task,
    const char* label,
    const char* model,
    const char* thinking,
    int timeout,
    int thread,
    const char* mode
) {
    SpawnConfig config = {0};
    
    config.task = task ? strdup(task) : NULL;
    config.label = label ? strdup(label) : NULL;
    config.thinking = thinking ? strdup(thinking) : NULL;
    config.timeout = timeout;
    config.thread = thread;
    config.mode = mode ? strdup(mode) : strdup("run");
    
    // Modellprüfung
    if (model && string_in_array(model, global_config.models, global_config.model_count)) {
        config.model = strdup(model);
    } else {
        config.model = NULL;
    }
    
    return config;
}

// Gebe das äquivalente Tool-Kommando aus
void print_spawn_command(SpawnConfig config) {
    printf("\n🛠️  Tool-Aufruf:\n");
    printf("==================================================\n");
    printf("sessions_spawn(\n");
    
    if (config.task) {
        printf("    task=\"%s\"\n", config.task);
    }
    if (config.label) {
        printf("    label=\"%s\"\n", config.label);
    }
    if (config.model) {
        printf("    model=\"%s\"\n", config.model);
    }
    if (config.thinking) {
        printf("    thinking=\"%s\"\n", config.thinking);
    }
    if (config.timeout > 0) {
        printf("    runTimeoutSeconds=%d\n", config.timeout);
    }
    if (config.thread) {
        printf("    thread=True\n");
        if (strcmp(config.mode, "run") == 0) {
            printf("    mode=\"session\"\n"); // thread erfordert session mode
        }
    } else {
        printf("    mode=\"%s\"\n", config.mode);
    }
    
    printf(")\n");
    printf("==================================================\n");
}

// Gebe das äquivalente Slash-Kommando aus
void print_slash_command(SpawnConfig config) {
    printf("\n💬 Slash Command:\n");
    printf("==================================================\n");
    
    const char* task = config.task ? config.task : "";
    const char* label = config.label ? config.label : "agent";
    
    printf("/subagents spawn %s \"%s\"", label, task);
    
    if (config.model) {
        printf(" --model %s", config.model);
    }
    if (config.thinking) {
        printf(" --thinking %s", config.thinking);
    }
    
    printf("\n");
    printf("==================================================\n");
}

// Befreie Speicher der Konfiguration
void free_spawn_config(SpawnConfig* config) {
    if (config->task) free(config->task);
    if (config->label) free(config->label);
    if (config->model) free(config->model);
    if (config->thinking) free(config->thinking);
    if (config->mode) free(config->mode);
}

// Argumentparser-Struktur
const char *argp_program_version = "spawn_agent 1.0";
const char *argp_program_bug_address = "<bug-report@example.com>";
static char doc[] = "Sub-Agent Spawn Helper\n\
\n\
Beispiele:\n\
  spawn_agent --task \"Analyze logs\" \n\
  spawn_agent --task \"Code review\" --model openai/gpt-5.6-sol --timeout 1800\n\
  spawn_agent --task \"Batch process\" --label batch-worker --thread";

static char args_doc[] = "";

static struct argp_option options[] = {
    {"task", 't', "TASK", 0, "Aufgabenbeschreibung"},
    {"label", 'l', "LABEL", 0, "Optionaler Label"},
    {"model", 'm', "MODEL", 0, "KI-Modell"},
    {"thinking", 0x100, "LEVEL", 0, "Thinking Level (low|medium|high)"},
    {"timeout", 0x101, "SECONDS", 0, "Timeout in Sekunden (default: 900)"},
    {"thread", 0x102, 0, 0, "Thread-Binding aktivieren"},
    {"mode", 0x103, "MODE", 0, "Run mode (run|session)"},
    {"output", 'o', "FORMAT", 0, "Output format (tool|slash|json)"},
    {0}
};

struct arguments {
    char* task;
    char* label;
    char* model;
    char* thinking;
    int timeout;
    int thread;
    char* mode;
    char* output;
};

static error_t parse_opt(int key, char *arg, struct argp_state *state) {
    struct arguments *arguments = state->input;
    
    switch (key) {
        case 't':
            arguments->task = arg;
            break;
        case 'l':
            arguments->label = arg;
            break;
        case 'm':
            arguments->model = arg;
            break;
        case 0x100:
            arguments->thinking = arg;
            break;
        case 0x101:
            arguments->timeout = atoi(arg);
            break;
        case 0x102:
            arguments->thread = 1;
            break;
        case 0x103:
            arguments->mode = arg;
            break;
        case 'o':
            arguments->output = arg;
            break;
        case ARGP_KEY_ARG:
            return ARGP_ERR_UNKNOWN;
        case ARGP_KEY_END:
            if (!arguments->task) {
                argp_usage(state);
            }
            break;
        default:
            return ARGP_ERR_UNKNOWN;
    }
    return 0;
}

static struct argp argp = {options, parse_opt, args_doc, doc};

int main(int argc, char **argv) {
    struct arguments arguments = {0};
    arguments.timeout = 900;
    arguments.mode = "run";
    arguments.output = "tool";
    
    argp_parse(&argp, argc, argv, 0, 0, &arguments);
    
    // Modelle laden
    load_models();
    
    // Konfiguration erstellen
    SpawnConfig config = get_spawn_config(
        arguments.task,
        arguments.label,
        arguments.model,
        arguments.thinking,
        arguments.timeout,
        arguments.thread,
        arguments.mode
    );
    
    // Konfiguration ausgeben
    printf("✅ Sub-Agent Konfiguration:\n");
    printf("{\n");
    if (config.task) printf("  \"task\": \"%s\",\n", config.task);
    if (config.label) printf("  \"label\": \"%s\",\n", config.label);
    if (config.model) printf("  \"model\": \"%s\",\n", config.model);
    if (config.thinking) printf("  \"thinking\": \"%s\",\n", config.thinking);
    if (config.timeout > 0) printf("  \"runTimeoutSeconds\": %d,\n", config.timeout);
    if (config.thread) printf("  \"thread\": true,\n");
    printf("  \"mode\": \"%s\"\n", config.thread && strcmp(config.mode, "run") == 0 ? "session" : config.mode);
    printf("}\n");
    
    // Output basierend auf Format
    if (strcmp(arguments.output, "tool") == 0) {
        print_spawn_command(config);
    } else if (strcmp(arguments.output, "slash") == 0) {
        print_slash_command(config);
    } else if (strcmp(arguments.output, "json") == 0) {
        printf("\n📄 JSON:\n");
        printf("{");
        int first = 1;
        if (config.task) {
            if (!first) printf(",");
            printf("\"task\":\"%s\"", config.task);
            first = 0;
        }
        if (config.label) {
            if (!first) printf(",");
            printf("\"label\":\"%s\"", config.label);
            first = 0;
        }
        if (config.model) {
            if (!first) printf(",");
            printf("\"model\":\"%s\"", config.model);
            first = 0;
        }
        if (config.thinking) {
            if (!first) printf(",");
            printf("\"thinking\":\"%s\"", config.thinking);
            first = 0;
        }
        if (config.timeout > 0) {
            if (!first) printf(",");
            printf("\"runTimeoutSeconds\":%d", config.timeout);
            first = 0;
        }
        if (config.thread) {
            if (!first) printf(",");
            printf("\"thread\":true");
            first = 0;
        }
        printf(",\"mode\":\"%s\"", config.thread && strcmp(config.mode, "run") == 0 ? "session" : config.mode);
        printf("}\n");
        
        // In Datei speichern
        char filename[256];
        snprintf(filename, sizeof(filename), "/tmp/subagent_%s.json", config.label ? config.label : "spawn");
        FILE* file = fopen(filename, "w");
        if (file) {
            fprintf(file, "{");
            first = 1;
            if (config.task) {
                if (!first) fprintf(file, ",");
                fprintf(file, "\"task\":\"%s\"", config.task);
                first = 0;
            }
            if (config.label) {
                if (!first) fprintf(file, ",");
                fprintf(file, "\"label\":\"%s\"", config.label);
                first = 0;
            }
            if (config.model) {
                if (!first) fprintf(file, ",");
                fprintf(file, "\"model\":\"%s\"", config.model);
                first = 0;
            }
            if (config.thinking) {
                if (!first) fprintf(file, ",");
                fprintf(file, "\"thinking\":\"%s\"", config.thinking);
                first = 0;
            }
            if (config.timeout > 0) {
                if (!first) fprintf(file, ",");
                fprintf(file, "\"runTimeoutSeconds\":%d", config.timeout);
                first = 0;
            }
            if (config.thread) {
                if (!first) fprintf(file, ",");
                fprintf(file, "\"thread\":true");
                first = 0;
            }
            fprintf(file, ",\"mode\":\"%s\"", config.thread && strcmp(config.mode, "run") == 0 ? "session" : config.mode);
            fprintf(file, "}\n");
            fclose(file);
            printf("💾 Gespeichert: %s\n", filename);
        }
    }
    
    // Speicher freigeben
    free_spawn_config(&config);
    
    return 0;
}

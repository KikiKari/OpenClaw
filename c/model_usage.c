// abstraction-provenance: {"artifact_sha256": "c2994865d409a3b32843aff90d28c15e7b808602958699e2efd8db86173fb0db", "source_sha256": "5e833080809c70bbbe1eee5fa14d9d07d639ca0b16c37253625f4dc46ca1e64f", "target_language": "c"}
// model_usage.py — portiert nach c
// Quelle: python, workspace@local:skills/github-clones/openclaw/skills/model-usage/scripts/model_usage.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <time.h>
#include <math.h>

#define MAX_LINE_LENGTH 4096
#define MAX_MODEL_NAME 256
#define MAX_DATE_LENGTH 32

typedef enum {
    MODE_CURRENT,
    MODE_ALL
} mode_t;

typedef enum {
    FORMAT_TEXT,
    FORMAT_JSON
} format_t;

typedef struct {
    char* model;
    double cost;
} model_cost_t;

typedef struct {
    char* date;
    char* model_name;
    double cost;
} daily_entry_t;

typedef struct {
    char* provider;
    char* mode;
    char* model;
    char* input;
    int days;
    int has_days;
    format_t format;
    int pretty;
} args_t;

typedef struct {
    char** keys;
    double* values;
    int count;
    int capacity;
} model_totals_t;

typedef struct {
    daily_entry_t* entries;
    int count;
    int capacity;
} daily_entries_t;

void free_args(args_t* args) {
    if (args->provider) free(args->provider);
    if (args->mode) free(args->mode);
    if (args->model) free(args->model);
    if (args->input) free(args->input);
}

void eprintf(const char* format, ...) {
    va_list args;
    va_start(args, format);
    vfprintf(stderr, format, args);
    va_end(args);
}

char* read_file(const char* path) {
    FILE* file = fopen(path, "r");
    if (!file) {
        perror("Failed to open file");
        return NULL;
    }

    fseek(file, 0, SEEK_END);
    long length = ftell(file);
    fseek(file, 0, SEEK_SET);

    char* buffer = malloc(length + 1);
    if (!buffer) {
        fclose(file);
        return NULL;
    }

    fread(buffer, 1, length, file);
    buffer[length] = '\0';
    fclose(file);
    return buffer;
}

char* read_stdin() {
    size_t capacity = 4096;
    size_t length = 0;
    char* buffer = malloc(capacity);
    if (!buffer) return NULL;

    int ch;
    while ((ch = getchar()) != EOF) {
        if (length >= capacity - 1) {
            capacity *= 2;
            char* temp = realloc(buffer, capacity);
            if (!temp) {
                free(buffer);
                return NULL;
            }
            buffer = temp;
        }
        buffer[length++] = ch;
    }
    buffer[length] = '\0';
    return buffer;
}

int parse_positive_int(const char* str) {
    char* endptr;
    long value = strtol(str, &endptr, 10);
    
    if (*endptr != '\0' || value <= 0 || value > INT_MAX) {
        return -1;
    }
    return (int)value;
}

int parse_date(const char* date_str, struct tm* tm_result) {
    memset(tm_result, 0, sizeof(struct tm));
    return sscanf(date_str, "%d-%d-%d", 
                  &tm_result->tm_year, 
                  &tm_result->tm_mon, 
                  &tm_result->tm_mday) == 3;
}

double parse_double(const char* str) {
    char* endptr;
    double value = strtod(str, &endptr);
    if (*endptr != '\0') {
        return NAN;
    }
    return value;
}

char* strdup_safe(const char* str) {
    if (!str) return NULL;
    char* result = malloc(strlen(str) + 1);
    if (result) strcpy(result, str);
    return result;
}

model_totals_t* create_model_totals() {
    model_totals_t* totals = malloc(sizeof(model_totals_t));
    if (!totals) return NULL;
    
    totals->keys = malloc(100 * sizeof(char*));
    totals->values = malloc(100 * sizeof(double));
    totals->count = 0;
    totals->capacity = 100;
    
    if (!totals->keys || !totals->values) {
        free(totals->keys);
        free(totals->values);
        free(totals);
        return NULL;
    }
    
    return totals;
}

void free_model_totals(model_totals_t* totals) {
    if (!totals) return;
    for (int i = 0; i < totals->count; i++) {
        free(totals->keys[i]);
    }
    free(totals->keys);
    free(totals->values);
    free(totals);
}

void add_to_totals(model_totals_t* totals, const char* model, double cost) {
    for (int i = 0; i < totals->count; i++) {
        if (strcmp(totals->keys[i], model) == 0) {
            totals->values[i] += cost;
            return;
        }
    }
    
    if (totals->count >= totals->capacity) {
        totals->capacity *= 2;
        totals->keys = realloc(totals->keys, totals->capacity * sizeof(char*));
        totals->values = realloc(totals->values, totals->capacity * sizeof(double));
    }
    
    totals->keys[totals->count] = strdup_safe(model);
    totals->values[totals->count] = cost;
    totals->count++;
}

daily_entries_t* create_daily_entries() {
    daily_entries_t* entries = malloc(sizeof(daily_entries_t));
    if (!entries) return NULL;
    
    entries->entries = malloc(1000 * sizeof(daily_entry_t));
    entries->count = 0;
    entries->capacity = 1000;
    
    if (!entries->entries) {
        free(entries);
        return NULL;
    }
    
    return entries;
}

void free_daily_entries(daily_entries_t* entries) {
    if (!entries) return;
    for (int i = 0; i < entries->count; i++) {
        free(entries->entries[i].date);
        free(entries->entries[i].model_name);
    }
    free(entries->entries);
    free(entries);
}

void add_daily_entry(daily_entries_t* entries, const char* date, const char* model_name, double cost) {
    if (entries->count >= entries->capacity) {
        entries->capacity *= 2;
        entries->entries = realloc(entries->entries, entries->capacity * sizeof(daily_entry_t));
    }
    
    entries->entries[entries->count].date = strdup_safe(date);
    entries->entries[entries->count].model_name = strdup_safe(model_name);
    entries->entries[entries->count].cost = cost;
    entries->count++;
}

int compare_dates_desc(const void* a, const void* b) {
    const daily_entry_t* entry_a = (const daily_entry_t*)a;
    const daily_entry_t* entry_b = (const daily_entry_t*)b;
    return strcmp(entry_b->date, entry_a->date);
}

int compare_model_costs_desc(const void* a, const void* b) {
    const model_cost_t* cost_a = (const model_cost_t*)a;
    const model_cost_t* cost_b = (const model_cost_t*)b;
    if (cost_a->cost > cost_b->cost) return -1;
    if (cost_a->cost < cost_b->cost) return 1;
    return 0;
}

void print_usd(double value) {
    if (isnan(value)) {
        printf("—");
    } else {
        printf("$%.2f", value);
    }
}

void print_json_current(const char* provider, const char* model, const char* latest_date, 
                        double total_cost, double latest_cost, const char* latest_cost_date, 
                        int entry_count, int pretty) {
    if (pretty) {
        printf("{\n");
        printf("  \"provider\": \"%s\",\n", provider);
        printf("  \"mode\": \"current\",\n");
        printf("  \"model\": \"%s\",\n", model);
        if (latest_date) {
            printf("  \"latestModelDate\": \"%s\",\n", latest_date);
        }
        if (!isnan(total_cost)) {
            printf("  \"totalCostUSD\": %.2f,\n", total_cost);
        } else {
            printf("  \"totalCostUSD\": null,\n");
        }
        if (!isnan(latest_cost)) {
            printf("  \"latestDayCostUSD\": %.2f,\n", latest_cost);
        } else {
            printf("  \"latestDayCostUSD\": null,\n");
        }
        if (latest_cost_date) {
            printf("  \"latestDayCostDate\": \"%s\",\n", latest_cost_date);
        } else {
            printf("  \"latestDayCostDate\": null,\n");
        }
        printf("  \"dailyRowCount\": %d\n", entry_count);
        printf("}\n");
    } else {
        printf("{\"provider\":\"%s\",\"mode\":\"current\",\"model\":\"%s\"", provider, model);
        if (latest_date) {
            printf(",\"latestModelDate\":\"%s\"", latest_date);
        }
        if (!isnan(total_cost)) {
            printf(",\"totalCostUSD\":%.2f", total_cost);
        } else {
            printf(",\"totalCostUSD\":null");
        }
        if (!isnan(latest_cost)) {
            printf(",\"latestDayCostUSD\":%.2f", latest_cost);
        } else {
            printf(",\"latestDayCostUSD\":null");
        }
        if (latest_cost_date) {
            printf(",\"latestDayCostDate\":\"%s\"", latest_cost_date);
        } else {
            printf(",\"latestDayCostDate\":null");
        }
        printf(",\"dailyRowCount\":%d}\n", entry_count);
    }
}

void print_json_all(const char* provider, model_totals_t* totals, int pretty) {
    if (pretty) {
        printf("{\n");
        printf("  \"provider\": \"%s\",\n", provider);
        printf("  \"mode\": \"all\",\n");
        printf("  \"models\": [\n");
        
        for (int i = 0; i < totals->count; i++) {
            printf("    {\n");
            printf("      \"model\": \"%s\",\n", totals->keys[i]);
            printf("      \"totalCostUSD\": %.2f\n", totals->values[i]);
            if (i < totals->count - 1) {
                printf("    },\n");
            } else {
                printf("    }\n");
            }
        }
        
        printf("  ]\n");
        printf("}\n");
    } else {
        printf("{\"provider\":\"%s\",\"mode\":\"all\",\"models\":[", provider);
        for (int i = 0; i < totals->count; i++) {
            printf("{\"model\":\"%s\",\"totalCostUSD\":%.2f}", totals->keys[i], totals->values[i]);
            if (i < totals->count - 1) {
                printf(",");
            }
        }
        printf("]}\n");
    }
}

void print_text_current(const char* provider, const char* model, const char* latest_date, 
                       double total_cost, double latest_cost, const char* latest_cost_date, 
                       int entry_count) {
    printf("Provider: %s\n", provider);
    printf("Current model: %s\n", model);
    if (latest_date) {
        printf("Latest model date: %s\n", latest_date);
    }
    printf("Total cost (rows): ");
    print_usd(total_cost);
    printf("\n");
    if (!isnan(latest_cost) && latest_cost_date) {
        printf("Latest day cost: ");
        print_usd(latest_cost);
        printf(" (%s)\n", latest_cost_date);
    }
    printf("Daily rows: %d\n", entry_count);
}

void print_text_all(const char* provider, model_totals_t* totals) {
    printf("Provider: %s\n", provider);
    printf("Models:\n");
    
    // Sort by cost descending
    model_cost_t* costs = malloc(totals->count * sizeof(model_cost_t));
    for (int i = 0; i < totals->count; i++) {
        costs[i].model = totals->keys[i];
        costs[i].cost = totals->values[i];
    }
    
    qsort(costs, totals->count, sizeof(model_cost_t), compare_model_costs_desc);
    
    for (int i = 0; i < totals->count; i++) {
        printf("- %s: ", costs[i].model);
        print_usd(costs[i].cost);
        printf("\n");
    }
    
    free(costs);
}

// Simple JSON parser functions (basic implementation)
int find_json_object_end(const char* json, int start) {
    int depth = 1;
    int i = start;
    
    while (depth > 0 && json[i] != '\0') {
        if (json[i] == '{') {
            depth++;
        } else if (json[i] == '}') {
            depth--;
        }
        i++;
    }
    
    return depth == 0 ? i : -1;
}

int find_json_array_end(const char* json, int start) {
    int depth = 1;
    int i = start;
    
    while (depth > 0 && json[i] != '\0') {
        if (json[i] == '[') {
            depth++;
        } else if (json[i] == ']') {
            depth--;
        }
        i++;
    }
    
    return depth == 0 ? i : -1;
}

char* extract_json_string_value(const char* json, const char* key) {
    static char buffer[4096];
    char search_key[512];
    snprintf(search_key, sizeof(search_key), "\"%s\"", key);
    
    char* pos = strstr(json, search_key);
    if (!pos) return NULL;
    
    pos += strlen(search_key);
    while (*pos == ' ' || *pos == ':') pos++;
    
    if (*pos != '"') return NULL;
    pos++;
    
    char* end = strchr(pos, '"');
    if (!end) return NULL;
    
    int len = end - pos;
    if (len >= sizeof(buffer)) len = sizeof(buffer) - 1;
    
    strncpy(buffer, pos, len);
    buffer[len] = '\0';
    
    return buffer;
}

double extract_json_number_value(const char* json, const char* key) {
    char search_key[512];
    snprintf(search_key, sizeof(search_key), "\"%s\"", key);
    
    char* pos = strstr(json, search_key);
    if (!pos) return NAN;
    
    pos += strlen(search_key);
    while (*pos == ' ' || *pos == ':') pos++;
    
    if (*pos == 'n' && strncmp(pos, "null", 4) == 0) {
        return NAN;
    }
    
    char* endptr;
    double value = strtod(pos, &endptr);
    if (endptr == pos) {
        return NAN;
    }
    
    return value;
}

int parse_daily_entries_from_json(const char* json_data, daily_entries_t* entries) {
    const char* daily_start = strstr(json_data, "\"daily\"");
    if (!daily_start) return 0;
    
    daily_start = strchr(daily_start, '[');
    if (!daily_start) return 0;
    
    int array_end = find_json_array_end(json_data, daily_start - json_data);
    if (array_end < 0) return 0;
    
    char* daily_section = strndup(daily_start, array_end - (daily_start - json_data));
    if (!daily_section) return 0;
    
    // Parse each daily entry
    char* pos = daily_section;
    while ((pos = strchr(pos, '{')) != NULL) {
        int obj_end = find_json_object_end(daily_section, pos - daily_section);
        if (obj_end < 0) break;
        
        char* entry_json = strndup(pos, obj_end - (pos - daily_section));
        if (!entry_json) break;
        
        char* date = extract_json_string_value(entry_json, "date");
        if (date) {
            // Parse modelBreakdowns
            const char* breakdowns_start = strstr(entry_json, "\"modelBreakdowns\"");
            if (breakdowns_start) {
                breakdowns_start = strchr(breakdowns_start, '[');
                if (breakdowns_start) {
                    int breakdowns_end = find_json_array_end(entry_json, breakdowns_start - entry_json);
                    if (breakdowns_end > 0) {
                        char* breakdowns_section = strndup(breakdowns_start, breakdowns_end - (breakdowns_start - entry_json));
                        if (breakdowns_section) {
                            // Parse each breakdown item
                            char* item_pos = breakdowns_section;
                            while ((item_pos = strchr(item_pos, '{')) != NULL) {
                                int item_end = find_json_object_end(breakdowns_section, item_pos - breakdowns_section);
                                if (item_end < 0) break;
                                
                                char* item_json = strndup(item_pos, item_end - (item_pos - breakdowns_section));
                                if (item_json) {
                                    char* model_name = extract_json_string_value(item_json, "modelName");
                                    double cost = extract_json_number_value(item_json, "cost");
                                    
                                    if (model_name && !isnan(cost)) {
                                        add_daily_entry(entries, date, model_name, cost);
                                    }
                                    
                                    free(item_json);
                                }
                                
                                item_pos += item_end;
                            }
                            free(breakdowns_section);
                        }
                    }
                }
            }
        }
        
        free(entry_json);
        pos += obj_end;
    }
    
    free(daily_section);
    return 1;
}

char* get_provider_data(const char* json_data, const char* provider) {
    // For simplicity, we'll assume the entire JSON is for the requested provider
    // In a real implementation, you'd need to parse the full structure
    return strdup(json_data);
}

int main(int argc, char* argv[]) {
    args_t args = {0};
    args.provider = strdup("codex");
    args.mode = strdup("current");
    args.format = FORMAT_TEXT;
    
    // Parse command line arguments
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--provider") == 0 && i + 1 < argc) {
            free(args.provider);
            args.provider = strdup(argv[++i]);
        } else if (strcmp(argv[i], "--mode") == 0 && i + 1 < argc) {
            free(args.mode);
            args.mode = strdup(argv[++i]);
        } else if (strcmp(argv[i], "--model") == 0 && i + 1 < argc) {
            args.model = strdup(argv[++i]);
        } else if (strcmp(argv[i], "--input") == 0 && i + 1 < argc) {
            args.input = strdup(argv[++i]);
        } else if (strcmp(argv[i], "--days") == 0 && i + 1 < argc) {
            int days = parse_positive_int(argv[++i]);
            if (days > 0) {
                args.days = days;
                args.has_days = 1;
            }
        } else if (strcmp(argv[i], "--format") == 0 && i + 1 < argc) {
            if (strcmp(argv[++i], "json") == 0) {
                args.format = FORMAT_JSON;
            } else {
                args.format = FORMAT_TEXT;
            }
        } else if (strcmp(argv[i], "--pretty") == 0) {
            args.pretty = 1;
        }
    }
    
    // Load JSON data
    char* json_data = NULL;
    if (args.input) {
        if (strcmp(args.input, "-") == 0) {
            json_data = read_stdin();
        } else {
            json_data = read_file(args.input);
        }
    } else {
        eprintf("codexbar not found on PATH. Install CodexBar CLI first.\n");
        free_args(&args);
        return 1;
    }
    
    if (!json_data) {
        eprintf("Failed to load JSON data.\n");
        free_args(&args);
        return 1;
    }
    
    // Get provider-specific data
    char* provider_data = get_provider_data(json_data, args.provider);
    if (!provider_data) {
        eprintf("Provider '%s' not found in codexbar payload.\n", args.provider);
        free(json_data);
        free_args(&args);
        return 1;
    }
    
    // Parse daily entries
    daily_entries_t* entries = create_daily_entries();
    if (!entries) {
        eprintf("Memory allocation failed.\n");
        free(json_data);
        free(provider_data);
        free_args(&args);
        return 1;
    }
    
    if (!parse_daily_entries_from_json(provider_data, entries)) {
        eprintf("Failed to parse daily entries.\n");
        free_daily_entries(entries);
        free(json_data);
        free(provider_data);
        free_args(&args);
        return 1;
    }
    
    // Filter by days if specified
    if (args.has_days && args.days > 0) {
        time_t now = time(NULL);
        struct tm* today_tm = localtime(&now);
        struct tm cutoff_tm = *today_tm;
        cutoff_tm.tm_mday -= (args.days - 1);
        mktime(&cutoff_tm); // Normalize
        
        int filtered_count = 0;
        for (int i = 0; i < entries->count; i++) {
            struct tm entry_tm;
            if (parse_date(entries->entries[i].date, &entry_tm)) {
                entry_tm.tm_year -= 1900;
                entry_tm.tm_mon -= 1;
                time_t entry_time = mktime(&entry_tm);
                
                if (entry_time >= mktime(&cutoff_tm)) {
                    if (filtered_count != i) {
                        entries->entries[filtered_count] = entries->entries[i];
                    }
                    filtered_count++;
                }
            }
        }
        entries->count = filtered_count;
    }
    
    // Sort entries by date descending
    qsort(entries->entries, entries->count, sizeof(daily_entry_t), compare_dates_desc);
    
    if (strcmp(args.mode, "current") == 0) {
        char* model = args.model;
        char* latest_date = NULL;
        
        if (!model) {
            // Find current model (highest cost model from most recent date)
            for (int i = 0; i < entries->count; i++) {
                if (!latest_date) {
                    latest_date = entries->entries[i].date;
                }
                
                model = entries->entries[i].model_name;
                break; // Just take the first one for simplicity
            }
        }
        
        if (!model) {
            eprintf("No model data found in codexbar cost payload.\n");
            free_daily_entries(entries);
            free(json_data);
            free(provider_data);
            free_args(&args);
            return 2;
        }
        
        // Calculate totals
        model_totals_t* totals = create_model_totals();
        if (!totals) {
            eprintf("Memory allocation failed.\n");
            free_daily_entries(entries);
            free(json_data);
            free(provider_data);
            free_args(&args);
            return 1;
        }
        
        for (int i = 0; i < entries->count; i++) {
            add_to_totals(totals, entries->entries[i].model_name, entries->entries[i].cost);
        }
        
        double total_cost = NAN;
        for (int i = 0; i < totals->count; i++) {
            if (strcmp(totals->keys[i], model) == 0) {
                total_cost = totals->values[i];
                break;
            }
        }
        
        // Find latest day cost
        double latest_cost = NAN;
        char* latest_cost_date = NULL;
        for (int i = 0; i < entries->count; i++) {
            if (strcmp(entries->entries[i].model_name, model) == 0) {
                latest_cost = entries->entries[i].cost;
                latest_cost_date = entries->entries[i].date;
                break;
            }
        }
        
        if (args.format == FORMAT_JSON) {
            print_json_current(args.provider, model, latest_date, total_cost, latest_cost, 
                              latest_cost_date, entries->count, args.pretty);
        } else {
            print_text_current(args.provider, model, latest_date, total_cost, latest_cost, 
                               latest_cost_date, entries->count);
        }
        
        free_model_totals(totals);
    } else {
        // Mode "all"
        model_totals_t* totals = create_model_totals();
        if (!totals) {
            eprintf("Memory allocation failed.\n");
            free_daily_entries(entries);
            free(json_data);
            free(provider_data);
            free_args(&args);
            return 1;
        }
        
        for (int i = 0; i < entries->count; i++) {
            add_to_totals(totals, entries->entries[i].model_name, entries->entries[i].cost);
        }
        
        if (totals->count == 0) {
            eprintf("No model breakdowns found in codexbar cost payload.\n");
            free_model_totals(totals);
            free_daily_entries(entries);
            free(json_data);
            free(provider_data);
            free_args(&args);
            return 2;
        }
        
        if (args.format == FORMAT_JSON) {
            print_json_all(args.provider, totals, args.pretty);
        } else {
            print_text_all(args.provider, totals);
        }
        
        free_model_totals(totals);
    }
    
    free_daily_entries(entries);
    free(json_data);
    free(provider_data);
    free_args(&args);
    return 0;
}

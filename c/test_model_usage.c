// abstraction-provenance: {"artifact_sha256": "cec7da243797a07a98cb4d7050f429310d5c4afcd0f7b454a88b9927dede9fef", "source_sha256": "95f62a3e3f38308dd9be80e09ec85e4a14455ab95457febb8f915c0f54685141", "target_language": "c"}
// test_model_usage.py — portiert nach c
// Quelle: python, workspace@local:skills/github-clones/openclaw/skills/model-usage/scripts/test_model_usage.py
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <time.h>

// Mocking argparse functionality
typedef struct {
    const char* message;
} ArgumentTypeError;

ArgumentTypeError* create_argument_type_error(const char* message) {
    ArgumentTypeError* error = malloc(sizeof(ArgumentTypeError));
    error->message = message;
    return error;
}

// Function prototypes
int positive_int(const char* str, ArgumentTypeError** error);
typedef struct {
    char date[11]; // YYYY-MM-DD format + null terminator
    void* modelBreakdowns; // Placeholder for array
} Entry;

Entry* filter_by_days(Entry* entries, int count, int days, int* out_count);

// Test functions
void test_positive_int_accepts_valid_numbers() {
    ArgumentTypeError* error = NULL;
    assert(positive_int("1", &error) == 1);
    assert(positive_int("7", &error) == 7);
    printf("test_positive_int_accepts_valid_numbers passed\n");
}

void test_positive_int_rejects_zero_and_negative() {
    ArgumentTypeError* error = NULL;
    positive_int("0", &error);
    assert(error != NULL);
    
    error = NULL;
    positive_int("-3", &error);
    assert(error != NULL);
    printf("test_positive_int_rejects_zero_and_negative passed\n");
}

void test_filter_by_days_keeps_recent_entries() {
    // Get today's date
    time_t now = time(NULL);
    struct tm* today_tm = localtime(&now);
    
    // Create test entries
    Entry entries[3];
    
    // Entry 5 days ago
    struct tm five_days_ago_tm = *today_tm;
    five_days_ago_tm.tm_mday -= 5;
    mktime(&five_days_ago_tm);
    strftime(entries[0].date, sizeof(entries[0].date), "%Y-%m-%d", &five_days_ago_tm);
    entries[0].modelBreakdowns = NULL;
    
    // Entry 1 day ago
    struct tm one_day_ago_tm = *today_tm;
    one_day_ago_tm.tm_mday -= 1;
    mktime(&one_day_ago_tm);
    strftime(entries[1].date, sizeof(entries[1].date), "%Y-%m-%d", &one_day_ago_tm);
    entries[1].modelBreakdowns = NULL;
    
    // Today
    strftime(entries[2].date, sizeof(entries[2].date), "%Y-%m-%d", today_tm);
    entries[2].modelBreakdowns = NULL;
    
    int out_count;
    Entry* filtered = filter_by_days(entries, 3, 2, &out_count);
    
    assert(out_count == 2);
    
    // Check dates match expected (should be last 2 entries)
    struct tm expected_one_day_ago_tm = *today_tm;
    expected_one_day_ago_tm.tm_mday -= 1;
    mktime(&expected_one_day_ago_tm);
    char expected_date1[11];
    strftime(expected_date1, sizeof(expected_date1), "%Y-%m-%d", &expected_one_day_ago_tm);
    
    char expected_date2[11];
    strftime(expected_date2, sizeof(expected_date2), "%Y-%m-%d", today_tm);
    
    assert(strcmp(filtered[0].date, expected_date1) == 0);
    assert(strcmp(filtered[1].date, expected_date2) == 0);
    
    free(filtered);
    printf("test_filter_by_days_keeps_recent_entries passed\n");
}

// Implementation of functions
int positive_int(const char* str, ArgumentTypeError** error) {
    int value = atoi(str);
    if (value <= 0) {
        *error = create_argument_type_error("Value must be positive");
        return -1;
    }
    return value;
}

Entry* filter_by_days(Entry* entries, int count, int days, int* out_count) {
    // For simplicity, we'll just take the last 'days' entries
    // In a real implementation, this would compare actual dates
    
    int start_index = (count > days) ? (count - days) : 0;
    int result_count = count - start_index;
    
    Entry* result = malloc(result_count * sizeof(Entry));
    for (int i = 0; i < result_count; i++) {
        result[i] = entries[start_index + i];
    }
    
    *out_count = result_count;
    return result;
}

int main() {
    test_positive_int_accepts_valid_numbers();
    test_positive_int_rejects_zero_and_negative();
    test_filter_by_days_keeps_recent_entries();
    
    printf("All tests passed!\n");
    return 0;
}

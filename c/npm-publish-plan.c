// abstraction-provenance: {"artifact_sha256": "6935e1ec390fd3ef0eec9a7688dcafaf24df5d7277dfc31254ec7fdec1a4d41d", "source_sha256": "a34985d25128cedfc16fb8a861471a22db49d62133276bbab6c7492eee461c4d", "target_language": "c"}
// npm-publish-plan.mjs — portiert nach c
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/npm-publish-plan.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <time.h>
#include <regex.h>

#define MAX_VERSION_LENGTH 256

typedef enum {
    CHANNEL_STABLE,
    CHANNEL_BETA
} channel_type;

typedef enum {
    PUBLISH_TAG_LATEST,
    PUBLISH_TAG_BETA
} publish_tag_type;

typedef struct {
    char version[MAX_VERSION_LENGTH];
    char baseVersion[MAX_VERSION_LENGTH];
    channel_type channel;
    int year;
    int month;
    int day;
    int betaNumber;
    int correctionNumber;
    time_t date;
    int has_beta_number;
    int has_correction_number;
} ParsedReleaseVersion;

typedef struct {
    channel_type channel;
    publish_tag_type publishTag;
    publish_tag_type* mirrorDistTags;
    int mirror_count;
} NpmPublishPlan;

typedef struct {
    int hasAuth;
    char source[32]; // "node-auth-token", "npm-token", or "none"
} NpmDistTagMirrorAuth;

typedef enum {
    MODE_DRY_RUN,
    MODE_PUBLISH
} NpmPublishMode;

// Helper functions
int is_valid_date(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) {
        return 0;
    }
    
    struct tm tm_date = {0};
    tm_date.tm_year = year - 1900;
    tm_date.tm_mon = month - 1;
    tm_date.tm_mday = day;
    tm_date.tm_hour = 0;
    tm_date.tm_min = 0;
    tm_date.tm_sec = 0;
    tm_date.tm_isdst = -1;
    
    time_t t = mktime(&tm_date);
    if (t == -1) {
        return 0;
    }
    
    struct tm *utc_tm = gmtime(&t);
    return (utc_tm->tm_year + 1900 == year &&
            utc_tm->tm_mon + 1 == month &&
            utc_tm->tm_mday == day);
}

int parse_int(const char* str, int* result) {
    if (!str || strlen(str) == 0) {
        return 0;
    }
    
    char* endptr;
    long val = strtol(str, &endptr, 10);
    if (*endptr != '\0') {
        return 0;
    }
    
    *result = (int)val;
    return 1;
}

void trim(char* str) {
    char* end;
    
    // Trim leading space
    while(isspace((unsigned char)*str)) str++;
    
    if(*str == 0)  // All spaces?
        return;
    
    // Trim trailing space
    end = str + strlen(str) - 1;
    while(end > str && isspace((unsigned char)*end)) end--;
    
    // Write new null terminator character
    *(end+1) = 0;
}

ParsedReleaseVersion* parseDateParts(const char* version, regmatch_t* matches, size_t nmatch, const char* input, channel_type channel) {
    ParsedReleaseVersion* result = malloc(sizeof(ParsedReleaseVersion));
    if (!result) return NULL;
    
    memset(result, 0, sizeof(ParsedReleaseVersion));
    
    char year_str[8], month_str[8], day_str[8];
    char beta_str[16] = {0}, correction_str[16] = {0};
    
    // Extract matched groups
    if (matches[1].rm_so != -1) {
        int len = matches[1].rm_eo - matches[1].rm_so;
        strncpy(year_str, input + matches[1].rm_so, len);
        year_str[len] = '\0';
    }
    
    if (matches[2].rm_so != -1) {
        int len = matches[2].rm_eo - matches[2].rm_so;
        strncpy(month_str, input + matches[2].rm_so, len);
        month_str[len] = '\0';
    }
    
    if (matches[3].rm_so != -1) {
        int len = matches[3].rm_eo - matches[3].rm_so;
        strncpy(day_str, input + matches[3].rm_so, len);
        day_str[len] = '\0';
    }
    
    if (channel == CHANNEL_BETA && matches[4].rm_so != -1) {
        int len = matches[4].rm_eo - matches[4].rm_so;
        strncpy(beta_str, input + matches[4].rm_so, len);
        beta_str[len] = '\0';
    }
    
    if (channel == CHANNEL_STABLE && nmatch > 4 && matches[4].rm_so != -1) {
        int len = matches[4].rm_eo - matches[4].rm_so;
        strncpy(correction_str, input + matches[4].rm_so, len);
        correction_str[len] = '\0';
    }
    
    if (!parse_int(year_str, &result->year) ||
        !parse_int(month_str, &result->month) ||
        !parse_int(day_str, &result->day)) {
        free(result);
        return NULL;
    }
    
    if (channel == CHANNEL_BETA) {
        if (!parse_int(beta_str, &result->betaNumber)) {
            free(result);
            return NULL;
        }
        result->has_beta_number = 1;
    } else if (strlen(correction_str) > 0) {
        if (!parse_int(correction_str, &result->correctionNumber)) {
            free(result);
            return NULL;
        }
        result->has_correction_number = 1;
    }
    
    if (!is_valid_date(result->year, result->month, result->day)) {
        free(result);
        return NULL;
    }
    
    strcpy(result->version, version);
    sprintf(result->baseVersion, "%d.%d.%d", result->year, result->month, result->day);
    result->channel = channel;
    
    struct tm tm_date = {0};
    tm_date.tm_year = result->year - 1900;
    tm_date.tm_mon = result->month - 1;
    tm_date.tm_mday = result->day;
    tm_date.tm_hour = 0;
    tm_date.tm_min = 0;
    tm_date.tm_sec = 0;
    tm_date.tm_isdst = -1;
    
    result->date = mktime(&tm_date);
    
    return result;
}

ParsedReleaseVersion* parseReleaseVersion(const char* version) {
    if (!version) return NULL;
    
    char trimmed_version[MAX_VERSION_LENGTH];
    strncpy(trimmed_version, version, MAX_VERSION_LENGTH - 1);
    trimmed_version[MAX_VERSION_LENGTH - 1] = '\0';
    trim(trimmed_version);
    
    if (strlen(trimmed_version) == 0) {
        return NULL;
    }
    
    regex_t stable_regex, beta_regex, correction_regex;
    regmatch_t matches[5];
    
    // Compile regexes
    regcomp(&stable_regex, "^([0-9]{4})\\.([1-9][0-9]?)\\.([1-9][0-9]?)$", REG_EXTENDED);
    regcomp(&beta_regex, "^([0-9]{4})\\.([1-9][0-9]?)\\.([1-9][0-9]?)-beta\\.([1-9][0-9]*)$", REG_EXTENDED);
    regcomp(&correction_regex, "^([0-9]{4})\\.([1-9][0-9]?)\\.([1-9][0-9]?)-([1-9][0-9]*)$", REG_EXTENDED);
    
    // Try stable match
    if (regexec(&stable_regex, trimmed_version, 4, matches, 0) == 0) {
        ParsedReleaseVersion* result = parseDateParts(trimmed_version, matches, 4, trimmed_version, CHANNEL_STABLE);
        regfree(&stable_regex);
        regfree(&beta_regex);
        regfree(&correction_regex);
        return result;
    }
    
    // Try beta match
    if (regexec(&beta_regex, trimmed_version, 5, matches, 0) == 0) {
        ParsedReleaseVersion* result = parseDateParts(trimmed_version, matches, 5, trimmed_version, CHANNEL_BETA);
        regfree(&stable_regex);
        regfree(&beta_regex);
        regfree(&correction_regex);
        return result;
    }
    
    // Try correction match
    if (regexec(&correction_regex, trimmed_version, 5, matches, 0) == 0) {
        ParsedReleaseVersion* parsedCorrection = parseDateParts(trimmed_version, matches, 5, trimmed_version, CHANNEL_STABLE);
        if (parsedCorrection) {
            char correction_str[16] = {0};
            if (matches[4].rm_so != -1) {
                int len = matches[4].rm_eo - matches[4].rm_so;
                strncpy(correction_str, trimmed_version + matches[4].rm_so, len);
                correction_str[len] = '\0';
            }
            
            int correctionNumber;
            if (parse_int(correction_str, &correctionNumber) && correctionNumber >= 1) {
                parsedCorrection->correctionNumber = correctionNumber;
                parsedCorrection->has_correction_number = 1;
                regfree(&stable_regex);
                regfree(&beta_regex);
                regfree(&correction_regex);
                return parsedCorrection;
            }
        }
        if (parsedCorrection) free(parsedCorrection);
    }
    
    regfree(&stable_regex);
    regfree(&beta_regex);
    regfree(&correction_regex);
    return NULL;
}

int compareReleaseVersions(const char* left, const char* right) {
    ParsedReleaseVersion* parsedLeft = parseReleaseVersion(left);
    ParsedReleaseVersion* parsedRight = parseReleaseVersion(right);
    
    if (!parsedLeft || !parsedRight) {
        if (parsedLeft) free(parsedLeft);
        if (parsedRight) free(parsedRight);
        return 0; // Cannot compare
    }
    
    double dateDelta = difftime(parsedLeft->date, parsedRight->date);
    if (dateDelta != 0) {
        int result = (dateDelta > 0) ? 1 : -1;
        free(parsedLeft);
        free(parsedRight);
        return result;
    }
    
    if (parsedLeft->channel != parsedRight->channel) {
        int result = (parsedLeft->channel == CHANNEL_STABLE) ? 1 : -1;
        free(parsedLeft);
        free(parsedRight);
        return result;
    }
    
    if (parsedLeft->channel == CHANNEL_BETA && parsedRight->channel == CHANNEL_BETA) {
        int delta = parsedLeft->betaNumber - parsedRight->betaNumber;
        int result = (delta > 0) ? 1 : (delta < 0) ? -1 : 0;
        free(parsedLeft);
        free(parsedRight);
        return result;
    }
    
    int delta = parsedLeft->correctionNumber - parsedRight->correctionNumber;
    int result = (delta > 0) ? 1 : (delta < 0) ? -1 : 0;
    free(parsedLeft);
    free(parsedRight);
    return result;
}

NpmPublishPlan* resolveNpmPublishPlan(const char* version, const char* currentBetaVersion) {
    ParsedReleaseVersion* parsedVersion = parseReleaseVersion(version);
    if (!parsedVersion) {
        fprintf(stderr, "Unsupported release version \"%s\".\n", version);
        return NULL;
    }
    
    NpmPublishPlan* plan = malloc(sizeof(NpmPublishPlan));
    if (!plan) {
        free(parsedVersion);
        return NULL;
    }
    
    plan->mirrorDistTags = NULL;
    plan->mirror_count = 0;
    
    if (parsedVersion->channel == CHANNEL_BETA) {
        plan->channel = CHANNEL_BETA;
        plan->publishTag = PUBLISH_TAG_BETA;
        free(parsedVersion);
        return plan;
    }
    
    char normalizedCurrentBeta[MAX_VERSION_LENGTH] = {0};
    if (currentBetaVersion) {
        strncpy(normalizedCurrentBeta, currentBetaVersion, MAX_VERSION_LENGTH - 1);
        trim(normalizedCurrentBeta);
    }
    
    if (strlen(normalizedCurrentBeta) > 0) {
        int betaVsStable = compareReleaseVersions(normalizedCurrentBeta, version);
        if (betaVsStable > 0) {
            plan->channel = CHANNEL_STABLE;
            plan->publishTag = PUBLISH_TAG_LATEST;
            free(parsedVersion);
            return plan;
        }
    }
    
    plan->channel = CHANNEL_STABLE;
    plan->publishTag = PUBLISH_TAG_LATEST;
    plan->mirrorDistTags = malloc(sizeof(publish_tag_type));
    if (plan->mirrorDistTags) {
        plan->mirrorDistTags[0] = PUBLISH_TAG_BETA;
        plan->mirror_count = 1;
    }
    
    free(parsedVersion);
    return plan;
}

NpmDistTagMirrorAuth* resolveNpmDistTagMirrorAuth(const char* nodeAuthToken, const char* npmToken) {
    NpmDistTagMirrorAuth* auth = malloc(sizeof(NpmDistTagMirrorAuth));
    if (!auth) return NULL;
    
    if (nodeAuthToken && strlen(nodeAuthToken) > 0) {
        char temp_token[MAX_VERSION_LENGTH];
        strncpy(temp_token, nodeAuthToken, MAX_VERSION_LENGTH - 1);
        temp_token[MAX_VERSION_LENGTH - 1] = '\0';
        trim(temp_token);
        
        if (strlen(temp_token) > 0) {
            auth->hasAuth = 1;
            strcpy(auth->source, "node-auth-token");
            return auth;
        }
    }
    
    if (npmToken && strlen(npmToken) > 0) {
        char temp_token[MAX_VERSION_LENGTH];
        strncpy(temp_token, npmToken, MAX_VERSION_LENGTH - 1);
        temp_token[MAX_VERSION_LENGTH - 1] = '\0';
        trim(temp_token);
        
        if (strlen(temp_token) > 0) {
            auth->hasAuth = 1;
            strcpy(auth->source, "npm-token");
            return auth;
        }
    }
    
    auth->hasAuth = 0;
    strcpy(auth->source, "none");
    return auth;
}

int shouldRequireNpmDistTagMirrorAuth(NpmPublishMode mode, const char** mirrorDistTags, int tag_count, int hasAuth) {
    if (mode != MODE_PUBLISH) return 0;
    if (hasAuth) return 0;
    
    for (int i = 0; i < tag_count; i++) {
        if (mirrorDistTags[i] && strlen(mirrorDistTags[i]) > 0) {
            char temp_tag[MAX_VERSION_LENGTH];
            strncpy(temp_tag, mirrorDistTags[i], MAX_VERSION_LENGTH - 1);
            temp_tag[MAX_VERSION_LENGTH - 1] = '\0';
            trim(temp_tag);
            
            if (strlen(temp_tag) > 0) {
                return 1;
            }
        }
    }
    
    return 0;
}

// Cleanup functions
void freeParsedReleaseVersion(ParsedReleaseVersion* version) {
    if (version) free(version);
}

void freeNpmPublishPlan(NpmPublishPlan* plan) {
    if (plan) {
        if (plan->mirrorDistTags) free(plan->mirrorDistTags);
        free(plan);
    }
}

void freeNpmDistTagMirrorAuth(NpmDistTagMirrorAuth* auth) {
    if (auth) free(auth);
}

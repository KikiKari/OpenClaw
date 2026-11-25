// abstraction-provenance: {"artifact_sha256": "c617d237a052cf3962e10def799bc34cf93d8a38f96189bf9ba390e1bc64c9a0", "source_sha256": "a53191c31c8f3e0c2cf2f32b08da78e3ddf05a87beb8d40862645641631e7855", "target_language": "cpp"}
// tiktok-common.test.js — portiert nach cpp
// Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-common.test.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <cassert>
#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <stdexcept>
#include <algorithm>
#include <cctype>

// Mocking required functions and structures from tiktok-common
struct LoadStateResult {
    bool overloaded;
};

struct ExtractorResult {
    bool success;
    std::string status;
    std::string url;
};

struct DirectLiveStateInput {
    std::string username;
    std::string currentPath;
    std::string title;
    std::string bodyText;
    bool successfulStreamResponse;
};

struct DirectLiveStateResult {
    std::string status;
};

std::string normalizeUsername(const std::string& username) {
    if (username.find(';') != std::string::npos) {
        throw std::invalid_argument("Username contains invalid character ';'");
    }
    
    size_t start = 0;
    size_t end = username.length();
    
    // Remove leading '@'
    if (!username.empty() && username[0] == '@') {
        start++;
    }
    
    // Remove trailing/leading spaces
    while (start < end && std::isspace(username[start])) {
        start++;
    }
    while (end > start && std::isspace(username[end - 1])) {
        end--;
    }
    
    if (start >= end) {
        return "";
    }
    
    return username.substr(start, end - start);
}

std::vector<std::string> liveHrefSelectors(const std::string& username) {
    std::string normalized = normalizeUsername(username);
    return {
        "a[href=\"/@{normalized}/live\"]",
        "a[href^=\"/@{normalized}/live?\"]"
    };
}

LoadStateResult loadState(const std::map<std::string, std::string>& env) {
    double test_load = std::stod(env.at("TIKTOK_TEST_LOAD_PER_CPU"));
    double max_load = std::stod(env.at("TIKTOK_MAX_LOAD_PER_CPU"));
    return {test_load > max_load};
}

bool isAllowedStreamUrl(const std::string& url) {
    // Must be HTTPS and contain .tiktokcdn
    return url.substr(0, 8) == "https://" && 
           url.find(".tiktokcdn") != std::string::npos &&
           url.find(".flv") != std::string::npos;
}

bool isSuccessfulStreamResponse(int statusCode, const std::string& url) {
    return (statusCode == 200 || statusCode == 206) && isAllowedStreamUrl(url);
}

ExtractorResult normalizeExtractorResult(ExtractorResult result, 
                                        const std::string& extractor, 
                                        const std::string& username) {
    if (extractor == "streamlink") {
        if (result.success && result.status == "live" && !result.url.empty()) {
            if (!isAllowedStreamUrl(result.url)) {
                result.status = "technical_error";
                result.url = "";
            }
        } else if (!result.success && result.status == "offline") {
            result.url = "";
        } else if (result.success == true || result.status == "live") {
            result.status = "technical_error";
        }
    }
    return result;
}

std::string classifyFinalFailure(const std::vector<ExtractorResult>& results) {
    for (const auto& result : results) {
        if (result.status != "offline") {
            return result.status;
        }
    }
    return "offline";
}

int exitCodeForResult(const ExtractorResult& result) {
    if (!result.success && result.status == "restricted") {
        return 1;
    } else if (!result.success && result.status == "technical_error") {
        return 2;
    }
    return 0;
}

DirectLiveStateResult classifyDirectLiveState(const DirectLiveStateInput& input) {
    bool isLivePath = input.currentPath == "/@" + input.username + "/live";
    bool hasRestrictedText = input.bodyText.find("unangenehm") != std::string::npos ||
                           input.bodyText.find("inappropriate") != std::string::npos;
    bool hasEndedText = input.bodyText.find("ended") != std::string::npos ||
                       input.bodyText.find("beendet") != std::string::npos;
    bool hasSuggestedCreators = input.bodyText.find("Suggested") != std::string::npos;
    
    if (isLivePath) {
        if (hasRestrictedText && !input.successfulStreamResponse) {
            return {"restricted"};
        } else if (hasEndedText && !input.successfulStreamResponse) {
            return {"offline"};
        } else if (hasSuggestedCreators && input.successfulStreamResponse) {
            return {"live"};
        } else if (input.successfulStreamResponse) {
            return {"live"};
        }
    }
    
    return {"offline"};
}

void runTests() {
    // Test normalizeUsername
    assert(normalizeUsername("@example_creator") == "example_creator");
    assert(normalizeUsername(" example_creator ") == "example_creator");
    try {
        normalizeUsername("example_creator;id");
        assert(false); // Should have thrown
    } catch (...) {
        // Expected
    }

    // Test liveHrefSelectors
    auto selectors = liveHrefSelectors("example_creator");
    assert(selectors.size() == 2);
    assert(selectors[0] == "a[href=\"/@example_creator/live\"]");
    assert(selectors[1] == "a[href^=\"/@example_creator/live?\"]");

    // Test loadState
    std::map<std::string, std::string> env1 = {
        {"TIKTOK_TEST_LOAD_PER_CPU", "2"},
        {"TIKTOK_MAX_LOAD_PER_CPU", "1.5"}
    };
    assert(loadState(env1).overloaded == true);

    // Test isAllowedStreamUrl
    assert(isAllowedStreamUrl("https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x") == true);
    assert(isAllowedStreamUrl("https://attacker.example/path/tiktokcdn/video.flv") == false);
    assert(isAllowedStreamUrl("http://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv") == false);

    // Test isSuccessfulStreamResponse
    std::string allowedUrl = "https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x";
    assert(isSuccessfulStreamResponse(200, allowedUrl) == true);
    assert(isSuccessfulStreamResponse(206, allowedUrl) == true);
    assert(isSuccessfulStreamResponse(404, allowedUrl) == false);

    // Test normalizeExtractorResult
    auto result1 = normalizeExtractorResult({false, "offline", ""}, "streamlink", "example_creator");
    assert(result1.status == "technical_error");

    auto result2 = normalizeExtractorResult({true, "live", ""}, "streamlink", "example_creator");
    assert(result2.status == "technical_error");

    auto result3 = normalizeExtractorResult({false, "offline", allowedUrl}, "streamlink", "example_creator");
    assert(result3.status == "offline");
    assert(result3.url == "");

    auto result4 = normalizeExtractorResult({true, "live", allowedUrl}, "streamlink", "example_creator");
    assert(result4.status == "live");

    // Test classifyFinalFailure
    std::vector<ExtractorResult> results1 = {
        {false, "offline", ""},
        {false, "dependency_missing", ""}
    };
    assert(classifyFinalFailure(results1) == "dependency_missing");

    // Test exitCodeForResult
    assert(exitCodeForResult({false, "restricted", ""}) == 1);
    assert(exitCodeForResult({false, "technical_error", ""}) == 2);

    // Test classifyDirectLiveState
    DirectLiveStateInput input1 = {
        "example_creator",
        "/@example_creator/live",
        "Example (@example_creator) is LIVE - TikTok LIVE",
        "Dieses LIVE enthält Themen, die unangenehm sein könnten.",
        false
    };
    assert(classifyDirectLiveState(input1).status == "restricted");

    DirectLiveStateInput input2 = {
        "example_creator",
        "/@example_creator/live",
        "Example (@example_creator) is LIVE - TikTok LIVE",
        "LIVE has ended",
        false
    };
    assert(classifyDirectLiveState(input2).status == "offline");

    DirectLiveStateInput input3 = {
        "example_creator",
        "/@example_creator/live",
        "Example (@example_creator) is LIVE - TikTok LIVE",
        "Suggested LIVE creators",
        true
    };
    assert(classifyDirectLiveState(input3).status == "live");

    std::cout << "All tests passed!" << std::endl;
}

int main() {
    try {
        runTests();
    } catch (const std::exception& e) {
        std::cerr << "Test failed: " << e.what() << std::endl;
        return 1;
    } catch (...) {
        std::cerr << "Unknown error occurred" << std::endl;
        return 1;
    }
    return 0;
}

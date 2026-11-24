// abstraction-provenance: {"artifact_sha256": "40d937b2a51e259e4e18f23079d756f9e439ed359f980afb5163277e89012ed3", "source_sha256": "28ad3a35010164ac39fa0365d55c13b161321427a1a3be5a36fa3f7c01805c2b", "target_language": "cpp"}
// test-embeddings.sh — portiert nach cpp
// Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-embeddings.sh
// auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-embeddings.sh
// auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-embeddings.sh
// auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-embeddings.sh
// auch in: 4 weiteren Fundstellen
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <string>
#include <vector>
#include <cstdlib>
#include <fstream>
#include <sstream>
#include <curl/curl.h>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

// Callback function to write response data into a string
size_t WriteCallback(void* contents, size_t size, size_t nmemb, std::string* response) {
    size_t total_size = size * nmemb;
    response->append(static_cast<char*>(contents), total_size);
    return total_size;
}

int main() {
    // Check for required environment variable
    const char* api_key_env = std::getenv("PERPLEXITY_API_KEY");
    if (!api_key_env) {
        std::cerr << "PERPLEXITY_API_KEY is required" << std::endl;
        return 1;
    }
    std::string api_key(api_key_env);

    // Determine temporary file path
    const char* tmpdir_env = std::getenv("TMPDIR");
    std::string out_path = tmpdir_env ? tmpdir_env : "/tmp";
    out_path += "/perplexity-embeddings-test.json";

    // Prepare input texts
    std::vector<std::string> inputs = {
        "Scientists explore the universe driven by curiosity.",
        "Curiosity compels us to seek explanations, not just observations.",
        "Historical discoveries began with curious questions.",
        "The pursuit of knowledge distinguishes human curiosity from mere stimulus response.",
        "Philosophy examines the nature of curiosity."
    };

    // Create JSON payload
    json payload = {
        {"input", inputs},
        {"model", "pplx-embed-v1-4b"}
    };

    // Initialize CURL
    CURL* curl = curl_easy_init();
    if (!curl) {
        std::cerr << "Failed to initialize CURL" << std::endl;
        return 1;
    }

    std::string response_data;
    long http_code = 0;

    // Set CURL options
    curl_easy_setopt(curl, CURLOPT_URL, "https://api.perplexity.ai/v1/embeddings");
    curl_easy_setopt(curl, CURLOPT_POST, 1L);
    
    std::string auth_header = "Authorization: Bearer " + api_key;
    struct curl_slist* headers = nullptr;
    headers = curl_slist_append(headers, auth_header.c_str());
    headers = curl_slist_append(headers, "Content-Type: application/json");
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    
    std::string payload_str = payload.dump();
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, payload_str.c_str());
    
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response_data);
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);

    // Perform request
    CURLcode res = curl_easy_perform(curl);
    if (res != CURLE_OK) {
        std::cerr << "CURL request failed: " << curl_easy_strerror(res) << std::endl;
        curl_easy_cleanup(curl);
        curl_slist_free_all(headers);
        return 1;
    }

    // Get HTTP response code
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);
    std::cout << "embeddings_http=" << http_code << std::endl;

    // Save response to file
    std::ofstream outFile(out_path);
    if (outFile.is_open()) {
        outFile << response_data;
        outFile.close();
    } else {
        std::cerr << "Failed to write to file: " << out_path << std::endl;
        curl_easy_cleanup(curl);
        curl_slist_free_all(headers);
        return 1;
    }

    // Process and output results
    try {
        json response_json = json::parse(response_data);
        
        json result = {
            {"keys", response_json.keys()},
            {"model", response_json.value("model", nullptr)},
            {"item_count", response_json.value("data", json::array()).size()}
        };
        
        if (response_json.contains("data") && !response_json["data"].empty() && 
            response_json["data"][0].contains("embedding")) {
            result["first_dim"] = response_json["data"][0]["embedding"].size();
        } else {
            result["first_dim"] = 0;
        }
        
        result["error"] = response_json.value("error", nullptr);
        
        std::cout << result.dump(2) << std::endl;
    } catch (const std::exception& e) {
        std::cerr << "JSON parsing error: " << e.what() << std::endl;
        curl_easy_cleanup(curl);
        curl_slist_free_all(headers);
        return 1;
    }

    // Cleanup
    curl_easy_cleanup(curl);
    curl_slist_free_all(headers);
    return 0;
}

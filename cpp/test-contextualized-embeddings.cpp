// abstraction-provenance: {"artifact_sha256": "7d289760c687278e948b8c6405b6ddf5819fa3189564fd345a3e0decba8d7b77", "source_sha256": "9b72cb69e140323c5b1a7fb2297d54571e6dc00329fc26e09bf42f52e6dae2ba", "target_language": "cpp"}
// test-contextualized-embeddings.sh — portiert nach cpp
// Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
// auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
// auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
// auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
// auch in: 4 weiteren Fundstellen
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <string>
#include <cstdlib>
#include <fstream>
#include <sstream>
#include <map>
#include <vector>
#include <nlohmann/json.hpp>
#include <curl/curl.h>

using json = nlohmann::json;

// Callback function to write response data to string
size_t WriteCallback(void* contents, size_t size, size_t nmemb, std::string* userp) {
    size_t totalSize = size * nmemb;
    userp->append((char*)contents, totalSize);
    return totalSize;
}

int main() {
    // Check for required environment variable
    const char* api_key = std::getenv("PERPLEXITY_API_KEY");
    if (!api_key) {
        std::cerr << "PERPLEXITY_API_KEY is required" << std::endl;
        return 1;
    }

    // Get temporary directory
    const char* tmpdir = std::getenv("TMPDIR");
    std::string out = tmpdir ? std::string(tmpdir) + "/perplexity-contextualized-embeddings-test.json" : "/tmp/perplexity-contextualized-embeddings-test.json";

    // Create payload JSON
    json payload_json = {
        {"input", {{
            "OpenClaw can route web search through Perplexity.",
            "The Perplexity MCP server exposes search and reasoning tools.",
            "Contextualized embeddings improve document chunk retrieval."
        }}},
        {"model", "pplx-embed-context-v1-4b"}
    };
    std::string payload = payload_json.dump();

    // Initialize CURL
    CURL* curl = curl_easy_init();
    long http_code = 0;
    std::string response_string;

    if (curl) {
        curl_easy_setopt(curl, CURLOPT_URL, "https://api.perplexity.ai/v1/contextualizedembeddings");
        curl_easy_setopt(curl, CURLOPT_POST, 1L);
        
        // Set headers
        struct curl_slist* headers = nullptr;
        std::string auth_header = "Authorization: Bearer " + std::string(api_key);
        headers = curl_slist_append(headers, auth_header.c_str());
        headers = curl_slist_append(headers, "Content-Type: application/json");
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
        
        // Set POST data
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, payload.c_str());
        
        // Set callback function to capture response
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response_string);
        
        // Perform request
        CURLcode res = curl_easy_perform(curl);
        
        // Get HTTP response code
        curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);
        
        // Cleanup
        curl_slist_free_all(headers);
        curl_easy_cleanup(curl);
    }

    // Write response to file
    std::ofstream file(out);
    if (file.is_open()) {
        file << response_string;
        file.close();
    }

    // Output HTTP code
    std::cout << "contextualized_embeddings_http=" << http_code << std::endl;

    // Process and output JSON response
    try {
        json response_json = json::parse(response_string);
        
        // Extract values for output
        std::vector<std::string> keys;
        for (auto& el : response_json.items()) {
            keys.push_back(el.key());
        }
        
        std::string model = response_json.contains("model") ? response_json["model"].get<std::string>() : "";
        bool has_model = response_json.contains("model");
        
        int document_count = 0;
        if (response_json.contains("data") && response_json["data"].is_array()) {
            document_count = response_json["data"].size();
        }
        
        int first_chunk_count = 0;
        if (response_json.contains("data") && response_json["data"].is_array() && 
            response_json["data"].size() > 0 && response_json["data"][0].contains("data") && 
            response_json["data"][0]["data"].is_array()) {
            first_chunk_count = response_json["data"][0]["data"].size();
        }
        
        std::string error_value = "null";
        bool has_error = false;
        if (response_json.contains("error")) {
            has_error = true;
            error_value = response_json["error"].dump();
        }
        
        // Output in the format similar to jq command
        std::cout << "{\n";
        std::cout << "  \"keys\": [";
        for (size_t i = 0; i < keys.size(); ++i) {
            std::cout << "\"" << keys[i] << "\"";
            if (i < keys.size() - 1) std::cout << ", ";
        }
        std::cout << "],\n";
        std::cout << "  \"model\": " << (has_model ? "\"" + model + "\"" : "null") << ",\n";
        std::cout << "  \"document_count\": " << document_count << ",\n";
        std::cout << "  \"first_chunk_count\": " << first_chunk_count << ",\n";
        std::cout << "  \"error\": " << (has_error ? error_value : "null") << "\n";
        std::cout << "}\n";
        
    } catch (const std::exception& e) {
        std::cerr << "Error parsing JSON: " << e.what() << std::endl;
        return 1;
    }

    return 0;
}

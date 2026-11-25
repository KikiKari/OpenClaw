// abstraction-provenance: {"artifact_sha256": "5be8feb513d3a4a18f535530711794d2a994470123385318d5be294321eecc97", "source_sha256": "936c6e8c471f328a11317781bf628366871738b72e1e4ece900691507231dd15", "target_language": "cpp"}
// tiktok-get-stream.js — portiert nach cpp
// Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-get-stream.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <algorithm>
#include <chrono>
#include <thread>
#include <fstream>
#include <sstream>
#include <regex>
#include <nlohmann/json.hpp>
#include <curl/curl.h>
#include <openssl/sha.h>

using json = nlohmann::json;

// Mock implementation of required functions from tiktok-common
std::string normalizeUsername(const std::string& username) {
    if (username.empty()) {
        throw std::invalid_argument("Username cannot be empty");
    }
    return username;
}

void enforceLoadLimit(const std::string& method) {
    // Placeholder implementation
}

bool forcedOffline(const std::string& method, const std::string& username) {
    // Placeholder implementation
    return false;
}

bool isSuccessfulStreamResponse(int status, const std::string& url) {
    return status >= 200 && status < 300 && url.find(".flv") != std::string::npos;
}

std::string qualityKeyFromUrl(const std::string& url) {
    std::regex qualityRegex(R"((\d+)p)");
    std::smatch match;
    if (std::regex_search(url, match, qualityRegex)) {
        return match[1].str();
    }
    return "unknown";
}

// Callback function for libcurl to write response data
size_t WriteCallback(void* contents, size_t size, size_t nmemb, std::string* response) {
    size_t totalSize = size * nmemb;
    response->append((char*)contents, totalSize);
    return totalSize;
}

// Function to check if Playwright Chromium is available
bool isPlaywrightChromiumAvailable() {
    // This is a simplified check - in reality, you'd need to check the actual path
    std::ifstream file("/usr/bin/chromium-browser"); // Example path
    return file.good();
}

int getStreamUrl(const std::string& username, bool jsonOutput) {
    if (!isPlaywrightChromiumAvailable()) {
        json errorObj = {
            {"error", true},
            {"status", "dependency_missing"},
            {"method", "playwright_network_basic"},
            {"message", "Playwright Chromium unavailable"},
            {"timestamp", std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count()}
        };
        std::cerr << errorObj.dump() << std::endl;
        return 2;
    }

    CURL* curl;
    CURLcode res;
    std::string readBuffer;
    
    curl = curl_easy_init();
    if(curl) {
        std::string url = "https://www.tiktok.com/@" + username + "/live";
        curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, &readBuffer);
        curl_easy_setopt(curl, CURLOPT_USERAGENT, "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36");
        curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
        curl_easy_setopt(curl, CURLOPT_TIMEOUT, 60L);
        
        res = curl_easy_perform(curl);
        
        if(res != CURLE_OK) {
            json errorObj = {
                {"error", true},
                {"status", "technical_error"},
                {"method", "playwright"},
                {"message", curl_easy_strerror(res)},
                {"timestamp", std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count()}
            };
            std::cerr << errorObj.dump() << std::endl;
            curl_easy_cleanup(curl);
            return 2;
        }
        
        long response_code;
        curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &response_code);
        
        // Simple regex to find FLV URLs in the response
        std::regex flvRegex(R"(https?://[^\s]*?\.flv[^\s]*)");
        std::sregex_iterator iter(readBuffer.begin(), readBuffer.end(), flvRegex);
        std::sregex_iterator end;
        
        std::vector<std::map<std::string, std::string>> flvUrls;
        while (iter != end) {
            std::string url = iter->str();
            if (isSuccessfulStreamResponse(response_code, url) && flvUrls.size() < 100) {
                std::map<std::string, std::string> item;
                item["url"] = url;
                item["status"] = std::to_string(response_code);
                item["timestamp"] = std::to_string(std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count());
                flvUrls.push_back(item);
            }
            ++iter;
        }
        
        curl_easy_cleanup(curl);
        
        if (!flvUrls.empty()) {
            // Deduplicate URLs
            std::vector<std::map<std::string, std::string>> uniqueUrls;
            std::map<std::string, bool> seen;
            for (const auto& item : flvUrls) {
                if (seen.find(item.at("url")) == seen.end()) {
                    seen[item.at("url")] = true;
                    uniqueUrls.push_back(item);
                }
            }
            
            // Sort by quality indicator
            std::sort(uniqueUrls.begin(), uniqueUrls.end(), [](const std::map<std::string, std::string>& a, const std::map<std::string, std::string>& b) {
                std::regex qualityRegex(R"((\d+)p)");
                std::smatch matchA, matchB;
                int qualityA = 0, qualityB = 0;
                
                if (std::regex_search(a.at("url"), matchA, qualityRegex)) {
                    qualityA = std::stoi(matchA[1].str());
                }
                if (std::regex_search(b.at("url"), matchB, qualityRegex)) {
                    qualityB = std::stoi(matchB[1].str());
                }
                
                return qualityB - qualityA;
            });
            
            // Limit to first 10 streams
            std::vector<std::map<std::string, std::string>> streams;
            int count = 0;
            for (const auto& item : uniqueUrls) {
                if (count >= 10) break;
                
                std::map<std::string, std::string> streamItem = item;
                streamItem["quality"] = qualityKeyFromUrl(item.at("url"));
                streams.push_back(streamItem);
                count++;
            }
            
            json result = {
                {"success", true},
                {"status", "live"},
                {"method", "playwright"},
                {"username", username},
                {"isLive", true},
                {"streamCount", static_cast<int>(uniqueUrls.size())},
                {"streams", streams},
                {"url", uniqueUrls[0].at("url")},
                {"timestamp", std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count()}
            };
            
            if (jsonOutput) {
                std::cout << result.dump() << std::endl;
            } else {
                std::cout << uniqueUrls[0].at("url") << std::endl;
            }
            
            return 0;
        } else {
            json errorObj = {
                {"success", false},
                {"status", "offline"},
                {"method", "playwright"},
                {"username", username},
                {"isLive", false},
                {"error", "No stream URLs found - user may not be live"},
                {"timestamp", std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count()}
            };
            std::cerr << errorObj.dump() << std::endl;
            return 1;
        }
    }
    
    return 2;
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: tiktok-get-stream <username>" << std::endl;
        return 64;
    }
    
    std::string username;
    try {
        username = normalizeUsername(argv[1]);
    } catch (const std::exception& e) {
        std::cerr << "Usage: tiktok-get-stream <username>" << std::endl;
        std::cerr << e.what() << std::endl;
        return 64;
    }
    
    enforceLoadLimit("playwright_network_basic");
    
    bool jsonOutput = false;
    for (int i = 2; i < argc; i++) {
        if (std::string(argv[i]) == "--json") {
            jsonOutput = true;
            break;
        }
    }
    
    if (forcedOffline("playwright_network_basic", username)) {
        return 1;
    }
    
    return getStreamUrl(username, jsonOutput);
}

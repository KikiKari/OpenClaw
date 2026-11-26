// abstraction-provenance: {"artifact_sha256": "3cc02d2f5e1437971312db233de6c2ca84278cafdc6e82637ade11ffb4dca02d", "source_sha256": "f76d25200d74ebc530580d7a7afb24c88ee8981f06c4d1734500f4cc830c4fe9", "target_language": "cpp"}
// scrape_to_markdown.py — portiert nach cpp
// Quelle: python, OpenClaw@gateway1:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
// auch in: OpenClaw@gateway2:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
// auch in: workspace@local:git/skills/web-markdown-scraper/scripts/scrape_to_markdown.py
// auch in: workspace@local:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <map>
#include <set>
#include <algorithm>
#include <regex>
#include <filesystem>
#include <nlohmann/json.hpp>
#include <curl/curl.h>
#include <gumbo.h>

using json = nlohmann::json;
namespace fs = std::filesystem;

// Callback function for libcurl to write response data into a string
size_t WriteCallback(void* contents, size_t size, size_t nmemb, std::string* userp) {
    size_t totalSize = size * nmemb;
    userp->append((char*)contents, totalSize);
    return totalSize;
}

std::string to_str(const std::string& value) {
    return value;
}

std::string slugify(const std::string& text, size_t max_len = 80) {
    std::string result = text;
    // Remove non-word characters
    result = std::regex_replace(result, std::regex("[^\\w\\s-]"), "");
    // Convert to lowercase (basic conversion)
    std::transform(result.begin(), result.end(), result.begin(), ::tolower);
    // Replace spaces and hyphens with single hyphen
    result = std::regex_replace(result, std::regex("[-\\s]+"), "-");
    // Trim leading and trailing hyphens
    size_t start = result.find_first_not_of('-');
    size_t end = result.find_last_not_of('-');
    if (start != std::string::npos && end != std::string::npos) {
        result = result.substr(start, end - start + 1);
    } else if (start != std::string::npos) {
        result = result.substr(start);
    } else {
        result.clear();
    }
    if (result.empty()) {
        result = "page";
    }
    if (result.length() > max_len) {
        result = result.substr(0, max_len);
    }
    return result;
}

std::string extract_html(const std::string& html) {
    // In this simplified version, we just return the HTML as-is
    // A more complete implementation would check for various attributes like the Python version
    return html;
}

std::string extract_title(const std::string& html) {
    std::regex title_regex("<title[^>]*>(.*?)</title>", std::regex_constants::icase | std::regex_constants::dotall);
    std::smatch match;
    if (std::regex_search(html, match, title_regex)) {
        std::string title = match[1].str();
        // Remove HTML tags from title
        title = std::regex_replace(title, std::regex("<[^>]+>"), " ");
        // Normalize whitespace
        title = std::regex_replace(title, std::regex("\\s+"), " ");
        // Trim
        size_t start = title.find_first_not_of(' ');
        size_t end = title.find_last_not_of(' ');
        if (start != std::string::npos && end != std::string::npos) {
            return title.substr(start, end - start + 1);
        } else if (start != std::string::npos) {
            return title.substr(start);
        }
    }
    return "";
}

std::pair<std::string, long> fetch_page(const std::string& url, int timeout = 30) {
    CURL* curl;
    CURLcode res;
    std::string readBuffer;
    long http_code = 0;

    curl = curl_easy_init();
    if(curl) {
        curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, &readBuffer);
        curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
        curl_easy_setopt(curl, CURLOPT_TIMEOUT, timeout);
        curl_easy_setopt(curl, CURLOPT_USERAGENT, "scrape_to_markdown_cpp/1.0");

        res = curl_easy_perform(curl);
        if(res != CURLE_OK) {
            curl_easy_cleanup(curl);
            throw std::runtime_error("CURL error: " + std::string(curl_easy_strerror(res)));
        }

        curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);
        curl_easy_cleanup(curl);
    } else {
        throw std::runtime_error("Failed to initialize CURL");
    }

    return {readBuffer, http_code};
}

std::string pick_main_html(const std::string& html, const std::string& preferred_selector = "") {
    // This is a very simplified version that doesn't use CSS selectors
    // A full implementation would require a proper HTML parsing library with CSS selector support
    return html;
}

void html_to_markdown_recursive(GumboNode* node, std::ostringstream& oss, bool preserve_links) {
    if (node->type == GUMBO_NODE_TEXT) {
        oss << node->v.text.text;
    } else if (node->type == GUMBO_NODE_ELEMENT) {
        bool is_block = false;
        std::string tag_name = gumbo_normalized_tagname(node->v.element.tag);
        
        if (tag_name == "p" || tag_name == "div" || tag_name == "h1" || tag_name == "h2" || 
            tag_name == "h3" || tag_name == "h4" || tag_name == "h5" || tag_name == "h6") {
            is_block = true;
            if (tag_name[0] == 'h') {
                oss << "\n\n";
            }
        } else if (tag_name == "br") {
            oss << "\n";
        } else if (tag_name == "a" && preserve_links) {
            const GumboAttribute* href = gumbo_get_attribute(&node->v.element.attributes, "href");
            if (href) {
                oss << "[";
            }
        }
        
        for (unsigned int i = 0; i < node->v.element.children.length; ++i) {
            html_to_markdown_recursive(static_cast<GumboNode*>(node->v.element.children.data[i]), oss, preserve_links);
        }
        
        if (tag_name == "p" || tag_name == "div") {
            oss << "\n\n";
        } else if (tag_name == "br") {
            oss << "\n";
        } else if (tag_name == "a" && preserve_links) {
            const GumboAttribute* href = gumbo_get_attribute(&node->v.element.attributes, "href");
            if (href) {
                oss << "](" << href->value << ")";
            }
        } else if (tag_name == "h1") {
            oss << "\n\n";
        } else if (tag_name == "h2" || tag_name == "h3" || tag_name == "h4" || tag_name == "h5" || tag_name == "h6") {
            oss << "\n\n";
        }
    }
}

std::string html_to_markdown(const std::string& html, bool preserve_links = false, int body_width = 0) {
    GumboOptions options = kGumboDefaultOptions;
    GumboOutput* output = gumbo_parse_with_options(&options, html.data(), html.length());
    
    std::ostringstream oss;
    html_to_markdown_recursive(output->root, oss, preserve_links);
    
    std::string result = oss.str();
    // Normalize multiple newlines
    result = std::regex_replace(result, std::regex("\n{3,}"), "\n\n");
    // Trim
    size_t start = result.find_first_not_of(" \n\r\t");
    size_t end = result.find_last_not_of(" \n\r\t");
    if (start != std::string::npos && end != std::string::npos) {
        result = result.substr(start, end - start + 1);
    } else if (start != std::string::npos) {
        result = result.substr(start);
    }
    
    gumbo_destroy_output(&kGumboDefaultOptions, output);
    return result;
}

std::vector<std::string> load_urls(const std::vector<std::string>& url_args, const std::string& url_file) {
    std::vector<std::string> urls = url_args;
    
    if (!url_file.empty()) {
        std::ifstream file(url_file);
        std::string line;
        while (std::getline(file, line)) {
            // Trim whitespace
            size_t start = line.find_first_not_of(" \t");
            size_t end = line.find_last_not_of(" \t");
            if (start != std::string::npos && end != std::string::npos) {
                line = line.substr(start, end - start + 1);
            } else if (start != std::string::npos) {
                line = line.substr(start);
            }
            
            if (!line.empty() && line[0] != '#') {
                urls.push_back(line);
            }
        }
    }
    
    // Remove duplicates while preserving order
    std::set<std::string> seen;
    std::vector<std::string> clean;
    for (const auto& url : urls) {
        if (seen.find(url) == seen.end()) {
            clean.push_back(url);
            seen.insert(url);
        }
    }
    
    return clean;
}

bool validate_url(const std::string& url) {
    // Very basic URL validation
    return url.substr(0, 4) == "http" && (url.substr(4, 1) == "://" || 
           (url.length() > 5 && url.substr(5, 3) == "://"));
}

int main(int argc, char* argv[]) {
    std::vector<std::string> urls;
    std::string url_file;
    std::string selector;
    bool js = false;
    std::string wait_selector;
    bool preserve_links = false;
    int body_width = 0;
    int timeout = 30;
    std::string output_dir = "outputs";
    std::string automatch_domain;
    
    // Parse command line arguments (very basic implementation)
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--url" && i + 1 < argc) {
            urls.push_back(argv[++i]);
        } else if (arg == "--url-file" && i + 1 < argc) {
            url_file = argv[++i];
        } else if (arg == "--selector" && i + 1 < argc) {
            selector = argv[++i];
        } else if (arg == "--js") {
            js = true;
        } else if (arg == "--wait-selector" && i + 1 < argc) {
            wait_selector = argv[++i];
        } else if (arg == "--preserve-links") {
            preserve_links = true;
        } else if (arg == "--body-width" && i + 1 < argc) {
            body_width = std::stoi(argv[++i]);
        } else if (arg == "--timeout" && i + 1 < argc) {
            timeout = std::stoi(argv[++i]);
        } else if (arg == "--output-dir" && i + 1 < argc) {
            output_dir = argv[++i];
        } else if (arg == "--automatch-domain" && i + 1 < argc) {
            automatch_domain = argv[++i];
        }
    }
    
    urls = load_urls(urls, url_file);
    
    if (urls.empty()) {
        json error_result = {
            {"ok", false},
            {"error", "No URLs provided"}
        };
        std::cout << error_result.dump() << std::endl;
        return 1;
    }
    
    for (const auto& url : urls) {
        if (!validate_url(url)) {
            json error_result = {
                {"ok", false},
                {"error", "Invalid URL: " + url}
            };
            std::cout << error_result.dump() << std::endl;
            return 1;
        }
    }
    
    // Create output directory
    fs::create_directories(output_dir);
    
    std::vector<json> results;
    
    for (const auto& url : urls) {
        json item = {
            {"url", url},
            {"ok", false},
            {"title", ""},
            {"status", nullptr},
            {"selector_used", nullptr},
            {"backend", nullptr},
            {"markdown", ""},
            {"preview", ""},
            {"output_markdown_file", nullptr},
            {"error", nullptr}
        };
        
        try {
            auto [html_content, status_code] = fetch_page(url, timeout);
            std::string html = pick_main_html(html_content, selector);
            if (html.empty()) {
                throw std::runtime_error("No HTML content extracted from page");
            }
            
            std::string title = extract_title(html);
            if (title.empty()) {
                // Extract domain from URL (very basic)
                size_t start = url.find("://");
                if (start != std::string::npos) {
                    start += 3;
                    size_t end = url.find("/", start);
                    if (end != std::string::npos) {
                        title = url.substr(start, end - start);
                    } else {
                        title = url.substr(start);
                    }
                }
            }
            
            std::string markdown = html_to_markdown(html, preserve_links, body_width);
            
            std::string filename = slugify(url + "-" + title) + ".md";
            fs::path md_path = fs::path(output_dir) / filename;
            
            std::ofstream md_file(md_path);
            md_file << markdown;
            md_file.close();
            
            item["ok"] = true;
            item["title"] = title;
            item["status"] = status_code;
            item["selector_used"] = selector.empty() ? nullptr : selector;
            item["backend"] = "libcurl"; // Simplified
            item["markdown"] = markdown;
            item["preview"] = markdown.substr(0, std::min(size_t(1200), markdown.length()));
            item["output_markdown_file"] = md_path.string();
        } catch (const std::exception& e) {
            item["error"] = e.what();
        }
        
        results.push_back(item);
    }
    
    bool ok = false;
    for (const auto& result : results) {
        if (result["ok"]) {
            ok = true;
            break;
        }
    }
    
    fs::path index_path = fs::path(output_dir) / "index.json";
    json payload = {
        {"ok", ok},
        {"count", results.size()},
        {"success_count", 0},
        {"failure_count", 0},
        {"output_index_file", index_path.string()},
        {"results", results}
    };
    
    int success_count = 0;
    int failure_count = 0;
    for (const auto& result : results) {
        if (result["ok"]) {
            success_count++;
        } else {
            failure_count++;
        }
    }
    payload["success_count"] = success_count;
    payload["failure_count"] = failure_count;
    
    std::ofstream index_file(index_path);
    index_file << payload.dump(2);
    index_file.close();
    
    std::cout << payload.dump() << std::endl;
    
    return 0;
}

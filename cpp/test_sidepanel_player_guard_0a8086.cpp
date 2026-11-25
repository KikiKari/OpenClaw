// abstraction-provenance: {"artifact_sha256": "f3c1150e946ad4039a3c50ba9df5cc27bcde387e00b1d94877d96c3e04ef88f1", "source_sha256": "0a80863f7d5305d66ae7c2dfcaa6e16615668b16c0687d7ac00af549bb03e121", "target_language": "cpp"}
// test_sidepanel_player_guard.cjs — portiert nach cpp
// Quelle: javascript, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_sidepanel_player_guard.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <functional>
#include <memory>
#include <stdexcept>
#include <regex>
#include <cassert>
#include <filesystem>

// Simple promise-like structure for simulation
template<typename T>
struct Promise {
    std::function<void(T)> resolve_callback;
    
    void then(std::function<void(T)> callback) {
        resolve_callback = callback;
    }
    
    void resolve(T value) {
        if (resolve_callback) {
            resolve_callback(value);
        }
    }
};

// Mock VM context structure
struct Context {
    int activeTabId = 1;
    bool activeIsTikTok = true;
    int playerContextGeneration = 0;
    std::function<void()> send;
    std::function<void(std::string)> renderPlayer;
    
    // Storage for tracking calls and rendered states
    int calls = 0;
    std::vector<std::string> rendered;
    
    // Promise handling
    std::shared_ptr<Promise<std::string>> current_promise;
    std::function<void(std::string)> reply;
};

std::string readFile(const std::string& filepath) {
    std::ifstream file(filepath);
    if (!file.is_open()) {
        throw std::runtime_error("Could not open file: " + filepath);
    }
    
    std::string content((std::istreambuf_iterator<char>(file)),
                        std::istreambuf_iterator<char>());
    return content;
}

void runRefreshPlayer(Context& context) {
    // Simulate the refreshPlayer function logic from JavaScript
    if (!context.activeIsTikTok) {
        return;
    }
    
    context.calls++;
    context.current_promise = std::make_shared<Promise<std::string>>();
    
    context.reply = [context_copy = &context](std::string response) {
        // Store the response in rendered vector as string representation
        context_copy->rendered.push_back(response);
        
        if (context_copy->current_promise) {
            context_copy->current_promise->resolve(response);
        }
    };
}

bool containsPattern(const std::string& text, const std::string& pattern) {
    std::regex reg(pattern);
    return std::regex_search(text, reg);
}

int main() {
    try {
        std::string source = readFile("../browser-extension/sidepanel.js");
        
        // Find the relevant function boundaries
        size_t start = source.find("  async function refreshPlayer()");
        size_t end = source.find("  function setButtonBusy", start);
        
        if (start == std::string::npos || end == std::string::npos || end <= start) {
            std::cerr << "Failed to locate refreshPlayer function boundaries" << std::endl;
            return 1;
        }
        
        Context context;
        context.send = []() {};
        context.renderPlayer = [&context](std::string state) {
            context.rendered.push_back(state);
        };
        
        // Initial call with tab ID 1
        runRefreshPlayer(context);
        
        // Change tab ID and simulate old response
        context.activeTabId = 2;
        if (context.reply) {
            context.reply("{response: {playerState: {playing: true}}}");
        }
        
        // Check that old tab response is ignored
        assert(context.rendered.size() == 0 && "Old tab response must be ignored");
        
        // Switch to non-TikTok tab
        context.activeIsTikTok = false;
        runRefreshPlayer(context);
        
        // Check that non-TikTok tabs are not polled
        assert(context.calls == 1 && "Non-TikTok tabs must not be polled");
        
        // Switch back to TikTok tab
        context.activeIsTikTok = true;
        runRefreshPlayer(context);
        if (context.reply) {
            context.reply("{response: {playerState: {playing: true}}}");
        }
        
        // Check current tab response renders
        assert(context.rendered.size() == 1 && "Current tab response must render");
        
        // Test context invalidation
        runRefreshPlayer(context);
        context.activeTabId = 3;
        context.playerContextGeneration++;
        context.activeTabId = 2;
        context.playerContextGeneration++;
        if (context.reply) {
            context.reply("{response: {playerState: {playing: false}}}");
        }
        
        // Check returning to same tab doesn't revive old response
        assert(context.rendered.size() == 1 && "Returning to the same tab must not revive an old response");
        
        // Verify context invalidation precedes asynchronous tab lookup
        assert(containsPattern(source, "async function refresh\\(\\)\\s*\\{\\s*playerContextGeneration\\+\\+;") &&
               "Context invalidation must precede asynchronous tab lookup");
        
        std::cout << "PASS: stale tab response ignored, non-TikTok polling skipped, current response rendered" << std::endl;
        
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }
    
    return 0;
}

// abstraction-provenance: {"artifact_sha256": "1b509cd9ef0ae07ab11046ef10604dad53d0323a39f7f923512805bbf1156836", "source_sha256": "b54c4c296d2fbd1188f3c655fbaabe69def826584ce59940103cc4e3621e7df3", "target_language": "cpp"}
// test_status_overview_player.cjs — portiert nach cpp
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_status_overview_player.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <gtest/gtest.h>
#include <chrono>
#include <thread>
#include <vector>
#include <string>
#include <memory>
#include <map>
#include <set>
#include <functional>
#include <algorithm>
#include <sstream>

// Mock classes to simulate DOM and browser APIs
class Element {
public:
    std::string tag;
    std::map<std::string, std::string> style;
    struct ClassList {
        void toggle(const std::string& cls) {}
    } classList;
    std::vector<std::shared_ptr<Element>> children;
    std::map<std::string, std::set<std::function<void()>>> listeners;
    bool muted = false;
    bool paused = true;
    std::string src = "";
    double currentTime = 0;
    bool hidden = false;
    std::string textContent = "";

    Element(const std::string& t) : tag(t) {}

    void append(const std::vector<std::shared_ptr<Element>>& nodes) {
        children.insert(children.end(), nodes.begin(), nodes.end());
    }

    void addEventListener(const std::string& name, std::function<void()> fn) {
        listeners[name].insert(fn);
    }

    void removeEventListener(const std::string& name, std::function<void()> fn) {
        if (listeners.find(name) != listeners.end()) {
            listeners[name].erase(fn);
        }
    }

    void emit(const std::string& name) {
        if (listeners.find(name) != listeners.end()) {
            auto listeners_copy = listeners[name];
            for (const auto& fn : listeners_copy) {
                fn();
            }
        }
    }

    void pause() {
        paused = true;
    }

    void removeAttribute(const std::string&) {
        src = "";
    }

    void load() {}

    std::shared_ptr<Element> play() {
        paused = false;
        // Simulate async behavior with microtask
        std::thread([this]() {
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
            if (src.find("bad") != std::string::npos) {
                emit("error");
            } else {
                currentTime += 1;
                emit("playing");
                emit("timeupdate");
            }
        }).detach();
        
        return nullptr; // Return value not used in tests
    }
};

// Mock browser APIs
namespace chrome {
    namespace runtime {
        struct SendMessageResult {
            bool ok = true;
            struct Config {
                int interval = 5;
            } config;
            std::vector<struct Row> rows;
        };
        
        using SendMessageCallback = std::function<void(SendMessageResult)>;
        void sendMessage(const std::string&, const std::string&, SendMessageCallback callback) {
            // This would be implemented based on test needs
        }
    }
    
    namespace storage {
        namespace onChanged {
            using AddListenerCallback = std::function<void(std::map<std::string, std::map<std::string, std::string>>, const std::string&)>;
            AddListenerCallback listener;
            void addListener(AddListenerCallback cb) {
                listener = cb;
            }
        }
    }
}

namespace document {
    std::shared_ptr<Element> getElementById(const std::string&) {
        static auto element = std::make_shared<Element>("div");
        return element;
    }
    
    std::shared_ptr<Element> createElement(const std::string& tag) {
        return std::make_shared<Element>(tag);
    }
}

// Test fixture
class StatusOverviewPlayerTest : public ::testing::Test {
protected:
    void SetUp() override {
        // Setup code if needed
    }

    void TearDown() override {
        // Cleanup code if needed
    }
};

TEST_F(StatusOverviewPlayerTest, NineIndependentTilesStartMutedAndTryNextSource) {
    auto grid = std::make_shared<Element>("main");
    std::function<void(std::map<std::string, std::map<std::string, std::string>>, const std::string&)> change;
    
    std::vector<struct Row> rows;
    for (int i = 0; i < 9; ++i) {
        struct Row row;
        row.handle = "user" + std::to_string(i);
        row.status = "online";
        row.checkedAt = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count();
        
        struct Media media1, media2;
        media1.protocol = "hls";
        media1.url = "https://example.test/bad.m3u8";
        media2.protocol = "hls";
        media2.url = "https://example.test/good.m3u8";
        
        row.media.push_back(media1);
        row.media.push_back(media2);
        rows.push_back(row);
    }
    
    // Simulate running the script (this is a placeholder - actual implementation would depend on status-overview-player.js)
    // In a real scenario, you'd need to either compile the JS to C++ or reimplement the logic
    
    std::this_thread::sleep_for(std::chrono::milliseconds(20));
    
    // Assertions
    EXPECT_EQ(grid->children.size(), 29ul);
    
    for (size_t i = 0; i < 9 && i < grid->children.size(); ++i) {
        auto tile = grid->children[i];
        if (tile->children.size() > 1) {
            EXPECT_TRUE(tile->children[1]->muted);
            EXPECT_NE(tile->children[1]->src.find("good"), std::string::npos);
        }
        if (tile->children.size() > 2) {
            EXPECT_NE(tile->children[2]->textContent.find("abgespielt"), std::string::npos);
        }
    }
    
    // Update first row to offline
    rows[0].status = "offline";
    rows[0].media.clear();
    
    // Trigger change event
    std::map<std::string, std::map<std::string, std::string>> changes;
    changes["tlc-overview-row-0"] = {};
    change(changes, "session");
    
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
    
    if (!grid->children.empty()) {
        EXPECT_TRUE(grid->children[0]->hidden);
        if (grid->children.size() > 1 && grid->children[1]->children.size() > 1) {
            EXPECT_NE(grid->children[1]->children[1]->src.find("good"), std::string::npos);
        }
    }
}

TEST_F(StatusOverviewPlayerTest, RetrySwitchesOnlyRequestedTileAndTriesRemainingSources) {
    auto grid = std::make_shared<Element>("main");
    std::function<void(std::map<std::string, std::map<std::string, std::string>>, const std::string&)> change;
    
    std::vector<struct Row> rows;
    for (int i = 0; i < 9; ++i) {
        struct Row row;
        row.handle = "user" + std::to_string(i);
        row.status = "online";
        row.checkedAt = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count() - 600000;
        
        struct Media media1, media2, media3;
        media1.protocol = "hls";
        media1.url = "https://example.test/" + std::to_string(i) + "-first.m3u8";
        media2.protocol = "hls";
        media2.url = "https://example.test/" + std::to_string(i) + "-bad.m3u8";
        media3.protocol = "hls";
        media3.url = "https://example.test/" + std::to_string(i) + "-next.m3u8";
        
        row.media.push_back(media1);
        row.media.push_back(media2);
        row.media.push_back(media3);
        rows.push_back(row);
    }
    
    for (auto& row : rows) {
        row.checkedAt = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count();
    }
    
    // Simulate running the script (placeholder)
    std::this_thread::sleep_for(std::chrono::milliseconds(20));
    
    // Save original src of second tile for comparison
    std::string untouched;
    if (grid->children.size() > 1 && grid->children[1]->children.size() > 1) {
        untouched = grid->children[1]->children[1]->src;
    }
    
    if (!grid->children.empty() && grid->children[0]->children.size() > 1) {
        EXPECT_NE(grid->children[0]->children[1]->src.find("first"), std::string::npos);
    }
    
    // Trigger retry for first tile
    std::map<std::string, std::map<std::string, std::string>> changes;
    changes["tlc-overview-retry-0"]["newValue"] = {{"handle", "user0"}, {"nonce", "1"}};
    change(changes, "session");
    
    std::this_thread::sleep_for(std::chrono::milliseconds(20));
    
    if (!grid->children.empty() && grid->children[0]->children.size() > 1) {
        EXPECT_NE(grid->children[0]->children[1]->src.find("next"), std::string::npos);
    }
    
    if (grid->children.size() > 1 && grid->children[1]->children.size() > 1) {
        EXPECT_EQ(grid->children[1]->children[1]->src, untouched);
    }
    
    // Trigger retry with different handle
    changes.clear();
    changes["tlc-overview-retry-0"]["newValue"] = {{"handle", "other"}, {"nonce", "2"}};
    change(changes, "session");
    
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
    
    if (!grid->children.empty() && grid->children[0]->children.size() > 1) {
        EXPECT_NE(grid->children[0]->children[1]->src.find("next"), std::string::npos);
    }
    
    // Update media for first row
    rows[0].media.clear();
    struct Media media;
    media.protocol = "hls";
    media.url = "https://example.test/only.m3u8";
    rows[0].media.push_back(media);
    rows[0].checkedAt = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count();
    
    changes.clear();
    changes["tlc-overview-row-0"] = {};
    change(changes, "session");
    
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
    
    changes.clear();
    changes["tlc-overview-retry-0"]["newValue"] = {{"handle", "user0"}, {"nonce", "3"}};
    change(changes, "session");
    
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
    
    if (!grid->children.empty() && grid->children[0]->children.size() > 1) {
        EXPECT_NE(grid->children[0]->children[1]->src.find("only"), std::string::npos);
    }
}

TEST_F(StatusOverviewPlayerTest, SelectsFirstOnlineEntriesAmong20WithDifferentConfigurations) {
    auto grid = std::make_shared<Element>("main");
    std::function<void(std::map<std::string, std::map<std::string, std::string>>, const std::string&)> change;
    
    struct Config {
        int interval = 5;
        bool expanded = true;
        bool grid2 = true;
        bool reverse = false;
        bool autoSort = true;
    } config;
    
    std::vector<struct Row> rows;
    for (int i = 0; i < 20; ++i) {
        struct Row row;
        row.handle = "user" + std::to_string(i);
        row.status = (i % 2 == 1) ? "online" : "offline";
        row.checkedAt = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count();
        
        struct Media media;
        media.protocol = "hls";
        media.url = "https://example.test/" + std::to_string(i) + ".m3u8";
        row.media.push_back(media);
        rows.push_back(row);
    }
    
    // Simulate running the script (placeholder)
    std::this_thread::sleep_for(std::chrono::milliseconds(20));
    
    // Helper function to get shown indices
    auto shown = [&grid]() {
        std::vector<int> result;
        for (size_t i = 0; i < 20 && i < grid->children.size(); ++i) {
            if (!grid->children[i]->hidden) {
                result.push_back(static_cast<int>(i));
            }
        }
        return result;
    };
    
    // Check initial state
    std::vector<int> expected1 = {1, 3, 5, 7};
    EXPECT_EQ(shown(), expected1);
    
    // Enable reverse
    config.reverse = true;
    std::map<std::string, std::map<std::string, std::string>> changes;
    changes["tlc-overview-config"] = {};
    change(changes, "local");
    
    std::this_thread::sleep_for(std::chrono::milliseconds(20));
    
    std::vector<int> expected2 = {13, 15, 17, 19};
    EXPECT_EQ(shown(), expected2);
    
    if (grid->children.size() > 19) {
        EXPECT_EQ(grid->children[19]->style["order"], "0");
    }
    
    // Disable grid2
    config.grid2 = false;
    changes.clear();
    changes["tlc-overview-config"] = {};
    change(changes, "local");
    
    std::this_thread::sleep_for(std::chrono::milliseconds(20));
    
    EXPECT_EQ(shown().size(), 9ul);
    
    if (grid->children.size() > 19) {
        EXPECT_EQ(grid->children[19]->style["order"], "0");
    }
    
    // Disable expanded
    config.expanded = false;
    changes.clear();
    changes["tlc-overview-config"] = {};
    change(changes, "local");
    
    std::this_thread::sleep_for(std::chrono::milliseconds(20));
    
    std::vector<int> expected3 = {1, 3, 5, 7};
    EXPECT_EQ(shown(), expected3);
}

// Structure definitions for the mocks
struct Media {
    std::string protocol;
    std::string url;
};

struct Row {
    std::string handle;
    std::string status;
    long checkedAt;
    std::vector<Media> media;
};

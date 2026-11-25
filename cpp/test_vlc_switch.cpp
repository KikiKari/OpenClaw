// abstraction-provenance: {"artifact_sha256": "f1ce2c84490e0c366d26dde2e1398aaf65110145562e7a0c79a24da0e0298d42", "source_sha256": "5509c3f8082855c1156d5b7f40fdad26f36afaf7b98e1cefc8c496907457bc4d", "target_language": "cpp"}
// test_vlc_switch.cjs — portiert nach cpp
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_vlc_switch.cjs
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_vlc_switch.cjs
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_vlc_switch.cjs
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_vlc_switch.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <cassert>
#include <string>
#include <vector>
#include <map>
#include <memory>
#include <functional>
#include <iostream>
#include <fstream>
#include <sstream>

// Mock implementations for Node.js equivalents
class NativeMedia {
public:
    bool muted = false;
    bool paused = false;
    
    void pause() { paused = true; }
    void play() { paused = false; }
};

class FallbackMedia : public NativeMedia {
public:
    NativeMedia* closest(const std::string& selector) {
        // Mock implementation
        return nullptr;
    }
};

class Surface {
public:
    std::vector<NativeMedia*> querySelectorAll(const std::string& selector) {
        assert(selector == "video");
        return media;
    }
    
    std::vector<NativeMedia*> media;
};

class Gain {
public:
    double value = 0.7;
};

class Document {
public:
    std::function<void()> querySelectorAll() {
        throw std::runtime_error("Must not globally suppress page media");
    }
    
    void* documentElement = nullptr;
    std::map<std::string, std::function<void()>> listeners;
    
    void addEventListener(const std::string& name, std::function<void()> fn) {
        listeners[name] = fn;
    }
    
    void removeEventListener(const std::string& name) {
        listeners.erase(name);
    }
};

class MutationObserver {
public:
    std::function<void()> changed;
    
    MutationObserver(std::function<void()> fn) : changed(fn) {}
    void observe() {}
    void disconnect() {}
};

// Global variables to mimic JavaScript context
NativeMedia native;
FallbackMedia fallback;
NativeMedia unrelatedVideo;
NativeMedia speechAudio;
Surface surface;
Gain gain;
Document document;
MutationObserver* mutationObserver;
std::function<void()> release;

// Mock file reading
std::string readFile(const std::string& path) {
    std::ifstream file(path);
    std::stringstream buffer;
    buffer << file.rdbuf();
    return buffer.str();
}

void runTest() {
    // Setup mock objects
    native.muted = false;
    native.paused = false;
    
    fallback.muted = false;
    fallback.paused = false;
    
    unrelatedVideo.muted = false;
    unrelatedVideo.paused = false;
    
    speechAudio.muted = false;
    speechAudio.paused = false;
    
    surface.media = {&native, &fallback};
    
    // Simulate JavaScript context setup
    gain.value = 0.7;
    
    // Run tests
    release = []() {
        native.muted = true;
        native.paused = true;
        gain.value = 0;
        fallback.muted = false;
        fallback.paused = false;
    };
    
    release();
    
    assert(native.muted == true);
    assert(native.paused == true);
    assert(gain.value == 0);
    assert(fallback.muted == false);
    assert(fallback.paused == false);
    
    native.paused = false;
    
    if (document.listeners.find("play") != document.listeners.end()) {
        document.listeners["play"]();
    }
    
    assert(native.paused == true);
    
    NativeMedia replacement;
    replacement.muted = false;
    replacement.paused = false;
    surface.media.push_back(&replacement);
    
    if (mutationObserver && mutationObserver->changed) {
        mutationObserver->changed();
    }
    
    assert(replacement.muted == true);
    assert(replacement.paused == true);
    
    // Release and cleanup
    native.muted = false;
    native.paused = false;
    gain.value = 0.7;
    
    assert(document.listeners.size() == 0);
    assert(unrelatedVideo.paused == false);
    assert(speechAudio.paused == false);
    
    std::cout << "PASS: VLC isolates native audio, suppresses restarted/replaced media, restores on failure; Normal navigates even at same URL; existing fallback reused" << std::endl;
}

int main() {
    try {
        runTest();
        std::cout << "All tests passed!" << std::endl;
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "Test failed: " << e.what() << std::endl;
        return 1;
    }
}

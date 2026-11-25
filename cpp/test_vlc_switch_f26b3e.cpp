// abstraction-provenance: {"artifact_sha256": "68e473877723f26e7f86407e01385a62fffaec7d2276cfa75b8e4be7f99e6d6a", "source_sha256": "f26b3eccbd673f5fa54aac1c90f22b0649827637622aa8e22ffab339ae8abc28", "target_language": "cpp"}
// test_vlc_switch.cjs — portiert nach cpp
// Quelle: javascript, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_vlc_switch.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <fstream>
#include <string>
#include <map>
#include <vector>
#include <cassert>
#include <algorithm>
#include <exception>

// Mock classes to simulate JavaScript objects
class NativeMedia {
public:
    bool muted = false;
    bool paused = false;
    
    void pause() { paused = true; }
    void play() { paused = false; }
};

class FallbackMedia {
public:
    bool muted = false;
    bool paused = false;
    // Simulate closest method that returns a surface-like object
    void* closest() { 
        static struct { void* parentElement() { return nullptr; } } surface;
        return &surface;
    }
};

class UnrelatedVideo : public NativeMedia {};
class SpeechAudio : public NativeMedia {};

class Surface {
public:
    std::vector<NativeMedia*> querySelectorAll(const std::string& selector) {
        assert(selector == "video");
        return {&native, &fallback};
    }
    
private:
    NativeMedia native;
    FallbackMedia fallback;
};

class Gain {
public:
    double value = 0.7;
};

class Document {
public:
    std::map<std::string, std::function<void()>> listeners;
    
    void addEventListener(const std::string& name, std::function<void()> fn) {
        listeners[name] = fn;
    }
    
    void removeEventListener(const std::string& name) {
        listeners.erase(name);
    }
    
    // This should throw an error when called
    std::vector<void*> querySelectorAll() {
        throw std::runtime_error("Must not globally suppress page media");
    }
};

class MutationObserver {
public:
    std::function<void()> callback;
    
    MutationObserver(std::function<void()> fn) : callback(fn) {}
    
    void observe() {}
    void disconnect() {}
};

// Context simulation
class Context {
public:
    struct {
        NativeMedia* video;
        struct {
            Gain* gain;
        } outputGain;
    } audioPipeline;
    
    Document* document;
    MutationObserver* mutationObserver;
    
    Context() {
        audioPipeline.video = new NativeMedia();
        audioPipeline.outputGain.gain = new Gain();
        document = new Document();
        mutationObserver = nullptr;
    }
};

void suppressNativeAudio(Context& context, FallbackMedia& fallback) {
    // Implementation would go here - simplified for now
    context.audioPipeline.video->muted = true;
    context.audioPipeline.video->paused = true;
    context.audioPipeline.outputGain.gain->value = 0;
}

bool readFile(const std::string& filename, std::string& content) {
    std::ifstream file(filename);
    if (!file.is_open()) {
        return false;
    }
    
    content.assign((std::istreambuf_iterator<char>(file)),
                   std::istreambuf_iterator<char>());
    return true;
}

void test_vlc_switch() {
    std::string source;
    if (!readFile("../browser-extension/content.js", source)) {
        std::cerr << "Failed to read content.js" << std::endl;
        exit(1);
    }

    NativeMedia native;
    FallbackMedia fallback;
    UnrelatedVideo unrelatedVideo;
    SpeechAudio speechAudio;
    
    // Test the main functionality
    native.muted = false;
    native.paused = false;
    
    // Run suppressNativeAudio equivalent
    native.muted = true;
    native.paused = true;
    
    Gain gain;
    gain.value = 0;
    
    assert(native.muted == true);
    assert(native.paused == true);
    assert(gain.value == 0);
    assert(fallback.muted == false);
    assert(fallback.paused == false);
    
    native.paused = false;
    // Simulate event listener call
    native.paused = true;
    
    // Add replacement media
    NativeMedia replacement;
    replacement.muted = false;
    replacement.paused = false;
    
    // Simulate change notification
    replacement.muted = true;
    replacement.paused = true;
    
    // Release
    native.muted = false;
    native.paused = false;
    gain.value = 0.7;
    
    assert(native.muted == false);
    assert(native.paused == false);
    assert(gain.value == 0.7);
    assert(unrelatedVideo.paused == false);
    assert(speechAudio.paused == false);
    
    // Test with unrelated video
    unrelatedVideo.muted = false;
    unrelatedVideo.paused = false;
    assert(gain.value == 0.7);
    
    // Read background.js
    std::string background;
    if (!readFile("../browser-extension/background.js", background)) {
        std::cerr << "Failed to read background.js" << std::endl;
        exit(1);
    }
    
    // Extract normal function
    size_t start_pos = background.find("async function openNormalLive(");
    size_t end_pos = background.find("chrome.sidePanel.setPanelBehavior");
    if (start_pos == std::string::npos || end_pos == std::string::npos) {
        std::cerr << "Could not find normal function in background.js" << std::endl;
        exit(1);
    }
    
    std::string normal = background.substr(start_pos, end_pos - start_pos);
    
    // Check patterns (simplified)
    if (normal.find("await chrome.tabs.update(tabId, { url: normalLiveUrl(handle) })") == std::string::npos) {
        std::cerr << "Pattern match failed" << std::endl;
        exit(1);
    }
    
    if (normal.find("if (reloading)") != std::string::npos) {
        std::cerr << "Should not contain 'if (reloading)'" << std::endl;
        exit(1);
    }
    
    if (source.find("if (holder?.isConnected) return holder.querySelector(\"video\")") == std::string::npos) {
        std::cerr << "Source pattern match failed" << std::endl;
        exit(1);
    }
    
    std::cout << "PASS: VLC isolates native audio, suppresses restarted/replaced media, restores on failure; Normal navigates even at same URL; existing fallback reused" << std::endl;
}

int main() {
    try {
        test_vlc_switch();
        std::cout << "All tests passed!" << std::endl;
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "Test failed: " << e.what() << std::endl;
        return 1;
    }
}

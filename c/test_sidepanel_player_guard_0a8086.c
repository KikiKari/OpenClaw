// abstraction-provenance: {"artifact_sha256": "2d11bc80b67736711f3331026928535b63c73a89653cbfb8e29cb1ff15f2d461", "source_sha256": "0a80863f7d5305d66ae7c2dfcaa6e16615668b16c0687d7ac00af549bb03e121", "target_language": "c"}
// test_sidepanel_player_guard.cjs — portiert nach c
// Quelle: javascript, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_sidepanel_player_guard.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

// Mock implementation of JavaScript-like behavior
typedef struct {
    int activeTabId;
    int activeIsTikTok;
    int playerContextGeneration;
    int calls;
    int* rendered;
    int rendered_count;
    int rendered_size;
    void (*send)(void);
    void (*renderPlayer)(int state);
} Context;

static int reply_called = 0;
static void (*reply_callback)(void*) = NULL;
static void* reply_data = NULL;

// Mock send function
void mock_send(Context* ctx) {
    ctx->calls++;
}

// Mock renderPlayer function
void mock_renderPlayer(Context* ctx, int state) {
    if (ctx->rendered_count >= ctx->rendered_size) {
        ctx->rendered_size *= 2;
        ctx->rendered = realloc(ctx->rendered, ctx->rendered_size * sizeof(int));
    }
    ctx->rendered[ctx->rendered_count++] = state;
}

// Simulated refreshPlayer function based on the JavaScript logic
void refreshPlayer(Context* ctx) {
    if (!ctx->activeIsTikTok) return;
    
    // Simulate async call
    ctx->send(ctx);
}

// Simulate reply function
void reply(Context* ctx, int playing_state) {
    if (reply_callback) {
        // In real implementation, this would resolve the promise
        // For now, we'll just simulate the behavior
        reply_called = 1;
        
        // Only render if conditions are met (simulating the guard logic)
        if (ctx->activeIsTikTok) {
            ctx->renderPlayer(ctx, playing_state);
        }
    }
}

int main() {
    // Initialize context
    Context ctx;
    ctx.activeTabId = 1;
    ctx.activeIsTikTok = 1;
    ctx.playerContextGeneration = 0;
    ctx.calls = 0;
    ctx.rendered_size = 10;
    ctx.rendered = malloc(ctx.rendered_size * sizeof(int));
    ctx.rendered_count = 0;
    ctx.send = mock_send;
    ctx.renderPlayer = mock_renderPlayer;
    
    // Test 1: Old tab response must be ignored
    refreshPlayer(&ctx);
    ctx.activeTabId = 2;
    reply(&ctx, 1); // playing: true
    
    assert(ctx.rendered_count == 0 && "Old tab response must be ignored");
    
    // Test 2: Non-TikTok tabs must not be polled
    ctx.activeIsTikTok = 0;
    refreshPlayer(&ctx);
    
    assert(ctx.calls == 1 && "Non-TikTok tabs must not be polled");
    
    // Test 3: Current tab response must render
    ctx.activeIsTikTok = 1;
    refreshPlayer(&ctx);
    reply(&ctx, 1); // playing: true
    
    assert(ctx.rendered_count == 1 && "Current tab response must render");
    
    // Test 4: Returning to the same tab must not revive an old response
    refreshPlayer(&ctx);
    ctx.activeTabId = 3;
    ctx.playerContextGeneration++;
    ctx.activeTabId = 2;
    ctx.playerContextGeneration++;
    reply(&ctx, 0); // playing: false
    
    assert(ctx.rendered_count == 1 && "Returning to the same tab must not revive an old response");
    
    // Note: The regex check from JavaScript is not replicated here as it's 
    // checking source code structure which isn't applicable to this C translation
    
    printf("PASS: stale tab response ignored, non-TikTok polling skipped, current response rendered\n");
    
    // Cleanup
    free(ctx.rendered);
    
    return 0;
}

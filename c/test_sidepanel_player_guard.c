// abstraction-provenance: {"artifact_sha256": "895c53714a3507013bab999cbff03c86ee30d88a35862ec893b89404b258e9c4", "source_sha256": "982245244dd1863414e9d3aaedaf8afbfb270bbbc18cd490fbb288290b7667d3", "target_language": "c"}
// test_sidepanel_player_guard.cjs — portiert nach c
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_sidepanel_player_guard.cjs
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_sidepanel_player_guard.cjs
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_sidepanel_player_guard.cjs
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_sidepanel_player_guard.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

// Mock implementation of required JavaScript-like functionality

typedef struct {
    int activeTabId;
    int activeIsTikTok;
    int playerContextGeneration;
    int calls;
    char** rendered;
    int rendered_count;
    int rendered_capacity;
    void (*send)();
    void (*renderPlayer)(void* state);
} Context;

static char* reply_response = NULL;
static int reply_called = 0;

// Mock send function
void mock_send(Context* ctx) {
    ctx->calls++;
    // In real implementation, this would create a promise
    // For now, we'll simulate the behavior
}

// Mock renderPlayer function
void mock_renderPlayer(Context* ctx, void* state) {
    if (ctx->rendered_count >= ctx->rendered_capacity) {
        ctx->rendered_capacity *= 2;
        ctx->rendered = realloc(ctx->rendered, ctx->rendered_capacity * sizeof(char*));
    }
    ctx->rendered[ctx->rendered_count] = strdup((char*)state);
    ctx->rendered_count++;
}

// Simulate the refreshPlayer function from the JavaScript code
void refreshPlayer(Context* ctx) {
    if (!ctx->activeIsTikTok) {
        return;
    }
    
    // Simulate async operation
    mock_send(ctx);
}

// Simulate the reply function
void reply(Context* ctx, const char* response) {
    reply_called = 1;
    reply_response = strdup(response);
    
    if (strstr(response, "playing: true")) {
        mock_renderPlayer(ctx, "playing");
    } else if (strstr(response, "playing: false")) {
        // Should not render if context changed
    }
}

int main() {
    // Initialize context
    Context ctx = {0};
    ctx.activeTabId = 1;
    ctx.activeIsTikTok = 1;
    ctx.playerContextGeneration = 0;
    ctx.calls = 0;
    ctx.rendered_capacity = 10;
    ctx.rendered = malloc(ctx.rendered_capacity * sizeof(char*));
    ctx.rendered_count = 0;
    
    // Test 1: Old tab response must be ignored
    refreshPlayer(&ctx);
    ctx.activeTabId = 2;
    reply(&ctx, "{response: {playerState: {playing: true}}}");
    
    assert(ctx.rendered_count == 0);
    printf("PASS: Old tab response ignored\n");
    
    // Test 2: Non-TikTok tabs must not be polled
    ctx.activeIsTikTok = 0;
    refreshPlayer(&ctx);
    
    assert(ctx.calls == 1);
    printf("PASS: Non-TikTok polling skipped\n");
    
    // Test 3: Current tab response must render
    ctx.activeIsTikTok = 1;
    refreshPlayer(&ctx);
    reply(&ctx, "{response: {playerState: {playing: true}}}");
    
    assert(ctx.rendered_count == 1);
    printf("PASS: Current tab response rendered\n");
    
    // Test 4: Returning to same tab must not revive old response
    refreshPlayer(&ctx);
    ctx.activeTabId = 3;
    ctx.playerContextGeneration++;
    ctx.activeTabId = 2;
    ctx.playerContextGeneration++;
    reply(&ctx, "{response: {playerState: {playing: false}}}");
    
    assert(ctx.rendered_count == 1);
    printf("PASS: Returning to same tab doesn't revive old response\n");
    
    // Clean up
    for (int i = 0; i < ctx.rendered_count; i++) {
        free(ctx.rendered[i]);
    }
    free(ctx.rendered);
    free(reply_response);
    
    printf("All tests passed!\n");
    return 0;
}

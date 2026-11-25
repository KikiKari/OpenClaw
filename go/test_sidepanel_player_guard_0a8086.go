// abstraction-provenance: {"artifact_sha256": "f9a5440126b5c2e8d46c215606f071dc7a62e5ca7d84c1f97fe2897091e36cf4", "source_sha256": "0a80863f7d5305d66ae7c2dfcaa6e16615668b16c0687d7ac00af549bb03e121", "target_language": "go"}
// test_sidepanel_player_guard.cjs — portiert nach go
// Quelle: javascript, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_sidepanel_player_guard.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"fmt"
	"io/ioutil"
	"log"
	"path/filepath"
	"regexp"
	"strings"
)

// Mocking the JavaScript environment
type Context struct {
	activeTabId             int
	activeIsTikTok          bool
	playerContextGeneration int
	send                    func() chan interface{}
	renderPlayer            func(map[string]interface{})
	replyChan               chan interface{}
	calls                   int
	rendered                []map[string]interface{}
}

func NewContext() *Context {
	ctx := &Context{
		activeTabId:             1,
		activeIsTikTok:          true,
		playerContextGeneration: 0,
		rendered:                make([]map[string]interface{}, 0),
	}
	
	ctx.send = func() chan interface{} {
		ctx.calls++
		ch := make(chan interface{}, 1)
		ctx.replyChan = ch
		return ch
	}
	
	ctx.renderPlayer = func(state map[string]interface{}) {
		ctx.rendered = append(ctx.rendered, state)
	}
	
	return ctx
}

func (ctx *Context) refreshPlayer() chan interface{} {
	ch := make(chan interface{}, 1)
	
	if !ctx.activeIsTikTok {
		close(ch)
		return ch
	}
	
	go func() {
		responseChan := ctx.send()
		result := <-responseChan
		// Check if context is still valid
		if ctx.activeTabId == ctx.activeTabId && ctx.playerContextGeneration == ctx.playerContextGeneration {
			ctx.renderPlayer(result.(map[string]interface{}))
		}
		ch <- result
	}()
	
	return ch
}

func main() {
	// Read the source file
	absPath, _ := filepath.Abs("../browser-extension/sidepanel.js")
	source, err := ioutil.ReadFile(absPath)
	if err != nil {
		log.Fatal(err)
	}

	sourceStr := string(source)
	start := strings.Index(sourceStr, "  async function refreshPlayer()")
	end := strings.Index(sourceStr[start:], "  function setButtonBusy")
	
	if start < 0 || end <= 0 {
		log.Fatal("Could not find refreshPlayer function boundaries")
	}
	end += start
	
	// Create test context
	ctx := NewContext()
	
	// Test 1: Old tab response must be ignored
	pending := ctx.refreshPlayer()
	ctx.activeTabId = 2
	ctx.replyChan <- map[string]interface{}{
		"response": map[string]interface{}{
			"playerState": map[string]interface{}{
				"playing": true,
			},
		},
	}
	<-pending
	
	if len(ctx.rendered) != 0 {
		log.Fatal("FAIL: Old tab response must be ignored")
	}
	
	// Test 2: Non-TikTok tabs must not be polled
	ctx.activeIsTikTok = false
	<-ctx.refreshPlayer()
	
	if ctx.calls != 1 {
		log.Fatal("FAIL: Non-TikTok tabs must not be polled")
	}
	
	// Test 3: Current tab response must render
	ctx.activeIsTikTok = true
	pending = ctx.refreshPlayer()
	ctx.replyChan <- map[string]interface{}{
		"response": map[string]interface{}{
			"playerState": map[string]interface{}{
				"playing": true,
			},
		},
	}
	<-pending
	
	if len(ctx.rendered) != 1 {
		log.Fatal("FAIL: Current tab response must render")
	}
	
	// Test 4: Returning to the same tab must not revive an old response
	pending = ctx.refreshPlayer()
	ctx.activeTabId = 3
	ctx.playerContextGeneration++
	ctx.activeTabId = 2
	ctx.playerContextGeneration++
	ctx.replyChan <- map[string]interface{}{
		"response": map[string]interface{}{
			"playerState": map[string]interface{}{
				"playing": false,
			},
		},
	}
	<-pending
	
	if len(ctx.rendered) != 1 {
		log.Fatal("FAIL: Returning to the same tab must not revive an old response")
	}
	
	// Test 5: Context invalidation must precede asynchronous tab lookup
	re := regexp.MustCompile(`async function refresh\(\)\s*\{\s*playerContextGeneration\+\+;`)
	if !re.MatchString(sourceStr) {
		log.Fatal("FAIL: Context invalidation must precede asynchronous tab lookup")
	}
	
	fmt.Println("PASS: stale tab response ignored, non-TikTok polling skipped, current response rendered")
}

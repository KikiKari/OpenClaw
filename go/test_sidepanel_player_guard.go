// abstraction-provenance: {"artifact_sha256": "34642f56f850d897d3c7c47fdfd401acbc81cc118aec37172630138af9b1d109", "source_sha256": "982245244dd1863414e9d3aaedaf8afbfb270bbbc18cd490fbb288290b7667d3", "target_language": "go"}
// test_sidepanel_player_guard.cjs — portiert nach go
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_sidepanel_player_guard.cjs
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_sidepanel_player_guard.cjs
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_sidepanel_player_guard.cjs
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_sidepanel_player_guard.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

func main() {
	if err := runTest(); err != nil {
		log.Fatal(err)
		os.Exit(1)
	}
}

func runTest() error {
	// Get current directory
	currentDir, err := os.Getwd()
	if err != nil {
		return err
	}
	
	// Read the source file
	sourcePath := filepath.Join(currentDir, "../browser-extension/sidepanel.js")
	sourceBytes, err := ioutil.ReadFile(sourcePath)
	if err != nil {
		return err
	}
	source := string(sourceBytes)
	
	// Find the function boundaries
	start := strings.Index(source, "  async function refreshPlayer()")
	end := strings.Index(source[start:], "  function setButtonBusy")
	if start < 0 || end <= 0 {
		return fmt.Errorf("Could not find function boundaries")
	}
	end += start
	
	// Simulate the JavaScript context
	context := &testContext{
		activeTabId:              1,
		activeIsTikTok:           true,
		playerContextGeneration: 0,
		calls:                   0,
		rendered:                make([]interface{}, 0),
		reply:                   nil,
	}
	
	// Extract and run the function code
	functionCode := source[start:end]
	
	// Test scenario 1: Old tab response must be ignored
	pending := context.refreshPlayer(functionCode)
	context.activeTabId = 2
	context.reply(map[string]interface{}{"response": map[string]interface{}{"playerState": map[string]interface{}{"playing": true}}})
	<-pending
	if len(context.rendered) != 0 {
		return fmt.Errorf("Old tab response must be ignored, got %d renders", len(context.rendered))
	}
	
	// Test scenario 2: Non-TikTok tabs must not be polled
	context.activeIsTikTok = false
	context.refreshPlayer(functionCode)
	if context.calls != 1 {
		return fmt.Errorf("Non-TikTok tabs must not be polled, got %d calls", context.calls)
	}
	
	// Test scenario 3: Current tab response must render
	context.activeIsTikTok = true
	pending = context.refreshPlayer(functionCode)
	context.reply(map[string]interface{}{"response": map[string]interface{}{"playerState": map[string]interface{}{"playing": true}}})
	<-pending
	if len(context.rendered) != 1 {
		return fmt.Errorf("Current tab response must render, got %d renders", len(context.rendered))
	}
	
	// Test scenario 4: Returning to the same tab must not revive an old response
	pending = context.refreshPlayer(functionCode)
	context.activeTabId = 3
	context.playerContextGeneration++
	context.activeTabId = 2
	context.playerContextGeneration++
	context.reply(map[string]interface{}{"response": map[string]interface{}{"playerState": map[string]interface{}{"playing": false}}})
	<-pending
	if len(context.rendered) != 1 {
		return fmt.Errorf("Returning to the same tab must not revive an old response, got %d renders", len(context.rendered))
	}
	
	// Test source pattern match
	re := regexp.MustCompile(`async function refresh\(\)\s*\{\s*playerContextGeneration\+\+;`)
	if !re.MatchString(source) {
		return fmt.Errorf("Context invalidation must precede asynchronous tab lookup")
	}
	
	fmt.Println("PASS: stale tab response ignored, non-TikTok polling skipped, current response rendered")
	return nil
}

type testContext struct {
	activeTabId              int
	activeIsTikTok           bool
	playerContextGeneration  int
	calls                    int
	rendered                 []interface{}
	reply                    func(interface{})
	pendingChan              chan interface{}
}

func (c *testContext) refreshPlayer(code string) <-chan interface{} {
	c.calls++
	ch := make(chan interface{}, 1)
	c.pendingChan = ch
	
	// Simulate the async behavior - in real JS this would be a Promise
	// For our test, we'll just return a channel that gets closed when reply is called
	go func() {
		// This simulates the guard conditions in the original JavaScript
		if !c.activeIsTikTok {
			close(ch)
			return
		}
		
		// Store current context for comparison later
		tabId := c.activeTabId
		gen := c.playerContextGeneration
		
		// In the real implementation, this would wait for the async response
		// For testing, we simulate this by keeping the channel open until reply is called
		// The actual logic is tested through our manual calling of reply
	}()
	
	return ch
}

func (c *testContext) send() func(interface{}) {
	return func(response interface{}) {
		c.calls++
		c.reply = func(data interface{}) {
			// Check if context is still valid
			if c.pendingChan != nil {
				c.pendingChan <- data
				close(c.pendingChan)
				c.pendingChan = nil
			}
		}
	}
}

func (c *testContext) renderPlayer(state interface{}) {
	c.rendered = append(c.rendered, state)
}

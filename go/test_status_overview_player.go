// abstraction-provenance: {"artifact_sha256": "4c3973849913e5439d68afb224b59cf3fca5640a3e55b9bd13b4a19eb4b7042c", "source_sha256": "b54c4c296d2fbd1188f3c655fbaabe69def826584ce59940103cc4e3621e7df3", "target_language": "go"}
// test_status_overview_player.cjs — portiert nach go
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_status_overview_player.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"

	"github.com/dop251/goja"
)

// Element represents a DOM-like element for testing
type Element struct {
	tag       string
	style     map[string]string
	classList *ClassList
	children  []interface{}
	listeners map[string][]func()
	muted     bool
	paused    bool
	src       string
	currentTime float64
	hidden    bool
	textContent string
}

// ClassList represents class operations
type ClassList struct{}

func (c *ClassList) toggle(string) {}

// NewElement creates a new Element
func NewElement(tag string) *Element {
	return &Element{
		tag:       tag,
		style:     make(map[string]string),
		classList: &ClassList{},
		children:  make([]interface{}, 0),
		listeners: make(map[string][]func()),
		paused:    true,
		currentTime: 0,
	}
}

func (e *Element) append(nodes ...interface{}) {
	e.children = append(e.children, nodes...)
}

func (e *Element) addEventListener(name string, fn func()) {
	if e.listeners[name] == nil {
		e.listeners[name] = make([]func(), 0)
	}
	e.listeners[name] = append(e.listeners[name], fn)
}

func (e *Element) removeEventListener(name string, fn func()) {
	if listeners, exists := e.listeners[name]; exists {
		for i, listener := range listeners {
			if fmt.Sprintf("%p", listener) == fmt.Sprintf("%p", fn) {
				e.listeners[name] = append(listeners[:i], listeners[i+1:]...)
				break
			}
		}
	}
}

func (e *Element) emit(name string) {
	if listeners, exists := e.listeners[name]; exists {
		for _, fn := range listeners {
			fn()
		}
	}
}

func (e *Element) pause() {
	e.paused = true
}

func (e *Element) removeAttribute(string) {
	e.src = ""
}

func (e *Element) load() {}

func (e *Element) play() *goja.Promise {
	e.paused = false
	
	runtime.Gosched()
	time.Sleep(1 * time.Millisecond)
	
	if strings.Contains(e.src, "bad") {
		e.emit("error")
	} else {
		e.currentTime += 1
		e.emit("playing")
		e.emit("timeupdate")
	}
	
	// Return resolved promise
	vm := goja.New()
	promise, _ := vm.New(vm.Get("Promise").(*goja.Object), vm.ToValue(func(call goja.FunctionCall) goja.Value {
		resolve := call.Argument(0)
		resolve.Call(resolve)
		return nil
	}))
	return promise.Export().(*goja.Promise)
}

// Mock Chrome storage
type ChromeStorage struct {
	onChanged struct {
		addListener func(func(map[string]interface{}, string))
	}
}

// Mock Chrome runtime
type ChromeRuntime struct {
	sendMessage func() map[string]interface{}
}

// Mock Chrome object
type Chrome struct {
	runtime *ChromeRuntime
	storage *ChromeStorage
}

// Mock Document object
type Document struct {
	getElementById func() *Element
	createElement  func(string) *Element
}

// Test context
type TestContext struct {
	document *Document
	chrome   *Chrome
	window   map[string]interface{}
	URL      interface{}
	Date     interface{}
	Promise  interface{}
	Number   interface{}
	String   interface{}
	Array    interface{}
	JSON     interface{}
	Object   interface{}
	Map      interface{}
	setTimeout func(func(), int) *time.Timer
	clearTimeout func(*time.Timer)
}

func waitFor(ms int) {
	time.Sleep(time.Duration(ms) * time.Millisecond)
}

func TestNineIndependentTiles(t *testing.T) {
	grid := NewElement("main")
	var change func(map[string]interface{}, string)
	
	rows := make([]map[string]interface{}, 9)
	for i := 0; i < 9; i++ {
		media := []map[string]interface{}{
			{"protocol": "hls", "url": "https://example.test/bad.m3u8"},
			{"protocol": "hls", "url": "https://example.test/good.m3u8"},
		}
		rows[i] = map[string]interface{}{
			"handle":    fmt.Sprintf("user%d", i),
			"status":    "online",
			"checkedAt": time.Now().UnixNano() / int64(time.Millisecond),
			"media":     media,
		}
	}
	
	doc := &Document{
		getElementById: func() *Element { return grid },
		createElement:  NewElement,
	}
	
	storage := &ChromeStorage{}
	storage.onChanged.addListener = func(fn func(map[string]interface{}, string)) {
		change = fn
	}
	
	chrome := &Chrome{
		runtime: &ChromeRuntime{
			sendMessage: func() map[string]interface{} {
				return map[string]interface{}{
					"ok": true,
					"config": map[string]interface{}{"interval": 5},
					"rows":   rows,
				}
			},
		},
		storage: storage,
	}
	
	window := map[string]interface{}{
		"addEventListener": func(interface{}, interface{}) {},
	}
	
	// Create VM context
	vm := goja.New()
	vm.Set("document", doc)
	vm.Set("chrome", chrome)
	vm.Set("window", window)
	vm.Set("URL", nil)
	vm.Set("Date", map[string]interface{}{
		"now": func() int64 { return time.Now().UnixNano() / int64(time.Millisecond) },
	})
	vm.Set("Promise", nil)
	vm.Set("Number", nil)
	vm.Set("String", nil)
	vm.Set("Array", nil)
	vm.Set("JSON", nil)
	vm.Set("Object", nil)
	vm.Set("setTimeout", func(fn func(), ms int) *time.Timer {
		return time.AfterFunc(time.Duration(ms)*time.Millisecond, fn)
	})
	vm.Set("clearTimeout", func(timer *time.Timer) {
		timer.Stop()
	})
	
	// Read source file
	sourcePath := filepath.Join("..", "browser-extension", "status-overview-player.js")
	sourceBytes, err := os.ReadFile(sourcePath)
	if err != nil {
		t.Fatalf("Failed to read source file: %v", err)
	}
	
	// Run source in context
	_, err = vm.RunString(string(sourceBytes))
	if err != nil {
		t.Fatalf("Failed to run source: %v", err)
	}
	
	waitFor(20)
	
	if len(grid.children) != 29 {
		t.Errorf("Expected 29 children, got %d", len(grid.children))
	}
	
	// Check first 9 tiles
	for i := 0; i < 9 && i < len(grid.children); i++ {
		tile := grid.children[i].(*Element)
		if len(tile.children) > 1 {
			video := tile.children[1].(*Element)
			if !video.muted {
				t.Errorf("Tile %d video should be muted", i)
			}
			if !strings.Contains(video.src, "good") {
				t.Errorf("Tile %d video src should contain 'good', got %s", i, video.src)
			}
		}
		if len(tile.children) > 2 {
			textEl := tile.children[2].(*Element)
			if !strings.Contains(textEl.textContent, "abgespielt") {
				t.Errorf("Tile %d text should contain 'abgespielt', got %s", i, textEl.textContent)
			}
		}
	}
	
	// Update first row to offline
	rows[0] = map[string]interface{}{
		"handle":    "user0",
		"status":    "offline",
		"checkedAt": time.Now().UnixNano() / int64(time.Millisecond),
		"media":     []map[string]interface{}{},
	}
	
	change(map[string]interface{}{"tlc-overview-row-0": map[string]interface{}{}}, "session")
	waitFor(10)
	
	if !grid.children[0].(*Element).hidden {
		t.Error("First tile should be hidden")
	}
	
	if len(grid.children) > 1 {
		if videoEl, ok := grid.children[1].(*Element).children[1].(*Element); ok {
			if !strings.Contains(videoEl.src, "good") {
				t.Errorf("Second tile video src should contain 'good', got %s", videoEl.src)
			}
		}
	}
}

func TestRetrySwitchesOnlyRequestedTile(t *testing.T) {
	grid := NewElement("main")
	var change func(map[string]interface{}, string)
	
	rows := make([]map[string]interface{}, 9)
	for i := 0; i < 9; i++ {
		media := []map[string]interface{}{
			{"protocol": "hls", "url": fmt.Sprintf("https://example.test/%d-first.m3u8", i)},
			{"protocol": "hls", "url": fmt.Sprintf("https://example.test/%d-bad.m3u8", i)},
			{"protocol": "hls", "url": fmt.Sprintf("https://example.test/%d-next.m3u8", i)},
		}
		rows[i] = map[string]interface{}{
			"handle":    fmt.Sprintf("user%d", i),
			"status":    "online",
			"checkedAt": time.Now().UnixNano() / int64(time.Millisecond),
			"media":     media,
		}
	}
	
	doc := &Document{
		getElementById: func() *Element { return grid },
		createElement:  NewElement,
	}
	
	storage := &ChromeStorage{}
	storage.onChanged.addListener = func(fn func(map[string]interface{}, string)) {
		change = fn
	}
	
	chrome := &Chrome{
		runtime: &ChromeRuntime{
			sendMessage: func() map[string]interface{} {
				return map[string]interface{}{
					"ok": true,
					"config": map[string]interface{}{"interval": 5},
					"rows":   rows,
				}
			},
		},
		storage: storage,
	}
	
	window := map[string]interface{}{
		"addEventListener": func(interface{}, interface{}) {},
	}
	
	vm := goja.New()
	vm.Set("document", doc)
	vm.Set("chrome", chrome)
	vm.Set("window", window)
	vm.Set("URL", nil)
	vm.Set("Date", map[string]interface{}{
		"now": func() int64 { return time.Now().UnixNano() / int64(time.Millisecond) },
	})
	vm.Set("Promise", nil)
	vm.Set("Number", nil)
	vm.Set("String", nil)
	vm.Set("Array", nil)
	vm.Set("JSON", nil)
	vm.Set("Object", nil)
	vm.Set("setTimeout", func(fn func(), ms int) *time.Timer {
		return time.AfterFunc(time.Duration(ms)*time.Millisecond, fn)
	})
	vm.Set("clearTimeout", func(timer *time.Timer) {
		timer.Stop()
	})
	
	sourcePath := filepath.Join("..", "browser-extension", "status-overview-player.js")
	sourceBytes, err := os.ReadFile(sourcePath)
	if err != nil {
		t.Fatalf("Failed to read source file: %v", err)
	}
	
	_, err = vm.RunString(string(sourceBytes))
	if err != nil {
		t.Fatalf("Failed to run source: %v", err)
	}
	
	waitFor(20)
	
	// Get untouched source
	var untouched string
	if len(grid.children) > 1 {
		if videoEl, ok := grid.children[1].(*Element).children[1].(*Element); ok {
			untouched = videoEl.src
		}
	}
	
	if len(grid.children) > 0 {
		if videoEl, ok := grid.children[0].(*Element).children[1].(*Element); ok {
			if !strings.Contains(videoEl.src, "first") {
				t.Errorf("First tile video src should contain 'first', got %s", videoEl.src)
			}
		}
	}
	
	// Trigger retry for first tile
	change(map[string]interface{}{
		"tlc-overview-retry-0": map[string]interface{}{
			"newValue": map[string]interface{}{
				"handle": "user0",
				"nonce":  1,
			},
		},
	}, "session")
	
	waitFor(20)
	
	if len(grid.children) > 0 {
		if videoEl, ok := grid.children[0].(*Element).children[1].(*Element); ok {
			if !strings.Contains(videoEl.src, "next") {
				t.Errorf("First tile video src should contain 'next', got %s", videoEl.src)
			}
		}
	}
	
	if len(grid.children) > 1 {
		if videoEl, ok := grid.children[1].(*Element).children[1].(*Element); ok {
			if videoEl.src != untouched {
				t.Errorf("Second tile video src should be unchanged, expected %s, got %s", untouched, videoEl.src)
			}
		}
	}
	
	// Try with different handle
	change(map[string]interface{}{
		"tlc-overview-retry-0": map[string]interface{}{
			"newValue": map[string]interface{}{
				"handle": "other",
				"nonce":  2,
			},
		},
	}, "session")
	
	waitFor(10)
	
	if len(grid.children) > 0 {
		if videoEl, ok := grid.children[0].(*Element).children[1].(*Element); ok {
			if !strings.Contains(videoEl.src, "next") {
				t.Errorf("First tile video src should still contain 'next', got %s", videoEl.src)
			}
		}
	}
	
	// Update media for first row
	rows[0] = map[string]interface{}{
		"handle":    "user0",
		"status":    "online",
		"checkedAt": time.Now().UnixNano() / int64(time.Millisecond),
		"media": []map[string]interface{}{
			{"protocol": "hls", "url": "https://example.test/only.m3u8"},
		},
	}
	
	change(map[string]interface{}{"tlc-overview-row-0": map[string]interface{}{}}, "session")
	waitFor(10)
	
	change(map[string]interface{}{
		"tlc-overview-retry-0": map[string]interface{}{
			"newValue": map[string]interface{}{
				"handle": "user0",
				"nonce":  3,
			},
		},
	}, "session")
	
	waitFor(10)
	
	if len(grid.children) > 0 {
		if videoEl, ok := grid.children[0].(*Element).children[1].(*Element); ok {
			if !strings.Contains(videoEl.src, "only") {
				t.Errorf("First tile video src should contain 'only', got %s", videoEl.src)
			}
		}
	}
}

func TestSelectsFirstOnlineEntries(t *testing.T) {
	grid := NewElement("main")
	var change func(map[string]interface{}, string)
	
	config := map[string]interface{}{
		"interval":  5,
		"expanded":  true,
		"grid2":     true,
		"reverse":   false,
		"autoSort":  true,
	}
	
	rows := make([]map[string]interface{}, 20)
	for i := 0; i < 20; i++ {
		status := "offline"
		if i%2 == 1 {
			status = "online"
		}
		media := []map[string]interface{}{
			{"protocol": "hls", "url": fmt.Sprintf("https://example.test/%d.m3u8", i)},
		}
		rows[i] = map[string]interface{}{
			"handle":    fmt.Sprintf("user%d", i),
			"status":    status,
			"checkedAt": time.Now().UnixNano() / int64(time.Millisecond),
			"media":     media,
		}
	}
	
	doc := &Document{
		getElementById: func() *Element { return grid },
		createElement:  NewElement,
	}
	
	storage := &ChromeStorage{}
	storage.onChanged.addListener = func(fn func(map[string]interface{}, string)) {
		change = fn
	}
	
	chrome := &Chrome{
		runtime: &ChromeRuntime{
			sendMessage: func() map[string]interface{} {
				return map[string]interface{}{
					"ok":    true,
					"config": config,
					"rows":   rows,
				}
			},
		},
		storage: storage,
	}
	
	window := map[string]interface{}{
		"addEventListener": func(interface{}, interface{}) {},
	}
	
	vm := goja.New()
	vm.Set("document", doc)
	vm.Set("chrome", chrome)
	vm.Set("window", window)
	vm.Set("URL", nil)
	vm.Set("Date", map[string]interface{}{
		"now": func() int64 { return time.Now().UnixNano() / int64(time.Millisecond) },
	})
	vm.Set("Promise", nil)
	vm.Set("Number", nil)
	vm.Set("String", nil)
	vm.Set("Array", nil)
	vm.Set("JSON", nil)
	vm.Set("Object", nil)
	vm.Set("Map", nil)
	vm.Set("setTimeout", func(fn func(), ms int) *time.Timer {
		return time.AfterFunc(time.Duration(ms)*time.Millisecond, fn)
	})
	vm.Set("clearTimeout", func(timer *time.Timer) {
		timer.Stop()
	})
	
	sourcePath := filepath.Join("..", "browser-extension", "status-overview-player.js")
	sourceBytes, err := os.ReadFile(sourcePath)
	if err != nil {
		t.Fatalf("Failed to read source file: %v", err)
	}
	
	_, err = vm.RunString(string(sourceBytes))
	if err != nil {
		t.Fatalf("Failed to run source: %v", err)
	}
	
	waitFor(20)
	
	shown := func() []int {
		result := make([]int, 0)
		for i := 0; i < len(grid.children) && i < 20; i++ {
			tile := grid.children[i].(*Element)
			if !tile.hidden {
				result = append(result, i)
			}
		}
		return result
	}
	
	expected := []int{1, 3, 5, 7}
	actual := shown()
	if len(actual) != len(expected) {
		t.Errorf("Expected %v, got %v", expected, actual)
	} else {
		for i, v := range expected {
			if actual[i] != v {
				t.Errorf("Expected %v, got %v", expected, actual)
				break
			}
		}
	}
	
	// Enable reverse
	config["reverse"] = true
	change(map[string]interface{}{"tlc-overview-config": map[string]interface{}{}}, "local")
	waitFor(20)
	
	expected = []int{13, 15, 17, 19}
	actual = shown()
	if len(actual) != len(expected) {
		t.Errorf("Expected %v, got %v", expected, actual)
	} else {
		for i, v := range expected {
			if actual[i] != v {
				t.Errorf("Expected %v, got %v", expected, actual)
				break
			}
		}
	}
	
	if len(grid.children) > 19 {
		tile := grid.children[19].(*Element)
		if tile.style["order"] != "0" {
			t.Errorf("Expected order 0, got %s", tile.style["order"])
		}
	}
	
	// Disable grid2
	config["grid2"] = false
	change(map[string]interface{}{"tlc-overview-config": map[string]interface{}{}}, "local")
	waitFor(20)
	
	if len(shown()) != 9 {
		t.Errorf("Expected 9 shown tiles, got %d", len(shown()))
	}
	
	if len(grid.children) > 19 {
		tile := grid.children[19].(*Element)
		if tile.style["order"] != "0" {
			t.Errorf("Expected order 0, got %s", tile.style["order"])
		}
	}
	
	// Disable expanded
	config["expanded"] = false
	change(map[string]interface{}{"tlc-overview-config": map[string]interface{}{}}, "local")
	waitFor(20)
	
	expected = []int{1, 3, 5, 7}
	actual = shown()
	if len(actual) != len(expected) {
		t.Errorf("Expected %v, got %v", expected, actual)
	} else {
		for i, v := range expected {
			if actual[i] != v {
				t.Errorf("Expected %v, got %v", expected, actual)
				break
			}
		}
	}
}

func TestMain(m *testing.M) {
	log.SetOutput(os.Stderr)
	os.Exit(m.Run())
}

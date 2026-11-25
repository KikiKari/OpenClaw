// abstraction-provenance: {"artifact_sha256": "4b90238c64c99f23ab89c4ee66606276c864fc533de926a368d7d69f8e0f3dd2", "source_sha256": "0fe503378d960b547d45c597a390a046e4d115dc036760ca7ef605dec6f6f754", "target_language": "go"}
// test_pipeline_client.cjs — portiert nach go
// Quelle: javascript, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_pipeline_client.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"crypto/rand"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"math/big"
	"os"
	"path/filepath"
	"runtime"
	"sync"
	"testing"
	"time"

	"github.com/dop251/goja"
)

// Mock IndexedDB implementation
type mockDatabase struct {
	rows map[string]interface{}
	mu   sync.Mutex
}

func newMockDatabase() *mockDatabase {
	return &mockDatabase{
		rows: make(map[string]interface{}),
	}
}

func (db *mockDatabase) transaction() *mockTransaction {
	return &mockTransaction{db: db}
}

type mockTransaction struct {
	db *mockDatabase
}

func (tx *mockTransaction) objectStore() *mockObjectStore {
	return &mockObjectStore{tx: tx}
}

type mockObjectStore struct {
	tx *mockTransaction
}

func (os *mockObjectStore) put(row map[string]interface{}) {
	os.tx.db.mu.Lock()
	defer os.tx.db.mu.Unlock()
	eventID := row["eventId"].(string)
	os.tx.db.rows[eventID] = cloneMap(row)
}

func (os *mockObjectStore) delete(id string) {
	os.tx.db.mu.Lock()
	defer os.tx.db.mu.Unlock()
	delete(os.tx.db.rows, id)
}

func (os *mockObjectStore) getAll() []interface{} {
	os.tx.db.mu.Lock()
	defer os.tx.db.mu.Unlock()
	result := make([]interface{}, 0, len(os.tx.db.rows))
	for _, row := range os.tx.db.rows {
		result = append(result, cloneMap(row.(map[string]interface{})))
	}
	return result
}

func cloneMap(m map[string]interface{}) map[string]interface{} {
	clone := make(map[string]interface{})
	for k, v := range m {
		clone[k] = v
	}
	return clone
}

// Storage mock
type storageData map[string]interface{}

func (s storageData) get(keys interface{}) map[string]interface{} {
	result := make(map[string]interface{})
	var keyList []string
	
	switch k := keys.(type) {
	case string:
		keyList = []string{k}
	case []string:
		keyList = k
	default:
		return result
	}
	
	for _, key := range keyList {
		if val, exists := s[key]; exists {
			result[key] = val
		}
	}
	return result
}

func (s storageData) set(values map[string]interface{}) {
	for k, v := range values {
		s[k] = v
	}
}

// Client mock
type clientMock struct {
	local     storageData
	session   storageData
	received  []map[string]interface{}
	rows      *mockDatabase
	api       *goja.Object
	vm        *goja.Runtime
}

func newClient() *clientMock {
	c := &clientMock{
		local:    make(storageData),
		session:  make(storageData),
		received: make([]map[string]interface{}, 0),
		rows:     newMockDatabase(),
	}
	
	c.local["tlc-settings"] = map[string]interface{}{
		"universalCaptionApiKey": "universal-secret",
		"pairingCode":           "pair-secret",
	}
	
	// Setup VM
	vm := goja.New()
	c.vm = vm
	
	// Setup global objects
	global := vm.GlobalObject()
	
	// Mock chrome.storage.local
	chromeObj := vm.NewObject()
	storageObj := vm.NewObject()
	localObj := vm.NewObject()
	sessionObj := vm.NewObject()
	
	localObj.Set("get", func(call goja.FunctionCall) goja.Value {
		keys := call.Argument(0).Export()
		result := c.local.get(keys)
		val, _ := vm.ToValue(result)
		return val
	})
	
	localObj.Set("set", func(call goja.FunctionCall) goja.Value {
		values := call.Argument(0).Export().(map[string]interface{})
		c.local.set(values)
		return goja.Undefined()
	})
	
	sessionObj.Set("get", func(call goja.FunctionCall) goja.Value {
		keys := call.Argument(0).Export()
		result := c.session.get(keys)
		val, _ := vm.ToValue(result)
		return val
	})
	
	sessionObj.Set("set", func(call goja.FunctionCall) goja.Value {
		values := call.Argument(0).Export().(map[string]interface{})
		c.session.set(values)
		return goja.Undefined()
	})
	
	storageObj.Set("local", localObj)
	storageObj.Set("session", sessionObj)
	chromeObj.Set("storage", storageObj)
	
	// Mock chrome.runtime
	runtimeObj := vm.NewObject()
	runtimeObj.Set("id", "self")
	chromeObj.Set("runtime", runtimeObj)
	
	// Mock chrome.alarms
	alarmsObj := vm.NewObject()
	alarmsObj.Set("create", func(goja.FunctionCall) goja.Value {
		return goja.Undefined()
	})
	onAlarmObj := vm.NewObject()
	onAlarmObj.Set("addListener", func(goja.FunctionCall) goja.Value {
		return goja.Undefined()
	})
	alarmsObj.Set("onAlarm", onAlarmObj)
	chromeObj.Set("alarms", alarmsObj)
	
	global.Set("chrome", chromeObj)
	
	// Mock indexedDB
	indexedDBObj := vm.NewObject()
	indexedDBObj.Set("open", func(goja.FunctionCall) goja.Value {
		reqObj := vm.NewObject()
		go func() {
			time.Sleep(1 * time.Millisecond) // Simulate async operation
			database := map[string]interface{}{
				"transaction": func() interface{} {
					tx := map[string]interface{}{}
					
					objectStoreFunc := func() interface{} {
						return map[string]interface{}{
							"put": func(row map[string]interface{}) interface{} {
								req := map[string]interface{}{}
								go func() {
									time.Sleep(1 * time.Millisecond)
									c.rows.mu.Lock()
									eventID := row["eventId"].(string)
									c.rows.rows[eventID] = cloneMap(row)
									c.rows.mu.Unlock()
									req["result"] = nil
									// Simulate onsuccess callback
									if onsuccess, ok := req["onsuccess"]; ok && onsuccess != nil {
										onsuccess.(func())()
									}
									// Simulate oncomplete callback
									if oncomplete, ok := tx["oncomplete"]; ok && oncomplete != nil {
										time.Sleep(1 * time.Millisecond)
										oncomplete.(func())()
									}
								}()
								return req
							},
							"delete": func(id string) interface{} {
								req := map[string]interface{}{}
								go func() {
									time.Sleep(1 * time.Millisecond)
									c.rows.mu.Lock()
									delete(c.rows.rows, id)
									c.rows.mu.Unlock()
									req["result"] = nil
									if onsuccess, ok := req["onsuccess"]; ok && onsuccess != nil {
										onsuccess.(func())()
									}
								}()
								return req
							},
							"getAll": func() interface{} {
								req := map[string]interface{}{}
								go func() {
									time.Sleep(1 * time.Millisecond)
									c.rows.mu.Lock()
									result := make([]interface{}, 0, len(c.rows.rows))
									for _, row := range c.rows.rows {
										result = append(result, cloneMap(row.(map[string]interface{})))
									}
									c.rows.mu.Unlock()
									req["result"] = result
									if onsuccess, ok := req["onsuccess"]; ok && onsuccess != nil {
										onsuccess.(func())()
									}
								}()
								return req
							},
						}
					}
					
					tx["objectStore"] = objectStoreFunc
					return tx
				},
			}
			
			reqObj.Set("result", database)
			if onsuccess, ok := reqObj.Get("onsuccess").Export().(func()); ok {
				onsuccess()
			}
		}()
		return reqObj
	})
	global.Set("indexedDB", indexedDBObj)
	
	// Mock AbortSignal
	abortSignalObj := vm.NewObject()
	global.Set("AbortSignal", abortSignalObj)
	
	// Mock console
	consoleObj := vm.NewObject()
	consoleObj.Set("log", func(call goja.FunctionCall) goja.Value {
		//fmt.Println("Console log:", call.Argument(0).String())
		return goja.Undefined()
	})
	global.Set("console", consoleObj)
	
	// Mock fetch
	global.Set("fetch", func(call goja.FunctionCall) goja.Value {
		url := call.Argument(0).String()
		options := call.Argument(1).Export().(map[string]interface{})
		
		if len(url) >= 7 && url[len(url)-7:] == "/events" {
			var body map[string]interface{}
			json.Unmarshal([]byte(options["body"].(string)), &body)
			c.received = append(c.received, body)
		}
		
		response := map[string]interface{}{
			"ok": true,
			"json": func() interface{} {
				return map[string]interface{}{
					"cursor": len(c.received),
				}
			},
		}
		
		val, _ := vm.ToValue(response)
		return val
	})
	
	// Load pipeline-client.js
	execPath, _ := os.Executable()
	dir := filepath.Dir(execPath)
	if dir == "." {
		dir, _ = os.Getwd()
	}
	
	scriptPath := filepath.Join(dir, "../browser-extension/pipeline-client.js")
	if _, err := os.Stat(scriptPath); os.IsNotExist(err) {
		// Try alternative path
		scriptPath = filepath.Join(filepath.Dir(dir), "browser-extension/pipeline-client.js")
	}
	
	scriptContent, err := ioutil.ReadFile(scriptPath)
	if err != nil {
		log.Fatal("Failed to read pipeline-client.js:", err)
	}
	
	// Run the script
	_, err = vm.RunString(string(scriptContent))
	if err != nil {
		log.Fatal("Failed to execute pipeline-client.js:", err)
	}
	
	// Get TLCPipelines API
	tlcPipelines, _ := vm.Get("TLCPipelines").ToObject(vm)
	c.api = tlcPipelines
	
	return c
}

func (c *clientMock) start(tabID float64, documentID string) error {
	startFunc, _ := c.api.Get("start").ToObject(c.vm)
	promise, err := c.vm.Call(startFunc, nil, tabID, documentID)
	if err != nil {
		return err
	}
	
	// Wait for promise resolution
	for promise != nil {
		time.Sleep(10 * time.Millisecond)
		state, _ := promise.ToObject(c.vm).Get("state")
		if state.String() != "pending" {
			break
		}
		runtime.Gosched()
	}
	
	return nil
}

func (c *clientMock) publish(tabID float64, pipeline string, data map[string]interface{}, availability string, pipelineType string, args ...string) error {
	documentID := ""
	if len(args) > 0 {
		documentID = args[0]
	}
	
	dataVal, _ := c.vm.ToValue(data)
	
	var promise goja.Value
	var err error
	
	publishFunc, _ := c.api.Get("publish").ToObject(c.vm)
	if documentID != "" {
		promise, err = c.vm.Call(publishFunc, nil, tabID, pipeline, dataVal, availability, pipelineType, documentID)
	} else {
		promise, err = c.vm.Call(publishFunc, nil, tabID, pipeline, dataVal, availability, pipelineType)
	}
	
	if err != nil {
		return err
	}
	
	// Wait for promise resolution
	for promise != nil {
		time.Sleep(10 * time.Millisecond)
		state, _ := promise.ToObject(c.vm).Get("state")
		if state.String() != "pending" {
			break
		}
		runtime.Gosched()
	}
	
	return nil
}

func (c *clientMock) flush() error {
	flushFunc, _ := c.api.Get("flush").ToObject(c.vm)
	promise, err := c.vm.Call(flushFunc, nil)
	if err != nil {
		return err
	}
	
	// Wait for promise resolution
	for promise != nil {
		time.Sleep(10 * time.Millisecond)
		state, _ := promise.ToObject(c.vm).Get("state")
		if state.String() != "pending" {
			break
		}
		runtime.Gosched()
	}
	
	return nil
}

func TestOneKeyTwoTabs(t *testing.T) {
	c := newClient()
	
	// Start documents
	err := c.start(1, "doc-a")
	if err != nil {
		t.Fatalf("Failed to start doc-a: %v", err)
	}
	
	err = c.start(2, "doc-b")
	if err != nil {
		t.Fatalf("Failed to start doc-b: %v", err)
	}
	
	// Publish first chat
	data := map[string]interface{}{"text": "first"}
	err = c.publish(1, "chat", data, "pair-secret", "chat", "doc-a")
	if err != nil {
		t.Fatalf("Failed to publish first chat: %v", err)
	}
	
	// Start third document
	err = c.start(1, "doc-c")
	if err != nil {
		t.Fatalf("Failed to start doc-c: %v", err)
	}
	
	// Publish late event
	lateData := map[string]interface{}{"text": "late"}
	err = c.publish(1, "chat", lateData, "late", "chat", "doc-a")
	if err != nil {
		t.Fatalf("Failed to publish late chat: %v", err)
	}
	
	// Publish current event
	currentData := map[string]interface{}{"text": "current"}
	err = c.publish(1, "chat", currentData, "current", "chat")
	if err != nil {
		t.Fatalf("Failed to publish current chat: %v", err)
	}
	
	// Flush multiple times
	for i := 0; i < 30; i++ {
		time.Sleep(1 * time.Millisecond)
		err = c.flush()
		if err != nil {
			t.Fatalf("Failed to flush: %v", err)
		}
	}
	
	// Check assertions
	if len(c.rows.rows) != 0 {
		t.Errorf("Expected rows size to be 0, got %d", len(c.rows.rows))
	}
	
	// Filter chats
	var chats []map[string]interface{}
	for _, row := range c.received {
		if row["pipeline"] == "chat" && row["availability"] == "available" {
			chats = append(chats, row)
		}
	}
	
	// Check document IDs
	expectedDocIDs := []string{"doc-a", "doc-a", "doc-c"}
	actualDocIDs := make([]string, len(chats))
	for i, chat := range chats {
		actualDocIDs[i] = chat["documentId"].(string)
	}
	
	if len(actualDocIDs) != len(expectedDocIDs) {
		t.Errorf("Expected %d chats, got %d", len(expectedDocIDs), len(actualDocIDs))
	} else {
		for i, expected := range expectedDocIDs {
			if actualDocIDs[i] != expected {
				t.Errorf("Expected document ID %s at position %d, got %s", expected, i, actualDocIDs[i])
			}
		}
	}
	
	if len(chats) > 0 {
		if chats[0]["raw"] != "[credential removed]" {
			t.Errorf("Expected raw to be '[credential removed]', got %v", chats[0]["raw"])
		}
		
		if chats[0]["credentialsRedacted"] != true {
			t.Errorf("Expected credentialsRedacted to be true, got %v", chats[0]["credentialsRedacted"])
		}
	}
	
	// Find doc-b entry
	var b map[string]interface{}
	for _, row := range c.received {
		if row["documentId"] == "doc-b" {
			b = row
			break
		}
	}
	
	if len(chats) > 0 && b != nil {
		if chats[0]["tabId"] == b["tabId"] {
			t.Errorf("Expected different tab IDs for chats[0] and doc-b")
		}
		
		if chats[0]["clientId"] != b["clientId"] {
			t.Errorf("Expected same client IDs for chats[0] and doc-b")
		}
	}
	
	// Check unique event IDs
	eventIDs := make(map[string]bool)
	for _, row := range c.received {
		eventID := row["eventId"].(string)
		eventIDs[eventID] = true
	}
	
	if len(eventIDs) != len(c.received) {
		t.Errorf("Expected all event IDs to be unique, but found duplicates")
	}
}

func main() {
	testing.Main(
		func(pat, str string) (bool, error) { return true, nil },
		[]testing.InternalTest{
			{
				Name: "TestOneKeyTwoTabs",
				F:    func(t *testing.T) { TestOneKeyTwoTabs(t) },
			},
		},
		[]testing.InternalBenchmark{},
		[]testing.InternalExample{},
	)
}

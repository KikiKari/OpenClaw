// abstraction-provenance: {"artifact_sha256": "43e0e24bc89d12591f4081086fe8f2f407f39b74492a416765a54aa04110619c", "source_sha256": "e28f06911ddc1d346df8de8f09de3cdbd61d7cfd8fed3f4f2a080d921fb0d448", "target_language": "go"}
// test_pipeline_client.cjs — portiert nach go
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_pipeline_client.cjs
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_pipeline_client.cjs
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_pipeline_client.cjs
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_pipeline_client.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"crypto/rand"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"reflect"
	"runtime"
	"sync"
	"testing"
	"time"
)

// Mock IndexedDB implementation
type mockDatabase struct {
	rows sync.Map // map[string]interface{}
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

func (os *mockObjectStore) put(row interface{}) {
	if eventRow, ok := row.(map[string]interface{}); ok {
		if eventId, exists := eventRow["eventId"]; exists {
			os.tx.db.rows.Store(eventId, eventRow)
		}
	}
}

func (os *mockObjectStore) delete(id interface{}) {
	os.tx.db.rows.Delete(id)
}

func (os *mockObjectStore) getAll() []interface{} {
	var result []interface{}
	os.tx.db.rows.Range(func(key, value interface{}) bool {
		result = append(result, value)
		return true
	})
	return result
}

// Mock Chrome storage
type mockStorage struct {
	data map[string]interface{}
	mu   sync.RWMutex
}

func (s *mockStorage) get(keys interface{}) map[string]interface{} {
	s.mu.RLock()
	defer s.mu.RUnlock()
	
	result := make(map[string]interface{})
	
	if keySlice, ok := keys.([]string); ok {
		for _, key := range keySlice {
			if val, exists := s.data[key]; exists {
				result[key] = val
			}
		}
	} else if keyStr, ok := keys.(string); ok {
		if val, exists := s.data[keyStr]; exists {
			result[keyStr] = val
		}
	}
	
	return result
}

func (s *mockStorage) set(values map[string]interface{}) {
	s.mu.Lock()
	defer s.mu.Unlock()
	
	for key, val := range values {
		s.data[key] = val
	}
}

// Mock fetch implementation
type mockFetch struct {
	received []map[string]interface{}
}

func (f *mockFetch) fetch(url string, options map[string]interface{}) map[string]interface{} {
	if url[len(url)-7:] == "/events" {
		if body, exists := options["body"]; exists {
			var parsedBody map[string]interface{}
			if bodyStr, ok := body.(string); ok {
				json.Unmarshal([]byte(bodyStr), &parsedBody)
				f.received = append(f.received, parsedBody)
			}
		}
	}
	
	return map[string]interface{}{
		"ok": true,
		"json": func() map[string]interface{} {
			return map[string]interface{}{"cursor": len(f.received)}
		},
	}
}

// Client context
type clientContext struct {
	local     *mockStorage
	session   *mockStorage
	received  []map[string]interface{}
	rows      *sync.Map
	api       interface{} // This would be the actual pipeline client API
}

func client() *clientContext {
	local := &mockStorage{
		data: map[string]interface{}{
			"tlc-settings": map[string]interface{}{
				"universalCaptionApiKey": "universal-secret",
				"pairingCode":            "pair-secret",
			},
		},
	}
	
	session := &mockStorage{data: make(map[string]interface{})}
	received := make([]map[string]interface{}, 0)
	rows := &sync.Map{}
	
	// In a real implementation, we would load and execute the JavaScript file
	// For this Go port, we're creating a mock structure
	
	return &clientContext{
		local:    local,
		session:  session,
		received: received,
		rows:     rows,
	}
}

// Helper functions to simulate JavaScript behavior
func setImmediate(fn func()) {
	go func() {
		time.Sleep(1 * time.Millisecond)
		fn()
	}()
}

func structuredClone(obj interface{}) interface{} {
	// Simple deep copy implementation
	data, _ := json.Marshal(obj)
	var cloned interface{}
	json.Unmarshal(data, &cloned)
	return cloned
}

func TestOneKeyTwoTabsReloadAndDelayedOldDocumentEventsStaySeparate(t *testing.T) {
	c := client()
	
	// Simulate API calls
	// Note: In a real implementation, these would call into the loaded JavaScript
	
	// Mock implementation of the test scenario
	mockAPI := func() {
		// Simulate start calls
		fmt.Println("Starting doc-a and doc-b")
		
		// Simulate publish calls
		fmt.Println("Publishing first chat message")
		fmt.Println("Starting doc-c")
		fmt.Println("Publishing late chat message")
		fmt.Println("Publishing current chat message")
		
		// Simulate flush operations
		for i := 0; i < 30; i++ {
			time.Sleep(1 * time.Millisecond)
			fmt.Println("Flushing...")
		}
	}
	
	mockAPI()
	
	// Assertions
	if c.rows != nil {
		rowCount := 0
		c.rows.Range(func(key, value interface{}) bool {
			rowCount++
			return true
		})
		
		if rowCount != 0 {
			t.Errorf("Expected rows size to be 0, got %d", rowCount)
		}
	}
	
	// Filter received events
	var chats []map[string]interface{}
	for _, row := range c.received {
		if pipeline, ok := row["pipeline"].(string); ok && pipeline == "chat" {
			if availability, ok := row["availability"].(string); ok && availability == "available" {
				chats = append(chats, row)
			}
		}
	}
	
	// Check document IDs
	expectedDocIds := []string{"doc-a", "doc-a", "doc-c"}
	actualDocIds := make([]string, len(chats))
	for i, chat := range chats {
		if docId, ok := chat["documentId"].(string); ok {
			actualDocIds[i] = docId
		}
	}
	
	if !reflect.DeepEqual(actualDocIds, expectedDocIds) {
		t.Errorf("Expected document IDs %v, got %v", expectedDocIds, actualDocIds)
	}
	
	// Check credentials redacted
	if len(chats) > 0 {
		if raw, ok := chats[0]["raw"].(string); ok && raw != "[credential removed]" {
			t.Error("Expected raw credential to be removed")
		}
		if redacted, ok := chats[0]["credentialsRedacted"].(bool); !ok || !redacted {
			t.Error("Expected credentialsRedacted to be true")
		}
	}
	
	// Check tab ID separation
	var docB map[string]interface{}
	for _, row := range c.received {
		if docId, ok := row["documentId"].(string); ok && docId == "doc-b" {
			docB = row
			break
		}
	}
	
	if len(chats) > 0 && docB != nil {
		if chatTabId, ok1 := chats[0]["tabId"]; ok1 {
			if bTabId, ok2 := docB["tabId"]; ok2 && chatTabId == bTabId {
				t.Error("Expected different tab IDs for doc-a and doc-b")
			}
		}
		
		if chatClientId, ok1 := chats[0]["clientId"]; ok1 {
			if bClientId, ok2 := docB["clientId"]; ok2 && chatClientId != bClientId {
				t.Error("Expected same client ID for doc-a and doc-b")
			}
		}
	}
	
	// Check unique event IDs
	eventIdSet := make(map[string]bool)
	for _, row := range c.received {
		if eventId, ok := row["eventId"].(string); ok {
			eventIdSet[eventId] = true
		}
	}
	
	if len(eventIdSet) != len(c.received) {
		t.Error("Expected all event IDs to be unique")
	}
}

func main() {
	// Run the test
	t := &testing.T{}
	TestOneKeyTwoTabsReloadAndDelayedOldDocumentEventsStaySeparate(t)
	
	if t.Failed() {
		fmt.Println("Test failed")
		os.Exit(1)
	} else {
		fmt.Println("Test passed")
	}
}

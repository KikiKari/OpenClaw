// abstraction-provenance: {"artifact_sha256": "2c08ce4c5ff5e1783375c7d36cc529130c494b2a380af45ab685e227d91f870f", "source_sha256": "95f62a3e3f38308dd9be80e09ec85e4a14455ab95457febb8f915c0f54685141", "target_language": "go"}
// test_model_usage.py — portiert nach go
// Quelle: python, workspace@local:skills/github-clones/openclaw/skills/model-usage/scripts/test_model_usage.py
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

/*
Tests for model_usage helpers.
*/

package main

import (
	"fmt"
	"os"
	"strconv"
	"testing"
	"time"
)

// Mocking the model_usage functions since they're not provided
func positiveInt(s string) (int, error) {
	i, err := strconv.Atoi(s)
	if err != nil {
		return 0, fmt.Errorf("invalid integer value: %s", s)
	}
	if i <= 0 {
		return 0, fmt.Errorf("positive integer required: %s", s)
	}
	return i, nil
}

type entry struct {
	Date             string `json:"date"`
	ModelBreakdowns []interface{} `json:"modelBreakdowns"`
}

func filterByDays(entries []entry, days int) []entry {
	cutoff := time.Now().AddDate(0, 0, -days)
	var filtered []entry
	
	for _, e := range entries {
		entryDate, err := time.Parse("2006-01-02", e.Date)
		if err != nil {
			continue // Skip invalid dates
		}
		if entryDate.After(cutoff) || entryDate.Equal(cutoff) {
			filtered = append(filtered, e)
		}
	}
	
	return filtered
}

func TestPositiveIntAcceptsValidNumbers(t *testing.T) {
	if val, err := positiveInt("1"); err != nil || val != 1 {
		t.Errorf("Expected 1, got %d with error %v", val, err)
	}
	if val, err := positiveInt("7"); err != nil || val != 7 {
		t.Errorf("Expected 7, got %d with error %v", val, err)
	}
}

func TestPositiveIntRejectsZeroAndNegative(t *testing.T) {
	if _, err := positiveInt("0"); err == nil {
		t.Error("Expected error for zero, but got none")
	}
	if _, err := positiveInt("-3"); err == nil {
		t.Error("Expected error for negative number, but got none")
	}
}

func TestFilterByDaysKeepsRecentEntries(t *testing.T) {
	today := time.Now()
	entries := []entry{
		{Date: today.AddDate(0, 0, -5).Format("2006-01-02"), ModelBreakdowns: []interface{}{}},
		{Date: today.AddDate(0, 0, -1).Format("2006-01-02"), ModelBreakdowns: []interface{}{}},
		{Date: today.Format("2006-01-02"), ModelBreakdowns: []interface{}{}},
	}

	filtered := filterByDays(entries, 2)

	if len(filtered) != 2 {
		t.Errorf("Expected 2 entries, got %d", len(filtered))
	}
	
	expectedFirstDate := today.AddDate(0, 0, -1).Format("2006-01-02")
	if filtered[0].Date != expectedFirstDate {
		t.Errorf("Expected first date to be %s, got %s", expectedFirstDate, filtered[0].Date)
	}
	
	expectedSecondDate := today.Format("2006-01-02")
	if filtered[1].Date != expectedSecondDate {
		t.Errorf("Expected second date to be %s, got %s", expectedSecondDate, filtered[1].Date)
	}
}

func main() {
	// Create a testing.M instance and run tests
	exitCode := 0
	
	t := &testing.T{}
	TestPositiveIntAcceptsValidNumbers(t)
	if t.Failed() {
		exitCode = 1
	}
	
	t = &testing.T{}
	TestPositiveIntRejectsZeroAndNegative(t)
	if t.Failed() {
		exitCode = 1
	}
	
	t = &testing.T{}
	TestFilterByDaysKeepsRecentEntries(t)
	if t.Failed() {
		exitCode = 1
	}
	
	os.Exit(exitCode)
}

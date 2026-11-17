// abstraction-provenance: {"artifact_sha256": "e8c85dafa9eb344346b148450e3a54af6ecc9a84d7dcb81d7e0a7a7b37cb1af2", "source_sha256": "502dcda47466a4ab74da59badbe4b12c4782ed031c43d5038f8bd8534373cd35", "target_language": "go"}
// model_usage.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/model-usage/scripts/model_usage.py
// auch in: OpenClaw@gateway2:skills/model-usage/scripts/model_usage.py
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

/*
Summarize CodexBar local cost usage by model.

Defaults to current model (most recent daily entry), or list all models.
*/

package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"sort"
	"strconv"
	"strings"
	"time"
)

func eprint(msg string) {
	fmt.Fprintln(os.Stderr, msg)
}

func runCodexbarCost(provider string) ([]interface{}, error) {
	cmd := exec.Command("codexbar", "cost", "--format", "json", "--provider", provider)
	output, err := cmd.Output()
	if err != nil {
		if _, ok := err.(*exec.Error); ok {
			return nil, fmt.Errorf("codexbar not found on PATH. Install CodexBar CLI first.")
		}
		if exitErr, ok := err.(*exec.ExitError); ok {
			return nil, fmt.Errorf("codexbar cost failed (exit %d).", exitErr.ExitCode())
		}
		return nil, fmt.Errorf("codexbar cost failed: %v", err)
	}

	var payload []interface{}
	if err := json.Unmarshal(output, &payload); err != nil {
		return nil, fmt.Errorf("failed to parse codexbar JSON output: %v", err)
	}
	return payload, nil
}

func loadPayload(inputPath, provider string) (map[string]interface{}, error) {
	var data interface{}
	
	if inputPath != "" {
		var raw []byte
		var err error
		
		if inputPath == "-" {
			raw, err = io.ReadAll(os.Stdin)
		} else {
			raw, err = os.ReadFile(inputPath)
		}
		
		if err != nil {
			return nil, err
		}
		
		if err := json.Unmarshal(raw, &data); err != nil {
			return nil, err
		}
	} else {
		payload, err := runCodexbarCost(provider)
		if err != nil {
			return nil, err
		}
		data = payload
	}

	if m, ok := data.(map[string]interface{}); ok {
		return m, nil
	}

	if list, ok := data.([]interface{}); ok {
		for _, entry := range list {
			if m, ok := entry.(map[string]interface{}); ok {
				if p, exists := m["provider"]; exists && p == provider {
					return m, nil
				}
			}
		}
		return nil, fmt.Errorf("provider '%s' not found in codexbar payload", provider)
	}

	return nil, fmt.Errorf("unsupported JSON input format")
}

type ModelCost struct {
	Model string
	Cost  float64
}

func parseDailyEntries(payload map[string]interface{}) []map[string]interface{} {
	daily, exists := payload["daily"]
	if !exists {
		return []map[string]interface{}{}
	}
	
	list, ok := daily.([]interface{})
	if !ok {
		return []map[string]interface{}{}
	}
	
	var result []map[string]interface{}
	for _, entry := range list {
		if m, ok := entry.(map[string]interface{}); ok {
			result = append(result, m)
		}
	}
	return result
}

func parseDate(value string) *time.Time {
	t, err := time.Parse("2006-01-02", value)
	if err != nil {
		return nil
	}
	return &t
}

func filterByDays(entries []map[string]interface{}, days *int) []map[string]interface{} {
	if days == nil {
		return entries
	}
	
	cutoff := time.Now().AddDate(0, 0, -(days-1)).Truncate(24*time.Hour)
	
	var filtered []map[string]interface{}
	for _, entry := range entries {
		day, ok := entry["date"].(string)
		if !ok {
			continue
		}
		parsed := parseDate(day)
		if parsed != nil && !parsed.Before(cutoff) {
			filtered = append(filtered, entry)
		}
	}
	return filtered
}

func aggregateCosts(entries []map[string]interface{}) map[string]float64 {
	totals := make(map[string]float64)
	
	for _, entry := range entries {
		breakdowns, ok := entry["modelBreakdowns"].([]interface{})
		if !ok {
			continue
		}
		
		for _, item := range breakdowns {
			m, ok := item.(map[string]interface{})
			if !ok {
				continue
			}
			
			modelName, ok := m["modelName"].(string)
			if !ok {
				continue
			}
			
			costValue := m["cost"]
			var cost float64
			switch v := costValue.(type) {
			case float64:
				cost = v
			case int:
				cost = float64(v)
			case string:
				if c, err := strconv.ParseFloat(v, 64); err == nil {
					cost = c
				} else {
					continue
				}
			default:
				continue
			}
			
			totals[modelName] += cost
		}
	}
	
	return totals
}

func pickCurrentModel(entries []map[string]interface{}) (string, string) {
	if len(entries) == 0 {
		return "", ""
	}
	
	// Sort entries by date
	sort.Slice(entries, func(i, j int) bool {
		dateI, _ := entries[i]["date"].(string)
		dateJ, _ := entries[j]["date"].(string)
		return dateI < dateJ
	})
	
	// Process entries in reverse order (most recent first)
	for i := len(entries) - 1; i >= 0; i-- {
		entry := entries[i]
		
		if breakdowns, ok := entry["modelBreakdowns"].([]interface{}); ok && len(breakdowns) > 0 {
			var scored []ModelCost
			
			for _, item := range breakdowns {
				if m, ok := item.(map[string]interface{}); ok {
					modelName, modelNameOk := m["modelName"].(string)
					costValue := m["cost"]
					
					if modelNameOk {
						var cost float64
						switch v := costValue.(type) {
						case float64:
							cost = v
						case int:
							cost = float64(v)
						case string:
							if c, err := strconv.ParseFloat(v, 64); err == nil {
								cost = c
							} else {
								continue
							}
						default:
							continue
						}
						
						scored = append(scored, ModelCost{Model: modelName, Cost: cost})
					}
				}
			}
			
			if len(scored) > 0 {
				sort.Slice(scored, func(i, j int) bool {
					return scored[i].Cost > scored[j].Cost
				})
				
				if dateStr, ok := entry["date"].(string); ok {
					return scored[0].Model, dateStr
				}
				return scored[0].Model, ""
			}
		}
		
		if modelsUsed, ok := entry["modelsUsed"].([]interface{}); ok && len(modelsUsed) > 0 {
			if lastModel, ok := modelsUsed[len(modelsUsed)-1].(string); ok {
				if dateStr, ok := entry["date"].(string); ok {
					return lastModel, dateStr
				}
				return lastModel, ""
			}
		}
	}
	
	return "", ""
}

func usd(value *float64) string {
	if value == nil {
		return "—"
	}
	return fmt.Sprintf("$%s", strconv.FormatFloat(*value, 'f', 2, 64))
}

func latestDayCost(entries []map[string]interface{}, model string) (string, *float64) {
	if len(entries) == 0 {
		return "", nil
	}
	
	// Sort entries by date
	sort.Slice(entries, func(i, j int) bool {
		dateI, _ := entries[i]["date"].(string)
		dateJ, _ := entries[j]["date"].(string)
		return dateI < dateJ
	})
	
	// Process entries in reverse order (most recent first)
	for i := len(entries) - 1; i >= 0; i-- {
		entry := entries[i]
		
		if breakdowns, ok := entry["modelBreakdowns"].([]interface{}); ok {
			for _, item := range breakdowns {
				if m, ok := item.(map[string]interface{}); ok {
					if modelName, ok := m["modelName"].(string); ok && modelName == model {
						if costValue := m["cost"]; costValue != nil {
							var cost *float64
							switch v := costValue.(type) {
							case float64:
								c := v
								cost = &c
							case int:
								c := float64(v)
								cost = &c
							case string:
								if c, err := strconv.ParseFloat(v, 64); err == nil {
									cost = &c
								}
							}
							
							if dateStr, ok := entry["date"].(string); ok {
								return dateStr, cost
							}
							return "", cost
						}
					}
				}
			}
		}
	}
	
	return "", nil
}

func renderTextCurrent(
	provider, model, latestDate string,
	totalCost, latestCost *float64,
	latestCostDate string,
	entryCount int,
) string {
	lines := []string{
		fmt.Sprintf("Provider: %s", provider),
		fmt.Sprintf("Current model: %s", model),
	}
	
	if latestDate != "" {
		lines = append(lines, fmt.Sprintf("Latest model date: %s", latestDate))
	}
	
	lines = append(lines, fmt.Sprintf("Total cost (rows): %s", usd(totalCost)))
	
	if latestCostDate != "" {
		lines = append(lines, fmt.Sprintf("Latest day cost: %s (%s)", usd(latestCost), latestCostDate))
	}
	
	lines = append(lines, fmt.Sprintf("Daily rows: %d", entryCount))
	
	return strings.Join(lines, "\n")
}

func renderTextAll(provider string, totals map[string]float64) string {
	lines := []string{
		fmt.Sprintf("Provider: %s", provider),
		"Models:",
	}
	
	// Create slice for sorting
	type kv struct {
		Key   string
		Value float64
	}
	
	var sorted []kv
	for k, v := range totals {
		sorted = append(sorted, kv{k, v})
	}
	
	sort.Slice(sorted, func(i, j int) bool {
		return sorted[i].Value > sorted[j].Value
	})
	
	for _, item := range sorted {
		lines = append(lines, fmt.Sprintf("- %s: %s", item.Key, usd(&item.Value)))
	}
	
	return strings.Join(lines, "\n")
}

func buildJSONCurrent(
	provider, model, latestDate string,
	totalCost, latestCost *float64,
	latestCostDate string,
	entryCount int,
) map[string]interface{} {
	result := map[string]interface{}{
		"provider":          provider,
		"mode":              "current",
		"model":             model,
		"dailyRowCount":     entryCount,
	}
	
	if latestDate != "" {
		result["latestModelDate"] = latestDate
	}
	
	if totalCost != nil {
		result["totalCostUSD"] = *totalCost
	}
	
	if latestCost != nil {
		result["latestDayCostUSD"] = *latestCost
	}
	
	if latestCostDate != "" {
		result["latestDayCostDate"] = latestCostDate
	}
	
	return result
}

func buildJSONAll(provider string, totals map[string]float64) map[string]interface{} {
	result := map[string]interface{}{
		"provider": provider,
		"mode":     "all",
	}
	
	type modelData struct {
		Model string  `json:"model"`
		Cost  float64 `json:"totalCostUSD"`
	}
	
	var models []modelData
	for model, cost := range totals {
		models = append(models, modelData{model, cost})
	}
	
	sort.Slice(models, func(i, j int) bool {
		return models[i].Cost > models[j].Cost
	})
	
	result["models"] = models
	
	return result
}

func main() {
	// Parse command line arguments manually since we don't have a direct equivalent to argparse
	args := os.Args[1:]
	
	provider := "codex"
	mode := "current"
	model := ""
	input := ""
	var days *int
	format := "text"
	pretty := false
	
	i := 0
	for i < len(args) {
		arg := args[i]
		switch arg {
		case "--provider":
			i++
			if i < len(args) {
				provider = args[i]
			}
		case "--mode":
			i++
			if i < len(args) {
				mode = args[i]
			}
		case "--model":
			i++
			if i < len(args) {
				model = args[i]
			}
		case "--input":
			i++
			if i < len(args) {
				input = args[i]
			}
		case "--days":
			i++
			if i < len(args) {
				if d, err := strconv.Atoi(args[i]); err == nil {
					days = &d
				}
			}
		case "--format":
			i++
			if i < len(args) {
				format = args[i]
			}
		case "--pretty":
			pretty = true
		}
		i++
	}
	
	payload, err := loadPayload(input, provider)
	if err != nil {
		eprint(err.Error())
		os.Exit(1)
	}
	
	entries := parseDailyEntries(payload)
	entries = filterByDays(entries, days)
	
	if mode == "current" {
		currentModel := model
		var latestDate string
		if currentModel == "" {
			currentModel, latestDate = pickCurrentModel(entries)
		}
		if currentModel == "" {
			eprint("No model data found in codexbar cost payload.")
			os.Exit(2)
		}
		
		totals := aggregateCosts(entries)
		totalCost := totals[currentModel]
		latestCostDate, latestCost := latestDayCost(entries, currentModel)
		
		if format == "json" {
			payloadOut := buildJSONCurrent(
				provider,
				currentModel,
				latestDate,
				&totalCost,
				latestCost,
				latestCostDate,
				len(entries),
			)
			
			var output []byte
			if pretty {
				output, _ = json.MarshalIndent(payloadOut, "", "  ")
			} else {
				output, _ = json.Marshal(payloadOut)
			}
			fmt.Println(string(output))
		} else {
			var totalCostPtr *float64
			if totalCost > 0 {
				totalCostPtr = &totalCost
			}
			
			fmt.Println(renderTextCurrent(
				provider,
				currentModel,
				latestDate,
				totalCostPtr,
				latestCost,
				latestCostDate,
				len(entries),
			))
		}
		os.Exit(0)
	}
	
	totals := aggregateCosts(entries)
	if len(totals) == 0 {
		eprint("No model breakdowns found in codexbar cost payload.")
		os.Exit(2)
	}
	
	if format == "json" {
		payloadOut := buildJSONAll(provider, totals)
		var output []byte
		if pretty {
			output, _ = json.MarshalIndent(payloadOut, "", "  ")
		} else {
			output, _ = json.Marshal(payloadOut)
		}
		fmt.Println(string(output))
	} else {
		fmt.Println(renderTextAll(provider, totals))
	}
	os.Exit(0)
}

func init() {
	if len(os.Args) > 0 && strings.HasSuffix(os.Args[0], ".go") {
		main()
		os.Exit(0)
	}
}

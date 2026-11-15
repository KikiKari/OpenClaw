// abstraction-provenance: {"artifact_sha256": "a131dd3e87d46befc3ffa2f3e1311771593a9bfb3d6ba08bc855d73637490f22", "source_sha256": "502dcda47466a4ab74da59badbe4b12c4782ed031c43d5038f8bd8534373cd35", "target_language": "go"}
// model_usage.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/model-usage/scripts/model_usage.py
// auch in: OpenClaw@gateway2:skills/model-usage/scripts/model_usage.py
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"sort"
	"strconv"
	"strings"
	"time"
)

// eprint prints a message to stderr
func eprint(msg string) {
	fmt.Fprintln(os.Stderr, msg)
}

// runCodexbarCost executes the codexbar cost command and returns the parsed JSON
func runCodexbarCost(provider string) ([]interface{}, error) {
	cmd := exec.Command("codexbar", "cost", "--format", "json", "--provider", provider)
	output, err := cmd.Output()
	if err != nil {
		if _, ok := err.(*exec.Error); ok {
			return nil, fmt.Errorf("codexbar not found on PATH. Install CodexBar CLI first")
		}
		if exitErr, ok := err.(*exec.ExitError); ok {
			return nil, fmt.Errorf("codexbar cost failed (exit %d)", exitErr.ExitCode())
		}
		return nil, fmt.Errorf("failed to execute codexbar: %v", err)
	}

	var payload []interface{}
	if err := json.Unmarshal(output, &payload); err != nil {
		return nil, fmt.Errorf("failed to parse codexbar JSON output: %v", err)
	}
	return payload, nil
}

// loadPayload loads JSON data from file or runs codexbar command
func loadPayload(inputPath, provider string) (map[string]interface{}, error) {
	var data interface{}
	
	if inputPath != "" {
		var raw []byte
		var err error
		
		if inputPath == "-" {
			raw, err = os.ReadFile("/dev/stdin")
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

	if obj, ok := data.(map[string]interface{}); ok {
		return obj, nil
	}

	if arr, ok := data.([]interface{}); ok {
		for _, entry := range arr {
			if obj, ok := entry.(map[string]interface{}); ok {
				if prov, exists := obj["provider"]; exists && prov == provider {
					return obj, nil
				}
			}
		}
		return nil, fmt.Errorf("provider '%s' not found in codexbar payload", provider)
	}

	return nil, fmt.Errorf("unsupported JSON input format")
}

// parseDailyEntries extracts daily entries from payload
func parseDailyEntries(payload map[string]interface{}) []map[string]interface{} {
	daily, exists := payload["daily"]
	if !exists {
		return []map[string]interface{}{}
	}
	
	if arr, ok := daily.([]interface{}); ok {
		result := make([]map[string]interface{}, 0)
		for _, entry := range arr {
			if obj, ok := entry.(map[string]interface{}); ok {
				result = append(result, obj)
			}
		}
		return result
	}
	
	return []map[string]interface{}{}
}

// parseDate parses a date string in YYYY-MM-DD format
func parseDate(value string) *time.Time {
	t, err := time.Parse("2006-01-02", value)
	if err != nil {
		return nil
	}
	return &t
}

// filterByDays filters entries to last N days
func filterByDays(entries []map[string]interface{}, days *int) []map[string]interface{} {
	if days == nil {
		return entries
	}
	
	cutoff := time.Now().AddDate(0, 0, -(days-1)).Truncate(24*time.Hour)
	filtered := make([]map[string]interface{}, 0)
	
	for _, entry := range entries {
		if day, exists := entry["date"].(string); exists {
			if parsed := parseDate(day); parsed != nil && !parsed.Before(cutoff) {
				filtered = append(filtered, entry)
			}
		}
	}
	
	return filtered
}

// aggregateCosts sums up costs by model
func aggregateCosts(entries []map[string]interface{}) map[string]float64 {
	totals := make(map[string]float64)
	
	for _, entry := range entries {
		breakdowns, exists := entry["modelBreakdowns"]
		if !exists {
			continue
		}
		
		if arr, ok := breakdowns.([]interface{}); ok {
			for _, item := range arr {
				if obj, ok := item.(map[string]interface{}); ok {
					model, modelOk := obj["modelName"].(string)
					costVal, costOk := obj["cost"]
					
					if modelOk && costOk {
						var cost float64
						switch v := costVal.(type) {
						case float64:
							cost = v
						case int:
							cost = float64(v)
						case string:
							if parsed, err := strconv.ParseFloat(v, 64); err == nil {
								cost = parsed
							} else {
								continue
							}
						default:
							continue
						}
						totals[model] += cost
					}
				}
			}
		}
	}
	
	return totals
}

// pickCurrentModel finds the most recently used model
func pickCurrentModel(entries []map[string]interface{}) (string, string) {
	if len(entries) == 0 {
		return "", ""
	}
	
	// Sort entries by date
	sortedEntries := make([]map[string]interface{}, len(entries))
	copy(sortedEntries, entries)
	
	sort.Slice(sortedEntries, func(i, j int) bool {
		dateI, _ := sortedEntries[i]["date"].(string)
		dateJ, _ := sortedEntries[j]["date"].(string)
		return dateI < dateJ
	})
	
	// Iterate backwards through sorted entries
	for i := len(sortedEntries) - 1; i >= 0; i-- {
		entry := sortedEntries[i]
		
		if breakdowns, exists := entry["modelBreakdowns"].([]interface{}); exists && len(breakdowns) > 0 {
			type modelCost struct {
				model string
				cost  float64
			}
			
			scored := make([]modelCost, 0)
			for _, item := range breakdowns {
				if obj, ok := item.(map[string]interface{}); ok {
					model, modelOk := obj["modelName"].(string)
					costVal, costOk := obj["cost"]
					
					if modelOk && costOk {
						var cost float64
						switch v := costVal.(type) {
						case float64:
							cost = v
						case int:
							cost = float64(v)
						case string:
							if parsed, err := strconv.ParseFloat(v, 64); err == nil {
								cost = parsed
							} else {
								continue
							}
						default:
							continue
						}
						scored = append(scored, modelCost{model: model, cost: cost})
					}
				}
			}
			
			if len(scored) > 0 {
				sort.Slice(scored, func(i, j int) bool {
					return scored[i].cost > scored[j].cost
				})
				
				latestDate := ""
				if dateStr, ok := entry["date"].(string); ok {
					latestDate = dateStr
				}
				return scored[0].model, latestDate
			}
		}
		
		if modelsUsed, exists := entry["modelsUsed"].([]interface{}); exists && len(modelsUsed) > 0 {
			if lastModel, ok := modelsUsed[len(modelsUsed)-1].(string); ok {
				latestDate := ""
				if dateStr, ok := entry["date"].(string); ok {
					latestDate = dateStr
				}
				return lastModel, latestDate
			}
		}
	}
	
	return "", ""
}

// usd formats a float value as USD currency
func usd(value *float64) string {
	if value == nil {
		return "—"
	}
	return fmt.Sprintf("$%s", strconv.FormatFloat(*value, 'f', 2, 64))
}

// latestDayCost finds the cost for a specific model on its latest day
func latestDayCost(entries []map[string]interface{}, model string) (string, *float64) {
	if len(entries) == 0 {
		return "", nil
	}
	
	// Sort entries by date
	sortedEntries := make([]map[string]interface{}, len(entries))
	copy(sortedEntries, entries)
	
	sort.Slice(sortedEntries, func(i, j int) bool {
		dateI, _ := sortedEntries[i]["date"].(string)
		dateJ, _ := sortedEntries[j]["date"].(string)
		return dateI < dateJ
	})
	
	// Iterate backwards through sorted entries
	for i := len(sortedEntries) - 1; i >= 0; i-- {
		entry := sortedEntries[i]
		
		if breakdowns, exists := entry["modelBreakdowns"].([]interface{}); exists {
			for _, item := range breakdowns {
				if obj, ok := item.(map[string]interface{}); ok {
					if modelName, exists := obj["modelName"].(string); exists && modelName == model {
						if costVal, exists := obj["cost"]; exists {
							var cost *float64
							switch v := costVal.(type) {
							case float64:
								cost = &v
							case int:
								f := float64(v)
								cost = &f
							case string:
								if parsed, err := strconv.ParseFloat(v, 64); err == nil {
									cost = &parsed
								}
							}
							
							var day string
							if dateStr, exists := entry["date"].(string); exists {
								day = dateStr
							}
							return day, cost
						}
					}
				}
			}
		}
	}
	
	return "", nil
}

// renderTextCurrent renders current mode output in text format
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

// renderTextAll renders all mode output in text format
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

// buildJSONCurrent builds JSON output for current mode
func buildJSONCurrent(
	provider, model, latestDate string,
	totalCost, latestCost *float64,
	latestCostDate string,
	entryCount int,
) map[string]interface{} {
	result := map[string]interface{}{
		"provider":       provider,
		"mode":          "current",
		"model":         model,
		"dailyRowCount": entryCount,
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

// buildJSONAll builds JSON output for all mode
func buildJSONAll(provider string, totals map[string]float64) map[string]interface{} {
	type modelEntry struct {
		Model        string  `json:"model"`
		TotalCostUSD float64 `json:"totalCostUSD"`
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
	
	models := make([]modelEntry, len(sorted))
	for i, item := range sorted {
		models[i] = modelEntry{Model: item.Key, TotalCostUSD: item.Value}
	}
	
	return map[string]interface{}{
		"provider": provider,
		"mode":     "all",
		"models":   models,
	}
}

func main() {
	// Parse command line arguments
	args := parseArgs()
	
	// Load payload
	payload, err := loadPayload(args.Input, args.Provider)
	if err != nil {
		eprint(err.Error())
		os.Exit(1)
	}
	
	// Process entries
	entries := parseDailyEntries(payload)
	entries = filterByDays(entries, args.Days)
	
	if args.Mode == "current" {
		model := args.Model
		latestDate := ""
		
		if model == "" {
			model, latestDate = pickCurrentModel(entries)
		}
		
		if model == "" {
			eprint("No model data found in codexbar cost payload.")
			os.Exit(2)
		}
		
		totals := aggregateCosts(entries)
		totalCost := totals[model]
		
		latestCostDate, latestCost := latestDayCost(entries, model)
		
		if args.Format == "json" {
			payloadOut := buildJSONCurrent(
				args.Provider,
				model,
				latestDate,
				&totalCost,
				latestCost,
				latestCostDate,
				len(entries),
			)
			
			var output []byte
			if args.Pretty {
				output, _ = json.MarshalIndent(payloadOut, "", "  ")
			} else {
				output, _ = json.Marshal(payloadOut)
			}
			fmt.Println(string(output))
		} else {
			fmt.Println(renderTextCurrent(
				args.Provider,
				model,
				latestDate,
				&totalCost,
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
	
	if args.Format == "json" {
		payloadOut := buildJSONAll(args.Provider, totals)
		var output []byte
		if args.Pretty {
			output, _ = json.MarshalIndent(payloadOut, "", "  ")
		} else {
			output, _ = json.Marshal(payloadOut)
		}
		fmt.Println(string(output))
	} else {
		fmt.Println(renderTextAll(args.Provider, totals))
	}
	os.Exit(0)
}

// Args represents command line arguments
type Args struct {
	Provider string
	Mode     string
	Model    string
	Input    string
	Days     *int
	Format   string
	Pretty   bool
}

// parseArgs parses command line arguments
func parseArgs() Args {
	args := Args{
		Provider: "codex",
		Mode:     "current",
		Format:   "text",
	}
	
	for i := 1; i < len(os.Args); i++ {
		arg := os.Args[i]
		
		switch arg {
		case "--provider":
			if i+1 < len(os.Args) {
				i++
				args.Provider = os.Args[i]
			}
		case "--mode":
			if i+1 < len(os.Args) {
				i++
				args.Mode = os.Args[i]
			}
		case "--model":
			if i+1 < len(os.Args) {
				i++
				args.Model = os.Args[i]
			}
		case "--input":
			if i+1 < len(os.Args) {
				i++
				args.Input = os.Args[i]
			}
		case "--days":
			if i+1 < len(os.Args) {
				i++
				days, err := strconv.Atoi(os.Args[i+1])
				if err == nil {
					args.Days = &days
				}
				i++
			}
		case "--format":
			if i+1 < len(os.Args) {
				i++
				args.Format = os.Args[i]
			}
		case "--pretty":
			args.Pretty = true
		}
	}
	
	return args
}

// abstraction-provenance: {"artifact_sha256": "166d289df135e250703e365320b6883d5c34e9a29aafc56b0b2b006ac80094f3", "source_sha256": "c28e85cfc52b92ed64eb8e20b072fd218cfe0e1ab0787781c1a9abd3355c3514", "target_language": "go"}
// extension-test-plan.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/extension-test-plan.mjs
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

const (
	repoRoot                         = ".." + string(filepath.Separator) + ".."
	BUNDLED_PLUGIN_ROOT_DIR         = "packages"
	BUNDLED_PLUGIN_PATH_PREFIX       = "packages/"
	DEFAULT_EXTENSION_TEST_SHARD_COUNT = 6
)

var channelTestRoots = []string{} // This would need to be populated from vitest.channel-paths.mjs

func init() {
	// Initialize channelTestRoots here if needed
}

func normalizeRelative(inputPath string) string {
	return strings.ReplaceAll(inputPath, string(filepath.Separator), "/")
}

func countTestFiles(rootPath string) int {
	total := 0
	stack := []string{rootPath}

	for len(stack) > 0 {
		current := stack[len(stack)-1]
		stack = stack[:len(stack)-1]

		if _, err := os.Stat(current); os.IsNotExist(err) {
			continue
		}

		entries, err := os.ReadDir(current)
		if err != nil {
			continue
		}

		for _, entry := range entries {
			fullPath := filepath.Join(current, entry.Name())
			if entry.IsDir() {
				if entry.Name() == "node_modules" || entry.Name() == "dist" {
					continue
				}
				stack = append(stack, fullPath)
				continue
			}
			if !entry.IsDir() && (strings.HasSuffix(fullPath, ".test.ts") || strings.HasSuffix(fullPath, ".test.tsx")) {
				total++
			}
		}
	}

	return total
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return !os.IsNotExist(err)
}

func resolveExtensionDirectory(targetArg string, cwd string) (string, error) {
	if targetArg != "" {
		asGiven := filepath.Join(cwd, targetArg)
		if fileExists(filepath.Join(asGiven, "package.json")) {
			return asGiven, nil
		}

		byName := filepath.Join(repoRoot, BUNDLED_PLUGIN_ROOT_DIR, targetArg)
		if fileExists(filepath.Join(byName, "package.json")) {
			return byName, nil
		}

		return "", fmt.Errorf("Unknown extension target \"%s\". Use a plugin name like \"slack\" or a path inside the bundled plugin workspace tree.", targetArg)
	}

	current := cwd
	for {
		relPath, _ := filepath.Rel(repoRoot, current)
		if strings.HasPrefix(normalizeRelative(relPath), BUNDLED_PLUGIN_PATH_PREFIX) &&
			fileExists(filepath.Join(current, "package.json")) {
			return current, nil
		}
		parent := filepath.Dir(current)
		if parent == current {
			break
		}
		current = parent
	}

	return "", fmt.Errorf("No extension target provided, and current working directory is not inside the bundled plugin workspace tree.")
}

type ExtensionTestPlan struct {
	Config        string   `json:"config"`
	ExtensionDir  string   `json:"extensionDir"`
	ExtensionId   string   `json:"extensionId"`
	HasTests      bool     `json:"hasTests"`
	Roots         []string `json:"roots"`
	TestFileCount int      `json:"testFileCount"`
}

func resolveExtensionTestPlan(params map[string]interface{}) (*ExtensionTestPlan, error) {
	cwd := "."
	if c, ok := params["cwd"].(string); ok {
		cwd = c
	}
	
	targetArg := ""
	if t, ok := params["targetArg"].(string); ok {
		targetArg = t
	}

	extensionDir, err := resolveExtensionDirectory(targetArg, cwd)
	if err != nil {
		return nil, err
	}
	
	extensionId := filepath.Base(extensionDir)
	relExtDir, _ := filepath.Rel(repoRoot, extensionDir)
	relativeExtensionDir := normalizeRelative(relExtDir)

	roots := []string{relativeExtensionDir}

	usesChannelConfig := false
	for _, root := range channelTestRoots {
		for _, r := range roots {
			if r == root {
				usesChannelConfig = true
				break
			}
		}
	}

	config := "test/vitest/vitest.extensions.config.ts"
	if usesChannelConfig {
		config = "test/vitest/vitest.extension-channels.config.ts"
	} else if isAcpxExtensionRoot(relativeExtensionDir) {
		config = "test/vitest/vitest.extension-acpx.config.ts"
	} else if isDiffsExtensionRoot(relativeExtensionDir) {
		config = "test/vitest/vitest.extension-diffs.config.ts"
	} else if isBlueBubblesExtensionRoot(relativeExtensionDir) {
		config = "test/vitest/vitest.extension-bluebubbles.config.ts"
	} else if isFeishuExtensionRoot(relativeExtensionDir) {
		config = "test/vitest/vitest.extension-feishu.config.ts"
	} else if isIrcExtensionRoot(relativeExtensionDir) {
		config = "test/vitest/vitest.extension-irc.config.ts"
	} else if isMattermostExtensionRoot(relativeExtensionDir) {
		config = "test/vitest/vitest.extension-mattermost.config.ts"
	} else if isMatrixExtensionRoot(relativeExtensionDir) {
		config = "test/vitest/vitest.extension-matrix.config.ts"
	} else if isTelegramExtensionRoot(relativeExtensionDir) {
		config = "test/vitest/vitest.extension-telegram.config.ts"
	} else if isVoiceCallExtensionRoot(relativeExtensionDir) {
		config = "test/vitest/vitest.extension-voice-call.config.ts"
	} else if isWhatsAppExtensionRoot(relativeExtensionDir) {
		config = "test/vitest/vitest.extension-whatsapp.config.ts"
	} else if isZaloExtensionRoot(relativeExtensionDir) {
		config = "test/vitest/vitest.extension-zalo.config.ts"
	} else if isMemoryExtensionRoot(relativeExtensionDir) {
		config = "test/vitest/vitest.extension-memory.config.ts"
	} else if isMsTeamsExtensionRoot(relativeExtensionDir) {
		config = "test/vitest/vitest.extension-msteams.config.ts"
	} else if isMessagingExtensionRoot(relativeExtensionDir) {
		config = "test/vitest/vitest.extension-messaging.config.ts"
	} else if isProviderExtensionRoot(relativeExtensionDir) {
		config = "test/vitest/vitest.extension-providers.config.ts"
	}

	testFileCount := 0
	for _, root := range roots {
		testFileCount += countTestFiles(filepath.Join(repoRoot, root))
	}

	return &ExtensionTestPlan{
		Config:        config,
		ExtensionDir:  relativeExtensionDir,
		ExtensionId:   extensionId,
		HasTests:      testFileCount > 0,
		Roots:         roots,
		TestFileCount: testFileCount,
	}, nil
}

type PlanGroup struct {
	Config         string   `json:"config"`
	ExtensionIds   []string `json:"extensionIds"`
	Roots          []string `json:"roots"`
	TestFileCount  int      `json:"testFileCount"`
}

type ExtensionBatchPlan struct {
	ExtensionCount   int          `json:"extensionCount"`
	ExtensionIds     []string     `json:"extensionIds"`
	HasTests         bool         `json:"hasTests"`
	PlanGroups       []PlanGroup  `json:"planGroups"`
	TestFileCount    int          `json:"testFileCount"`
}

func mergeTestPlans(plans []*ExtensionTestPlan) *ExtensionBatchPlan {
	groupsByConfig := make(map[string]*PlanGroup)

	for _, plan := range plans {
		current, exists := groupsByConfig[plan.Config]
		if !exists {
			current = &PlanGroup{
				Config:        plan.Config,
				ExtensionIds:  []string{},
				Roots:         []string{},
				TestFileCount: 0,
			}
			groupsByConfig[plan.Config] = current
		}

		current.ExtensionIds = append(current.ExtensionIds, plan.ExtensionId)
		current.Roots = append(current.Roots, plan.Roots...)
		current.TestFileCount += plan.TestFileCount
	}

	var planGroups []PlanGroup
	for _, group := range groupsByConfig {
		// Remove duplicates from roots
		uniqueRoots := make(map[string]bool)
		var dedupedRoots []string
		for _, root := range group.Roots {
			if !uniqueRoots[root] {
				uniqueRoots[root] = true
				dedupedRoots = append(dedupedRoots, root)
			}
		}
		group.Roots = dedupedRoots

		// Sort extension IDs
		sort.Strings(group.ExtensionIds)
		planGroups = append(planGroups, *group)
	}

	// Sort planGroups by config
	sort.Slice(planGroups, func(i, j int) bool {
		return planGroups[i].Config < planGroups[j].Config
	})

	// Collect all extension IDs
	var allExtensionIds []string
	totalTestFileCount := 0
	for _, plan := range plans {
		allExtensionIds = append(allExtensionIds, plan.ExtensionId)
		totalTestFileCount += plan.TestFileCount
	}
	sort.Strings(allExtensionIds)

	return &ExtensionBatchPlan{
		ExtensionCount: len(plans),
		ExtensionIds:   allExtensionIds,
		HasTests:       len(plans) > 0,
		PlanGroups:     planGroups,
		TestFileCount:  totalTestFileCount,
	}
}

func resolveExtensionBatchPlan(params map[string]interface{}) (*ExtensionBatchPlan, error) {
	cwd := "."
	if c, ok := params["cwd"].(string); ok {
		cwd = c
	}
	
	extensionIds := listAvailableExtensionIds()
	if ids, ok := params["extensionIds"].([]string); ok {
		extensionIds = ids
	}

	var plans []*ExtensionTestPlan
	for _, extensionId := range extensionIds {
		plan, err := resolveExtensionTestPlan(map[string]interface{}{
			"cwd": cwd,
			"targetArg": extensionId,
		})
		if err != nil {
			return nil, err
		}
		if plan.HasTests {
			plans = append(plans, plan)
		}
	}

	return mergeTestPlans(plans), nil
}

type Shard struct {
	Plans         []*ExtensionTestPlan `json:"plans"`
	TestFileCount int                   `json:"testFileCount"`
}

func pickLeastLoadedShard(shards []Shard) int {
	bestIndex := -1
	for index, shard := range shards {
		if bestIndex == -1 {
			bestIndex = index
			continue
		}
		best := shards[bestIndex]
		if shard.TestFileCount != best.TestFileCount {
			if shard.TestFileCount < best.TestFileCount {
				bestIndex = index
			}
			continue
		}
		if len(shard.Plans) != len(best.Plans) {
			if len(shard.Plans) < len(best.Plans) {
				bestIndex = index
			}
			continue
		}
		if index < bestIndex {
			bestIndex = index
		}
	}
	return bestIndex
}

type TestShard struct {
	Index     int               `json:"index"`
	CheckName string            `json:"checkName"`
	*ExtensionBatchPlan
}

func createExtensionTestShards(params map[string]interface{}) ([]TestShard, error) {
	cwd := "."
	if c, ok := params["cwd"].(string); ok {
		cwd = c
	}
	
	shardCount := 1
	if s, ok := params["shardCount"].(int); ok {
		shardCount = s
	} else if s, ok := params["shardCount"].(string); ok {
		fmt.Sscanf(s, "%d", &shardCount)
	}

	extensionIds := listAvailableExtensionIds()
	if ids, ok := params["extensionIds"].([]string); ok {
		extensionIds = ids
	}

	var plans []*ExtensionTestPlan
	for _, extensionId := range extensionIds {
		plan, err := resolveExtensionTestPlan(map[string]interface{}{
			"cwd": cwd,
			"targetArg": extensionId,
		})
		if err != nil {
			return nil, err
		}
		if plan.HasTests {
			plans = append(plans, plan)
		}
	}

	// Sort plans
	sort.Slice(plans, func(i, j int) bool {
		if plans[i].TestFileCount != plans[j].TestFileCount {
			return plans[i].TestFileCount > plans[j].TestFileCount
		}
		return plans[i].ExtensionId < plans[j].ExtensionId
	})

	effectiveShardCount := shardCount
	if effectiveShardCount > len(plans) {
		effectiveShardCount = len(plans)
	}
	if effectiveShardCount < 1 {
		effectiveShardCount = 1
	}

	shards := make([]Shard, effectiveShardCount)
	for i := range shards {
		shards[i] = Shard{
			Plans:         []*ExtensionTestPlan{},
			TestFileCount: 0,
		}
	}

	for _, plan := range plans {
		targetIndex := pickLeastLoadedShard(shards)
		shards[targetIndex].Plans = append(shards[targetIndex].Plans, plan)
		shards[targetIndex].TestFileCount += plan.TestFileCount
	}

	var result []TestShard
	for i, shard := range shards {
		batchPlan := mergeTestPlans(shard.Plans)
		if batchPlan.HasTests {
			result = append(result, TestShard{
				Index:             i,
				CheckName:         fmt.Sprintf("checks-node-extensions-shard-%d", i+1),
				ExtensionBatchPlan: batchPlan,
			})
		}
	}

	return result, nil
}

// Placeholder functions that would need implementation based on actual JS files
func isAcpxExtensionRoot(root string) bool {
	return false
}

func isBlueBubblesExtensionRoot(root string) bool {
	return false
}

func isDiffsExtensionRoot(root string) bool {
	return false
}

func isFeishuExtensionRoot(root string) bool {
	return false
}

func isIrcExtensionRoot(root string) bool {
	return false
}

func isMatrixExtensionRoot(root string) bool {
	return false
}

func isMattermostExtensionRoot(root string) bool {
	return false
}

func isMemoryExtensionRoot(root string) bool {
	return false
}

func isMessagingExtensionRoot(root string) bool {
	return false
}

func isMsTeamsExtensionRoot(root string) bool {
	return false
}

func isProviderExtensionRoot(root string) bool {
	return false
}

func isTelegramExtensionRoot(root string) bool {
	return false
}

func isVoiceCallExtensionRoot(root string) bool {
	return false
}

func isWhatsAppExtensionRoot(root string) bool {
	return false
}

func isZaloExtensionRoot(root string) bool {
	return false
}

func listAvailableExtensionIds() []string {
	// This should read from the filesystem to get available extensions
	// For now returning empty slice as placeholder
	return []string{}
}

func main() {
	// Example usage
	params := map[string]interface{}{}
	
	plan, err := resolveExtensionTestPlan(params)
	if err != nil {
		fmt.Printf("Error: %v\n", err)
		return
	}
	
	jsonData, _ := json.MarshalIndent(plan, "", "  ")
	fmt.Println(string(jsonData))
}

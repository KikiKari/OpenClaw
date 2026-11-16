// abstraction-provenance: {"artifact_sha256": "74d73a19f3ee7b93de8f5853bef43842299bed312a3ec213711ee77f3ce260ec", "source_sha256": "08abd9802ec4316f1570b6eba8dd2d40356789759d4be8f3a0078e57999a841c", "target_language": "go"}
// check-gateway-watch-regression.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-gateway-watch-regression.mjs
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"math"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

type Options struct {
	OutputDir                 string
	WindowMs                  int64
	ReadyTimeoutMs            int64
	ReadySettleMs             int64
	SigkillGraceMs            int64
	CpuWarnMs                 int64
	CpuFailMs                 int64
	DistRuntimeFileGrowthMax  int64
	DistRuntimeByteGrowthMax  int64
	KeepLogs                  bool
	SkipBuild                 bool
}

var DEFAULTS = Options{
	OutputDir:                filepath.Join(".", ".local", "gateway-watch-regression"),
	WindowMs:                 10000,
	ReadyTimeoutMs:           20000,
	ReadySettleMs:            500,
	SigkillGraceMs:           10000,
	CpuWarnMs:                1000,
	CpuFailMs:                8000,
	DistRuntimeFileGrowthMax: 200,
	DistRuntimeByteGrowthMax: 2 * 1024 * 1024,
	KeepLogs:                 true,
	SkipBuild:                false,
}

var WATCH_GATEWAY_SKIP_ENV = map[string]string{
	"OPENCLAW_DISABLE_BONJOUR":           "1",
	"OPENCLAW_SKIP_ACPX_RUNTIME":         "1",
	"OPENCLAW_SKIP_ACPX_RUNTIME_PROBE":   "1",
	"OPENCLAW_SKIP_BROWSER_CONTROL_SERVER": "1",
	"OPENCLAW_SKIP_CANVAS_HOST":          "1",
	"OPENCLAW_SKIP_CHANNELS":             "1",
	"OPENCLAW_SKIP_CRON":                 "1",
	"OPENCLAW_SKIP_GMAIL_WATCHER":        "1",
}

func parseArgs(args []string) Options {
	options := DEFAULTS
	for i := 0; i < len(args); i++ {
		arg := args[i]
		readValue := func() string {
			if i+1 >= len(args) {
				panic(fmt.Sprintf("Missing value for %s", arg))
			}
			i++
			return args[i]
		}
		switch arg {
		case "--output-dir":
			options.OutputDir, _ = filepath.Abs(readValue())
		case "--window-ms":
			options.WindowMs, _ = strconv.ParseInt(readValue(), 10, 64)
		case "--ready-timeout-ms":
			options.ReadyTimeoutMs, _ = strconv.ParseInt(readValue(), 10, 64)
		case "--ready-settle-ms":
			options.ReadySettleMs, _ = strconv.ParseInt(readValue(), 10, 64)
		case "--sigkill-grace-ms":
			options.SigkillGraceMs, _ = strconv.ParseInt(readValue(), 10, 64)
		case "--cpu-warn-ms":
			options.CpuWarnMs, _ = strconv.ParseInt(readValue(), 10, 64)
		case "--cpu-fail-ms":
			options.CpuFailMs, _ = strconv.ParseInt(readValue(), 10, 64)
		case "--dist-runtime-file-growth-max":
			options.DistRuntimeFileGrowthMax, _ = strconv.ParseInt(readValue(), 10, 64)
		case "--dist-runtime-byte-growth-max":
			options.DistRuntimeByteGrowthMax, _ = strconv.ParseInt(readValue(), 10, 64)
		case "--skip-build":
			options.SkipBuild = true
		default:
			panic(fmt.Sprintf("Unknown argument: %s", arg))
		}
	}
	return options
}

func ensureDir(dirPath string) error {
	return os.MkdirAll(dirPath, 0755)
}

func removePathIfExists(targetPath string) error {
	return os.RemoveAll(targetPath)
}

func normalizePath(filePath string) string {
	return strings.ReplaceAll(filePath, "\\", "/")
}

func listTreeEntries(rootName string) []string {
	cwd, _ := os.Getwd()
	rootPath := filepath.Join(cwd, rootName)
	if _, err := os.Stat(rootPath); os.IsNotExist(err) {
		return []string{rootName + " (missing)"}
	}

	entries := []string{rootName}
	queue := []string{rootPath}
	for len(queue) > 0 {
		current := queue[len(queue)-1]
		queue = queue[:len(queue)-1]
		dirEntries, err := os.ReadDir(current)
		if err != nil {
			continue
		}
		for _, dirent := range dirEntries {
			fullPath := filepath.Join(current, dirent.Name())
			relativePath, _ := filepath.Rel(cwd, fullPath)
			entries = append(entries, normalizePath(relativePath))
			if dirent.IsDir() {
				queue = append(queue, fullPath)
			}
		}
	}
	sort.Strings(entries)
	return entries
}

func humanBytes(bytes int64) string {
	if bytes < 1024 {
		return fmt.Sprintf("%dB", bytes)
	}
	if bytes < 1024*1024 {
		return fmt.Sprintf("%.1fK", float64(bytes)/1024)
	}
	if bytes < 1024*1024*1024 {
		return fmt.Sprintf("%.1fM", float64(bytes)/(1024*1024))
	}
	return fmt.Sprintf("%.1fG", float64(bytes)/(1024*1024*1024))
}

type TreeStats struct {
	Exists         bool
	Files          int64
	Directories    int64
	Symlinks       int64
	Entries        int64
	ApparentBytes  int64
}

func snapshotTree(rootName string) TreeStats {
	cwd, _ := os.Getwd()
	rootPath := filepath.Join(cwd, rootName)
	stats := TreeStats{}
	if _, err := os.Stat(rootPath); os.IsNotExist(err) {
		return stats
	}
	stats.Exists = true

	queue := []string{rootPath}
	for len(queue) > 0 {
		current := queue[len(queue)-1]
		queue = queue[:len(queue)-1]
		info, err := os.Lstat(current)
		if err != nil {
			continue
		}
		stats.Entries++
		if info.IsDir() {
			stats.Directories++
			dirEntries, err := os.ReadDir(current)
			if err != nil {
				continue
			}
			for _, dirent := range dirEntries {
				queue = append(queue, filepath.Join(current, dirent.Name()))
			}
			continue
		}
		if info.Mode()&os.ModeSymlink != 0 {
			stats.Symlinks++
			continue
		}
		if info.Mode().IsRegular() {
			stats.Files++
			stats.ApparentBytes += info.Size()
		}
	}
	return stats
}

type Snapshot struct {
	GeneratedAt string
	Dist        TreeStats
	DistRuntime TreeStats
}

func writeSnapshot(snapshotDir string) Snapshot {
	ensureDir(snapshotDir)
	pathEntries := append(listTreeEntries("dist"), listTreeEntries("dist-runtime")...)
	os.WriteFile(filepath.Join(snapshotDir, "paths.txt"), []byte(strings.Join(pathEntries, "\n")+"\n"), 0644)

	dist := snapshotTree("dist")
	distRuntime := snapshotTree("dist-runtime")
	snapshot := Snapshot{
		GeneratedAt: time.Now().UTC().Format(time.RFC3339),
		Dist:        dist,
		DistRuntime: distRuntime,
	}
	snapshotJSON, _ := json.MarshalIndent(snapshot, "", "  ")
	os.WriteFile(filepath.Join(snapshotDir, "snapshot.json"), append(snapshotJSON, '\n'), 0644)

	statsText := fmt.Sprintf(`generated_at: %s

[dist]
files: %d
directories: %d
symlinks: %d
entries: %d
apparent_bytes: %d
apparent_human: %s

[dist-runtime]
files: %d
directories: %d
symlinks: %d
entries: %d
apparent_bytes: %d
apparent_human: %s

`,
		snapshot.GeneratedAt,
		dist.Files, dist.Directories, dist.Symlinks, dist.Entries, dist.ApparentBytes, humanBytes(dist.ApparentBytes),
		distRuntime.Files, distRuntime.Directories, distRuntime.Symlinks, distRuntime.Entries, distRuntime.ApparentBytes, humanBytes(distRuntime.ApparentBytes),
	)
	os.WriteFile(filepath.Join(snapshotDir, "stats.txt"), []byte(statsText), 0644)
	return snapshot
}

func runCheckedCommand(command string, args []string) {
	cmd := exec.Command(command, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		panic(fmt.Sprintf("%s %s failed: %v", command, strings.Join(args, " "), err))
	}
}

func sleep(ms int64) {
	time.Sleep(time.Duration(ms) * time.Millisecond)
}

func parsePsCpuTimeMs(timeText string) *int64 {
	parts := strings.Split(timeText, "-")
	var days int64
	var clockText string
	if len(parts) == 2 {
		days, _ = strconv.ParseInt(parts[0], 10, 64)
		clockText = parts[1]
	} else {
		days = 0
		clockText = timeText
	}
	clockParts := strings.Split(clockText, ":")
	if len(clockParts) < 2 || len(clockParts) > 3 {
		return nil
	}
	var hours, minutes, seconds int64
	if len(clockParts) == 3 {
		hours, _ = strconv.ParseInt(clockParts[0], 10, 64)
		minutes, _ = strconv.ParseInt(clockParts[1], 10, 64)
		seconds, _ = strconv.ParseInt(clockParts[2], 10, 64)
	} else {
		hours = 0
		minutes, _ = strconv.ParseInt(clockParts[0], 10, 64)
		seconds, _ = strconv.ParseInt(clockParts[1], 10, 64)
	}
	totalSeconds := (days*24+hours)*3600 + minutes*60 + seconds
	totalMs := totalSeconds * 1000
	return &totalMs
}

type PsRow struct {
	Pid   int64
	Ppid  int64
	CpuMs int64
}

func readProcessTreeCpuMs(rootPid int64) *int64 {
	if rootPid <= 0 {
		return nil
	}
	cmd := exec.Command("ps", "-eo", "pid=,ppid=,time=")
	output, err := cmd.Output()
	if err != nil {
		return nil
	}
	var rows []PsRow
	scanner := bufio.NewScanner(strings.NewReader(string(output)))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		fields := strings.Fields(line)
		if len(fields) < 3 {
			continue
		}
		pid, _ := strconv.ParseInt(fields[0], 10, 64)
		ppid, _ := strconv.ParseInt(fields[1], 10, 64)
		cpuMs := parsePsCpuTimeMs(fields[2])
		if cpuMs == nil {
			continue
		}
		rows = append(rows, PsRow{Pid: pid, Ppid: ppid, CpuMs: *cpuMs})
	}
	cpuByPid := make(map[int64]int64)
	childrenByParent := make(map[int64][]int64)
	for _, row := range rows {
		cpuByPid[row.Pid] = row.CpuMs
		childrenByParent[row.Ppid] = append(childrenByParent[row.Ppid], row.Pid)
	}
	if _, exists := cpuByPid[rootPid]; !exists {
		return nil
	}
	var totalCpuMs int64
	seen := make(map[int64]bool)
	stack := []int64{rootPid}
	for len(stack) > 0 {
		pid := stack[len(stack)-1]
		stack = stack[:len(stack)-1]
		if seen[pid] {
			continue
		}
		seen[pid] = true
		totalCpuMs += cpuByPid[pid]
		for _, childPid := range childrenByParent[pid] {
			stack = append(stack, childPid)
		}
	}
	return &totalCpuMs
}

func waitForGatewayReady(readText func() string, timeoutMs int64) bool {
	deadline := time.Now().Add(time.Duration(timeoutMs) * time.Millisecond)
	for time.Now().Before(deadline) {
		if strings.Contains(readText(), "[gateway] ready (") {
			return true
		}
		sleep(100)
	}
	return false
}

func allocateLoopbackPort() (int, error) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return 0, err
	}
	defer listener.Close()
	addr := listener.Addr().(*net.TCPAddr)
	return addr.Port, nil
}

type TimedCommand struct {
	Command string
	Args    []string
	Env     map[string]string
}

func buildTimedWatchCommand(pidFilePath, timeFilePath, isolatedHomeDir string, port int) TimedCommand {
	shellSource := fmt.Sprintf(`echo "$$" > "%s"
mkdir -p "%s/.openclaw"
printf '%%s\n' '{"gateway":{"controlUi":{"enabled":false}}}' > "%s/.openclaw/openclaw.json"
exec node scripts/watch-node.mjs gateway --force --allow-unconfigured --port %d --token watch-regression-token`,
		pidFilePath, isolatedHomeDir, isolatedHomeDir, port)
	env := map[string]string{
		"OPENCLAW_WATCH_PID_FILE": pidFilePath,
		"HOME":                    isolatedHomeDir,
		"OPENCLAW_HOME":           isolatedHomeDir,
	}
	for k, v := range WATCH_GATEWAY_SKIP_ENV {
		env[k] = v
	}
	if os.Getenv("GOOS") == "darwin" || (runtime.GOOS == "darwin" && os.Getenv("GOOS") == "") {
		return TimedCommand{
			Command: "/usr/bin/time",
			Args:    []string{"-lp", "-o", timeFilePath, "/bin/sh", "-lc", shellSource},
			Env:     env,
		}
	}
	return TimedCommand{
		Command: "/usr/bin/time",
		Args:    []string{"-f", "__TIMING__ user=%U sys=%S elapsed=%e", "-o", timeFilePath, "/bin/sh", "-lc", shellSource},
		Env:     env,
	}
}

type Timing struct {
	UserSeconds    float64
	SysSeconds     float64
	ElapsedSeconds float64
}

func parseTimingFile(timeFilePath string) Timing {
	data, err := os.ReadFile(timeFilePath)
	if err != nil {
		return Timing{UserSeconds: math.NaN(), SysSeconds: math.NaN(), ElapsedSeconds: math.NaN()}
	}
	text := string(data)
	if os.Getenv("GOOS") == "darwin" || (runtime.GOOS == "darwin" && os.Getenv("GOOS") == "") {
		userRe := regexp.MustCompile(`user\s+([0-9.]+)`)
		sysRe := regexp.MustCompile(`sys\s+([0-9.]+)`)
		realRe := regexp.MustCompile(`real\s+([0-9.]+)`)
		userMatch := userRe.FindStringSubmatch(text)
		sysMatch := sysRe.FindStringSubmatch(text)
		realMatch := realRe.FindStringSubmatch(text)
		var user, sys, elapsed float64
		if len(userMatch) > 1 {
			user, _ = strconv.ParseFloat(userMatch[1], 64)
		}
		if len(sysMatch) > 1 {
			sys, _ = strconv.ParseFloat(sysMatch[1], 64)
		}
		if len(realMatch) > 1 {
			elapsed, _ = strconv.ParseFloat(realMatch[1], 64)
		}
		return Timing{UserSeconds: user, SysSeconds: sys, ElapsedSeconds: elapsed}
	}
	re := regexp.MustCompile(`__TIMING__ user=([0-9.]+) sys=([0-9.]+) elapsed=([0-9.]+)`)
	match := re.FindStringSubmatch(text)
	var user, sys, elapsed float64
	if len(match) > 3 {
		user, _ = strconv.ParseFloat(match[1], 64)
		sys, _ = strconv.ParseFloat(match[2], 64)
		elapsed, _ = strconv.ParseFloat(match[3], 64)
	}
	return Timing{UserSeconds: user, SysSeconds: sys, ElapsedSeconds: elapsed}
}

type WatchResult struct {
	Exit             *os.ProcessState
	Timing           Timing
	ReadyBeforeWindow bool
	IdleCpuMs        *int64
	StdoutPath       string
	StderrPath       string
	TimeFilePath     string
}

func runTimedWatch(options Options, outputDir string) (*WatchResult, error) {
	pidFilePath := filepath.Join(outputDir, "watch.pid")
	timeFilePath := filepath.Join(outputDir, "watch.time.log")
	isolatedHomeDir, err := os.MkdirTemp("", "openclaw-gateway-watch-")
	if err != nil {
		return nil, err
	}
	os.WriteFile(filepath.Join(outputDir, "watch.home.txt"), []byte(isolatedHomeDir+"\n"), 0644)
	stdoutPath := filepath.Join(outputDir, "watch.stdout.log")
	stderrPath := filepath.Join(outputDir, "watch.stderr.log")
	for _, stalePath := range []string{pidFilePath, timeFilePath, stdoutPath, stderrPath} {
		os.RemoveAll(stalePath)
	}
	port, err := allocateLoopbackPort()
	if err != nil {
		return nil, err
	}
	os.WriteFile(filepath.Join(outputDir, "watch.port.txt"), []byte(strconv.Itoa(port)+"\n"), 0644)
	cmdSpec := buildTimedWatchCommand(pidFilePath, timeFilePath, isolatedHomeDir, port)
	cmd := exec.Command(cmdSpec.Command, cmdSpec.Args...)
	cmd.Env = os.Environ()
	for k, v := range cmdSpec.Env {
		cmd.Env = append(cmd.Env, k+"="+v)
	}
	stdoutPipe, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	stderrPipe, err := cmd.StderrPipe()
	if err != nil {
		return nil, err
	}
	if err := cmd.Start(); err != nil {
		return nil, err
	}
	var stdout, stderr strings.Builder
	var wg sync.WaitGroup
	wg.Add(2)
	go func() {
		defer wg.Done()
		io.Copy(&stdout, stdoutPipe)
	}()
	go func() {
		defer wg.Done()
		io.Copy(&stderr, stderrPipe)
	}()
	exitChan := make(chan error, 1)
	go func() {
		err := cmd.Wait()
		wg.Wait()
		exitChan <- err
	}()
	var watchPid *int64
	for attempt := 0; attempt < 50; attempt++ {
		if data, err := os.ReadFile(pidFilePath); err == nil {
			pid, _ := strconv.ParseInt(strings.TrimSpace(string(data)), 10, 64)
			watchPid = &pid
			break
		}
		sleep(100)
	}
	readText := func() string {
		return stdout.String() + "\n" + stderr.String()
	}
	readyBeforeWindow := waitForGatewayReady(readText, options.ReadyTimeoutMs)
	if readyBeforeWindow && options.ReadySettleMs > 0 {
		sleep(options.ReadySettleMs)
	}
	var idleCpuStartMs, idleCpuEndMs *int64
	if watchPid != nil {
		idleCpuStartMs = readProcessTreeCpuMs(*watchPid)
	}
	sleep(options.WindowMs)
	if watchPid != nil {
		idleCpuEndMs = readProcessTreeCpuMs(*watchPid)
	}
	if watchPid != nil {
		syscall.Kill(int(*watchPid), syscall.SIGTERM)
	}
	var exitErr error
	select {
	case exitErr = <-exitChan:
	case <-time.After(time.Duration(options.SigkillGraceMs) * time.Millisecond):
		if watchPid != nil {
			syscall.Kill(int(*watchPid), syscall.SIGKILL)
		}
		exitErr = <-exitChan
	}
	os.WriteFile(stdoutPath, []byte(stdout.String()), 0644)
	os.WriteFile(stderrPath, []byte(stderr.String()), 0644)
	timing := parseTimingFile(timeFilePath)
	var idleCpuMs *int64
	if idleCpuStartMs != nil && idleCpuEndMs != nil {
		cpuMs := *idleCpuEndMs - *idleCpuStartMs
		if cpuMs < 0 {
			cpuMs = 0
		}
		idleCpuMs = &cpuMs
	}
	return &WatchResult{
		Exit:             cmd.ProcessState,
		Timing:           timing,
		ReadyBeforeWindow: readyBeforeWindow,
		IdleCpuMs:        idleCpuMs,
		StdoutPath:       stdoutPath,
		StderrPath:       stderrPath,
		TimeFilePath:     timeFilePath,
	}, nil
}

func parsePathFile(filePath string) []string {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return nil
	}
	lines := strings.Split(string(data), "\n")
	var result []string
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed != "" {
			result = append(result, trimmed)
		}
	}
	return result
}

type DiffResult struct {
	Added   []string
	Removed []string
}

func writeDiffArtifacts(outputDir, preDir, postDir string) DiffResult {
	diffDir := filepath.Join(outputDir, "diff")
	ensureDir(diffDir)
	prePaths := parsePathFile(filepath.Join(preDir, "paths.txt"))
	postPaths := parsePathFile(filepath.Join(postDir, "paths.txt"))
	preSet := make(map[string]bool)
	for _, path := range prePaths {
		preSet[path] = true
	}
	postSet := make(map[string]bool)
	for _, path := range postPaths {
		postSet[path] = true
	}
	var added, removed []string
	for _, path := range postPaths {
		if !preSet[path] {
			added = append(added, path)
		}
	}
	for _, path := range prePaths {
		if !postSet[path] {
			removed = append(removed, path)
		}
	}
	os.WriteFile(filepath.Join(diffDir, "added-paths.txt"), []byte(strings.Join(added, "\n")+"\n"), 0644)
	os.WriteFile(filepath.Join(diffDir, "removed-paths.txt"), []byte(strings.Join(removed, "\n")+"\n"), 0644)
	return DiffResult{Added: added, Removed: removed}
}

func fail(message string) {
	fmt.Fprintf(os.Stderr, "FAIL: %s\n", message)
}

func warn(message string) {
	fmt.Fprintf(os.Stderr, "WARN: %s\n", message)
}

func detectWatchBuildReason(stdout, stderr string) string {
	combined := stdout + "\n" + stderr
	re := regexp.MustCompile(`Building TypeScript \(dist is stale: ([a-z_]+)`)
	match := re.FindStringSubmatch(combined)
	if len(match) > 1 {
		return match[1]
	}
	return ""
}

type BuildRequirement struct {
	ShouldBuild bool
	Reason      string
}

func resolveBuildRequirement(deps map[string]interface{}) BuildRequirement {
	return BuildRequirement{ShouldBuild: false, Reason: ""}
}

func writeBuildStamp(cwd string) {
}

func main() {
	options := parseArgs(os.Args[1:])
	ensureDir(options.OutputDir)
	if !options.SkipBuild {
		runCheckedCommand("pnpm", []string{"build"})
		cwd, _ := os.Getwd()
		writeBuildStamp(cwd)
	}
	preflightBuildRequirement := resolveBuildRequirement(map[string]interface{}{})
	if preflightBuildRequirement.ShouldBuild && preflightBuildRequirement.Reason == "dirty_watched_tree" {
		summary := map[string]interface{}{
			"windowMs":            options.WindowMs,
			"invalidated":         true,
			"invalidationReason":  preflightBuildRequirement.Reason,
			"invalidationMessage": "gateway-watch-regression cannot run on a dirty watched tree because run-node will intentionally rebuild during the watch window.",
		}
		summaryJSON, _ := json.MarshalIndent(summary, "", "  ")
		os.WriteFile(filepath.Join(options.OutputDir, "summary.json"), append(summaryJSON, '\n'), 0644)
		fmt.Println(string(summaryJSON))
		fail("gateway-watch-regression invalid local run: dirty watched source tree would force a rebuild inside the watch window")
		os.Exit(1)
	}
	preDir := filepath.Join(options.OutputDir, "pre")
	pre := writeSnapshot(preDir)
	watchDir := filepath.Join(options.OutputDir, "watch")
	ensureDir(watchDir)
	watchResult, err := runTimedWatch(options, watchDir)
	if err != nil {
		panic(err)
	}
	postDir := filepath.Join(options.OutputDir, "post")
	post := writeSnapshot(postDir)
	diff := writeDiffArtifacts(options.OutputDir, preDir, postDir)
	distRuntimeFileGrowth := post.DistRuntime.Files - pre.DistRuntime.Files
	distRuntimeByteGrowth := post.DistRuntime.ApparentBytes - pre.DistRuntime.ApparentBytes
	var distRuntimeAddedPaths int64
	for _, entry := range diff.Added {
		if strings.HasPrefix(entry, "dist-runtime/") {
			distRuntimeAddedPaths++
		}
	}
	totalCpuMs := int64((watchResult.Timing.UserSeconds + watchResult.Timing.SysSeconds) * 1000)
	var cpuMs int64
	if watchResult.IdleCpuMs != nil {
		cpuMs = *watchResult.IdleCpuMs
	} else {
		cpuMs = totalCpuMs
	}
	stdoutData, _ := os.ReadFile(watchResult.StdoutPath)
	stderrData, _ := os.ReadFile(watchResult.StderrPath)
	stdoutStr := string(stdoutData)
	stderrStr := string(stderrData)
	watchTriggeredBuild := strings.Contains(stderrStr, "Building TypeScript (dist is stale") || strings.Contains(stdoutStr, "Building TypeScript (dist is stale")
	watchBuildReason := detectWatchBuildReason(stdoutStr, stderrStr)
	exitCode := -1
	exitSignal := -1
	if watchResult.Exit != nil {
		exitCode = watchResult.Exit.ExitCode()
		if status, ok := watchResult.Exit.Sys().(syscall.WaitStatus); ok {
			exitSignal = int(status.Signal())
		}
	}
	summary := map[string]interface{}{
		"windowMs":                  options.WindowMs,
		"watchTriggeredBuild":       watchTriggeredBuild,
		"watchBuildReason":          watchBuildReason,
		"cpuMs":                     cpuMs,
		"totalCpuMs":                totalCpuMs,
		"readyBeforeWindow":         watchResult.ReadyBeforeWindow,
		"cpuWarnMs":                 options.CpuWarnMs,
		"cpuFailMs":                 options.CpuFailMs,
		"distRuntimeFileGrowth":     distRuntimeFileGrowth,
		"distRuntimeFileGrowthMax":  options.DistRuntimeFileGrowthMax,
		"distRuntimeByteGrowth":     distRuntimeByteGrowth,
		"distRuntimeByteGrowthMax":  options.DistRuntimeByteGrowthMax,
		"distRuntimeAddedPaths":     distRuntimeAddedPaths,
		"addedPaths":                len(diff.Added),
		"removedPaths":              len(diff.Removed),
		"watchExit":                 map[string]interface{}{"code": exitCode, "signal": exitSignal},
		"timing":                    watchResult.Timing,
	}
	summaryJSON, _ := json.MarshalIndent(summary, "", "  ")
	os.WriteFile(filepath.Join(options.OutputDir, "summary.json"), append(summaryJSON, '\n'), 0644)
	fmt.Println(string(summaryJSON))
	var failures, warnings []string
	if watchTriggeredBuild && watchBuildReason == "dirty_watched_tree" {
		failures = append(failures, "gateway:watch invalid local run: dirty watched source tree forced a rebuild during the watch window")
	}
	if distRuntimeFileGrowth > options.DistRuntimeFileGrowthMax {
		failures = append(failures, fmt.Sprintf("dist-runtime file growth %d exceeded max %d", distRuntimeFileGrowth, options.DistRuntimeFileGrowthMax))
	}
	if distRuntimeByteGrowth > options.DistRuntimeByteGrowthMax {
		failures = append(failures, fmt.Sprintf("dist-runtime apparent byte growth %d exceeded max %d", distRuntimeByteGrowth, options.DistRuntimeByteGrowthMax))
	}
	if !(cpuMs >= 0) {
		failures = append(failures, "failed to parse CPU timing from the bounded gateway:watch run")
	} else if cpuMs > options.CpuFailMs {
		failures = append(failures, fmt.Sprintf("LOUD ALARM: gateway:watch used %dms CPU in %dms window, above loud-alarm threshold %dms", cpuMs, options.WindowMs, options.CpuFailMs))
	} else if cpuMs > options.CpuWarnMs {
		warnings = append(warnings, fmt.Sprintf("gateway:watch used %dms CPU in %dms window, above target %dms", cpuMs, options.WindowMs, options.CpuWarnMs))
	}
	for _, message := range warnings {
		warn(message)
	}
	if len(failures) > 0 {
		for _, message := range failures {
			fail(message)
		}
		allDirty := true
		for _, message := range failures {
			if !strings.Contains(message, "dirty watched source tree") {
				allDirty = false
				break
			}
		}
		if !allDirty {
			fail("Possible duplicate dist-runtime graph regression: this can reintroduce split runtime personalities where plugins and core observe different global state, including Telegram missing /voice, /phone, or /pair.")
		}
		os.Exit(1)
	}
	os.Exit(0)
}

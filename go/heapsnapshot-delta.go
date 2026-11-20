// abstraction-provenance: {"artifact_sha256": "45fa0fd7b9b531b9e7b0235d3c796e01b383f3df2f668ca712afbbd489860930", "source_sha256": "d38a1b483644fdcb8d1b3d4826eb7c89f54ac769bf87debab3ab554e0544844f", "target_language": "go"}
// heapsnapshot-delta.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/.agents/skills/openclaw-test-heap-leaks/scripts/heapsnapshot-delta.mjs
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"unicode"
)

type Options struct {
	Top       int
	MinKb     int
	LaneDir   string
	Pid       *int
	Files     []string
}

type HeapFileEntry struct {
	FilePath string
	Pid      int
	Stamp    string
	Sequence int
}

type JsonStreamScanner struct {
	reader   *bufio.Reader
	buffer   string
	offset   int
	done     bool
}

type SummaryEntry struct {
	Type     string
	Name     string
	SelfSize int
	Count    int
}

type DeltaRow struct {
	Type       string
	Name       string
	SizeDelta  int
	CountDelta int
	AfterSize  int
	AfterCount int
}

func printUsage() {
	fmt.Fprintln(os.Stderr, "Usage: go run heapsnapshot-delta.go <before.heapsnapshot> <after.heapsnapshot> [--top N] [--min-kb N]")
	fmt.Fprintln(os.Stderr, "   or: go run heapsnapshot-delta.go --lane-dir <dir> [--pid PID] [--top N] [--min-kb N]")
}

func fail(message string) {
	fmt.Fprintln(os.Stderr, message)
	os.Exit(1)
}

func parseInt(s string) int {
	i, err := strconv.Atoi(s)
	if err != nil {
		fail(fmt.Sprintf("Invalid integer: %s", s))
	}
	return i
}

func parseArgs(argv []string) *Options {
	options := &Options{
		Top:     30,
		MinKb:   64,
		LaneDir: "",
		Pid:     nil,
		Files:   make([]string, 0),
	}

	for index := 0; index < len(argv); index++ {
		arg := argv[index]
		switch arg {
		case "--top":
			if index+1 >= len(argv) {
				fail("--top requires a value")
			}
			options.Top = parseInt(argv[index+1])
			index++
		case "--min-kb":
			if index+1 >= len(argv) {
				fail("--min-kb requires a value")
			}
			options.MinKb = parseInt(argv[index+1])
			index++
		case "--lane-dir":
			if index+1 >= len(argv) {
				fail("--lane-dir requires a value")
			}
			options.LaneDir = argv[index+1]
			index++
		case "--pid":
			if index+1 >= len(argv) {
				fail("--pid requires a value")
			}
			pid := parseInt(argv[index+1])
			options.Pid = &pid
			index++
		default:
			options.Files = append(options.Files, arg)
		}
	}

	if options.Top <= 0 {
		fail("--top must be a positive integer")
	}
	if options.MinKb < 0 {
		fail("--min-kb must be a non-negative integer")
	}
	if options.Pid != nil && *options.Pid <= 0 {
		fail("--pid must be a positive integer")
	}

	return options
}

func NewJsonStreamScanner(filePath string) *JsonStreamScanner {
	file, err := os.Open(filePath)
	if err != nil {
		fail(fmt.Sprintf("Failed to open file: %v", err))
	}
	
	return &JsonStreamScanner{
		reader: bufio.NewReaderSize(file, 1024*1024),
		buffer: "",
		offset: 0,
		done:   false,
	}
}

func (j *JsonStreamScanner) compactBuffer() {
	if j.offset > 65536 {
		j.buffer = j.buffer[j.offset:]
		j.offset = 0
	}
}

func (j *JsonStreamScanner) ensureAvailable(count int) error {
	for !j.done && len(j.buffer)-j.offset < count {
		chunk, err := j.reader.ReadString('\n')
		if err == io.EOF {
			j.done = true
			break
		}
		if err != nil {
			return err
		}
		j.buffer += chunk
	}
	return nil
}

func (j *JsonStreamScanner) peek() (byte, error) {
	err := j.ensureAvailable(1)
	if err != nil {
		return 0, err
	}
	if j.offset >= len(j.buffer) {
		return 0, nil
	}
	return j.buffer[j.offset], nil
}

func (j *JsonStreamScanner) next() (byte, error) {
	err := j.ensureAvailable(1)
	if err != nil {
		return 0, err
	}
	if j.offset >= len(j.buffer) {
		return 0, nil
	}
	char := j.buffer[j.offset]
	j.offset++
	j.compactBuffer()
	return char, nil
}

func (j *JsonStreamScanner) skipWhitespace() error {
	for {
		char, err := j.peek()
		if err != nil {
			return err
		}
		if char == 0 || !unicode.IsSpace(rune(char)) {
			return nil
		}
		_, err = j.next()
		if err != nil {
			return err
		}
	}
}

func (j *JsonStreamScanner) expectChar(expected byte) error {
	char, err := j.next()
	if err != nil {
		return err
	}
	if char != expected {
		fail(fmt.Sprintf("Expected %c but found %c", expected, char))
	}
	return nil
}

func (j *JsonStreamScanner) find(sequence string) error {
	matched := 0
	for {
		char, err := j.next()
		if err != nil {
			return err
		}
		if char == 0 {
			fail(fmt.Sprintf("Could not find %s", sequence))
		}
		if char == sequence[matched] {
			matched++
			if matched == len(sequence) {
				return nil
			}
			continue
		}
		if char == sequence[0] {
			matched = 1
		} else {
			matched = 0
		}
		if matched == len(sequence) {
			return nil
		}
	}
}

func (j *JsonStreamScanner) readBalancedObject() (string, error) {
	start, err := j.next()
	if err != nil {
		return "", err
	}
	if start != '{' {
		fail(fmt.Sprintf("Expected { but found %c", start))
	}
	text := "{"
	depth := 1
	inString := false
	escaped := false
	
	for depth > 0 {
		char, err := j.next()
		if err != nil {
			return "", err
		}
		if char == 0 {
			fail("Unexpected EOF while reading JSON object")
		}
		text += string(char)
		
		if inString {
			if escaped {
				escaped = false
			} else if char == '\\' {
				escaped = true
			} else if char == '"' {
				inString = false
			}
			continue
		}
		
		if char == '"' {
			inString = true
		} else if char == '{' {
			depth++
		} else if char == '}' {
			depth--
		}
	}
	
	return text, nil
}

func (j *JsonStreamScanner) parseNumberArray(onValue func(int, int)) error {
	err := j.skipWhitespace()
	if err != nil {
		return err
	}
	err = j.expectChar('[')
	if err != nil {
		return err
	}
	err = j.skipWhitespace()
	if err != nil {
		return err
	}
	
	char, err := j.peek()
	if err != nil {
		return err
	}
	if char == ']' {
		_, err = j.next()
		return err
	}

	token := ""
	index := 0
	flush := func() {
		if len(token) == 0 {
			fail("Unexpected empty number token")
		}
		value, err := strconv.Atoi(token)
		if err != nil {
			fail(fmt.Sprintf("Invalid numeric token: %s", token))
		}
		onValue(value, index)
		index++
		token = ""
	}

	for {
		char, err := j.next()
		if err != nil {
			return err
		}
		if char == 0 {
			fail("Unexpected EOF while reading number array")
		}
		if char == ']' {
			flush()
			return nil
		}
		if char == ',' {
			flush()
			continue
		}
		if unicode.IsSpace(rune(char)) {
			continue
		}
		token += string(char)
	}
}

func (j *JsonStreamScanner) readJsonString() (string, error) {
	err := j.expectChar('"')
	if err != nil {
		return "", err
	}
	value := ""
	for {
		char, err := j.next()
		if err != nil {
			return "", err
		}
		if char == 0 {
			fail("Unexpected EOF while reading JSON string")
		}
		if char == '"' {
			return value, nil
		}
		if char != '\\' {
			value += string(char)
			continue
		}
		escaped, err := j.next()
		if err != nil {
			return "", err
		}
		if escaped == 0 {
			fail("Unexpected EOF while reading JSON string escape")
		}
		if escaped == 'u' {
			hex := ""
			for i := 0; i < 4; i++ {
				hexChar, err := j.next()
				if err != nil {
					return "", err
				}
				if hexChar == 0 {
					fail("Unexpected EOF while reading JSON unicode escape")
				}
				hex += string(hexChar)
			}
			hexVal, err := strconv.ParseInt(hex, 16, 32)
			if err != nil {
				fail(fmt.Sprintf("Invalid hex value: %s", hex))
			}
			value += string(rune(hexVal))
			continue
		}
		switch escaped {
		case 'b':
			value += "\b"
		case 'f':
			value += "\f"
		case 'n':
			value += "\n"
		case 'r':
			value += "\r"
		case 't':
			value += "\t"
		default:
			value += string(escaped)
		}
	}
}

func (j *JsonStreamScanner) parseStringArray(onValue func(string, int)) error {
	err := j.skipWhitespace()
	if err != nil {
		return err
	}
	err = j.expectChar('[')
	if err != nil {
		return err
	}
	err = j.skipWhitespace()
	if err != nil {
		return err
	}
	
	char, err := j.peek()
	if err != nil {
		return err
	}
	if char == ']' {
		_, err = j.next()
		return err
	}

	index := 0
	for {
		value, err := j.readJsonString()
		if err != nil {
			return err
		}
		onValue(value, index)
		index++
		err = j.skipWhitespace()
		if err != nil {
			return err
		}
		separator, err := j.next()
		if err != nil {
			return err
		}
		if separator == ']' {
			return nil
		}
		if separator != ',' {
			fail(fmt.Sprintf("Expected , or ] but found %c", separator))
		}
		err = j.skipWhitespace()
		if err != nil {
			return err
		}
	}
}

func parseHeapFilename(filePath string) *HeapFileEntry {
	base := filepath.Base(filePath)
	re := regexp.MustCompile(`^Heap\.(?P<stamp>\d{8}\.\d{6})\.(?P<pid>\d+)\.0\.(?P<seq>\d+)\.heapsnapshot$`)
	match := re.FindStringSubmatch(base)
	if match == nil {
		return nil
	}
	
	result := make(map[string]string)
	for i, name := range re.SubexpNames() {
		if i != 0 && name != "" {
			result[name] = match[i]
		}
	}
	
	pid, _ := strconv.Atoi(result["pid"])
	seq, _ := strconv.Atoi(result["seq"])
	
	return &HeapFileEntry{
		FilePath: filePath,
		Pid:      pid,
		Stamp:    result["stamp"],
		Sequence: seq,
	}
}

func resolvePair(options *Options) map[string]interface{} {
	if options.LaneDir != "" {
		entries := make([]*HeapFileEntry, 0)
		files, err := os.ReadDir(options.LaneDir)
		if err != nil {
			fail(fmt.Sprintf("Failed to read directory: %v", err))
		}
		
		for _, file := range files {
			if !file.IsDir() {
				entry := parseHeapFilename(filepath.Join(options.LaneDir, file.Name()))
				if entry != nil {
					if options.Pid == nil || entry.Pid == *options.Pid {
						entries = append(entries, entry)
					}
				}
			}
		}
		
		// Sort entries
		sort.Slice(entries, func(i, j int) bool {
			if entries[i].Pid != entries[j].Pid {
				return entries[i].Pid < entries[j].Pid
			}
			if entries[i].Stamp != entries[j].Stamp {
				return entries[i].Stamp < entries[j].Stamp
			}
			return entries[i].Sequence < entries[j].Sequence
		})
		
		if len(entries) == 0 {
			fail(fmt.Sprintf("No matching heap snapshots found in %s", options.LaneDir))
		}
		
		groups := make(map[int][]*HeapFileEntry)
		for _, entry := range entries {
			if _, exists := groups[entry.Pid]; !exists {
				groups[entry.Pid] = make([]*HeapFileEntry, 0)
			}
			groups[entry.Pid] = append(groups[entry.Pid], entry)
		}
		
		candidates := make([]map[string]interface{}, 0)
		for pid, group := range groups {
			if len(group) >= 2 {
				candidates = append(candidates, map[string]interface{}{
					"pid":      pid,
					"before":   group[0],
					"after":    group[len(group)-1],
					"count":    len(group),
				})
			}
		}
		
		if len(candidates) == 0 {
			fail(fmt.Sprintf("Need at least two snapshots for one PID in %s", options.LaneDir))
		}
		
		var chosen map[string]interface{}
		if options.Pid != nil {
			for _, candidate := range candidates {
				if candidate["pid"].(int) == *options.Pid {
					chosen = candidate
					break
				}
			}
		} else {
			// Sort by count descending, then by pid ascending
			sort.Slice(candidates, func(i, j int) bool {
				countI := candidates[i]["count"].(int)
				countJ := candidates[j]["count"].(int)
				if countI != countJ {
					return countI > countJ
				}
				return candidates[i]["pid"].(int) < candidates[j]["pid"].(int)
			})
			chosen = candidates[0]
		}
		
		if chosen == nil {
			fail(fmt.Sprintf("No PID with at least two snapshots matched in %s", options.LaneDir))
		}
		
		return map[string]interface{}{
			"before":        chosen["before"].(*HeapFileEntry).FilePath,
			"after":         chosen["after"].(*HeapFileEntry).FilePath,
			"pid":           chosen["pid"],
			"snapshotCount": chosen["count"],
		}
	}
	
	if len(options.Files) != 2 {
		printUsage()
		os.Exit(1)
	}
	
	return map[string]interface{}{
		"before":        options.Files[0],
		"after":         options.Files[1],
		"pid":           nil,
		"snapshotCount": 2,
	}
}

func parseSnapshotMeta(scanner *JsonStreamScanner) (map[string]interface{}, error) {
	err := scanner.find("\"snapshot\":")
	if err != nil {
		return nil, err
	}
	err = scanner.skipWhitespace()
	if err != nil {
		return nil, err
	}
	metaObjectText, err := scanner.readBalancedObject()
	if err != nil {
		return nil, err
	}
	
	var parsed map[string]interface{}
	err = json.Unmarshal([]byte(metaObjectText), &parsed)
	if err != nil {
		return nil, err
	}
	
	if meta, exists := parsed["meta"]; exists {
		return meta.(map[string]interface{}), nil
	}
	return nil, nil
}

func buildSummary(filePath string) (map[string]interface{}, error) {
	scanner := NewJsonStreamScanner(filePath)
	meta, err := parseSnapshotMeta(scanner)
	if err != nil {
		return nil, err
	}
	if meta == nil {
		fail(fmt.Sprintf("Invalid heap snapshot: %s", filePath))
	}
	
	nodeFields := meta["node_fields"].([]interface{})
	nodeTypes := meta["node_types"].([]interface{})
	
	nodeFieldCount := len(nodeFields)
	typeNames := nodeTypes[0].([]interface{})
	
	typeIndex := -1
	nameIndex := -1
	selfSizeIndex := -1
	
	for i, field := range nodeFields {
		fieldStr := field.(string)
		if fieldStr == "type" {
			typeIndex = i
		} else if fieldStr == "name" {
			nameIndex = i
		} else if fieldStr == "self_size" {
			selfSizeIndex = i
		}
	}
	
	if typeIndex == -1 || nameIndex == -1 || selfSizeIndex == -1 {
		fail(fmt.Sprintf("Unsupported heap snapshot schema: %s", filePath))
	}
	
	summaryByIndex := make(map[string]map[string]interface{})
	nodeCount := 0
	currentTypeId := 0
	currentNameId := 0
	currentSelfSize := 0
	
	err = scanner.find("\"nodes\":")
	if err != nil {
		return nil, err
	}
	
	err = scanner.parseNumberArray(func(value int, index int) {
		fieldIndex := index % nodeFieldCount
		if fieldIndex == typeIndex {
			currentTypeId = value
			return
		}
		if fieldIndex == nameIndex {
			currentNameId = value
			return
		}
		if fieldIndex == selfSizeIndex {
			currentSelfSize = value
		}
		if fieldIndex != nodeFieldCount-1 {
			return
		}
		
		key := fmt.Sprintf("%d\t%d", currentTypeId, currentNameId)
		current, exists := summaryByIndex[key]
		if !exists {
			current = map[string]interface{}{
				"typeId":   currentTypeId,
				"nameId":   currentNameId,
				"selfSize": 0,
				"count":    0,
			}
		}
		current["selfSize"] = current["selfSize"].(int) + currentSelfSize
		current["count"] = current["count"].(int) + 1
		summaryByIndex[key] = current
		nodeCount++
	})
	
	if err != nil {
		return nil, err
	}
	
	requiredNameIds := make(map[int]bool)
	for _, entry := range summaryByIndex {
		nameId := entry["nameId"].(int)
		if nameId >= 0 {
			requiredNameIds[nameId] = true
		}
	}
	
	nameStrings := make(map[int]string)
	err = scanner.find("\"strings\":")
	if err != nil {
		return nil, err
	}
	
	err = scanner.parseStringArray(func(value string, index int) {
		if requiredNameIds[index] {
			nameStrings[index] = value
		}
	})
	
	if err != nil {
		return nil, err
	}
	
	summary := make(map[string]SummaryEntry)
	for _, entry := range summaryByIndex {
		typeId := entry["typeId"].(int)
		nameId := entry["nameId"].(int)
		typeName := "unknown"
		if typeId < len(typeNames) {
			if str, ok := typeNames[typeId].(string); ok {
				typeName = str
			}
		}
		
		name := ""
		if val, exists := nameStrings[nameId]; exists {
			name = val
		}
		
		key := fmt.Sprintf("%s\t%s", typeName, name)
		summary[key] = SummaryEntry{
			Type:     typeName,
			Name:     name,
			SelfSize: entry["selfSize"].(int),
			Count:    entry["count"].(int),
		}
	}
	
	return map[string]interface{}{
		"nodeCount": nodeCount,
		"summary":   summary,
	}, nil
}

func formatBytes(bytes int) string {
	absBytes := int(math.Abs(float64(bytes)))
	if absBytes >= 1024*1024 {
		return fmt.Sprintf("%.2f MiB", float64(bytes)/(1024*1024))
	}
	if absBytes >= 1024 {
		return fmt.Sprintf("%.1f KiB", float64(bytes)/1024)
	}
	return fmt.Sprintf("%d B", bytes)
}

func formatDelta(bytes int) string {
	sign := "+"
	if bytes < 0 {
		sign = "-"
	}
	return fmt.Sprintf("%s%s", sign, formatBytes(int(math.Abs(float64(bytes)))))
}

func truncate(text string, maxLength int) string {
	if len(text) <= maxLength {
		return text
	}
	return text[:maxLength-1] + "…"
}

func main() {
	options := parseArgs(os.Args[1:])
	pair := resolvePair(options)
	
	beforeResult, err := buildSummary(pair["before"].(string))
	if err != nil {
		fail(fmt.Sprintf("Failed to build summary for before file: %v", err))
	}
	
	afterResult, err := buildSummary(pair["after"].(string))
	if err != nil {
		fail(fmt.Sprintf("Failed to build summary for after file: %v", err))
	}
	
	before := beforeResult["summary"].(map[string]SummaryEntry)
	after := afterResult["summary"].(map[string]SummaryEntry)
	minBytes := options.MinKb * 1024
	
	rows := make([]DeltaRow, 0)
	for key, next := range after {
		previous, exists := before[key]
		if !exists {
			previous = SummaryEntry{SelfSize: 0, Count: 0}
		}
		sizeDelta := next.SelfSize - previous.SelfSize
		countDelta := next.Count - previous.Count
		if sizeDelta >= minBytes {
			rows = append(rows, DeltaRow{
				Type:       next.Type,
				Name:       next.Name,
				SizeDelta:  sizeDelta,
				CountDelta: countDelta,
				AfterSize:  next.SelfSize,
				AfterCount: next.Count,
			})
		}
	}
	
	// Sort rows by sizeDelta descending, then by countDelta descending
	sort.Slice(rows, func(i, j int) bool {
		if rows[i].SizeDelta != rows[j].SizeDelta {
			return rows[i].SizeDelta > rows[j].SizeDelta
		}
		return rows[i].CountDelta > rows[j].CountDelta
	})
	
	fmt.Printf("before: %s\n", pair["before"])
	fmt.Printf("after:  %s\n", pair["after"])
	if pair["pid"] != nil {
		fmt.Printf("pid:    %d (%d snapshots found)\n", pair["pid"], pair["snapshotCount"])
	}
	
	beforeNodeCount := beforeResult["nodeCount"].(int)
	afterNodeCount := afterResult["nodeCount"].(int)
	nodeDelta := afterNodeCount - beforeNodeCount
	sign := "+"
	if nodeDelta < 0 {
		sign = ""
	}
	fmt.Printf("nodes:   %d -> %d (%s%d)\n", beforeNodeCount, afterNodeCount, sign, nodeDelta)
	fmt.Printf("filter:  top=%d min=%d KiB\n", options.Top, options.MinKb)
	fmt.Println("")
	
	if len(rows) == 0 {
		fmt.Println("No entries exceeded the minimum delta.")
		return
	}
	
	limit := options.Top
	if limit > len(rows) {
		limit = len(rows)
	}
	
	for i := 0; i < limit; i++ {
		row := rows[i]
		countSign := "+"
		if row.CountDelta < 0 {
			countSign = ""
		}
		
		fmt.Printf("%11s  %10s  %-16s  %s\n",
			formatDelta(row.SizeDelta),
			fmt.Sprintf("count %s%d", countSign, row.CountDelta),
			row.Type,
			truncate(row.Name, 96))
	}
}

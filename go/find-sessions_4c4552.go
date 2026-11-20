// abstraction-provenance: {"artifact_sha256": "6fa5f4a19b6a301918b10b597221ddf28dfcebaf8443ba1c940358a4f7da16ff", "source_sha256": "4c4552ce0adb2754080969f00b761c1c118766771e0595b8c9b416ee0842fbae", "target_language": "go"}
// find-sessions.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/skills/tmux/scripts/find-sessions.sh
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

var (
	socketName  string
	socketPath  string
	query       string
	scanAll     bool
	socketDir   string
	help        bool
)

func usage() {
	fmt.Print(`Usage: find-sessions [-L socket-name|-S socket-path|-A] [-q pattern]

List tmux sessions on a socket (default tmux socket if none provided).

Options:
  -L, --socket       tmux socket name (passed to tmux -L)
  -S, --socket-path  tmux socket path (passed to tmux -S)
  -A, --all          scan all sockets under OPENCLAW_TMUX_SOCKET_DIR
  -q, --query        case-insensitive substring to filter session names
  -h, --help         show this help
`)
}

func init() {
	flag.StringVar(&socketName, "L", "", "tmux socket name (passed to tmux -L)")
	flag.StringVar(&socketName, "socket", "", "tmux socket name (passed to tmux -L)")
	flag.StringVar(&socketPath, "S", "", "tmux socket path (passed to tmux -S)")
	flag.StringVar(&socketPath, "socket-path", "", "tmux socket path (passed to tmux -S)")
	flag.BoolVar(&scanAll, "A", false, "scan all sockets under OPENCLAW_TMUX_SOCKET_DIR")
	flag.BoolVar(&scanAll, "all", false, "scan all sockets under OPENCLAW_TMUX_SOCKET_DIR")
	flag.StringVar(&query, "q", "", "case-insensitive substring to filter session names")
	flag.StringVar(&query, "query", "", "case-insensitive substring to filter session names")
	flag.BoolVar(&help, "h", false, "show this help")
	flag.BoolVar(&help, "help", false, "show this help")
	
	flag.Usage = usage
}

func main() {
	flag.Parse()
	
	if help {
		usage()
		os.Exit(0)
	}
	
	// Set socket directory
	socketDirEnv := os.Getenv("OPENCLAW_TMUX_SOCKET_DIR")
	if socketDirEnv == "" {
		tmpDir := os.Getenv("TMPDIR")
		if tmpDir == "" {
			tmpDir = "/tmp"
		}
		socketDirEnv = filepath.Join(tmpDir, "openclaw-tmux-sockets")
	}
	socketDir = socketDirEnv
	
	if scanAll && (socketName != "" || socketPath != "") {
		fmt.Fprintln(os.Stderr, "Cannot combine --all with -L or -S")
		os.Exit(1)
	}
	
	if socketName != "" && socketPath != "" {
		fmt.Fprintln(os.Stderr, "Use either -L or -S, not both")
		os.Exit(1)
	}
	
	_, err := exec.LookPath("tmux")
	if err != nil {
		fmt.Fprintln(os.Stderr, "tmux not found in PATH")
		os.Exit(1)
	}
	
	if scanAll {
		scanAllSockets()
		return
	}
	
	var tmuxCmd []string
	socketLabel := "default socket"
	
	if socketName != "" {
		tmuxCmd = []string{"-L", socketName}
		socketLabel = fmt.Sprintf("socket name '%s'", socketName)
	} else if socketPath != "" {
		tmuxCmd = []string{"-S", socketPath}
		socketLabel = fmt.Sprintf("socket path '%s'", socketPath)
	}
	
	listSessions(socketLabel, tmuxCmd...)
}

func listSessions(label string, tmuxArgs ...string) error {
	args := append([]string{}, tmuxArgs...)
	args = append(args, "list-sessions", "-F", "#{session_name}\t#{session_attached}\t#{session_created_string}")
	
	cmd := exec.Command("tmux", args...)
	output, err := cmd.CombinedOutput()
	
	if err != nil {
		fmt.Fprintf(os.Stderr, "No tmux server found on %s\n", label)
		return err
	}
	
	sessions := string(output)
	if strings.TrimSpace(sessions) == "" {
		fmt.Printf("No sessions found on %s\n", label)
		return nil
	}
	
	// Filter by query if provided
	if query != "" {
		lines := strings.Split(sessions, "\n")
		filteredLines := []string{}
		for _, line := range lines {
			if line != "" && strings.Contains(strings.ToLower(line), strings.ToLower(query)) {
				filteredLines = append(filteredLines, line)
			}
		}
		sessions = strings.Join(filteredLines, "\n")
		if len(filteredLines) == 0 {
			fmt.Printf("No sessions found on %s\n", label)
			return nil
		}
	}
	
	fmt.Printf("Sessions on %s:\n", label)
	scanner := bufio.NewScanner(strings.NewReader(sessions))
	for scanner.Scan() {
		line := scanner.Text()
		if line == "" {
			continue
		}
		parts := strings.Split(line, "\t")
		if len(parts) >= 3 {
			name := parts[0]
			attached := parts[1]
			created := parts[2]
			
			attachedLabel := "detached"
			if attached == "1" {
				attachedLabel = "attached"
			}
			fmt.Printf("  - %s (%s, started %s)\n", name, attachedLabel, created)
		}
	}
	
	return nil
}

func scanAllSockets() {
	if _, err := os.Stat(socketDir); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "Socket directory not found: %s\n", socketDir)
		os.Exit(1)
	}
	
	entries, err := os.ReadDir(socketDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading socket directory: %s\n", err)
		os.Exit(1)
	}
	
	if len(entries) == 0 {
		fmt.Fprintf(os.Stderr, "No sockets found under %s\n", socketDir)
		os.Exit(1)
	}
	
	exitCode := 0
	for _, entry := range entries {
		if entry.Type()&os.ModeSocket != 0 {
			sockPath := filepath.Join(socketDir, entry.Name())
			err := listSessions(fmt.Sprintf("socket path '%s'", sockPath), "-S", sockPath)
			if err != nil {
				exitCode = 1
			}
		}
	}
	os.Exit(exitCode)
}

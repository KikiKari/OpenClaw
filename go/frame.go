// abstraction-provenance: {"artifact_sha256": "8f7e548c050cfa94d2ac5321e5f50bbf0c7ef957f427fd101b7cdd6e5a608df8", "source_sha256": "b339455e9e618c836ccf2e3732e4fec9897f079730d8814eadb716e2459df453", "target_language": "go"}
// frame.sh — portiert nach go
// Quelle: shell, OpenClaw@gateway1:skills/video-frames/scripts/frame.sh
// auch in: OpenClaw@gateway2:skills/video-frames/scripts/frame.sh
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func usage() {
	fmt.Fprintln(os.Stderr, `Usage:
  frame.go <video-file> [--time HH:MM:SS] [--index N] --out /path/to/frame.jpg

Examples:
  frame.go video.mp4 --out /tmp/frame.jpg
  frame.go video.mp4 --time 00:00:10 --out /tmp/frame-10s.jpg
  frame.go video.mp4 --index 0 --out /tmp/frame0.png`)
	os.Exit(2)
}

func main() {
	if len(os.Args) < 2 || os.Args[1] == "-h" || os.Args[1] == "--help" {
		usage()
	}

	in := os.Args[1]
	args := os.Args[2:]

	var time, index, out string

	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--time":
			i++
			if i >= len(args) {
				fmt.Fprintln(os.Stderr, "Missing value for --time")
				usage()
			}
			time = args[i]
		case "--index":
			i++
			if i >= len(args) {
				fmt.Fprintln(os.Stderr, "Missing value for --index")
				usage()
			}
			index = args[i]
		case "--out":
			i++
			if i >= len(args) {
				fmt.Fprintln(os.Stderr, "Missing value for --out")
				usage()
			}
			out = args[i]
		default:
			fmt.Fprintf(os.Stderr, "Unknown arg: %s\n", args[i])
			usage()
		}
	}

	if _, err := os.Stat(in); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "File not found: %s\n", in)
		os.Exit(1)
	}

	if out == "" {
		fmt.Fprintln(os.Stderr, "Missing --out")
		usage()
	}

	// Create output directory if it doesn't exist
	dir := filepath.Dir(out)
	if err := os.MkdirAll(dir, 0755); err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create directory %s: %v\n", dir, err)
		os.Exit(1)
	}

	var cmd *exec.Cmd

	if index != "" {
		cmd = exec.Command("ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
			"-i", in,
			"-vf", fmt.Sprintf("select=eq(n\\,%s)", index),
			"-vframes", "1",
			out)
	} else if time != "" {
		cmd = exec.Command("ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
			"-ss", time,
			"-i", in,
			"-frames:v", "1",
			out)
	} else {
		cmd = exec.Command("ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
			"-i", in,
			"-vf", "select=eq(n\\,0)",
			"-vframes", "1",
			out)
	}

	// Capture stderr for better error messages
	var stderr strings.Builder
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "ffmpeg error: %v\n%s\n", err, stderr.String())
		os.Exit(1)
	}

	fmt.Println(out)
}

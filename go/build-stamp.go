// abstraction-provenance: {"artifact_sha256": "7c2f4819a1fa99d41668d4c69779fbcc128db1421df91aada5279b1edd7f83b9", "source_sha256": "8537e4253cc6ca148bc7b8cee5f458bfd0843576263cad8e98ca2c46fa47f2f1", "target_language": "go"}
// build-stamp.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/build-stamp.mjs
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"time"
)

type Params struct {
	Cwd       string
	SpawnSync func(string, []string, string) (string, error)
	Fs        FileSystem
	Now       func() int64
}

type FileSystem interface {
	MkdirAll(path string, perm os.FileMode) error
	WriteFile(filename string, data []byte, perm os.FileMode) error
}

type OSFileSystem struct{}

func (OSFileSystem) MkdirAll(path string, perm os.FileMode) error {
	return os.MkdirAll(path, perm)
}

func (OSFileSystem) WriteFile(filename string, data []byte, perm os.FileMode) error {
	return os.WriteFile(filename, data, perm)
}

func resolveGitHead(params Params) *string {
	cwd := params.Cwd
	if cwd == "" {
		cwd, _ = os.Getwd()
	}
	
	spawnSync := params.SpawnSync
	if spawnSync == nil {
		spawnSync = func(name string, arg []string, dir string) (string, error) {
			cmd := exec.Command(name, arg...)
			cmd.Dir = dir
			output, err := cmd.Output()
			return string(output), err
		}
	}
	
	result, err := spawnSync("git", []string{"rev-parse", "HEAD"}, cwd)
	if err != nil {
		return nil
	}
	
	head := result
	for len(head) > 0 && (head[len(head)-1] == '\n' || head[len(head)-1] == '\r') {
		head = head[:len(head)-1]
	}
	
	if head == "" {
		return nil
	}
	
	return &head
}

func writeBuildStamp(params Params) (string, error) {
	cwd := params.Cwd
	if cwd == "" {
		cwd, _ = os.Getwd()
	}
	
	fs := params.Fs
	if fs == nil {
		fs = OSFileSystem{}
	}
	
	now := params.Now
	if now == nil {
		now = func() int64 {
			return time.Now().UnixNano() / int64(time.Millisecond)
		}
	}
	
	distRoot := filepath.Join(cwd, "dist")
	buildStampPath := filepath.Join(distRoot, ".buildstamp")
	
	head := resolveGitHead(Params{
		Cwd:       cwd,
		SpawnSync: params.SpawnSync,
	})
	
	var headStr string
	if head != nil {
		headStr = *head
	}
	
	err := fs.MkdirAll(distRoot, 0755)
	if err != nil {
		return "", err
	}
	
	stamp := struct {
		BuiltAt int64  `json:"builtAt"`
		Head    string `json:"head"`
	}{
		BuiltAt: now(),
		Head:    headStr,
	}
	
	data, err := json.Marshal(stamp)
	if err != nil {
		return "", err
	}
	
	err = fs.WriteFile(buildStampPath, append(data, '\n'), 0644)
	if err != nil {
		return "", err
	}
	
	return buildStampPath, nil
}

func main() {
	_, err := writeBuildStamp(Params{})
	if err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		os.Exit(1)
	}
}

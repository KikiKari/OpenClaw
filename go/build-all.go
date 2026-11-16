// abstraction-provenance: {"artifact_sha256": "a21f322e5ea97e91048a5612eff3059b217443e1392028b1609985f3aadea357", "source_sha256": "c07aee6a3f0a90788cfe647dfcc79cf95df841ce0459eb8ffd9bf6aaa426ea38", "target_language": "go"}
// build-all.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/build-all.mjs
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strings"
)

const (
	WINDOWS_BUILD_MAX_OLD_SPACE_MB = 4096
)

type Step struct {
	Label               string
	Kind                string
	PnpmArgs            []string
	Args                []string
	WindowsNodeOptions string
}

var BUILD_ALL_STEPS = []Step{
	{Label: "canvas:a2ui:bundle", Kind: "pnpm", PnpmArgs: []string{"canvas:a2ui:bundle"}},
	{Label: "tsdown", Kind: "node", Args: []string{"scripts/tsdown-build.mjs"}},
	{Label: "runtime-postbuild", Kind: "node", Args: []string{"scripts/runtime-postbuild.mjs"}},
	{Label: "write-npm-update-compat-sidecars", Kind: "node", Args: []string{"scripts/write-npm-update-compat-sidecars.mjs"}},
	{Label: "build-stamp", Kind: "node", Args: []string{"scripts/build-stamp.mjs"}},
	{Label: "build:plugin-sdk:dts", Kind: "pnpm", PnpmArgs: []string{"build:plugin-sdk:dts"}, WindowsNodeOptions: fmt.Sprintf("--max-old-space-size=%d", WINDOWS_BUILD_MAX_OLD_SPACE_MB)},
	{Label: "write-plugin-sdk-entry-dts", Kind: "node", Args: []string{"--import", "tsx", "scripts/write-plugin-sdk-entry-dts.ts"}},
	{Label: "check-plugin-sdk-exports", Kind: "node", Args: []string{"scripts/check-plugin-sdk-exports.mjs"}},
	{Label: "canvas-a2ui-copy", Kind: "node", Args: []string{"--import", "tsx", "scripts/canvas-a2ui-copy.ts"}},
	{Label: "copy-hook-metadata", Kind: "node", Args: []string{"--import", "tsx", "scripts/copy-hook-metadata.ts"}},
	{Label: "copy-export-html-templates", Kind: "node", Args: []string{"--import", "tsx", "scripts/copy-export-html-templates.ts"}},
	{Label: "write-build-info", Kind: "node", Args: []string{"--import", "tsx", "scripts/write-build-info.ts"}},
	{Label: "write-cli-startup-metadata", Kind: "node", Args: []string{"--experimental-strip-types", "scripts/write-cli-startup-metadata.ts"}},
	{Label: "write-cli-compat", Kind: "node", Args: []string{"--import", "tsx", "scripts/write-cli-compat.ts"}},
}

func resolveStepEnv(step Step, env map[string]string, platform string) map[string]string {
	if platform != "windows" || step.WindowsNodeOptions == "" {
		return env
	}
	
	currentNodeOptions := strings.TrimSpace(env["NODE_OPTIONS"])
	if strings.Contains(currentNodeOptions, step.WindowsNodeOptions) {
		return env
	}
	
	newEnv := make(map[string]string)
	for k, v := range env {
		newEnv[k] = v
	}
	
	if currentNodeOptions != "" {
		newEnv["NODE_OPTIONS"] = currentNodeOptions + " " + step.WindowsNodeOptions
	} else {
		newEnv["NODE_OPTIONS"] = step.WindowsNodeOptions
	}
	
	return newEnv
}

func getEnvMap() map[string]string {
	envMap := make(map[string]string)
	for _, envVar := range os.Environ() {
		parts := strings.SplitN(envVar, "=", 2)
		if len(parts) == 2 {
			envMap[parts[0]] = parts[1]
		}
	}
	return envMap
}

func resolvePnpmRunner(pnpmArgs []string, nodeExecPath string, npmExecPath string, comSpec string, platform string) (string, []string, bool, bool) {
	var command string
	var args []string
	var shell bool
	var windowsVerbatimArguments bool
	
	if platform == "windows" && strings.HasSuffix(npmExecPath, ".ps1") {
		command = "pwsh.exe"
		args = append([]string{"-ExecutionPolicy", "Bypass", "-File", npmExecPath}, append([]string{"run"}, pnpmArgs...)...)
		shell = true
		windowsVerbatimArguments = true
	} else if platform == "windows" && strings.HasSuffix(npmExecPath, ".cmd") {
		command = npmExecPath
		args = append([]string{"run"}, pnpmArgs...)
		shell = true
		windowsVerbatimArguments = true
	} else {
		command = nodeExecPath
		args = append([]string{npmExecPath, "run"}, pnpmArgs...)
		shell = false
		windowsVerbatimArguments = false
	}
	
	return command, args, shell, windowsVerbatimArguments
}

func resolveBuildAllStep(step Step, params map[string]interface{}) (string, []string, *exec.Cmd) {
	platform := "linux"
	if runtime.GOOS == "windows" {
		platform = "windows"
	}
	
	var env map[string]string
	if e, ok := params["env"]; ok {
		env = e.(map[string]string)
	} else {
		env = getEnvMap()
	}
	
	env = resolveStepEnv(step, env, platform)
	
	var command string
	var args []string
	
	if step.Kind == "pnpm" {
		nodeExecPath := ""
		if n, ok := params["nodeExecPath"]; ok {
			nodeExecPath = n.(string)
		} else {
			nodeExecPath = os.Args[0]
		}
		
		npmExecPath := ""
		if n, ok := params["npmExecPath"]; ok {
			npmExecPath = n.(string)
		} else {
			npmExecPath = env["npm_execpath"]
		}
		
		comSpec := ""
		if c, ok := params["comSpec"]; ok {
			comSpec = c.(string)
		} else {
			comSpec = env["ComSpec"]
		}
		
		var shell bool
		var windowsVerbatimArguments bool
		command, args, shell, windowsVerbatimArguments = resolvePnpmRunner(step.PnpmArgs, nodeExecPath, npmExecPath, comSpec, platform)
		
		cmd := exec.Command(command, args...)
		cmd.Stdin = os.Stdin
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		
		cmd.Env = []string{}
		for k, v := range env {
			cmd.Env = append(cmd.Env, k+"="+v)
		}
		
		if shell {
			cmd.WaitDelay = 0
		}
		
		return command, args, cmd
	} else {
		if n, ok := params["nodeExecPath"]; ok {
			command = n.(string)
		} else {
			command = os.Args[0]
		}
		args = step.Args
		
		cmd := exec.Command(command, args...)
		cmd.Stdin = os.Stdin
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		
		cmd.Env = []string{}
		for k, v := range env {
			cmd.Env = append(cmd.Env, k+"="+v)
		}
		
		return command, args, cmd
	}
}

func main() {
	for _, step := range BUILD_ALL_STEPS {
		fmt.Fprintf(os.Stderr, "[build-all] %s\n", step.Label)
		
		params := make(map[string]interface{})
		_, _, cmd := resolveBuildAllStep(step, params)
		
		err := cmd.Run()
		if err != nil {
			if exitError, ok := err.(*exec.ExitError); ok {
				os.Exit(exitError.ExitCode())
			} else {
				os.Exit(1)
			}
		}
	}
}

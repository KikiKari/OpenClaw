// abstraction-provenance: {"artifact_sha256": "e01ab33f3c498b51372348f46c988127d8e6d69ff75cff3390ee7f29ca6b2319", "source_sha256": "481f90055fd746cf4af45da5765d09d2a9289bac2b7aa0b2fecc8558803339d5", "target_language": "go"}
// stage-bundled-plugin-runtime-deps.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/stage-bundled-plugin-runtime-deps.mjs
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"time"
)

type PackageJSON struct {
	Name                    string            `json:"name"`
	Version                 string            `json:"version"`
	Dependencies            map[string]string `json:"dependencies,omitempty"`
	OptionalDependencies    map[string]string `json:"optionalDependencies,omitempty"`
	PeerDependencies        map[string]string `json:"peerDependencies,omitempty"`
	PeerDependenciesMeta    map[string]any    `json:"peerDependenciesMeta,omitempty"`
	DevDependencies         map[string]string `json:"devDependencies,omitempty"`
	Openclaw                *OpenclawConfig   `json:"openclaw,omitempty"`
}

type OpenclawConfig struct {
	Bundle *BundleConfig `json:"bundle,omitempty"`
}

type BundleConfig struct {
	StageRuntimeDependencies bool `json:"stageRuntimeDependencies,omitempty"`
}

type RuntimeDepsStamp struct {
	Fingerprint string `json:"fingerprint"`
	GeneratedAt string `json:"generatedAt"`
}

type NpmRunner struct {
	Command                  string
	Args                     []string
	Env                      map[string]string
	Shell                    bool
	WindowsVerbatimArguments bool
}

type InstallParams struct {
	Fingerprint string
	PackageJson PackageJSON
	PluginDir   string
	PluginId    string
	RepoRoot    string
	Attempt     int
}

type InstallFunction func(params InstallParams) error

var stagedRuntimeDepPruneRules = map[string][]string{
	"@larksuiteoapi/node-sdk": {"types"},
}

const runtimeDepsStagingVersion = 2

func readJson[T any](filePath string) (T, error) {
	var result T
	data, err := os.ReadFile(filePath)
	if err != nil {
		return result, err
	}
	err = json.Unmarshal(data, &result)
	return result, err
}

func writeJson[T any](filePath string, value T) error {
	data, err := json.MarshalIndent(value, "", "  ")
	if err != nil {
		return err
	}
	data = append(data, '\n')
	return os.WriteFile(filePath, data, 0644)
}

func removePathIfExists(targetPath string) error {
	return os.RemoveAll(targetPath)
}

func makeTempDir(parentDir, prefix string) (string, error) {
	return os.MkdirTemp(parentDir, prefix)
}

func sanitizeTempPrefixSegment(value string) string {
	normalized := strings.Join(strings.FieldsFunc(value, func(r rune) bool {
		return !((r >= 'A' && r <= 'Z') || (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '.' || r == '_' || r == '-')
	}), "-")
	
	result := ""
	for i := 0; i < len(normalized); i++ {
		if normalized[i] == '-' && len(result) > 0 && result[len(result)-1] == '-' {
			continue
		}
		result += string(normalized[i])
	}
	
	if len(result) > 0 {
		return result
	}
	return "plugin"
}

func replaceDir(targetPath, sourcePath string) error {
	err := removePathIfExists(targetPath)
	if err != nil {
		return err
	}
	
	err = os.Rename(sourcePath, targetPath)
	if err == nil {
		return nil
	}
	
	if !strings.Contains(err.Error(), "invalid cross-device link") && !strings.Contains(err.Error(), "crosses devices") {
		return err
	}
	
	err = copyDir(sourcePath, targetPath)
	if err != nil {
		return err
	}
	
	return removePathIfExists(sourcePath)
}

func copyDir(src, dst string) error {
	return filepath.Walk(src, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		
		relPath, err := filepath.Rel(src, path)
		if err != nil {
			return err
		}
		
		dstPath := filepath.Join(dst, relPath)
		
		if info.IsDir() {
			return os.MkdirAll(dstPath, info.Mode())
		}
		
		srcFile, err := os.Open(path)
		if err != nil {
			return err
		}
		defer srcFile.Close()
		
		dstFile, err := os.Create(dstPath)
		if err != nil {
			return err
		}
		defer dstFile.Close()
		
		_, err = io.Copy(dstFile, srcFile)
		if err != nil {
			return err
		}
		
		return dstFile.Chmod(info.Mode())
	})
}

func dependencyNodeModulesPath(nodeModulesDir, depName string) string {
	parts := strings.Split(depName, "/")
	return filepath.Join(append([]string{nodeModulesDir}, parts...)...)
}

func readInstalledDependencyVersion(nodeModulesDir, depName string) (string, error) {
	packageJsonPath := filepath.Join(dependencyNodeModulesPath(nodeModulesDir, depName), "package.json")
	if _, err := os.Stat(packageJsonPath); os.IsNotExist(err) {
		return "", nil
	}
	
	packageJson, err := readJson[PackageJSON](packageJsonPath)
	if err != nil {
		return "", err
	}
	
	if packageJson.Version != "" {
		return packageJson.Version, nil
	}
	return "", nil
}

func dependencyVersionSatisfied(spec, installedVersion string) bool {
	// Simplified semver check - in real implementation would need proper semver library
	return spec == installedVersion || strings.HasPrefix(spec, installedVersion) || strings.HasPrefix(installedVersion, spec)
}

func collectInstalledRuntimeClosure(rootNodeModulesDir string, dependencySpecs map[string]string) ([]string, error) {
	packageCache := make(map[string]PackageJSON)
	closure := make(map[string]bool)
	queue := make([]struct{ Name, Spec string }, 0)
	
	for name, spec := range dependencySpecs {
		queue = append(queue, struct{ Name, Spec string }{name, spec})
	}
	
	for len(queue) > 0 {
		item := queue[0]
		queue = queue[1:]
		
		installedVersion, err := readInstalledDependencyVersion(rootNodeModulesDir, item.Name)
		if err != nil {
			return nil, err
		}
		
		if installedVersion == "" || !dependencyVersionSatisfied(item.Spec, installedVersion) {
			return nil, nil
		}
		
		if closure[item.Name] {
			continue
		}
		
		var packageJson PackageJSON
		if cached, exists := packageCache[item.Name]; exists {
			packageJson = cached
		} else {
			packageJsonPath := filepath.Join(dependencyNodeModulesPath(rootNodeModulesDir, item.Name), "package.json")
			pkg, err := readJson[PackageJSON](packageJsonPath)
			if err != nil {
				return nil, err
			}
			packageJson = pkg
			packageCache[item.Name] = packageJson
		}
		
		closure[item.Name] = true
		
		for childName, childSpec := range packageJson.Dependencies {
			queue = append(queue, struct{ Name, Spec string }{childName, childSpec})
		}
		for childName, childSpec := range packageJson.OptionalDependencies {
			queue = append(queue, struct{ Name, Spec string }{childName, childSpec})
		}
	}
	
	result := make([]string, 0, len(closure))
	for name := range closure {
		result = append(result, name)
	}
	sort.Strings(result)
	
	return result, nil
}

func pruneStagedInstalledDependencyCargo(nodeModulesDir, depName string) error {
	prunePaths, exists := stagedRuntimeDepPruneRules[depName]
	if !exists {
		return nil
	}
	
	depRoot := dependencyNodeModulesPath(nodeModulesDir, depName)
	for _, relativePath := range prunePaths {
		pathToRemove := filepath.Join(depRoot, relativePath)
		err := removePathIfExists(pathToRemove)
		if err != nil {
			return err
		}
	}
	return nil
}

func pruneStagedRuntimeDependencyCargo(nodeModulesDir string) error {
	for depName := range stagedRuntimeDepPruneRules {
		err := pruneStagedInstalledDependencyCargo(nodeModulesDir, depName)
		if err != nil {
			return err
		}
	}
	return nil
}

func listBundledPluginRuntimeDirs(repoRoot string) ([]string, error) {
	extensionsRoot := filepath.Join(repoRoot, "dist", "extensions")
	if _, err := os.Stat(extensionsRoot); os.IsNotExist(err) {
		return []string{}, nil
	}
	
	entries, err := os.ReadDir(extensionsRoot)
	if err != nil {
		return nil, err
	}
	
	var result []string
	for _, entry := range entries {
		if entry.IsDir() {
			pluginDir := filepath.Join(extensionsRoot, entry.Name())
			packageJsonPath := filepath.Join(pluginDir, "package.json")
			if _, err := os.Stat(packageJsonPath); err == nil {
				result = append(result, pluginDir)
			}
		}
	}
	
	return result, nil
}

func hasRuntimeDeps(packageJson PackageJSON) bool {
	return (len(packageJson.Dependencies) > 0) || (len(packageJson.OptionalDependencies) > 0)
}

func shouldStageRuntimeDeps(packageJson PackageJSON) bool {
	return packageJson.Openclaw != nil && 
		   packageJson.Openclaw.Bundle != nil && 
		   packageJson.Openclaw.Bundle.StageRuntimeDependencies
}

func sanitizeBundledManifestForRuntimeInstall(pluginDir string) (PackageJSON, error) {
	manifestPath := filepath.Join(pluginDir, "package.json")
	packageJson, err := readJson[PackageJSON](manifestPath)
	if err != nil {
		return packageJson, err
	}
	
	changed := false
	
	if packageJson.PeerDependencies != nil {
		packageJson.PeerDependencies = nil
		changed = true
	}
	
	if packageJson.PeerDependenciesMeta != nil {
		packageJson.PeerDependenciesMeta = nil
		changed = true
	}
	
	if packageJson.DevDependencies != nil {
		packageJson.DevDependencies = nil
		changed = true
	}
	
	if changed {
		err = writeJson(manifestPath, packageJson)
		if err != nil {
			return packageJson, err
		}
	}
	
	return packageJson, nil
}

func resolveRuntimeDepsStampPath(pluginDir string) string {
	return filepath.Join(pluginDir, ".openclaw-runtime-deps-stamp.json")
}

func createRuntimeDepsFingerprint(packageJson PackageJSON) (string, error) {
	data := map[string]interface{}{
		"packageJson": packageJson,
		"pruneRules": func() [][2]interface{} {
			var rules [][2]interface{}
			for k, v := range stagedRuntimeDepPruneRules {
				rules = append(rules, [2]interface{}{k, v})
			}
			return rules
		}(),
		"version": runtimeDepsStagingVersion,
	}
	
	jsonData, err := json.Marshal(data)
	if err != nil {
		return "", err
	}
	
	hash := sha256.Sum256(jsonData)
	return hex.EncodeToString(hash[:]), nil
}

func readRuntimeDepsStamp(stampPath string) (*RuntimeDepsStamp, error) {
	if _, err := os.Stat(stampPath); os.IsNotExist(err) {
		return nil, nil
	}
	
	stamp, err := readJson[RuntimeDepsStamp](stampPath)
	if err != nil {
		return nil, nil
	}
	
	return &stamp, nil
}

func stageInstalledRootRuntimeDeps(fingerprint string, packageJson PackageJSON, pluginDir, repoRoot string) (bool, error) {
	dependencySpecs := make(map[string]string)
	for k, v := range packageJson.Dependencies {
		dependencySpecs[k] = v
	}
	for k, v := range packageJson.OptionalDependencies {
		dependencySpecs[k] = v
	}
	
	rootNodeModulesDir := filepath.Join(repoRoot, "node_modules")
	if len(dependencySpecs) == 0 || func() bool {
		_, err := os.Stat(rootNodeModulesDir)
		return os.IsNotExist(err)
	}() {
		return false, nil
	}
	
	dependencyNames, err := collectInstalledRuntimeClosure(rootNodeModulesDir, dependencySpecs)
	if err != nil || dependencyNames == nil {
		return false, err
	}
	
	nodeModulesDir := filepath.Join(pluginDir, "node_modules")
	stampPath := resolveRuntimeDepsStampPath(pluginDir)
	
	tempDir, err := makeTempDir(os.TempDir(), fmt.Sprintf("openclaw-runtime-deps-%s-", sanitizeTempPrefixSegment(filepath.Base(pluginDir))))
	if err != nil {
		return false, err
	}
	stagedNodeModulesDir := filepath.Join(tempDir, "node_modules")
	
	defer func() {
		removePathIfExists(filepath.Dir(stagedNodeModulesDir))
	}()
	
	for _, depName := range dependencyNames {
		sourcePath := dependencyNodeModulesPath(rootNodeModulesDir, depName)
		targetPath := dependencyNodeModulesPath(stagedNodeModulesDir, depName)
		
		err := os.MkdirAll(filepath.Dir(targetPath), 0755)
		if err != nil {
			return false, err
		}
		
		err = copyDir(sourcePath, targetPath)
		if err != nil {
			return false, err
		}
	}
	
	err = pruneStagedRuntimeDependencyCargo(stagedNodeModulesDir)
	if err != nil {
		return false, err
	}
	
	err = replaceDir(nodeModulesDir, stagedNodeModulesDir)
	if err != nil {
		return false, err
	}
	
	stamp := RuntimeDepsStamp{
		Fingerprint: fingerprint,
		GeneratedAt: time.Now().UTC().Format(time.RFC3339),
	}
	
	err = writeJson(stampPath, stamp)
	if err != nil {
		return false, err
	}
	
	return true, nil
}

func installPluginRuntimeDeps(fingerprint string, packageJson PackageJSON, pluginDir, pluginId, repoRoot string) error {
	if repoRoot != "" {
		success, err := stageInstalledRootRuntimeDeps(fingerprint, packageJson, pluginDir, repoRoot)
		if err != nil {
			return err
		}
		if success {
			return nil
		}
	}
	
	nodeModulesDir := filepath.Join(pluginDir, "node_modules")
	stampPath := resolveRuntimeDepsStampPath(pluginDir)
	
	tempInstallDir, err := makeTempDir(os.TempDir(), fmt.Sprintf("openclaw-runtime-deps-%s-", sanitizeTempPrefixSegment(pluginId)))
	if err != nil {
		return err
	}
	
	defer func() {
		removePathIfExists(tempInstallDir)
	}()
	
	npmRunner := resolveNpmRunner([]string{
		"install",
		"--omit=dev",
		"--silent",
		"--ignore-scripts",
		"--legacy-peer-deps",
		"--package-lock=false",
	})
	
	err = writeJson(filepath.Join(tempInstallDir, "package.json"), packageJson)
	if err != nil {
		return err
	}
	
	cmd := exec.Command(npmRunner.Command, npmRunner.Args...)
	cmd.Dir = tempInstallDir
	if npmRunner.Env != nil {
		env := os.Environ()
		for k, v := range npmRunner.Env {
			env = append(env, fmt.Sprintf("%s=%s", k, v))
		}
		cmd.Env = env
	}
	if npmRunner.Shell {
		if runtime.GOOS == "windows" {
			cmd = exec.Command("cmd", "/c", npmRunner.Command)
			cmd.Args = append(cmd.Args, npmRunner.Args...)
		} else {
			cmd = exec.Command("sh", "-c", npmRunner.Command+" "+strings.Join(npmRunner.Args, " "))
		}
	}
	
	output, err := cmd.CombinedOutput()
	if err != nil {
		outputStr := strings.TrimSpace(string(output))
		if outputStr == "" {
			outputStr = "npm install failed"
		}
		return fmt.Errorf("failed to stage bundled runtime deps for %s: %s", pluginId, outputStr)
	}
	
	stagedNodeModulesDir := filepath.Join(tempInstallDir, "node_modules")
	if _, err := os.Stat(stagedNodeModulesDir); os.IsNotExist(err) {
		return fmt.Errorf("failed to stage bundled runtime deps for %s: npm install produced no node_modules directory", pluginId)
	}
	
	err = pruneStagedRuntimeDependencyCargo(stagedNodeModulesDir)
	if err != nil {
		return err
	}
	
	err = replaceDir(nodeModulesDir, stagedNodeModulesDir)
	if err != nil {
		return err
	}
	
	stamp := RuntimeDepsStamp{
		Fingerprint: fingerprint,
		GeneratedAt: time.Now().UTC().Format(time.RFC3339),
	}
	
	return writeJson(stampPath, stamp)
}

func installPluginRuntimeDepsWithRetries(attempts int, installFn InstallFunction, installParams InstallParams) error {
	var lastError error
	for attempt := 1; attempt <= attempts; attempt++ {
		params := installParams
		params.Attempt = attempt
		
		err := installFn(params)
		if err == nil {
			return nil
		}
		
		lastError = err
		if attempt == attempts {
			break
		}
	}
	return lastError
}

func resolveNpmRunner(npmArgs []string) NpmRunner {
	command := "npm"
	args := npmArgs
	
	if runtime.GOOS == "windows" {
		if _, err := exec.LookPath("npm.cmd"); err == nil {
			command = "npm.cmd"
		}
	}
	
	return NpmRunner{
		Command: command,
		Args:    args,
		Env:     nil,
		Shell:   false,
	}
}

func stageBundledPluginRuntimeDeps(repoRoot string) error {
	pluginDirs, err := listBundledPluginRuntimeDirs(repoRoot)
	if err != nil {
		return err
	}
	
	for _, pluginDir := range pluginDirs {
		pluginId := filepath.Base(pluginDir)
		packageJson, err := sanitizeBundledManifestForRuntimeInstall(pluginDir)
		if err != nil {
			return err
		}
		
		nodeModulesDir := filepath.Join(pluginDir, "node_modules")
		stampPath := resolveRuntimeDepsStampPath(pluginDir)
		
		if !hasRuntimeDeps(packageJson) || !shouldStageRuntimeDeps(packageJson) {
			removePathIfExists(nodeModulesDir)
			removePathIfExists(stampPath)
			continue
		}
		
		fingerprint, err := createRuntimeDepsFingerprint(packageJson)
		if err != nil {
			return err
		}
		
		stamp, err := readRuntimeDepsStamp(stampPath)
		if err != nil {
			return err
		}
		
		if func() bool {
			_, err := os.Stat(nodeModulesDir)
			return err == nil
		}() && stamp != nil && stamp.Fingerprint == fingerprint {
			continue
		}
		
		installFn := func(params InstallParams) error {
			return installPluginRuntimeDeps(params.Fingerprint, params.PackageJson, params.PluginDir, params.PluginId, params.RepoRoot)
		}
		
		err = installPluginRuntimeDepsWithRetries(3, installFn, InstallParams{
			Fingerprint: fingerprint,
			PackageJson: packageJson,
			PluginDir:   pluginDir,
			PluginId:    pluginId,
			RepoRoot:    repoRoot,
		})
		if err != nil {
			return err
		}
	}
	
	return nil
}

func main() {
	cwd, err := os.Getwd()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error getting current directory: %v\n", err)
		os.Exit(1)
	}
	
	err = stageBundledPluginRuntimeDeps(cwd)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

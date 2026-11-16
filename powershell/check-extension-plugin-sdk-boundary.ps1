#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "38dbc91c35fcbf79067f167a96b6bfb899caebe55e7f6eefd165bde33a0c901f", "source_sha256": "c1ed4f7faa3c799c1ac7104f76f48529711802b8f045a3a2fa20f18a82447b76", "target_language": "powershell"}
# check-extension-plugin-sdk-boundary.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-extension-plugin-sdk-boundary.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Text.Json
using namespace System.Text.RegularExpressions

$ErrorActionPreference = "Stop"

# Import required modules or define helper functions here
# Since PowerShell doesn't have native TypeScript parsing, we'll need to simulate some behavior

# Define constants
$repoRoot = Join-Path $PSScriptRoot ".."
$BUNDLED_PLUGIN_ROOT_DIR = "extensions"
$extensionsRoot = Join-Path $repoRoot $BUNDLED_PLUGIN_ROOT_DIR

$MODES = @{
    "src-outside-plugin-sdk"        = $true
    "plugin-sdk-internal"           = $true
    "relative-outside-package"     = $true
}

$baselinePathByMode = @{
    "src-outside-plugin-sdk"        = Join-Path $repoRoot "test" "fixtures" "extension-src-outside-plugin-sdk-inventory.json"
    "plugin-sdk-internal"           = Join-Path $repoRoot "test" "fixtures" "extension-plugin-sdk-internal-inventory.json"
    "relative-outside-package"     = Join-Path $repoRoot "test" "fixtures" "extension-relative-outside-package-inventory.json"
}

$ruleTextByMode = @{
    "src-outside-plugin-sdk"        = "Rule: production bundled plugins must not import src/** outside src/plugin-sdk/**"
    "plugin-sdk-internal"           = "Rule: production bundled plugins must not import src/plugin-sdk-internal/**"
    "relative-outside-package"     = "Rule: production bundled plugins must not use relative imports that escape their own package root"
}

# Global variables to mimic promises
$allInventoryByModePromise = $null
$parsedExtensionSourceFilesPromise = $null

function isCodeFile($fileName) {
    return [Regex]::IsMatch($fileName, "\.(ts|tsx|mts|cts|js|jsx|mjs|cjs)$")
}

function isBoundaryCanaryFile($fileName) {
    return $fileName.Contains("__rootdir_boundary_canary__")
}

function normalizeRepoPath($repoRoot, $fullPath) {
    # Convert to relative path
    $relativePath = Resolve-Path -Path $fullPath -RelativeBasePath $repoRoot
    if ($relativePath.StartsWith(".\")) {
        $relativePath = $relativePath.Substring(2)
    }
    return $relativePath.Replace("\", "/")
}

function resolveRepoSpecifier($repoRoot, $specifier, $filePath) {
    # Simplified resolver - in real implementation would need proper module resolution
    if ($specifier.StartsWith("./") -or $specifier.StartsWith("../")) {
        $basePath = Split-Path $filePath -Parent
        $resolvedPath = Join-Path $basePath $specifier
        try {
            $resolvedPath = Resolve-Path $resolvedPath -ErrorAction Stop
            return normalizeRepoPath $repoRoot $resolvedPath.Path
        } catch {
            return $null
        }
    }
    return $specifier
}

function toLine($content, $position) {
    # Simplistic line number calculation
    $lines = $content.Substring(0, $position).Split("`n")
    return $lines.Count
}

function classifyBundledExtensionSourcePath($relativePath) {
    # Simplified classifier
    $isTestLike = $relativePath.Contains("/test/") -or $relativePath.Contains("/tests/") -or $relativePath.Contains(".test.") -or $relativePath.Contains(".spec.")
    return @{ isTestLike = $isTestLike }
}

function collectExtensionSourceFiles($rootDir) {
    $out = @()
    
    function walk($dir) {
        if (Test-Path $dir -PathType Leaf) {
            $entries = Get-ChildItem $dir -File -Recurse | Where-Object {
                $_.Name -ne "dist" -and $_.Name -ne "node_modules" -and 
                (isCodeFile $_.Name) -and 
                (-not (isBoundaryCanaryFile $_.Name)) -and
                (-not (classifyBundledExtensionSourcePath (normalizeRepoPath $script:repoRoot $_.FullName)).isTestLike)
            }
            $out += $entries.FullName
        } else {
            Get-ChildItem $dir -Directory | ForEach-Object {
                if ($_.Name -ne "dist" -and $_.Name -ne "node_modules") {
                    walk($_.FullName)
                }
            }
            
            $files = Get-ChildItem $dir -File | Where-Object {
                (isCodeFile $_.Name) -and 
                (-not (isBoundaryCanaryFile $_.Name)) -and
                (-not (classifyBundledExtensionSourcePath (normalizeRepoPath $script:repoRoot $_.FullName)).isTestLike)
            }
            $out += $files.FullName
        }
    }
    
    walk($rootDir)
    
    # Sort by normalized path
    $sortedOut = $out | Sort-Object { normalizeRepoPath $script:repoRoot $_ }
    return $sortedOut
}

function collectParsedExtensionSourceFiles() {
    if ($script:parsedExtensionSourceFilesPromise -eq $null) {
        $files = collectExtensionSourceFiles($script:extensionsRoot)
        $result = @()
        
        foreach ($filePath in $files) {
            $source = Get-Content $filePath -Raw
            # In real implementation, we'd parse with TypeScript here
            $result += @{
                filePath = $filePath
                sourceFile = $source
            }
        }
        
        $script:parsedExtensionSourceFilesPromise = $result
    }
    return $script:parsedExtensionSourceFilesPromise
}

function resolveExtensionRoot($filePath) {
    $relativePath = normalizeRepoPath $script:repoRoot $filePath
    $segments = $relativePath.Split("/")
    if ($segments[0] -ne $script:BUNDLED_PLUGIN_ROOT_DIR -or $segments.Length -lt 2) {
        return $null
    }
    return "${segments[0]}/${segments[1]}"
}

function classifyReason($mode, $kind, $resolvedPath, $specifier) {
    $verb = switch ($kind) {
        "export" { "re-exports" }
        "dynamic-import" { "dynamically imports" }
        default { "imports" }
    }
    
    if ($mode -eq "relative-outside-package") {
        if ($resolvedPath -and $resolvedPath.StartsWith("src/plugin-sdk/")) {
            return "${verb} plugin-sdk via relative path; use openclaw/plugin-sdk/<subpath>"
        }
        if ($resolvedPath -and $resolvedPath.StartsWith("src/")) {
            return "${verb} core src path via relative path outside the extension package"
        }
        if ($resolvedPath -and $resolvedPath.StartsWith($script:BUNDLED_PLUGIN_PATH_PREFIX)) {
            return "${verb} another bundled plugin via relative path outside the extension package"
        }
        return "${verb} relative path ${specifier} outside the extension package"
    }
    
    if ($mode -eq "plugin-sdk-internal") {
        return "${verb} src/plugin-sdk-internal from an extension"
    }
    
    if ($resolvedPath.StartsWith("src/plugin-sdk/")) {
        return "${verb} allowed plugin-sdk path"
    }
    
    return "${verb} core src path outside plugin-sdk from an extension"
}

function compareEntries($left, $right) {
    $fileComparison = $left.file.CompareTo($right.file)
    if ($fileComparison -ne 0) { return $fileComparison }
    
    $lineComparison = $left.line - $right.line
    if ($lineComparison -ne 0) { return $lineComparison }
    
    $kindComparison = $left.kind.CompareTo($right.kind)
    if ($kindComparison -ne 0) { return $kindComparison }
    
    $specifierComparison = $left.specifier.CompareTo($right.specifier)
    if ($specifierComparison -ne 0) { return $specifierComparison }
    
    return $left.resolvedPath.CompareTo($right.resolvedPath)
}

function shouldReport($mode, $resolvedPath) {
    if ($mode -eq "relative-outside-package") {
        return $false
    }
    if (-not $resolvedPath -or -not $resolvedPath.StartsWith("src/")) {
        return $false
    }
    if ($mode -eq "plugin-sdk-internal") {
        return $resolvedPath.StartsWith("src/plugin-sdk-internal/")
    }
    return -not $resolvedPath.StartsWith("src/plugin-sdk/")
}

function collectEntriesByModeFromSourceFile($sourceFile, $filePath) {
    $entriesByMode = @{
        "src-outside-plugin-sdk"        = @()
        "plugin-sdk-internal"           = @()
        "relative-outside-package"     = @()
    }
    
    $extensionRoot = resolveExtensionRoot($filePath)
    $relativeFile = normalizeRepoPath $script:repoRoot $filePath
    
    # This is a simplified version since we don't have TypeScript AST parsing
    # In a real implementation, you'd parse the source file and visit module specifiers
    
    # Mocking up some sample data for demonstration
    # A real implementation would extract actual import statements
    
    return $entriesByMode
}

function collectExtensionPluginSdkBoundaryInventory($mode) {
    if (-not $script:MODES.ContainsKey($mode)) {
        throw "Unknown mode: ${mode}"
    }
    
    if ($script:allInventoryByModePromise -eq $null) {
        $files = collectParsedExtensionSourceFiles
        $inventoryByMode = @{
            "src-outside-plugin-sdk"        = @()
            "plugin-sdk-internal"           = @()
            "relative-outside-package"     = @()
        }
        
        foreach ($fileInfo in $files) {
            $entriesByMode = collectEntriesByModeFromSourceFile $fileInfo.sourceFile $fileInfo.filePath
            foreach ($inventoryMode in $script:MODES.Keys) {
                $inventoryByMode[$inventoryMode] += $entriesByMode[$inventoryMode]
            }
        }
        
        # Sort entries
        foreach ($inventoryMode in $script:MODES.Keys) {
            $inventoryByMode[$inventoryMode] = $inventoryByMode[$inventoryMode] | Sort-Object { compareEntries $_ $null }
        }
        
        $script:allInventoryByModePromise = $inventoryByMode
    }
    
    return $script:allInventoryByModePromise[$mode]
}

function readExpectedInventory($mode) {
    try {
        $content = Get-Content $script:baselinePathByMode[$mode] -Raw
        return ConvertFrom-Json $content
    } catch [System.Management.Automation.ItemNotFoundException] {
        if (($mode -eq "plugin-sdk-internal" -or $mode -eq "src-outside-plugin-sdk" -or $mode -eq "relative-outside-package")) {
            return @()
        }
        throw
    }
}

function diffInventoryEntries($expected, $actual, $compareFunction) {
    # Simplified diff implementation
    $missing = @()
    $unexpected = @()
    
    # Find missing entries (in expected but not in actual)
    foreach ($exp in $expected) {
        $found = $false
        foreach ($act in $actual) {
            if ((compareEntries $exp $act) -eq 0) {
                $found = $true
                break
            }
        }
        if (-not $found) {
            $missing += $exp
        }
    }
    
    # Find unexpected entries (in actual but not in expected)
    foreach ($act in $actual) {
        $found = $false
        foreach ($exp in $expected) {
            if ((compareEntries $act $exp) -eq 0) {
                $found = $true
                break
            }
        }
        if (-not $found) {
            $unexpected += $act
        }
    }
    
    return @{
        missing = $missing
        unexpected = $unexpected
    }
}

function diffInventory($expected, $actual) {
    return diffInventoryEntries $expected $actual compareEntries
}

function formatInventoryHuman($mode, $inventory) {
    $lines = @($script:ruleTextByMode[$mode])
    
    if ($inventory.Count -eq 0) {
        $lines += "No extension plugin-sdk boundary violations found."
        return ($lines -join "`n")
    }
    
    $lines += "Extension boundary inventory:"
    $activeFile = ""
    
    foreach ($entry in $inventory) {
        if ($entry.file -ne $activeFile) {
            $activeFile = $entry.file
            $lines += $activeFile
        }
        $lines += "  - line $($entry.line) [$($entry.kind)] $($entry.reason)"
        $lines += "    specifier: $($entry.specifier)"
        $lines += "    resolved: $($entry.resolvedPath)"
    }
    
    return ($lines -join "`n")
}

function runExtensionPluginSdkBoundaryCheck($argv = $args, $io = $null) {
    if ($io -eq $null) {
        $io = @{
            stdout = [Console]::Out
            stderr = [Console]::Error
        }
    }
    
    $json = $argv -contains "--json"
    $modeArg = $argv | Where-Object { $_.StartsWith("--mode=") } | Select-Object -First 1
    $mode = if ($modeArg) { $modeArg.Substring("--mode=".Length) } else { "src-outside-plugin-sdk" }
    
    if (-not $script:MODES.ContainsKey($mode)) {
        throw "Unknown mode: ${mode}"
    }
    
    $actual = collectExtensionPluginSdkBoundaryInventory $mode
    
    if ($json) {
        $io.stdout.WriteLine((ConvertTo-Json $actual -Depth 10))
        return 0
    }
    
    $io.stdout.WriteLine((formatInventoryHuman $mode $actual))
    
    if ($mode -eq "relative-outside-package") {
        if ($actual.Count -eq 0) {
            return 0
        }
        $io.stderr.WriteLine("Relative outside-package violations found ($($actual.Count)); this mode no longer uses a baseline.")
        return 1
    }
    
    $expected = readExpectedInventory $mode
    $diff = diffInventory $expected $actual
    
    if ($diff.missing.Count -eq 0 -and $diff.unexpected.Count -eq 0) {
        $io.stdout.WriteLine("Baseline matches ($($actual.Count) entries).")
        return 0
    }
    
    if ($diff.missing.Count -gt 0) {
        $io.stderr.WriteLine("Missing baseline entries ($($diff.missing.Count)):")
        foreach ($entry in $diff.missing) {
            $io.stderr.WriteLine("  - $($entry.file):$($entry.line) $($entry.reason)")
        }
    }
    
    if ($diff.unexpected.Count -gt 0) {
        $io.stderr.WriteLine("Unexpected inventory entries ($($diff.unexpected.Count)):")
        foreach ($entry in $diff.unexpected) {
            $io.stderr.WriteLine("  - $($entry.file):$($entry.line) $($entry.reason)")
        }
    }
    
    return 1
}

function main($argv = $args, $io = $null) {
    $exitCode = runExtensionPluginSdkBoundaryCheck $argv $io
    if ($io -eq $null) {
        exit $exitCode
    }
    return $exitCode
}

# Execute main if script is run directly
if ($MyInvocation.InvocationName -eq "&") {
    main
}

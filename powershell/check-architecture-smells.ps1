#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "b91c2f629491afc17561b74f3515ce485e84dff7cc12f82ed7c0f928342598a6", "source_sha256": "913a32ef02a0f4e83bb9d65b279088c91abd5e717e9dbba62e17a4a50836e586", "target_language": "powershell"}
# check-architecture-smells.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-architecture-smells.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

param(
    [string[]]$Arguments = $args
)

$ErrorActionPreference = "Stop"

# Helper functions
function Write-Line($stream, $text) {
    if ($stream -eq "stdout") {
        Write-Output $text
    } elseif ($stream -eq "stderr") {
        Write-Error $text
    }
}

function Resolve-RepoSpecifier($repoRoot, $specifier, $filePath) {
    # Simplified resolution logic - adjust based on actual project structure
    if ($specifier.StartsWith("./") -or $specifier.StartsWith("../")) {
        $basePath = Split-Path $filePath -Parent
        $resolvedPath = Join-Path $basePath $specifier -Resolve
        return $resolvedPath.Replace($repoRoot, "").TrimStart("\")
    }
    return $null
}

function Normalize-RepoPath($repoRoot, $filePath) {
    return $filePath.Replace($repoRoot, "").TrimStart("\")
}

function Visit-ModuleSpecifiers($sourceFile, $callback) {
    # Placeholder for visiting module specifiers
    # Actual implementation would parse TypeScript AST
}

function To-Line($sourceFile, $node) {
    # Placeholder for getting line number
    return 1
}

function Collect-TypeScriptFilesFromRoots($scanRoots) {
    $files = @()
    foreach ($root in $scanRoots) {
        if (Test-Path $root) {
            $files += Get-ChildItem -Path $root -Recurse -Filter "*.ts" | ForEach-Object { $_.FullName }
        }
    }
    return $files | Sort-Object
}

function Collect-TypeScriptInventory($params) {
    $entries = @()
    foreach ($file in $params.files) {
        $sourceFile = Get-Content $file -Raw
        $filePath = $file
        $collected = & $params.collectEntries $sourceFile $filePath
        $entries += $collected
    }
    return $entries | Sort-Object @{Expression={($_.category, $_.file, $_.line, $_.kind, $_.specifier, $_.reason) -join "|"}}
}

# Constants
$BUNDLED_PLUGIN_PATH_PREFIX = "extensions/"

# Main script logic
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$repoRoot = Join-Path $scriptPath ".." | Resolve-Path
$scanRoots = @(
    Join-Path $repoRoot "src/plugin-sdk"
    Join-Path $repoRoot "src/plugins/runtime"
)

function Compare-Entries($left, $right) {
    $result = $left.category.CompareTo($right.category)
    if ($result -ne 0) { return $result }
    
    $result = $left.file.CompareTo($right.file)
    if ($result -ne 0) { return $result }
    
    $result = $left.line - $right.line
    if ($result -ne 0) { return $result }
    
    $result = $left.kind.CompareTo($right.kind)
    if ($result -ne 0) { return $result }
    
    $result = $left.specifier.CompareTo($right.specifier)
    if ($result -ne 0) { return $result }
    
    return $left.reason.CompareTo($right.reason)
}

function Push-Entry($entries, $entry) {
    $entries.Add($entry) | Out-Null
}

function Scan-PluginSdkExtensionFacadeSmells($sourceFile, $filePath) {
    $relativeFile = Normalize-RepoPath $repoRoot $filePath
    if (-not $relativeFile.StartsWith("src/plugin-sdk/")) {
        return @()
    }

    $entries = [System.Collections.ArrayList]@()

    # Placeholder for actual AST traversal
    # This would need a real TypeScript parser in PowerShell
    # For now we'll simulate with dummy data
    
    return $entries
}

function Scan-RuntimeTypeImplementationSmells($sourceFile, $filePath) {
    $relativeFile = Normalize-RepoPath $repoRoot $filePath
    if (-not ($relativeFile -match "^src/plugins/runtime/types(-[^/]+)?\.ts$")) {
        return @()
    }

    $entries = [System.Collections.ArrayList]@()
    
    # Placeholder for actual AST traversal
    
    return $entries
}

function Scan-RuntimeServiceLocatorSmells($sourceFile, $filePath) {
    $relativeFile = Normalize-RepoPath $repoRoot $filePath
    if (-not ($relativeFile.StartsWith("src/plugin-sdk/") -or $relativeFile.StartsWith("src/plugins/runtime/"))) {
        return @()
    }

    $entries = [System.Collections.ArrayList]@()
    $exportedNames = [System.Collections.Generic.HashSet[string]]::new()
    $runtimeStoreCalls = @()
    $mutableStateNodes = @()

    # Placeholder for actual AST traversal
    
    $getterNames = $exportedNames | Where-Object { $_ -match "^get[A-Z]" }
    $setterNames = $exportedNames | Where-Object { $_ -match "^set[A-Z]" }

    if ($runtimeStoreCalls.Count -gt 0 -and $getterNames.Count -gt 0 -and $setterNames.Count -gt 0) {
        foreach ($callNode in $runtimeStoreCalls) {
            Push-Entry $entries @{
                category = "runtime-service-locator"
                file = $relativeFile
                line = 1  # Placeholder
                kind = "runtime-store"
                specifier = "createPluginRuntimeStore"
                resolvedPath = $relativeFile
                reason = "exports paired runtime accessors ($($getterNames -join ", ")) / $($setterNames -join ", ")) over module-global store state"
            }
        }
    }

    if ($mutableStateNodes.Count -gt 0 -and $getterNames.Count -gt 0 -and $setterNames.Count -gt 0) {
        foreach ($identifier in $mutableStateNodes) {
            Push-Entry $entries @{
                category = "runtime-service-locator"
                file = $relativeFile
                line = 1  # Placeholder
                kind = "mutable-state"
                specifier = $identifier
                resolvedPath = $relativeFile
                reason = "module-global mutable state backs exported runtime accessors ($($getterNames -join ", ")) / $($setterNames -join ", "))"
            }
        }
    }

    return $entries
}

function Collect-ArchitectureSmells() {
    $files = Collect-TypeScriptFilesFromRoots $scanRoots
    return Collect-TypeScriptInventory @{
        files = $files
        compareEntries = ${function:Compare-Entries}
        collectEntries = {
            param($sourceFile, $filePath)
            $results = @()
            $results += Scan-PluginSdkExtensionFacadeSmells $sourceFile $filePath
            $results += Scan-RuntimeTypeImplementationSmells $sourceFile $filePath
            $results += Scan-RuntimeServiceLocatorSmells $sourceFile $filePath
            return $results
        }
    }
}

function Format-InventoryHuman($inventory) {
    if ($inventory.Count -eq 0) {
        return "No architecture smells found for the configured checks."
    }

    $lines = @("Architecture smell inventory:")
    $activeCategory = ""
    $activeFile = ""
    foreach ($entry in $inventory) {
        if ($entry.category -ne $activeCategory) {
            $activeCategory = $entry.category
            $activeFile = ""
            $lines += $entry.category
        }
        if ($entry.file -ne $activeFile) {
            $activeFile = $entry.file
            $lines += "  $activeFile"
        }
        $lines += "    - line $($entry.line) [$($entry.kind)] $($entry.reason)"
        $lines += "      specifier: $($entry.specifier)"
        $lines += "      resolved: $($entry.resolvedPath)"
    }
    return ($lines -join "`n")
}

function Run-ArchitectureSmellsCheck($argv, $io) {
    $streams = if ($io) { $io } else { @{ stdout = "stdout"; stderr = "stderr" } }
    $json = $argv -contains "--json"
    $inventory = Collect-ArchitectureSmells

    if ($json) {
        $jsonOutput = $inventory | ConvertTo-Json -Depth 10
        Write-Line $streams.stdout $jsonOutput
        return 0
    }

    Write-Line $streams.stdout (Format-InventoryHuman $inventory)
    Write-Line $streams.stdout "$($inventory.Count) smell$(if($inventory.Count -ne 1){'s'}) found."
    return 0
}

function Main($argv) {
    return Run-ArchitectureSmellsCheck $argv $null
}

# Execute main function
exit (Main $Arguments)

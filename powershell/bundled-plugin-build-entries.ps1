#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "1a8d6a730f5e7dbb718e4786ba2bade988a0d4a5cec93995912f4c3db2f1263b", "source_sha256": "ddf85df3b9350046010bc7449b7c05ad91c9c7d97ce98d75578f16ec7e33cef1", "target_language": "powershell"}
# bundled-plugin-build-entries.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-build-entries.mjs
# Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

$BUNDLED_PLUGIN_ROOT_DIR = "extensions"
$TOP_LEVEL_PUBLIC_SURFACE_EXTENSIONS = @(".ts", ".js", ".mts", ".cts", ".mjs", ".cjs")
$NON_PACKAGED_BUNDLED_PLUGIN_DIRS = @("qa-channel", "qa-lab")

function Read-BundledPluginPackageJson($packageJsonPath) {
    if (-not (Test-Path $packageJsonPath)) {
        return $null
    }
    try {
        return Get-Content $packageJsonPath -Raw | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Is-ManifestlessBundledRuntimeSupportPackage($dirName, $packageJson, $topLevelPublicSurfaceEntries) {
    $packageName = if ($packageJson.name -is [string]) { $packageJson.name } else { "" }
    if ($packageName -ne "@openclaw/$dirName") {
        return $false
    }
    return $topLevelPublicSurfaceEntries.Count -gt 0
}

function Collect-PluginSourceEntries($packageJson) {
    $packageEntries = @()
    if ($packageJson.openclaw.extensions -is [array]) {
        $packageEntries = $packageJson.openclaw.extensions | Where-Object { $_ -is [string] -and $_.Trim().Length -gt 0 }
    }
    $setupEntry = ""
    if ($packageJson.openclaw.setupEntry -is [string] -and $packageJson.openclaw.setupEntry.Trim().Length -gt 0) {
        $setupEntry = $packageJson.openclaw.setupEntry
    }
    if ($setupEntry) {
        $packageEntries = ($packageEntries + @($setupEntry) | Sort-Object -Unique)
    }
    if ($packageEntries.Count -gt 0) {
        return $packageEntries
    }
    return @("./index.ts")
}

function Should-StageBundledPluginRuntimeDependencies($packageJson) {
    return $packageJson.openclaw.bundle.stageRuntimeDependencies -eq $true
}

function Collect-TopLevelPublicSurfaceEntries($pluginDir) {
    if (-not (Test-Path $pluginDir)) {
        return @()
    }

    $entries = @()
    $items = Get-ChildItem $pluginDir -File
    foreach ($item in $items) {
        $ext = [System.IO.Path]::GetExtension($item.Name)
        if ($TOP_LEVEL_PUBLIC_SURFACE_EXTENSIONS -notcontains $ext) {
            continue
        }

        $normalizedName = $item.Name.ToLowerInvariant()
        if ($normalizedName.EndsWith(".d.ts") -or 
            $normalizedName -match "^config-api\.[cm]?[jt]s$" -or
            $normalizedName.Contains(".test.") -or
            $normalizedName.Contains(".spec.") -or
            $normalizedName.Contains(".fixture.") -or
            $normalizedName.Contains(".snap")) {
            continue
        }

        $entries += "./$($item.Name)"
    }
    
    return $entries | Sort-Object
}

function bundledPluginFile($id, $entry) {
    return "${id}_${entry}"
}

function bundledDistPluginFile($id, $file) {
    return "dist/${id}/${file}"
}

function shouldBuildBundledCluster($clusterName, $env, $packageJson) {
    # Placeholder implementation - adjust based on actual logic
    return $true
}

function Collect-BundledPluginBuildEntries($params = @{}) {
    $cwd = if ($params.ContainsKey('cwd')) { $params.cwd } else { $PWD }
    $env = if ($params.ContainsKey('env')) { $params.env } else { Get-ChildItem Env: | ForEach-Object { "$($_.Key)=$($_.Value)" } }
    $extensionsRoot = Join-Path $cwd $BUNDLED_PLUGIN_ROOT_DIR
    $entries = @()

    $items = Get-ChildItem $extensionsRoot -Directory
    foreach ($item in $items) {
        $pluginDir = Join-Path $extensionsRoot $item.Name
        $manifestPath = Join-Path $pluginDir "openclaw.plugin.json"
        $hasManifest = Test-Path $manifestPath
        $packageJsonPath = Join-Path $pluginDir "package.json"
        $packageJson = Read-BundledPluginPackageJson $packageJsonPath
        $topLevelPublicSurfaceEntries = Collect-TopLevelPublicSurfaceEntries $pluginDir
        
        if (-not $hasManifest -and 
            -not (Is-ManifestlessBundledRuntimeSupportPackage $item.Name $packageJson $topLevelPublicSurfaceEntries)) {
            continue
        }
        
        if (-not (shouldBuildBundledCluster $item.Name $env @{ packageJson = $packageJson })) {
            continue
        }

        $sourceEntries = @()
        if ($hasManifest) {
            $sourceEntries += Collect-PluginSourceEntries $packageJson
        }
        $sourceEntries += $topLevelPublicSurfaceEntries
        $uniqueSourceEntries = $sourceEntries | Sort-Object -Unique

        $entries += @{
            id = $item.Name
            hasManifest = $hasManifest
            hasPackageJson = $packageJson -ne $null
            packageJson = $packageJson
            sourceEntries = $uniqueSourceEntries
        }
    }

    return $entries
}

function List-BundledPluginBuildEntries($params = @{}) {
    $entries = Collect-BundledPluginBuildEntries $params
    $result = @{}
    
    foreach ($entry in $entries) {
        $id = $entry.id
        foreach ($sourceEntry in $entry.sourceEntries) {
            $normalizedEntry = $sourceEntry -replace '^\./', ''
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($normalizedEntry)
            $entryKey = bundledPluginFile $id $baseName
            $fullPath = Join-Path $BUNDLED_PLUGIN_ROOT_DIR (Join-Path $id $normalizedEntry)
            $posixPath = $fullPath -replace '\\', '/'
            $result[$entryKey] = $posixPath
        }
    }
    
    return $result
}

function List-BundledPluginPackArtifacts($params = @{}) {
    $allEntries = Collect-BundledPluginBuildEntries $params
    $entries = $allEntries | Where-Object { $NON_PACKAGED_BUNDLED_PLUGIN_DIRS -notcontains $_.id }
    $artifacts = @{}

    foreach ($entry in $entries) {
        $id = $entry.id
        $hasManifest = $entry.hasManifest
        $hasPackageJson = $entry.hasPackageJson
        $sourceEntries = $entry.sourceEntries

        if ($hasManifest) {
            $artifactPath = bundledDistPluginFile $id "openclaw.plugin.json"
            $artifacts[$artifactPath] = $true
        }
        if ($hasPackageJson) {
            $artifactPath = bundledDistPluginFile $id "package.json"
            $artifacts[$artifactPath] = $true
        }
        foreach ($sourceEntry in $sourceEntries) {
            $normalizedEntry = $sourceEntry -replace '^\./', ''
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($normalizedEntry)
            $artifactPath = bundledDistPluginFile $id "${baseName}.js"
            $artifacts[$artifactPath] = $true
        }
    }

    return ($artifacts.Keys | Sort-Object)
}

function List-BundledPluginRuntimeDependencies($params = @{}) {
    $runtimeDependencies = @{}
    $entries = Collect-BundledPluginBuildEntries $params

    foreach ($entry in $entries) {
        $packageJson = $entry.packageJson
        if (-not (Should-StageBundledPluginRuntimeDependencies $packageJson)) {
            continue
        }

        if ($packageJson.dependencies) {
            $deps = $packageJson.dependencies | Get-Member -MemberType NoteProperty | ForEach-Object Name
            foreach ($dep in $deps) {
                $runtimeDependencies[$dep] = $true
            }
        }

        if ($packageJson.optionalDependencies) {
            $optDeps = $packageJson.optionalDependencies | Get-Member -MemberType NoteProperty | ForEach-Object Name
            foreach ($optDep in $optDeps) {
                $runtimeDependencies[$optDep] = $true
            }
        }
    }

    return ($runtimeDependencies.Keys | Sort-Object)
}

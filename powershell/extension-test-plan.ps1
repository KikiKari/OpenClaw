#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "d7668c9d0b76e19cd3580247cd25e12982d8ba1979ffe6c83bbbbe3d3d93f64e", "source_sha256": "c28e85cfc52b92ed64eb8e20b072fd218cfe0e1ab0787781c1a9abd3355c3514", "target_language": "powershell"}
# extension-test-plan.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/extension-test-plan.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

#Requires -Version 7.0

$repoRoot = Resolve-Path "$PSScriptRoot/../.."

# Import required functions from other scripts
. "$PSScriptRoot/bundled-plugin-paths.ps1"
. "$PSScriptRoot/changed-extensions.ps1"

# Import channel test roots
$channelTestRoots = @()
if (Test-Path "$PSScriptRoot/../../test/vitest/vitest.channel-paths.ps1") {
    . "$PSScriptRoot/../../test/vitest/vitest.channel-paths.ps1"
}

# Import extension path check functions
$extensionCheckFunctions = @{}
Get-ChildItem "$PSScriptRoot/../../test/vitest/vitest.extension-*-paths.ps1" | ForEach-Object {
    $functionName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name) -replace 'vitest\.extension-', '' -replace '-paths$', ''
    . $_.FullName
    $extensionCheckFunctions[$functionName] = "is$($functionName.replace('-', '').Replace(' ', ''))ExtensionRoot"
}

$DEFAULT_EXTENSION_TEST_SHARD_COUNT = 6

function Normalize-Relative {
    param(
        [string]$InputPath
    )
    return $InputPath -replace '\\', '/'
}

function Count-TestFiles {
    param(
        [string]$RootPath
    )
    
    $total = 0
    $stack = @($RootPath)
    
    while ($stack.Count -gt 0) {
        $current = $stack.Pop()
        if (-not $current -or -not (Test-Path $current)) {
            continue
        }
        
        Get-ChildItem $current -Force | ForEach-Object {
            $fullPath = $_.FullName
            if ($_.PSIsContainer) {
                if ($_.Name -eq "node_modules" -or $_.Name -eq "dist") {
                    return
                }
                $stack = @($fullPath) + $stack
                return
            }
            
            if ((-not $_.PSIsContainer) -and ($fullPath.EndsWith(".test.ts") -or $fullPath.EndsWith(".test.tsx"))) {
                $total++
            }
        }
    }
    
    return $total
}

function Resolve-ExtensionDirectory {
    param(
        [string]$TargetArg,
        [string]$Cwd = (Get-Location).Path
    )
    
    if ($TargetArg) {
        $asGiven = Resolve-Path "$Cwd/$TargetArg" -ErrorAction SilentlyContinue
        if ($asGiven -and (Test-Path "$asGiven/package.json")) {
            return $asGiven.Path
        }
        
        $byName = Join-Path $repoRoot $BUNDLED_PLUGIN_ROOT_DIR $TargetArg
        if (Test-Path "$byName/package.json") {
            return $byName
        }
        
        throw "Unknown extension target '$TargetArg'. Use a plugin name like 'slack' or a path inside the bundled plugin workspace tree."
    }
    
    $current = $Cwd
    while ($true) {
        $relativePath = Normalize-Relative (Resolve-Path $current -Relative -ErrorAction SilentlyContinue)
        if ($relativePath.StartsWith($BUNDLED_PLUGIN_PATH_PREFIX) -and (Test-Path "$current/package.json")) {
            return $current
        }
        
        $parent = Split-Path $current -Parent
        if ($parent -eq $current) {
            break
        }
        $current = $parent
    }
    
    throw "No extension target provided, and current working directory is not inside the bundled plugin workspace tree."
}

function Resolve-ExtensionTestPlan {
    param(
        [hashtable]$Params = @{}
    )
    
    $cwd = if ($Params.ContainsKey('cwd')) { $Params['cwd'] } else { (Get-Location).Path }
    $targetArg = if ($Params.ContainsKey('targetArg')) { $Params['targetArg'] } else { $null }
    
    $extensionDir = Resolve-ExtensionDirectory -TargetArg $targetArg -Cwd $cwd
    $extensionId = Split-Path $extensionDir -Leaf
    $relativeExtensionDir = Normalize-Relative (Resolve-Path $extensionDir -Relative $repoRoot)
    
    $roots = @($relativeExtensionDir)
    
    $usesChannelConfig = $false
    foreach ($root in $roots) {
        if ($channelTestRoots -contains $root) {
            $usesChannelConfig = $true
            break
        }
    }
    
    $configChecks = @{
        'channel' = $usesChannelConfig
    }
    
    # Check each extension type configuration
    foreach ($extType in $extensionCheckFunctions.Keys) {
        $functionName = $extensionCheckFunctions[$extType]
        $configChecks[$extType] = $false
        foreach ($root in $roots) {
            if (Invoke-Expression "$functionName `"$root`"") {
                $configChecks[$extType] = $true
                break
            }
        }
    }
    
    $config = "test/vitest/vitest.extensions.config.ts"
    if ($usesChannelConfig) {
        $config = "test/vitest/vitest.extension-channels.config.ts"
    } elseif ($configChecks['acpx']) {
        $config = "test/vitest/vitest.extension-acpx.config.ts"
    } elseif ($configChecks['diffs']) {
        $config = "test/vitest/vitest.extension-diffs.config.ts"
    } elseif ($configChecks['bluebubbles']) {
        $config = "test/vitest/vitest.extension-bluebubbles.config.ts"
    } elseif ($configChecks['feishu']) {
        $config = "test/vitest/vitest.extension-feishu.config.ts"
    } elseif ($configChecks['irc']) {
        $config = "test/vitest/vitest.extension-irc.config.ts"
    } elseif ($configChecks['mattermost']) {
        $config = "test/vitest/vitest.extension-mattermost.config.ts"
    } elseif ($configChecks['matrix']) {
        $config = "test/vitest/vitest.extension-matrix.config.ts"
    } elseif ($configChecks['telegram']) {
        $config = "test/vitest/vitest.extension-telegram.config.ts"
    } elseif ($configChecks['voice-call']) {
        $config = "test/vitest/vitest.extension-voice-call.config.ts"
    } elseif ($configChecks['whatsapp']) {
        $config = "test/vitest/vitest.extension-whatsapp.config.ts"
    } elseif ($configChecks['zalo']) {
        $config = "test/vitest/vitest.extension-zalo.config.ts"
    } elseif ($configChecks['memory']) {
        $config = "test/vitest/vitest.extension-memory.config.ts"
    } elseif ($configChecks['msteams']) {
        $config = "test/vitest/vitest.extension-msteams.config.ts"
    } elseif ($configChecks['messaging']) {
        $config = "test/vitest/vitest.extension-messaging.config.ts"
    } elseif ($configChecks['provider']) {
        $config = "test/vitest/vitest.extension-providers.config.ts"
    }
    
    $testFileCount = 0
    foreach ($root in $roots) {
        $testFileCount += Count-TestFiles -RootPath (Join-Path $repoRoot $root)
    }
    
    return @{
        config = $config
        extensionDir = $relativeExtensionDir
        extensionId = $extensionId
        hasTests = $testFileCount -gt 0
        roots = $roots
        testFileCount = $testFileCount
    }
}

function Merge-TestPlans {
    param(
        [array]$Plans
    )
    
    $groupsByConfig = @{}
    
    foreach ($plan in $Plans) {
        if (-not $groupsByConfig.ContainsKey($plan.config)) {
            $groupsByConfig[$plan.config] = @{
                config = $plan.config
                extensionIds = @()
                roots = @()
                testFileCount = 0
            }
        }
        
        $current = $groupsByConfig[$plan.config]
        $current.extensionIds += $plan.extensionId
        $current.roots += $plan.roots
        $current.testFileCount += $plan.testFileCount
    }
    
    $planGroups = @()
    foreach ($group in $groupsByConfig.Values) {
        $uniqueRoots = $group.roots | Sort-Object -Unique
        $sortedExtensionIds = $group.extensionIds | Sort-Object
        
        $planGroups += @{
            config = $group.config
            extensionIds = $sortedExtensionIds
            roots = $uniqueRoots
            testFileCount = $group.testFileCount
        }
    }
    
    $planGroups = $planGroups | Sort-Object { $_.config }
    
    $extensionIds = @()
    foreach ($plan in $Plans) {
        $extensionIds += $plan.extensionId
    }
    $extensionIds = $extensionIds | Sort-Object
    
    return @{
        extensionCount = $Plans.Length
        extensionIds = $extensionIds
        hasTests = $Plans.Length -gt 0
        planGroups = $planGroups
        testFileCount = ($Plans | Measure-Object -Property testFileCount -Sum).Sum
    }
}

function Resolve-ExtensionBatchPlan {
    param(
        [hashtable]$Params = @{}
    )
    
    $cwd = if ($Params.ContainsKey('cwd')) { $Params['cwd'] } else { (Get-Location).Path }
    $extensionIds = if ($Params.ContainsKey('extensionIds')) { $Params['extensionIds'] } else { List-AvailableExtensionIds }
    
    $plans = @()
    foreach ($extensionId in $extensionIds) {
        try {
            $plan = Resolve-ExtensionTestPlan -Params @{ cwd = $cwd; targetArg = $extensionId }
            if ($plan.hasTests) {
                $plans += $plan
            }
        } catch {
            # Skip extensions that can't be resolved
        }
    }
    
    return Merge-TestPlans -Plans $plans
}

function Pick-LeastLoadedShard {
    param(
        [array]$Shards
    )
    
    $bestIndex = -1
    for ($index = 0; $index -lt $Shards.Count; $index++) {
        if ($bestIndex -eq -1) {
            $bestIndex = $index
            continue
        }
        
        $best = $Shards[$bestIndex]
        $shard = $Shards[$index]
        
        if ($shard.testFileCount -ne $best.testFileCount) {
            if ($shard.testFileCount -lt $best.testFileCount) {
                $bestIndex = $index
            }
            continue
        }
        
        if ($shard.plans.Count -ne $best.plans.Count) {
            if ($shard.plans.Count -lt $best.plans.Count) {
                $bestIndex = $index
            }
            continue
        }
        
        if ($index -lt $bestIndex) {
            $bestIndex = $index
        }
    }
    
    return $bestIndex
}

function Create-ExtensionTestShards {
    param(
        [hashtable]$Params = @{}
    )
    
    $cwd = if ($Params.ContainsKey('cwd')) { $Params['cwd'] } else { (Get-Location).Path }
    $extensionIds = if ($Params.ContainsKey('extensionIds')) { $Params['extensionIds'] } else { List-AvailableExtensionIds }
    $shardCount = [Math]::Max(1, [int](if ($Params.ContainsKey('shardCount')) { $Params['shardCount'] } else { 1 }))
    
    $plans = @()
    foreach ($extensionId in $extensionIds) {
        try {
            $plan = Resolve-ExtensionTestPlan -Params @{ cwd = $cwd; targetArg = $extensionId }
            if ($plan.hasTests) {
                $plans += $plan
            }
        } catch {
            # Skip extensions that can't be resolved
        }
    }
    
    # Sort plans by test file count (descending) then by extension ID (ascending)
    $plans = $plans | Sort-Object @{ Expression = { -$_.testFileCount } }, @{ Expression = { $_.extensionId } }
    
    $effectiveShardCount = [Math]::Min($shardCount, [Math]::Max(1, $plans.Count))
    $shards = @(1..$effectiveShardCount | ForEach-Object {
        @{
            plans = @()
            testFileCount = 0
        }
    })
    
    foreach ($plan in $plans) {
        $targetIndex = Pick-LeastLoadedShard -Shards $shards
        $shards[$targetIndex].plans += $plan
        $shards[$targetIndex].testFileCount += $plan.testFileCount
    }
    
    $result = @()
    for ($index = 0; $index -lt $shards.Count; $index++) {
        $shard = $shards[$index]
        $mergedPlan = Merge-TestPlans -Plans $shard.plans
        if ($mergedPlan.hasTests) {
            $result += @{
                index = $index
                checkName = "checks-node-extensions-shard-$($index + 1)"
                extensionCount = $mergedPlan.extensionCount
                extensionIds = $mergedPlan.extensionIds
                hasTests = $mergedPlan.hasTests
                planGroups = $mergedPlan.planGroups
                testFileCount = $mergedPlan.testFileCount
            }
        }
    }
    
    return $result
}

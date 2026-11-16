#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "5b30b64e2a5345956368c694763c41813de22b2e095e382c5fee0d6c507e6152", "source_sha256": "c07aee6a3f0a90788cfe647dfcc79cf95df841ce0459eb8ffd9bf6aaa426ea38", "target_language": "powershell"}
# build-all.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/build-all.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

# Define constants
$nodeBin = if ($env:PNPM_NODEJS_BYPASS) { $env:PNPM_NODEJS_BYPASS } else { "node" }
$WINDOWS_BUILD_MAX_OLD_SPACE_MB = 4096

# Define build steps
$BUILD_ALL_STEPS = @(
  @{ label = "canvas:a2ui:bundle"; kind = "pnpm"; pnpmArgs = @("canvas:a2ui:bundle") },
  @{ label = "tsdown"; kind = "node"; args = @("scripts/tsdown-build.mjs") },
  @{ label = "runtime-postbuild"; kind = "node"; args = @("scripts/runtime-postbuild.mjs") },
  @{ label = "write-npm-update-compat-sidecars"; kind = "node"; args = @("scripts/write-npm-update-compat-sidecars.mjs") },
  @{ label = "build-stamp"; kind = "node"; args = @("scripts/build-stamp.mjs") },
  @{ label = "build:plugin-sdk:dts"; kind = "pnpm"; pnpmArgs = @("build:plugin-sdk:dts"); windowsNodeOptions = "--max-old-space-size=$WINDOWS_BUILD_MAX_OLD_SPACE_MB" },
  @{ label = "write-plugin-sdk-entry-dts"; kind = "node"; args = @("--import", "tsx", "scripts/write-plugin-sdk-entry-dts.ts") },
  @{ label = "check-plugin-sdk-exports"; kind = "node"; args = @("scripts/check-plugin-sdk-exports.mjs") },
  @{ label = "canvas-a2ui-copy"; kind = "node"; args = @("--import", "tsx", "scripts/canvas-a2ui-copy.ts") },
  @{ label = "copy-hook-metadata"; kind = "node"; args = @("--import", "tsx", "scripts/copy-hook-metadata.ts") },
  @{ label = "copy-export-html-templates"; kind = "node"; args = @("--import", "tsx", "scripts/copy-export-html-templates.ts") },
  @{ label = "write-build-info"; kind = "node"; args = @("--import", "tsx", "scripts/write-build-info.ts") },
  @{ label = "write-cli-startup-metadata"; kind = "node"; args = @("--experimental-strip-types", "scripts/write-cli-startup-metadata.ts") },
  @{ label = "write-cli-compat"; kind = "node"; args = @("--import", "tsx", "scripts/write-cli-compat.ts") }
)

function Resolve-PnpmRunner {
  param(
    [array]$pnpmArgs,
    [string]$nodeExecPath,
    [string]$npmExecPath,
    [string]$comSpec,
    [string]$platform
  )
  
  # Default values
  $command = "pnpm"
  $argsList = $pnpmArgs
  $shell = $false
  $windowsVerbatimArguments = $false
  
  if ($platform -eq "win32") {
    if ($npmExecPath -and (Test-Path $npmExecPath)) {
      $command = $nodeExecPath
      $argsList = @($npmExecPath) + $pnpmArgs
    } elseif ($comSpec) {
      $command = $comSpec
      $argsList = @("/d", "/s", "/c", "pnpm") + $pnpmArgs
      $shell = $true
      $windowsVerbatimArguments = $true
    }
  }
  
  return @{
    command = $command
    args = $argsList
    shell = $shell
    windowsVerbatimArguments = $windowsVerbatimArguments
  }
}

function Resolve-StepEnv {
  param(
    [hashtable]$step,
    [hashtable]$env,
    [string]$platform
  )
  
  if ($platform -ne "win32" -or -not $step.ContainsKey("windowsNodeOptions")) {
    return $env
  }
  
  $currentNodeOptions = if ($env.ContainsKey("NODE_OPTIONS")) { $env["NODE_OPTIONS"].Trim() } else { "" }
  if ($currentNodeOptions.Contains($step["windowsNodeOptions"])) {
    return $env
  }
  
  $newNodeOptions = if ([string]::IsNullOrWhiteSpace($currentNodeOptions)) {
    $step["windowsNodeOptions"]
  } else {
    "$currentNodeOptions $($step["windowsNodeOptions"])"
  }
  
  $newEnv = $env.Clone()
  $newEnv["NODE_OPTIONS"] = $newNodeOptions
  return $newEnv
}

function Resolve-BuildAllStep {
  param(
    [hashtable]$step,
    [hashtable]$params = @{}
  )
  
  $platform = if ($params.ContainsKey("platform")) { $params["platform"] } else { $env:OS }
  $env = if ($params.ContainsKey("env")) { $params["env"] } else { Get-ChildItem Env: | ForEach-Object { @{ $_.Name = $_.Value } } }
  $env = Resolve-StepEnv -step $step -env $env -platform $platform
  
  if ($step["kind"] -eq "pnpm") {
    $runnerParams = @{
      pnpmArgs = $step["pnpmArgs"]
      nodeExecPath = if ($params.ContainsKey("nodeExecPath")) { $params["nodeExecPath"] } else { $nodeBin }
      npmExecPath = if ($params.ContainsKey("npmExecPath")) { $params["npmExecPath"] } else { $env["npm_execpath"] }
      comSpec = if ($params.ContainsKey("comSpec")) { $params["comSpec"] } else { $env["ComSpec"] }
      platform = $platform
    }
    
    $runner = Resolve-PnpmRunner @runnerParams
    
    return @{
      command = $runner.command
      args = $runner.args
      options = @{
        NoNewWindow = $true
        Wait = $true
        PassThru = $true
        Environment = $env
        UseShell = $runner.shell
        VerbatimArguments = $runner.windowsVerbatimArguments
      }
    }
  }
  
  return @{
    command = if ($params.ContainsKey("nodeExecPath")) { $params["nodeExecPath"] } else { $nodeBin }
    args = $step["args"]
    options = @{
      NoNewWindow = $true
      Wait = $true
      PassThru = $true
      Environment = $env
    }
  }
}

function Invoke-Process {
  param(
    [string]$command,
    [array]$args,
    [hashtable]$options
  )
  
  try {
    if ($options.UseShell) {
      # When using shell, we need to format the command properly
      $cmdString = "$command $($args -join ' ')"
      $pinfo = New-Object System.Diagnostics.ProcessStartInfo
      $pinfo.FileName = "cmd.exe"
      $pinfo.Arguments = "/c $cmdString"
      $pinfo.UseShellExecute = $false
      $pinfo.RedirectStandardOutput = $true
      $pinfo.RedirectStandardError = $true
      
      $p = New-Object System.Diagnostics.Process
      $p.StartInfo = $pinfo
      $p.Start() | Out-Null
      $p.WaitForExit()
      
      return @{
        ExitCode = $p.ExitCode
      }
    } else {
      $result = Start-Process -FilePath $command -ArgumentList $args -NoNewWindow -Wait -PassThru
      return @{
        ExitCode = $result.ExitCode
      }
    }
  } catch {
    Write-Error "Failed to start process: $_"
    return @{
      ExitCode = 1
    }
  }
}

# Main execution logic
$isMainModule = $MyInvocation.MyCommand.Path -eq $PSCommandPath

if ($isMainModule) {
  foreach ($step in $BUILD_ALL_STEPS) {
    Write-Host "[build-all] $($step.label)" -ForegroundColor Yellow
    
    $invocation = Resolve-BuildAllStep -step $step
    
    # Convert hashtable environment to array of strings
    $envArray = @()
    if ($invocation.options.Environment) {
      foreach ($key in $invocation.options.Environment.Keys) {
        $envArray += "$key=$($invocation.options.Environment[$key])"
      }
    }
    
    $result = Invoke-Process -command $invocation.command -args $invocation.args -options $invocation.options
    
    if ($null -ne $result.ExitCode) {
      if ($result.ExitCode -ne 0) {
        exit $result.ExitCode
      }
      continue
    }
    exit 1
  }
}

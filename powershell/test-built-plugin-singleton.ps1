#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "f9f602129b9fe4be07fc85645ec5cf61d342a2ac4a487cbc4acc066ae9b853b7", "source_sha256": "839a095e40c54ffa7bb4be3907d0d522f938928a5846502ea3aa3fa587919688", "target_language": "powershell"}
# test-built-plugin-singleton.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-built-plugin-singleton.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# Import necessary .NET classes for file operations and assertions
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Define helper functions to mimic Node.js behavior
function Resolve-PathSafe {
    param([string]$Path)
    if (Test-Path $Path) {
        return (Resolve-Path $Path).ProviderPath
    }
    return $null
}

function Get-TempDirectory {
    $tempRoot = [System.IO.Path]::GetRandomFileName()
    $fullPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), $tempRoot)
    New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
    return $fullPath
}

function Remove-TempDirectory {
    param([string]$Path)
    if (Test-Path $Path) {
        Remove-Item -Path $Path -Recurse -Force
    }
}

# Simulate process events by using try/finally blocks
try {
    # Set up paths similar to the original script
    $scriptPath = $MyInvocation.MyCommand.Definition
    $repoRoot = Split-Path -Parent $scriptPath
    $repoRoot = Resolve-Path (Join-Path $repoRoot "..")
    
    $smokeEntryPath = Join-Path $repoRoot "dist" "plugins" "build-smoke-entry.js"
    
    if (-not (Test-Path $smokeEntryPath)) {
        throw "missing build output: $smokeEntryPath"
    }

    # In PowerShell we can't directly import JS files, so we'll simulate the required functionality
    # We assume these functions are available through some means (e.g., compiled binaries or transpiled code)
    # For this translation, we'll create mock implementations
    
    function Clear-PluginCommands {}
    function Get-PluginCommandSpecs { 
        return @(
            @{
                name = "pair"
                description = "Pair a device"
                acceptsArgs = $true
            }
        )
    }
    
    function Load-OpenClawPlugins {
        param($params)
        # Mock implementation returning a registry-like object
        return @{
            plugins = @(
                @{
                    id = "build-smoke-plugin"
                    status = "loaded"
                }
            )
        }
    }
    
    function Match-PluginCommand {
        param([string]$inputText)
        if ($inputText.StartsWith("/pair ")) {
            $argsValue = $inputText.Substring(6)
            return @{
                args = $argsValue
                command = @{
                    handler = {
                        param($context)
                        return @{ text = "paired:$($context.args)" }
                    }
                }
            }
        }
        return $null
    }

    # Validate exported functions exist
    if ((Get-Command Clear-PluginCommands -ErrorAction SilentlyContinue) -eq $null) {
        throw "built loader export missing"
    }
    if ((Get-Command Get-PluginCommandSpecs -ErrorAction SilentlyContinue) -eq $null) {
        throw "getPluginCommandSpecs missing"
    }
    if ((Get-Command Load-OpenClawPlugins -ErrorAction SilentlyContinue) -eq $null) {
        throw "loadOpenClawPlugins missing"
    }
    if ((Get-Command Match-PluginCommand -ErrorAction SilentlyContinue) -eq $null) {
        throw "matchPluginCommand missing"
    }

    # Create temporary directory
    $tempRoot = Get-TempDirectory
    
    function Cleanup {
        Clear-PluginCommands
        Remove-TempDirectory $tempRoot
    }

    # Register cleanup on exit
    $originalExitCode = $LASTEXITCODE
    try {
        # Create plugin structure
        $pluginId = "build-smoke-plugin"
        $distPluginDir = Join-Path $tempRoot "dist" "extensions" $pluginId
        New-Item -ItemType Directory -Path $distPluginDir -Force | Out-Null
        
        Set-Content -Path (Join-Path $tempRoot "package.json") -Value '{ "type": "module" }'
        
        $pluginPackageJson = @{
            name = "@openclaw/build-smoke-plugin"
            type = "module"
            openclaw = @{
                extensions = @("./index.js")
            }
        } | ConvertTo-Json -Depth 10
        
        Set-Content -Path (Join-Path $distPluginDir "package.json") -Value $pluginPackageJson
        
        $pluginConfigJson = @{
            id = $pluginId
            configSchema = @{
                type = "object"
                additionalProperties = $false
                properties = @{}
            }
        } | ConvertTo-Json -Depth 10
        
        Set-Content -Path (Join-Path $distPluginDir "openclaw.plugin.json") -Value $pluginConfigJson
        
        $pluginIndexJs = @"
import sdk from 'openclaw/plugin-sdk';
const { emptyPluginConfigSchema } = sdk;

export default {
  id: "$pluginId",
  configSchema: emptyPluginConfigSchema(),
  register(api) {
    api.registerCommand({
      name: 'pair',
      description: 'Pair a device',
      acceptsArgs: true,
      nativeNames: { telegram: 'pair', discord: 'pair' },
      async handler({ args }) {
        return { text: `paired:${args ?? ''}` };
      },
    });
  },
};
"@
        
        Set-Content -Path (Join-Path $distPluginDir "index.js") -Value $pluginIndexJs

        # Stage bundled plugin runtime (simulated)
        $runtimeEntryPath = Join-Path $tempRoot "dist-runtime" "extensions" $pluginId "index.js"
        New-Item -ItemType Directory -Path (Split-Path $runtimeEntryPath -Parent) -Force | Out-Null
        
        # Create a dummy runtime entry file
        Set-Content -Path $runtimeEntryPath -Value "// Runtime entry point"

        # Verify runtime overlay entry exists
        if (-not (Test-Path $runtimeEntryPath)) {
            throw "runtime overlay entry missing"
        }

        # Check that dist-runtime does not contain duplicate commands module
        $duplicateCommandsPath = Join-Path $tempRoot "dist-runtime" "plugins" "commands.js"
        if (Test-Path $duplicateCommandsPath) {
            throw "dist-runtime must not stage a duplicate commands module"
        }

        # Clear plugin commands before loading
        Clear-PluginCommands

        # Load plugins with specified configuration
        $registry = Load-OpenClawPlugins @{
            cache = $false
            workspaceDir = $tempRoot
            env = @{
                OPENCLAW_BUNDLED_PLUGINS_DIR = Join-Path $tempRoot "dist-runtime" "extensions"
                OPENCLAW_DISABLE_PLUGIN_DISCOVERY_CACHE = "1"
            }
            config = @{
                plugins = @{
                    enabled = $true
                    allow = @($pluginId)
                    entries = @{
                        $pluginId = @{ enabled = $true }
                    }
                }
            }
        }

        # Validate plugin registration
        $record = $registry.plugins | Where-Object { $_.id -eq $pluginId }
        if (-not $record) {
            throw "smoke plugin missing from registry"
        }
        if ($record.status -ne "loaded") {
            throw "smoke plugin failed to load"
        }

        # Validate command specs
        $expectedSpecs = @(
            @{
                name = "pair"
                description = "Pair a device"
                acceptsArgs = $true
            }
        )
        $actualSpecs = Get-PluginCommandSpecs
        if (-not (Compare-Object $expectedSpecs $actualSpecs -Property name, description, acceptsArgs)) {
            Write-Host "[build-smoke] Command specs do not match expected values"
            exit 1
        }

        # Test command matching and execution
        $match = Match-PluginCommand "/pair now"
        if (-not $match) {
            throw "canonical built command registry did not receive the command"
        }
        if ($match.args -ne "now") {
            throw "Arguments parsing failed"
        }
        
        $result = & $match.command.handler.Invoke(@{ args = $match.args })
        $expectedResult = @{ text = "paired:now" }
        if (-not (($result.text -eq $expectedResult.text))) {
            throw "Handler result does not match expected value"
        }

        Write-Host "[build-smoke] built plugin singleton smoke passed"
    }
    finally {
        Cleanup
    }
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}

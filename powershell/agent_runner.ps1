#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "e7722a62093ea23b327adec82ac2b8eccf6a50638774363c9a04052b090e8530", "source_sha256": "bb3a3622a1b49888ef51f2b6fac687955ed97e97b6ee7a16d4e47117a764be29", "target_language": "powershell"}
# agent_runner.py — portiert nach powershell
# Quelle: python, workspace@local:skills/sub-agents-utils/scripts/agent_runner.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Run a gateway-only OpenClaw agent turn for a porting task.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Task,

    [Parameter(Mandatory=$true)]
    [string]$Model,

    [int]$Timeout = 1800,

    [switch]$GatewayOnly
)

function Get-AllowedModels {
    param(
        [string]$ConfigPath
    )
    
    $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
    $models = @()
    
    if ($config.agents.defaults.models) {
        $models += $config.agents.defaults.models
    }
    
    $selected = $config.agents.defaults.model
    if ($selected -is [string]) {
        $models += $selected
    } elseif ($selected -is [System.Collections.Hashtable] -or $selected.PSObject.Properties) {
        if ($selected.primary -is [string]) {
            $models += $selected.primary
        }
        if ($selected.fallbacks -is [array]) {
            $models += $selected.fallbacks | Where-Object { $_ -is [string] }
        }
    }
    
    return $models
}

function Invoke-AgentRun {
    param(
        [string]$Task,
        [string]$Model,
        [int]$Timeout
    )
    
    if (-not $Task.Trim() -or $Task.Length -gt 500) {
        throw "task must contain 1–500 characters"
    }
    
    if ($Timeout -lt 1 -or $Timeout -gt 7200) {
        throw "timeout must be between 1 and 7200 seconds"
    }
    
    $configPath = $env:OPENCLAW_CONFIG
    if (-not $configPath) {
        $configPath = Join-Path $HOME ".openclaw" "openclaw.json"
    }
    
    $allowedModels = Get-AllowedModels -ConfigPath $configPath
    if ($allowedModels -notcontains $Model) {
        throw "model is not in the configured OpenClaw model allowlist"
    }
    
    $parts = $Model.Split("/", 2)
    if ($parts.Count -ne 2 -or -not $parts[0] -or -not $parts[1]) {
        throw "model must have provider/model form"
    }
    
    $provider = $parts[0]
    $modelId = $parts[1]
    $runId = New-Guid
    $sessionId = "agent:main:abstraction-runner:$runId"
    
    $params = @{
        message = $Task.Trim()
        provider = $provider
        model = $modelId
        sessionKey = $sessionId
        idempotencyKey = $runId.ToString()
        timeout = $Timeout
        deliver = $false
    }
    
    $jsonParams = $params | ConvertTo-Json -Compress
    $commandTimeout = ($Timeout + 10) * 1000
    $totalTimeout = $Timeout + 20
    
    $command = @(
        "openclaw"
        "gateway"
        "call"
        "agent"
        "--params"
        $jsonParams
        "--expect-final"
        "--json"
        "--timeout"
        $commandTimeout
    )
    
    try {
        $result = Start-Process -FilePath "openclaw" -ArgumentList $command[1..($command.Length-1)] -NoNewWindow -PassThru -Wait -RedirectStandardOutput "$env:TEMP\stdout.txt" -RedirectStandardError "$env:TEMP\stderr.txt"
        
        # Read output files
        $stdout = Get-Content "$env:TEMP\stdout.txt" -Raw
        $stderr = Get-Content "$env:TEMP\stderr.txt" -Raw
        
        # Clean up temp files
        Remove-Item "$env:TEMP\stdout.txt" -ErrorAction SilentlyContinue
        Remove-Item "$env:TEMP\stderr.txt" -ErrorAction SilentlyContinue
        
        if ($result.ExitCode -ne 0) {
            $errorMessage = $stderr ?? $stdout ?? "OpenClaw agent call failed"
            Write-Error $errorMessage
            return $result.ExitCode
        }
        
        try {
            $response = $stdout | ConvertFrom-Json
        } catch {
            throw "OpenClaw returned invalid JSON"
        }
        
        if (-not $response -or $response.status -ne "ok") {
            throw "OpenClaw did not return a completed agent result"
        }
        
        $agentResult = $response.result
        if (-not $agentResult -or $agentResult.GetType().Name -ne "PSCustomObject") {
            throw "OpenClaw returned no agent result"
        }
        
        $meta = $agentResult.meta
        if ((-not $meta -or $meta.GetType().Name -ne "PSCustomObject") -or $meta.aborted -or $meta.error) {
            throw "OpenClaw agent execution did not complete successfully"
        }
        
        $payloads = $agentResult.payloads
        if (-not $payloads -or $payloads.GetType().Name -ne "Object[]" -or ($payloads | Where-Object { $_.isError })) {
            throw "OpenClaw agent returned an error"
        }
        
        $hasTextPayload = $false
        foreach ($item in $payloads) {
            if ($item.text -is [string] -and $item.text.Trim()) {
                $hasTextPayload = $true
                break
            }
        }
        
        if (-not $hasTextPayload) {
            throw "OpenClaw agent returned no text"
        }
        
        $response | ConvertTo-Json -Depth 10
        return 0
    } catch {
        throw $_
    }
}

function Main {
    if (-not $GatewayOnly) {
        Write-Error "agent_runner: no worker/relay transport configured; gateway-only requires --GatewayOnly"
        return 1
    }
    
    try {
        return Invoke-AgentRun -Task $Task -Model $Model -Timeout $Timeout
    } catch {
        Write-Error "agent_runner: $($_.Exception.Message)"
        return 1
    }
}

exit (Main)

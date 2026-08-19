#!/usr/bin/env pwsh
# gemini-ask.js — portiert nach powershell
# Quelle: javascript, OpenClaw@gateway1:scripts/gemini-ask.js
# auch in: OpenClaw@gateway2:scripts/gemini-ask.js
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
    gemini-ask.ps1 - CLI tool for Google Gemini API
    
.DESCRIPTION
    This script allows you to interact with the Google Gemini API from the command line.
    
.EXAMPLE
    .\gemini-ask.ps1 "Your question here"
    echo "Your question" | .\gemini-ask.ps1
    .\gemini-ask.ps1 --file prompt.txt
    .\gemini-ask.ps1 --model gemini-pro "Your question"

.NOTES
    Environment Variables:
        GEMINI_API_KEY - Required API key
        GEMINI_MODEL   - Optional default model (default: gemini-pro)
#>

param(
    [string[]]$Arguments = $args
)

$DEFAULT_MODEL = if ($env:GEMINI_MODEL) { $env:GEMINI_MODEL } else { 'gemini-pro' }

function Main {
    # Check API key
    if (-not $env:GEMINI_API_KEY) {
        Write-Error "Error: GEMINI_API_KEY environment variable is required"
        exit 1
    }

    # Parse arguments
    $prompt = ''
    $modelName = $DEFAULT_MODEL
    $argsList = @($Arguments)
    
    # Check for --model flag
    $modelIndex = -1
    for ($i = 0; $i -lt $argsList.Count; $i++) {
        if ($argsList[$i] -eq '--model' -or $argsList[$i] -eq '-m') {
            $modelIndex = $i
            break
        }
    }
    
    if ($modelIndex -ne -1 -and $argsList.Count -gt ($modelIndex + 1)) {
        $modelName = $argsList[$modelIndex + 1]
        $argsList = $argsList[0..($modelIndex-1)] + $argsList[($modelIndex+2)..($argsList.Count-1)]
    }

    # Check for --system flag (system prompt)
    $systemPrompt = ''
    $systemIndex = -1
    for ($i = 0; $i -lt $argsList.Count; $i++) {
        if ($argsList[$i] -eq '--system' -or $argsList[$i] -eq '-s') {
            $systemIndex = $i
            break
        }
    }
    
    if ($systemIndex -ne -1 -and $argsList.Count -gt ($systemIndex + 1)) {
        $systemPrompt = $argsList[$systemIndex + 1]
        $argsList = $argsList[0..($systemIndex-1)] + $argsList[($systemIndex+2)..($argsList.Count-1)]
    }

    if ($argsList -contains '--file' -or $argsList -contains '-f') {
        $fileIndex = -1
        for ($i = 0; $i -lt $argsList.Count; $i++) {
            if ($argsList[$i] -eq '--file' -or $argsList[$i] -eq '-f') {
                $fileIndex = $i
                break
            }
        }
        
        $filePath = $argsList[$fileIndex + 1]
        if (-not $filePath) {
            Write-Error "Error: No file specified"
            exit 1
        }
        
        if (Test-Path $filePath) {
            $prompt = Get-Content -Path $filePath -Raw -Encoding UTF8
        } else {
            Write-Error "Error: File not found: $filePath"
            exit 1
        }
        
        # Remove --file and path from args
        $argsList = $argsList[0..($fileIndex-1)] + $argsList[($fileIndex+2)..($argsList.Count-1)]
    } elseif ($argsList.Count -gt 0) {
        $prompt = $argsList -join ' '
    } elseif (-not [System.Console]::IsInputRedirected) {
        # Read from stdin when no arguments and input is redirected
        $inputLines = @()
        while ($input = [System.Console]::In.ReadLine()) {
            $inputLines += $input
        }
        $prompt = ($inputLines | Out-String).Trim()
    }

    if ([string]::IsNullOrWhiteSpace($prompt)) {
        Write-Error "Error: No prompt provided"
        Write-Host "Usage: gemini-ask ""your question"""
        Write-Host "       gemini-ask --model gemini-pro ""your question"""
        Write-Host "       echo ""your question"" | gemini-ask"
        exit 1
    }

    try {
        # Prepare the request body
        $generationConfig = @{
            maxOutputTokens = 8192
            temperature     = 0.7
            topP           = 0.95
        }
        
        if ($systemPrompt) {
            # For system prompt, we'll include it in the conversation history
            $body = @{
                generationConfig = $generationConfig
                contents         = @(
                    @{role = 'user'; parts = @(@{text = $systemPrompt})}
                    @{role = 'model'; parts = @(@{text = 'Understood. I will follow that instruction.'})}
                    @{role = 'user'; parts = @(@{text = $prompt})}
                )
            }
        } else {
            $body = @{
                generationConfig = $generationConfig
                contents         = @(@{role = 'user'; parts = @(@{text = $prompt})})
            }
        }
        
        $jsonBody = $body | ConvertTo-Json -Depth 10
        
        # Make the API call
        $headers = @{
            'Content-Type' = 'application/json'
        }
        
        $uri = "https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$env:GEMINI_API_KEY"
        
        $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $jsonBody
        
        # Extract and output the response text
        if ($response.candidates -and $response.candidates.Count -gt 0) {
            $candidate = $response.candidates[0]
            if ($candidate.content -and $candidate.content.parts -and $candidate.content.parts.Count -gt 0) {
                Write-Output $candidate.content.parts[0].text
            } else {
                Write-Error "No content returned from API"
                exit 1
            }
        } else {
            Write-Error "No candidates returned from API"
            exit 1
        }
    } catch {
        Write-Error "Error: $($_.Exception.Message)"
        if ($_.Exception.Message -like '*API key*') {
            Write-Host "Make sure GEMINI_API_KEY is set correctly"
        }
        exit 1
    }
}

Main

#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "a5626f930339b8db2099214400fd300e6005055e6eb8c0d5c934e3f40d65498f", "source_sha256": "9411ee01f75190a7b3bf9f276fc6bb624d2c943629885c1ddfc9f71a0039070e", "target_language": "powershell"}
# gemini-ask.js — portiert nach powershell
# Quelle: javascript, OpenClaw@gateway1:scripts/gemini-ask.js
# auch in: OpenClaw@gateway2:scripts/gemini-ask.js
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
    gemini-ask.ps1 - CLI tool for Google Gemini API

.DESCRIPTION
    This script allows you to interact with the Google Gemini API from the command line.
    You can provide a prompt as an argument, read it from a file, or pipe it via stdin.

.PARAMETER Prompt
    The prompt/question to send to the Gemini API.

.PARAMETER File
    Path to a file containing the prompt.

.PARAMETER Model
    The model name to use (default: gemini-pro or value of GEMINI_MODEL env var).

.PARAMETER System
    System prompt/instruction to prepend to the conversation.

.EXAMPLE
    .\gemini-ask.ps1 "Your question here"
    .\gemini-ask.ps1 -File prompt.txt
    echo "Your question" | .\gemini-ask.ps1
    .\gemini-ask.ps1 -Model gemini-pro "Your question"

.NOTES
    Requires GEMINI_API_KEY environment variable to be set.
#>

param(
    [Parameter(Position=0, ValueFromPipeline=$true)]
    [string]$Prompt,

    [string]$File,

    [string]$Model = $env:GEMINI_MODEL,

    [string]$System
)

begin {
    # Default model if not provided via parameter or environment variable
    if (-not $Model) {
        $Model = 'gemini-pro'
    }

    # Check API key
    if (-not $env:GEMINI_API_KEY) {
        Write-Error "Error: GEMINI_API_KEY environment variable is required"
        exit 1
    }

    $inputBuffer = @()
}

process {
    if ($File) {
        if (Test-Path $File) {
            $Prompt = Get-Content $File -Raw
        } else {
            Write-Error "Error: File '$File' does not exist"
            exit 1
        }
    } elseif ($Input) {
        $inputBuffer += $Input
    }
}

end {
    if (-not $Prompt -and $inputBuffer.Count -gt 0) {
        $Prompt = $inputBuffer -join "`n"
    }

    if (-not $Prompt.Trim()) {
        Write-Error "Error: No prompt provided`nUsage: gemini-ask `"your question`"`n       gemini-ask -Model gemini-pro `"your question`"`n       echo `"your question`" | gemini-ask"
        exit 1
    }

    try {
        # Prepare headers and base URL
        $headers = @{
            'Content-Type' = 'application/json'
        }

        $baseUrl = "https://generativelanguage.googleapis.com/v1beta/models/$Model:generateContent?key=$($env:GEMINI_API_KEY)"

        # Prepare request body
        $body = @{
            generationConfig = @{
                maxOutputTokens = 8192
                temperature     = 0.7
                topP           = 0.95
            }
        }

        if ($System) {
            # Include system prompt in history
            $body.contents = @(
                @{ role = 'user'; parts = @(@{ text = $System }) },
                @{ role = 'model'; parts = @(@{ text = 'Understood. I will follow that instruction.' }) },
                @{ role = 'user'; parts = @(@{ text = $Prompt }) }
            )
        } else {
            # Simple user prompt only
            $body.contents = @(
                @{ role = 'user'; parts = @(@{ text = $Prompt }) }
            )
        }

        # Convert to JSON
        $jsonBody = $body | ConvertTo-Json -Depth 10

        # Make REST call
        $response = Invoke-RestMethod -Uri $baseUrl -Method POST -Headers $headers -Body $jsonBody

        # Output the generated text
        if ($response.candidates -and $response.candidates.Count -gt 0) {
            $firstCandidate = $response.candidates[0]
            if ($firstCandidate.content -and $firstCandidate.content.parts -and $firstCandidate.content.parts.Count -gt 0) {
                Write-Output $firstCandidate.content.parts[0].text
            } else {
                Write-Warning "No content returned in candidate"
            }
        } else {
            Write-Warning "No candidates returned"
        }
    } catch {
        Write-Error "Error: $($_.Exception.Message)"
        if ($_.Exception.Message -like '*API key*') {
            Write-Error "Make sure GEMINI_API_KEY is set correctly"
        }
        exit 1
    }
}

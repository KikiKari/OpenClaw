#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "b10f9425fc1cc129561e4c60116121bd5f73d4a3cdb749c52b4707d4b998d73c", "source_sha256": "eb21431dabeaafc82a1e3ccf24278616e46ed082eca1de4d328c758ee82ee2c7", "target_language": "powershell"}
# language_validator.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/language_validator.py
# auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/language_validator.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Multi-language script validator supporting 8+ languages.
WebSearch integration for documentation lookup.
#>

class ValidationResult {
    [string]$Language
    [bool]$Valid
    [string[]]$Errors
    [string[]]$Warnings
    [string]$DocUrl

    ValidationResult([string]$language, [bool]$valid, [string[]]$errors, [string[]]$warnings, [string]$docUrl) {
        $this.Language = $language
        $this.Valid = $valid
        $this.Errors = $errors
        $this.Warnings = $warnings
        $this.DocUrl = $docUrl
    }
}

class LanguageValidator {
    static [hashtable]$LANGUAGES = @{
        "bash" = @{ cmd = "bash"; args = @("-n"); linter = "shellcheck" }
        "sh" = @{ cmd = "sh"; args = @("-n"); linter = "shellcheck" }
        "python" = @{ cmd = "python3"; args = @("-m", "py_compile"); linter = "pylint" }
        "perl" = @{ cmd = "perl"; args = @("-c"); linter = "perlcritic" }
        "raku" = @{ cmd = "raku"; args = @("-c"); linter = $null }
        "powershell" = @{ cmd = "pwsh"; args = @("-Command", "Get-Command"); linter = $null }
        "javascript" = @{ cmd = "node"; args = @("--check"); linter = "eslint" }
        "tcl" = @{ cmd = "tclsh"; args = @(); linter = $null }
    }

    [string]$Language
    [bool]$UseWebSearch
    [hashtable]$Config

    LanguageValidator([string]$language, [bool]$useWebSearch) {
        $this.Language = $language.ToLower()
        $this.UseWebSearch = $useWebSearch
        $this.Config = [LanguageValidator]::LANGUAGES[$this.Language]
        if ($null -eq $this.Config) {
            throw "Unsupported language: $language"
        }
    }

    [ValidationResult] Validate([string]$scriptPath) {
        $errors = @()
        $warnings = @()

        # Syntax check
        try {
            $allArgs = @($this.Config.cmd) + $this.Config.args + @($scriptPath)
            $result = Start-Process -FilePath $this.Config.cmd -ArgumentList $this.Config.args -NoNewWindow -Wait -PassThru -RedirectStandardOutput "$env:TEMP\stdout.txt" -RedirectStandardError "$env:TEMP\stderr.txt"
            
            if ($result.ExitCode -ne 0) {
                $errorContent = Get-Content "$env:TEMP\stderr.txt" -ErrorAction SilentlyContinue
                if ($errorContent) {
                    $errors += $errorContent
                } else {
                    $errors += "Non-zero exit code: $($result.ExitCode)"
                }
            }
        } catch {
            if ($_ -match "timeout") {
                $errors += "Validation timeout"
            } else {
                $errors += "Command not found: $($this.Config.cmd)"
                if ($this.UseWebSearch) {
                    $docUrl = $this._fetchDocs()
                    return [ValidationResult]::new($this.Language, $false, $errors, $warnings, $docUrl)
                }
            }
        }

        # Linter check if available
        if ($this.Config.linter) {
            $linterWarnings = $this._runLinter($scriptPath)
            $warnings += $linterWarnings
        }

        return [ValidationResult]::new($this.Language, $errors.Count -eq 0, $errors, $warnings, $null)
    }

    [string[]] _runLinter([string]$scriptPath) {
        $linter = $this.Config.linter
        $warnings = @()

        try {
            if ($linter -eq "shellcheck") {
                $result = Start-Process -FilePath "shellcheck" -ArgumentList "-f", "gcc", $scriptPath -NoNewWindow -Wait -PassThru -RedirectStandardOutput "$env:TEMP\shellcheck_stdout.txt" -RedirectStandardError "$env:TEMP\shellcheck_stderr.txt"
                $output = Get-Content "$env:TEMP\shellcheck_stdout.txt" -ErrorAction SilentlyContinue
                if ($output) {
                    $warnings += $output
                }
            } elseif ($linter -eq "pylint") {
                $result = Start-Process -FilePath "pylint" -ArgumentList "--output-format=parseable", $scriptPath -NoNewWindow -Wait -PassThru -RedirectStandardOutput "$env:TEMP\pylint_stdout.txt" -RedirectStandardError "$env:TEMP\pylint_stderr.txt"
                $output = Get-Content "$env:TEMP\pylint_stdout.txt" -ErrorAction SilentlyContinue
                if ($output) {
                    $warnings += $output
                }
            }
        } catch {
            $warnings += "Linter not installed: $linter"
        }

        return $warnings
    }

    [string] _fetchDocs() {
        if (-not $this.UseWebSearch) {
            return $null
        }

        # Return known good documentation URLs
        $docs = @{
            "powershell" = "https://docs.microsoft.com/powershell/"
            "raku" = "https://docs.raku.org/"
            "tcl" = "https://www.tcl.tk/"
        }
        return $docs[$this.Language]
    }
}

function Main {
    param(
        [Parameter(Mandatory=$true)][string]$Script,
        [Parameter(Mandatory=$true)][string]$Lang,
        [switch]$NoWebSearch
    )

    try {
        $validator = [LanguageValidator]::new($Lang, -not $NoWebSearch)
        $result = $validator.Validate($Script)

        Write-Host "Language: $($result.Language)"
        Write-Host "Valid: $($result.Valid)"
        if ($result.Errors.Count -gt 0) {
            Write-Host "Errors: $($result.Errors.Count)"
            $result.Errors | Select-Object -First 5 | ForEach-Object { Write-Host "  - $_" }
        }
        if ($result.Warnings.Count -gt 0) {
            Write-Host "Warnings: $($result.Warnings.Count)"
            $result.Warnings | Select-Object -First 5 | ForEach-Object { Write-Host "  - $_" }
        }
        if ($result.DocUrl) {
            Write-Host "Docs: $($result.DocUrl)"
        }

        exit ($result.Valid ? 0 : 1)
    } catch {
        Write-Error $_.Exception.Message
        exit 1
    }
}

# Entry point simulation
if ($MyInvocation.InvocationName -eq $MyInvocation.MyCommand.Name) {
    # Parse command line arguments manually since we can't use argparse
    $script = $null
    $lang = $null
    $noWebSearch = $false

    for ($i = 0; $i -lt $args.Count; $i++) {
        switch ($args[$i]) {
            "--script" { 
                if (++$i -lt $args.Count) { $script = $args[$i] } 
                else { throw "Missing value for --script" }
            }
            "--lang" { 
                if (++$i -lt $args.Count) { $lang = $args[$i] } 
                else { throw "Missing value for --lang" }
            }
            "--no-websearch" { $noWebSearch = $true }
            default { 
                if (-not $script) { $script = $args[$i] } 
                else { throw "Unexpected argument: $($args[$i])" }
            }
        }
    }

    if (-not $script) { throw "Missing script path" }
    if (-not $lang) { throw "Missing --lang parameter" }

    Main -Script $script -Lang $lang -NoWebSearch:$noWebSearch
}

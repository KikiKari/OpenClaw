#!/usr/bin/env pwsh
# language_validator.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/language_validator.py
# auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/language_validator.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

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

    ValidationResult([string]$Language, [bool]$Valid, [string[]]$Errors, [string[]]$Warnings, [string]$DocUrl) {
        $this.Language = $Language
        $this.Valid = $Valid
        $this.Errors = $Errors
        $this.Warnings = $Warnings
        $this.DocUrl = $DocUrl
    }
}

class LanguageValidator {
    static [hashtable]$Languages = @{
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

    LanguageValidator([string]$Language, [bool]$UseWebSearch) {
        $this.Language = $Language.ToLower()
        $this.UseWebSearch = $UseWebSearch
        $this.Config = [LanguageValidator]::Languages[$this.Language]
        if ($null -eq $this.Config) {
            throw "Unsupported language: $Language"
        }
    }

    [ValidationResult] Validate([string]$ScriptPath) {
        $Errors = @()
        $Warnings = @()

        # Syntax check
        try {
            $Arguments = @($this.Config.cmd) + $this.Config.args + @($ScriptPath)
            $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
            $ProcessInfo.FileName = $Arguments[0]
            $ProcessInfo.Arguments = ($Arguments | Select-Object -Skip 1) -join " "
            $ProcessInfo.RedirectStandardOutput = $true
            $ProcessInfo.RedirectStandardError = $true
            $ProcessInfo.UseShellExecute = $false
            $ProcessInfo.CreateNoWindow = $true

            $Process = New-Object System.Diagnostics.Process
            $Process.StartInfo = $ProcessInfo
            $Process.Start() | Out-Null
            $Process.WaitForExit(30000)

            if (-not $Process.HasExited) {
                $Process.Kill()
                $Errors += "Validation timeout"
            } elseif ($Process.ExitCode -ne 0) {
                $StdErr = $Process.StandardError.ReadToEnd()
                if ([string]::IsNullOrWhiteSpace($StdErr)) {
                    $StdOut = $Process.StandardOutput.ReadToEnd()
                    $Errors += $StdOut
                } else {
                    $Errors += $StdErr
                }
            }
        } catch [System.Management.Automation.CommandNotFoundException] {
            $Errors += "Command not found: $($this.Config.cmd)"
            if ($this.UseWebSearch) {
                $DocUrl = $this._FetchDocs()
                return [ValidationResult]::new($this.Language, $false, $Errors, $Warnings, $DocUrl)
            }
        } catch {
            $Errors += $_.Exception.Message
        }

        # Linter check if available
        if ($this.Config.linter) {
            $LinterWarnings = $this._RunLinter($ScriptPath)
            $Warnings += $LinterWarnings
        }

        return [ValidationResult]::new($this.Language, $Errors.Count -eq 0, $Errors, $Warnings, $null)
    }

    [string[]] _RunLinter([string]$ScriptPath) {
        $Linter = $this.Config.linter
        $Warnings = @()

        try {
            if ($Linter -eq "shellcheck") {
                $Result = & shellcheck -f gcc $ScriptPath 2>&1
                if ($LASTEXITCODE -ne 0 -or $Result) {
                    $Warnings += $Result | Out-String
                }
            } elseif ($Linter -eq "pylint") {
                $Result = & pylint --output-format=parseable $ScriptPath 2>&1
                if ($LASTEXITCODE -ne 0 -or $Result) {
                    $Warnings += $Result | Out-String
                }
            }
        } catch [System.Management.Automation.CommandNotFoundException] {
            $Warnings += "Linter not installed: $Linter"
        }

        return $Warnings
    }

    [string] _FetchDocs() {
        if (-not $this.UseWebSearch) {
            return $null
        }

        $Docs = @{
            "powershell" = "https://docs.microsoft.com/powershell/"
            "raku" = "https://docs.raku.org/"
            "tcl" = "https://www.tcl.tk/"
        }

        return $Docs[$this.Language]
    }
}

function Main {
    param(
        [Parameter(Mandatory=$true)][string]$Script,
        [Parameter(Mandatory=$true)][string]$Lang,
        [switch]$NoWebSearch
    )

    try {
        $Validator = [LanguageValidator]::new($Lang, (-not $NoWebSearch))
        $Result = $Validator.Validate($Script)

        Write-Host "Language: $($Result.Language)"
        Write-Host "Valid: $($Result.Valid)"
        if ($Result.Errors) {
            Write-Host "Errors: $($Result.Errors.Count)"
            $Result.Errors | Select-Object -First 5 | ForEach-Object { Write-Host "  - $_" }
        }
        if ($Result.Warnings) {
            Write-Host "Warnings: $($Result.Warnings.Count)"
            $Result.Warnings | Select-Object -First 5 | ForEach-Object { Write-Host "  - $_" }
        }
        if ($Result.DocUrl) {
            Write-Host "Docs: $($Result.DocUrl)"
        }

        if ($Result.Valid) {
            exit 0
        } else {
            exit 1
        }
    } catch {
        Write-Error $_.Exception.Message
        exit 1
    }
}

# Entry point simulation
if ($MyInvocation.InvocationName -eq '&') {
    # This section would normally be handled by command-line argument parsing in PowerShell
    # Since we're converting from Python's argparse, we'll simulate it here
    $Params = @{}
    
    for ($i = 0; $i -lt $args.Count; $i++) {
        switch ($args[$i]) {
            "--lang" { 
                $i++
                $Params.Lang = $args[$i]
            }
            "--no-websearch" {
                $Params.NoWebSearch = $true
            }
            default {
                if (-not $Params.Script) {
                    $Params.Script = $args[$i]
                }
            }
        }
    }
    
    if (-not $Params.Script -or -not $Params.Lang) {
        Write-Host "Usage: language_validator.ps1 <script> --lang <language> [--no-websearch]"
        exit 1
    }
    
    Main @Params
}

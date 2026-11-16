#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "89e695f9299607b2f96feaedb17582cc7ec1bfda219f7a97cfa41191d750c864", "source_sha256": "8537e4253cc6ca148bc7b8cee5f458bfd0843576263cad8e98ca2c46fa47f2f1", "target_language": "powershell"}
# build-stamp.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/build-stamp.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

function Resolve-GitHead {
    param(
        [string]$Cwd = (Get-Location).Path,
        [System.Diagnostics.ProcessStartInfo]$ProcessStartInfo = $null
    )

    try {
        $psi = if ($ProcessStartInfo) { $ProcessStartInfo } else {
            New-Object System.Diagnostics.ProcessStartInfo -Property @{
                FileName = "git"
                Arguments = "rev-parse HEAD"
                WorkingDirectory = $Cwd
                RedirectStandardOutput = $true
                RedirectStandardError = $true
                UseShellExecute = $false
                CreateNoWindow = $true
            }
        }

        if (-not $ProcessStartInfo) {
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $psi
            $process.Start() | Out-Null
            $output = $process.StandardOutput.ReadToEnd()
            $process.WaitForExit()
            
            if ($process.ExitCode -ne 0) {
                return $null
            }
        } else {
            # Wenn PSI übergeben wurde, wird es extern verwaltet
            return $null
        }

        $head = ($output -split "`n")[0].Trim()
        if ([string]::IsNullOrWhiteSpace($head)) {
            return $null
        }
        return $head
    } catch {
        return $null
    }
}

function Write-BuildStamp {
    param(
        [string]$Cwd = (Get-Location).Path,
        [scriptblock]$NowFunc = { [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() },
        [System.Object]$FsImpl = $null
    )

    $distRoot = Join-Path $Cwd "dist"
    $buildStampPath = Join-Path $distRoot ".buildstamp"
    
    # Erstelle das dist-Verzeichnis falls es nicht existiert
    if (!(Test-Path $distRoot)) {
        New-Item -ItemType Directory -Path $distRoot -Force | Out-Null
    }

    $head = Resolve-GitHead -Cwd $Cwd
    
    $builtAt = & $NowFunc
    $content = @{
        builtAt = $builtAt
        head = $head
    } | ConvertTo-Json
    
    Set-Content -Path $buildStampPath -Value "$content`n" -Encoding UTF8
    return $buildStampPath
}

# Hauptausführung wenn das Skript direkt aufgerufen wird
try {
    Write-BuildStamp
} catch {
    Write-Error $_.Exception.Message
    exit 1
}

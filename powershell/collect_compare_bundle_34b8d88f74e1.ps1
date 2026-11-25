#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "e6fb629af7c6c28e56273e4f15236572e3b4cd1128340ad0987e73cad03744c4", "source_sha256": "5aa602a80e57cbc63f54485d4cd66e205c54bd9f32bc03434218ff9bd388b3ab", "target_language": "powershell"}
# collect_compare_bundle.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway1:scripts/collect_compare_bundle.sh
# auch in: OpenClaw@gateway2:scripts/collect_compare_bundle.sh
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

$ROOT = "$env:HOME/.openclaw"
$OUT_DIR = "$ROOT/workspace/vscode/compare"
$TRANSFER_DIR = "$OUT_DIR/transfer"
$MD_FILE = "$OUT_DIR/local-gateway-config.md"
$TREE_FILE = "$OUT_DIR/tree.txt"
$BACKUP_FILE = "$env:HOME/openclaw-backup.tar.gz"
$NOW_LOCAL = Get-Date -Format "yyyy-MM-dd HH:mm:ss K"
$NOW_UTC = Get-Date -Utc -Format "yyyy-MM-ddTHH:mm:ssZ"
$HOST = hostname

$OPENCLAW_JSON = "$ROOT/openclaw.json"
$EXEC_APPROVALS_JSON = "$ROOT/exec-approvals.json"
$GATEWAY_SYSTEMD_ENV = "$ROOT/gateway.systemd.env"
$DOT_ENV = "$ROOT/.env"
$CONFIG_DIR = "$ROOT/.config"
$AGENTS_DIR = "$ROOT/agents"

New-Item -ItemType Directory -Path $OUT_DIR -Force | Out-Null
New-Item -ItemType Directory -Path $TRANSFER_DIR -Force | Out-Null

if (-not (Get-Command tree -ErrorAction SilentlyContinue)) {
    Write-Error "Fehler: 'tree' ist nicht installiert."
    exit 1
}

function Append-FileVerbatim {
    param(
        [string]$Label,
        [string]$Path,
        [string]$Lang = "text"
    )
    
    $content = @"
## $Label

Pfad: `$Path`

```$Lang
$(@(
    if (Test-Path $Path) {
        Get-Content $Path -Raw
    } else {
        "[FEHLT] $Path"
    }
) -join "`n")
```

"@
    Add-Content $MD_FILE $content
}

function Append-EnvVerbatim {
    $envContent = @"
## Umgebungsvariablen (env)

```text
$(@(
    Get-ChildItem env: | ForEach-Object { "$($_.Name)=$($_.Value)" }
) -join "`n")
```

"@
    Add-Content $MD_FILE $envContent
}

function Append-DirFilesVerbatim {
    param(
        [string]$Section,
        [string]$Dir
    )
    
    $header = @"
## $Section

"@
    Add-Content $MD_FILE $header
    
    if (-not (Test-Path $Dir)) {
        Add-Content $MD_FILE "[FEHLT] $Dir"
        return
    }
    
    Add-Content $MD_FILE "Basisverzeichnis: `$Dir`""
    
    Get-ChildItem -Path $Dir -File -Recurse | Sort-Object FullName | ForEach-Object {
        $fileContent = @"
### Datei: `"$($_.FullName)`"

```text
$((Get-Content $_.FullName -Raw) -join "`n")
```

"@
        Add-Content $MD_FILE $fileContent
    }
}

$header = @"
# Lokaler Gateway-Konfigurationsstand

Generiert: $NOW_LOCAL
UTC: $NOW_UTC
Host: $HOST

Diese Datei enthaelt den lokalen Stand mit unveraenderten Inhalten.
"@

Set-Content $MD_FILE $header

Append-FileVerbatim "openclaw.json" $OPENCLAW_JSON "json"
Append-FileVerbatim "exec-approvals.json" $EXEC_APPROVALS_JSON "json"
Append-FileVerbatim "gateway.systemd.env" $GATEWAY_SYSTEMD_ENV "dotenv"
Append-FileVerbatim ".env" $DOT_ENV "dotenv"
Append-EnvVerbatim
Append-DirFilesVerbatim ".config (alle Dateien rekursiv)" $CONFIG_DIR
Append-DirFilesVerbatim "agents (alle Dateien rekursiv)" $AGENTS_DIR

tree -a -L 6 $ROOT > $TREE_FILE
openclaw backup create --output $BACKUP_FILE --verify
Copy-Item $BACKUP_FILE $OUT_DIR

Write-Output "OK"
Write-Output "Erzeugt:"
Write-Output "- $MD_FILE"
Write-Output "- $TREE_FILE"
Write-Output "- $BACKUP_FILE"
Write-Output "- $TRANSFER_DIR (leer)"

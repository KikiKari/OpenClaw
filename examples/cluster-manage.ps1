#Requires -Version 5.1
# OpenClaw cluster management — PowerShell

param(
    [ValidateSet("Health","Restart","Logs","Status")]
    [string]$Action = "Health",
    [string[]]$Nodes = @("http://localhost:8080","http://localhost:8081"),
    [int]$TimeoutSec = 5
)

function Invoke-NodeRequest {
    param([string]$Uri, [string]$Method = "GET")
    try {
        $r = Invoke-WebRequest -Uri $Uri -Method $Method -TimeoutSec $TimeoutSec -UseBasicParsing
        return [PSCustomObject]@{ Success=$true; StatusCode=$r.StatusCode; Body=$r.Content }
    } catch {
        return [PSCustomObject]@{ Success=$false; StatusCode=0; Error=$_.Exception.Message }
    }
}

switch ($Action) {
    "Health" {
        $results = $Nodes | ForEach-Object {
            $r = Invoke-NodeRequest "$_/health"
            [PSCustomObject]@{ Node=$_; Status=if($r.Success){"OK"}else{"FAIL"}; Code=$r.StatusCode }
        }
        $results | Format-Table -AutoSize
        $failed = ($results | Where-Object Status -eq "FAIL").Count
        if ($failed -gt 0) { Write-Warning "$failed node(s) unreachable"; exit 1 }
    }
    "Restart" {
        $Nodes | ForEach-Object {
            Write-Host "Restarting $_..."
            $r = Invoke-NodeRequest "$_/admin/restart" -Method POST
            Write-Host $(if($r.Success){"  OK"}else{"  WARN: $($r.Error)"})
        }
    }
    "Status" {
        $Nodes | ForEach-Object {
            $r = Invoke-NodeRequest "$_/status"
            Write-Host "$_`: $(if($r.Success){$r.Body}else{$r.Error})"
        }
    }
}
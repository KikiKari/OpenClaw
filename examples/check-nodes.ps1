param(
    [string[]]$Nodes = @("http://localhost:8080", "http://localhost:8081"),
    [int]$TimeoutSeconds = 5
)
foreach ($node in $Nodes) {
    try {
        $r = Invoke-WebRequest -Uri "$node/health" -TimeoutSec $TimeoutSeconds -UseBasicParsing
        Write-Host "OK   $node -> $($r.StatusCode)" -ForegroundColor Green
    } catch {
        Write-Host "FAIL $node -> $($_.Exception.Message)" -ForegroundColor Red
    }
}
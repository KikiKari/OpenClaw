@echo off
:: OpenClaw cluster health check — Windows Batch
setlocal EnableDelayedExpansion

set NODES=localhost:8080 localhost:8081
set TIMEOUT=5
set OK=0
set FAIL=0

echo OpenClaw Health Check
echo =====================

for %%N in (%NODES%) do (
    curl -sf --max-time %TIMEOUT% "http://%%N/health" >/dev/null 2>&1
    if !errorlevel! == 0 (
        echo   OK    %%N
        set /a OK+=1
    ) else (
        echo   FAIL  %%N
        set /a FAIL+=1
    )
)

echo.
echo --- %OK% OK / %FAIL% FAIL

if %FAIL% gtr 0 (
    echo WARNING: One or more nodes are unreachable.
    exit /b 1
)
exit /b 0
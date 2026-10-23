#!/usr/bin/env pwsh
# test_scanner_limits.cjs — portiert nach powershell
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_scanner_limits.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_scanner_limits.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_scanner_limits.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_scanner_limits.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Join-Path $PSScriptRoot ".." | Resolve-Path
$sources = @(
    @("browser-extension/content.js", "  function explicitCardSummary", $true),
    @("mobile-shared/webview-bridge.js", "  function primaryVideo", $false)
)

function structuredClone($obj) {
    if ($null -eq $obj) { return $null }
    if ($obj -is [System.Collections.IDictionary]) {
        $clone = @{}
        foreach ($key in $obj.Keys) {
            $clone[$key] = structuredClone($obj[$key])
        }
        return $clone
    }
    if ($obj -is [System.Collections.IEnumerable] -and $obj -isnot [string]) {
        $clone = @()
        foreach ($item in $obj) {
            $clone += @(structuredClone($item))
        }
        return $clone
    }
    return $obj
}

foreach ($source in $sources) {
    $file = $source[0]
    $end = $source[1]
    $browser = $source[2]
    
    $fullPath = Join-Path $root $file
    $sourceContent = Get-Content -Path $fullPath -Raw -Encoding UTF8
    
    $startIndex = $sourceContent.IndexOf("  async function scanRecommendations(run)")
    $endIndex = $sourceContent.IndexOf($end, $startIndex)
    $code = $sourceContent.Substring($startIndex, $endIndex - $startIndex)
    
    if ($code.Length -le 100) {
        throw "Code length is not greater than 100"
    }
    
    foreach ($n in @(1, 50, 51, 299, 300, 301)) {
        $updates = @()
        $cards = @()
        for ($i = 0; $i -lt 301; $i++) {
            $cards += @{
                handle = "creator$i"
                card = @{
                    scrollIntoView = { }
                    dispatchEvent = { }
                }
            }
        }
        
        $run = @{
            limit = [Math]::Min($n, 300)
            sourceUrl = "https://www.tiktok.com/@creator/live"
            runId = "test"
            cancelled = $false
        }
        
        # Create a script block with the context variables
        $contextScript = {
            $root = @{}
            $scrollX = 0
            $scrollY = 0
            $innerHeight = 800
            $location = @{ href = $run.sourceUrl }
            
            class MouseEvent { }
            
            function setTimeout($fn) { 
                & $fn
                return 1 
            }
            
            $window = @{
                scrollX = 0
                scrollY = 0
                scrollTo = { }
                scrollBy = { }
            }
            
            function scrollTo() { }
            function scrollBy() { }
            
            $activeRecommendationScan = $run
            $RECOMMENDATION_SCAN_MAX_ROUNDS = 12
            $RECOMMENDATION_SCAN_MAX_MS = 45000
            
            # Load content-core.js
            $corePath = Join-Path $root "browser-extension/content-core.js"
            . $corePath
            
            function recommendationCards() { return $cards }
            
            function recommendationItem($e, $p) { 
                return @{
                    handle = $e.handle
                    position = $p
                    title = "x" * 300
                }
            }
            
            function text($str) { return [string]$str }
            
            function emit($type, $p) { 
                $updates.Add((structuredClone($p)))
            }
            
            function emitRecommendationProgress($r, $status, $items) { 
                $updates.Add((structuredClone(@{ status = $status; items = $items })))
            }
        }
        
        # Execute the context setup
        &$contextScript
        
        # Execute the code in the context (this is a simplified approach)
        Invoke-Expression $code
        
        # Call scanRecommendations
        &$scanRecommendations($run)
        
        # Assertions
        if ($updates[-1].status -ne "complete") {
            throw "Expected status 'complete', but got '$($updates[-1].status)'"
        }
        
        if ($updates[-1].items.Length -ne [Math]::Min($n, 300)) {
            throw "Expected items length $([Math]::Min($n, 300)), but got $($updates[-1].items.Length)"
        }
        
        if ($updates[-1].items[-1].position -ne [Math]::Min($n, 300)) {
            throw "Expected last item position $([Math]::Min($n, 300)), but got $($updates[-1].items[-1].position)"
        }
    }
    
    Write-Host "PASS synthetic production scan loop: $file; 1,50,51,299,300,301"
}

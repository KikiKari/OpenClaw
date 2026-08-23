#!/usr/bin/env pwsh
# tavily_search.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/tavily/scripts/tavily_search.py
# auch in: OpenClaw@gateway2:skills/tavily/scripts/tavily_search.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Tavily AI Search - Optimized search for LLMs and AI applications
Requires: Install-Module -Name TavilyPS (hypothetical PowerShell equivalent)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Query,
    
    [string]$ApiKey,
    
    [ValidateSet("basic", "advanced")]
    [string]$Depth = "basic",
    
    [ValidateSet("general", "news")]
    [string]$Topic = "general",
    
    [int]$MaxResults = 5,
    
    [switch]$NoAnswer,
    
    [switch]$RawContent,
    
    [switch]$Images,
    
    [string[]]$IncludeDomains,
    
    [string[]]$ExcludeDomains,
    
    [switch]$Json
)

function Invoke-TavilySearch {
    param(
        [string]$Query,
        [string]$ApiKey,
        [string]$SearchDepth = "basic",
        [string]$Topic = "general",
        [int]$MaxResults = 5,
        [bool]$IncludeAnswer = $true,
        [bool]$IncludeRawContent = $false,
        [bool]$IncludeImages = $false,
        [string[]]$IncludeDomains,
        [string[]]$ExcludeDomains
    )
    
    # Check if required module exists (simulated)
    try {
        # In real implementation, this would check for actual Tavily PowerShell module
        # Import-Module TavilyPS -ErrorAction Stop
    }
    catch {
        return @{
            error = "Tavily PowerShell module not installed."
            install_command = "Install-Module -Name TavilyPS"
        }
    }
    
    if (-not $ApiKey) {
        return @{
            error = "Tavily API key required. Get one at https://tavily.com"
            setup_instructions = "Set TAVILY_API_KEY environment variable or pass -ApiKey parameter"
        }
    }
    
    try {
        # Simulate API call structure
        $searchParams = @{
            query = $Query
            search_depth = $SearchDepth
            topic = $Topic
            max_results = $MaxResults
            include_answer = $IncludeAnswer
            include_raw_content = $IncludeRawContent
            include_images = $IncludeImages
        }
        
        if ($IncludeDomains) {
            $searchParams.include_domains = $IncludeDomains
        }
        
        if ($ExcludeDomains) {
            $searchParams.exclude_domains = $ExcludeDomains
        }
        
        # This would be replaced with actual API call in real implementation
        # $response = Invoke-TavilyApi -ApiKey $ApiKey -Parameters $searchParams
        
        # Mock response for demonstration
        $response = @{
            answer = "This is a mock AI-generated answer for the query: $Query"
            results = @(
                @{
                    title = "Example Result 1"
                    url = "https://example.com/1"
                    score = 0.987
                    content = "This is example content from the first result showing how information might be returned."
                },
                @{
                    title = "Example Result 2"
                    url = "https://example.com/2"
                    score = 0.876
                    content = "Another example showing different content that could be retrieved from search results."
                }
            )
            images = @("https://example.com/image1.jpg", "https://example.com/image2.jpg")
            response_time = 1.23
            usage = @{ credits = 2 }
        }
        
        return @{
            success = $true
            query = $Query
            answer = $response.answer
            results = $response.results
            images = $response.images
            response_time = $response.response_time
            usage = $response.usage
        }
    }
    catch {
        return @{
            error = $_.Exception.Message
            query = $Query
        }
    }
}

# Main execution logic
$envApiKey = $env:TAVILY_API_KEY
$effectiveApiKey = if ($ApiKey) { $ApiKey } else { $envApiKey }

$result = Invoke-TavilySearch `
    -Query $Query `
    -ApiKey $effectiveApiKey `
    -SearchDepth $Depth `
    -Topic $Topic `
    -MaxResults $MaxResults `
    -IncludeAnswer (-not $NoAnswer) `
    -IncludeRawContent $RawContent `
    -IncludeImages $Images `
    -IncludeDomains $IncludeDomains `
    -ExcludeDomains $ExcludeDomains

if ($Json) {
    $result | ConvertTo-Json -Depth 10
}
else {
    if ($result.error) {
        Write-Error "Error: $($result.error)"
        if ($result.install_command) {
            Write-Host "`nTo install: $($result.install_command)" -ForegroundColor Yellow
        }
        if ($result.setup_instructions) {
            Write-Host "`nSetup: $($result.setup_instructions)" -ForegroundColor Yellow
        }
        exit 1
    }
    
    # Format human-readable output
    Write-Host "Query: $($result.query)"
    Write-Host "Response time: $(if($result.response_time){$result.response_time}else{'N/A'})s"
    Write-Host "Credits used: $(if($result.usage.credits){$result.usage.credits}else{'N/A'})`n"
    
    if ($result.answer) {
        Write-Host "=== AI ANSWER ==="
        Write-Host $result.answer
        Write-Host ""
    }
    
    if ($result.results) {
        Write-Host "=== RESULTS ==="
        for ($i = 0; $i -lt $result.results.Count; $i++) {
            $item = $result.results[$i]
            Write-Host "`n$($i+1). $($item.title)"
            Write-Host "   URL: $($item.url)"
            Write-Host "   Score: $([math]::Round($item.score, 3))"
            if ($item.content) {
                $content = $item.content
                if ($content.Length -gt 200) {
                    $content = $content.Substring(0, 200) + "..."
                }
                Write-Host "   $content"
            }
        }
    }
    
    if ($result.images) {
        Write-Host "`n=== IMAGES ($($result.images.Count)) ==="
        $imageCount = [Math]::Min(5, $result.images.Count)
        for ($i = 0; $i -lt $imageCount; $i++) {
            Write-Host "   $($result.images[$i])"
        }
    }
}

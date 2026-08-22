#!/usr/bin/env pwsh
# scrape_to_markdown.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
# auch in: OpenClaw@gateway2:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
    Scrapes web pages and converts them to Markdown format.
.DESCRIPTION
    This script scrapes web pages using either standard HTTP requests or JavaScript-enabled browsers,
    extracts the main content, converts it to Markdown, and saves the results to files.
.PARAMETER Url
    One or more URLs to scrape. Can be specified multiple times.
.PARAMETER UrlFile
    Path to a file containing URLs to scrape, one per line.
.PARAMETER Selector
    Preferred CSS selector to use for extracting main content.
.PARAMETER Js
    Use JavaScript-enabled browser for scraping.
.PARAMETER WaitSelector
    CSS selector to wait for before scraping (only with -Js).
.PARAMETER PreserveLinks
    Preserve links in the Markdown output.
.PARAMETER BodyWidth
    Wrap lines at this width in the Markdown output.
.PARAMETER Timeout
    Timeout for HTTP requests in seconds.
.PARAMETER OutputDir
    Directory to save Markdown files and index.json.
.PARAMETER AutomatchDomain
    Domain to use for Scrapling's automatch feature.
#>

param(
    [string[]]$Url = @(),
    [string]$UrlFile = "",
    [string]$Selector = "",
    [switch]$Js,
    [string]$WaitSelector = "",
    [switch]$PreserveLinks,
    [int]$BodyWidth = 0,
    [int]$Timeout = 30,
    [string]$OutputDir = "outputs",
    [string]$AutomatchDomain = ""
)

function ConvertTo-StringSafe {
    param([object]$Value)
    
    if ($null -eq $Value) {
        return ""
    }
    if ($Value -is [byte[]]) {
        return [System.Text.Encoding]::UTF8.GetString($Value)
    }
    return [string]$Value
}

function Get-Slug {
    param(
        [string]$Text,
        [int]$MaxLength = 80
    )
    
    $text = [regex]::Replace($Text, '[^\w\s-]', '', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $text = $text.Trim().ToLower()
    $text = [regex]::Replace($text, '[-\s]+', '-')
    $text = $text.Substring(0, [Math]::Min($text.Length, $MaxLength)).Trim('-')
    if (-not $text) {
        $text = "page"
    }
    return $text
}

function Get-HtmlFromObject {
    param([object]$Obj)
    
    if ($null -eq $Obj) {
        return ""
    }
    
    $attrs = @("html", "raw_html", "content", "markup", "body", "inner_html")
    foreach ($attr in $attrs) {
        try {
            $value = $Obj.$attr
            if ($value -and $value.GetType().Name -eq "ScriptBlock") {
                $value = & $value
            }
            $text = ConvertTo-StringSafe $value
            if ($text -and $text.Contains("<") -and $text.Contains(">")) {
                return $text
            }
        } catch {
            # Continue to next attribute
        }
    }
    
    $text = ConvertTo-StringSafe $Obj
    if ($text -and $text.Contains("<") -and $text.Contains(">")) {
        return $text
    }
    return ""
}

function Get-TitleFromHtml {
    param([string]$Html)
    
    $match = [regex]::Match($Html, '<title[^>]*>(.*?)</title>', [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($match.Success) {
        $title = [regex]::Replace($match.Groups[1].Value, '<[^>]+>', ' ')
        $title = [regex]::Replace($title, '\s+', ' ').Trim()
        return $title
    }
    return ""
}

function Get-FetcherClass {
    param([bool]$UseJs)
    
    if ($UseJs) {
        $candidates = @(
            @{ Module = "scrapling.fetchers"; Class = "DynamicFetcher" },
            @{ Module = "scrapling.fetchers"; Class = "PlayWrightFetcher" },
            @{ Module = "scrapling.default"; Class = "PlayWrightFetcher" },
            @{ Module = "scrapling.defaults"; Class = "PlayWrightFetcher" }
        )
    } else {
        $candidates = @(
            @{ Module = "scrapling.fetchers"; Class = "Fetcher" },
            @{ Module = "scrapling.default"; Class = "Fetcher" },
            @{ Module = "scrapling.defaults"; Class = "Fetcher" }
        )
    }
    
    $errors = @()
    foreach ($candidate in $candidates) {
        try {
            $module = Import-Module $candidate.Module -PassThru -ErrorAction Stop
            $cls = $module.GetType($candidate.Class)
            foreach ($methodName in @("get", "fetch")) {
                if ($cls.GetMethod($methodName)) {
                    return @{
                        Class = $cls
                        MethodName = $methodName
                    }
                }
            }
        } catch {
            $errors += "$($candidate.Module).$($candidate.Class): $($_.Exception.Message)"
        }
    }
    
    throw "No compatible Scrapling fetcher found: $($errors[0..4] -join ' | ')"
}

function Invoke-FetchPage {
    param(
        [string]$Url,
        [bool]$UseJs,
        [string]$WaitSelector,
        [int]$TimeoutSeconds,
        [string]$AutomatchDomain
    )
    
    $fetcherInfo = Get-FetcherClass -UseJs $UseJs
    $cls = $fetcherInfo.Class
    $methodName = $fetcherInfo.MethodName
    
    $kwargs = @{}
    if ($UseJs) {
        $kwargs.headless = $true
        if ($WaitSelector) {
            $kwargs.wait_selector = $WaitSelector
        }
    } else {
        $kwargs.timeout = $TimeoutSeconds
    }
    
    if ($AutomatchDomain -and -not $UseJs) {
        try {
            $instance = New-Object $cls -Property @{ automatch_domain = $AutomatchDomain }
            $method = $instance.GetType().GetMethod($methodName)
        } catch {
            # Fall back to default instantiation
        }
    }
    
    try {
        $page = &$method.Invoke($null, @($Url, $kwargs))
        $backend = "$($cls.Module).$($cls.Name).$methodName"
        return @{
            Page = $page
            Backend = $backend
        }
    } catch [System.Management.Automation.MethodInvocationException] {
        $page = &$method.Invoke($null, @($Url))
        $backend = "$($cls.Module).$($cls.Name).$methodName"
        return @{
            Page = $page
            Backend = $backend
        }
    }
}

function Get-MainHtml {
    param(
        [object]$Page,
        [string]$PreferredSelector
    )
    
    $selectors = @()
    if ($PreferredSelector) {
        $selectors += $PreferredSelector
    }
    $selectors += @("article", "main", "[role='main']", ".post-content", ".entry-content", ".article-content", "body")
    
    if ($Page.PSObject.Members.Name -contains "css_first") {
        foreach ($selector in $selectors) {
            try {
                $node = $Page.css_first($selector)
                $html = Get-HtmlFromObject $node
                if ($html -and $html.Length -ge 120) {
                    return @{
                        Html = $html
                        SelectorUsed = $selector
                    }
                }
            } catch {
                # Continue to next selector
            }
        }
    }
    
    return @{
        Html = (Get-HtmlFromObject $Page)
        SelectorUsed = $null
    }
}

function Convert-HtmlToMarkdown {
    param(
        [string]$Html,
        [bool]$PreserveLinks,
        [int]$BodyWidthValue
    )
    
    # Note: html2text equivalent would need to be implemented or imported separately
    # For now we'll create a placeholder that returns raw HTML
    $md = $Html
    
    # Remove excessive newlines
    $md = [regex]::Replace($md, "`n`n`n+", "`n`n").Trim()
    return $md
}

function Get-UrlsFromFile {
    param([string]$FilePath)
    
    $urls = @()
    if (Test-Path $FilePath) {
        $content = Get-Content $FilePath -Encoding UTF8
        foreach ($line in $content) {
            $line = $line.Trim()
            if ($line -and -not $line.StartsWith("#")) {
                $urls += $line
            }
        }
    }
    return $urls
}

function Test-ValidUrl {
    param([string]$Url)
    
    try {
        $uri = [System.Uri]$Url
        return ($uri.Scheme -eq "http" -or $uri.Scheme -eq "https") -and $uri.Host
    } catch {
        return $false
    }
}

function Main {
    $allUrls = @()
    $allUrls += $Url
    
    if ($UrlFile) {
        $fileUrls = Get-UrlsFromFile $UrlFile
        $allUrls += $fileUrls
    }
    
    # Remove duplicates while preserving order
    $uniqueUrls = @()
    $seen = @{}
    foreach ($u in $allUrls) {
        if (-not $seen.ContainsKey($u)) {
            $uniqueUrls += $u
            $seen[$u] = $true
        }
    }
    $allUrls = $uniqueUrls
    
    if ($allUrls.Count -eq 0) {
        $result = @{
            ok = $false
            error = "No URLs provided"
        }
        Write-Output (ConvertTo-Json $result -Compress)
        exit 1
    }
    
    foreach ($u in $allUrls) {
        if (-not (Test-ValidUrl $u)) {
            $result = @{
                ok = $false
                error = "Invalid URL: $u"
            }
            Write-Output (ConvertTo-Json $result -Compress)
            exit 1
        }
    }
    
    $outDir = [System.IO.Path]::GetFullPath($OutputDir)
    if (-not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir | Out-Null
    }
    
    $results = @()
    
    foreach ($url in $allUrls) {
        $item = @{
            url = $url
            ok = $false
            title = ""
            status = $null
            selector_used = $null
            backend = $null
            markdown = ""
            preview = ""
            output_markdown_file = $null
            error = $null
        }
        
        try {
            $fetchResult = Invoke-FetchPage `
                -Url $url `
                -UseJs $Js `
                -WaitSelector ($WaitSelector -as [string]) `
                -TimeoutSeconds $Timeout `
                -AutomatchDomain ($AutomatchDomain -as [string])
            
            $page = $fetchResult.Page
            $backend = $fetchResult.Backend
            
            $mainHtmlResult = Get-MainHtml -Page $page -PreferredSelector ($Selector -as [string])
            $html = $mainHtmlResult.Html
            $selectorUsed = $mainHtmlResult.SelectorUsed
            
            if (-not $html) {
                throw "No HTML content extracted from page"
            }
            
            $title = Get-TitleFromHtml $html
            if (-not $title) {
                $uri = [System.Uri]$url
                $title = $uri.Host
            }
            
            $markdown = Convert-HtmlToMarkdown `
                -Html $html `
                -PreserveLinks $PreserveLinks `
                -BodyWidthValue $BodyWidth
            
            $filename = "$(Get-Slug("$(([System.Uri]$url).Host)-$title"))).md"
            $mdPath = Join-Path $outDir $filename
            Set-Content -Path $mdPath -Value $markdown -Encoding UTF8
            
            $status = $null
            if ($page.PSObject.Properties.Name -contains "status") {
                $status = $page.status
            } elseif ($page.PSObject.Properties.Name -contains "status_code") {
                $status = $page.status_code
            }
            
            $item.ok = $true
            $item.title = $title
            $item.status = $status
            $item.selector_used = $selectorUsed
            $item.backend = $backend
            $item.markdown = $markdown
            $item.preview = $markdown.Substring(0, [Math]::Min($markdown.Length, 1200))
            $item.output_markdown_file = $mdPath
        } catch {
            $item.error = $_.Exception.Message
        }
        
        $results += $item
    }
    
    $ok = $false
    foreach ($x in $results) {
        if ($x.ok) {
            $ok = $true
            break
        }
    }
    
    $indexPath = Join-Path $outDir "index.json"
    $payload = @{
        ok = $ok
        count = $results.Count
        success_count = ($results | Where-Object { $_.ok }).Count
        failure_count = ($results | Where-Object { -not $_.ok }).Count
        output_index_file = $indexPath
        results = $results
    }
    
    $jsonContent = ConvertTo-Json $payload -Depth 10 -Encoding UTF8
    Set-Content -Path $indexPath -Value $jsonContent -Encoding UTF8
    Write-Output $jsonContent
}

Main

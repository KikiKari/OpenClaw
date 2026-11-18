#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "bb0f9e5aaeb5d3914853aea24e092473a31bf7051076cabc3ca27d8ed4743a28", "source_sha256": "f76d25200d74ebc530580d7a7afb24c88ee8981f06c4d1734500f4cc830c4fe9", "target_language": "powershell"}
# scrape_to_markdown.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
# auch in: OpenClaw@gateway2:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
    Scrapes web pages and converts them to Markdown format.
.DESCRIPTION
    This script scrapes one or more URLs using either standard HTTP requests or JavaScript-enabled headless browser,
    extracts the main content, converts it to Markdown, and saves each result as a .md file.
    It also generates an index.json file summarizing all operations.
.PARAMETER Url
    One or more URLs to scrape directly from command line.
.PARAMETER UrlFile
    Path to a file containing URLs (one per line).
.PARAMETER Selector
    Preferred CSS selector to extract main content.
.PARAMETER Js
    Use JavaScript-enabled scraping engine (requires Playwright).
.PARAMETER WaitSelector
    Wait for this element to appear before extracting content (JS mode only).
.PARAMETER PreserveLinks
    Keep links in the output instead of stripping them.
.PARAMETER BodyWidth
    Wrap lines at N characters wide (default: 0 = no wrapping).
.PARAMETER Timeout
    Request timeout in seconds (non-JS mode only).
.PARAMETER OutputDir
    Directory where output files will be saved.
.PARAMETER AutomatchDomain
    Domain name for automatic matching rules (non-JS mode only).
.NOTES
    SECURITY MANIFEST:
    - Environment variables accessed: none
    - External endpoints called: only URLs supplied by the user at runtime via --Url / --UrlFile
    - Local files read: --UrlFile path (if provided by user)
    - Local files written: --OutputDir/*.md, --OutputDir/index.json (if --OutputDir provided)
                          Scrapling automatch SQLite DB (managed by Scrapling, local only)
    - Credentials handled: Proxy value (never logged or transmitted beyond the proxy itself)
    - Shell injection risk: none (pure PowerShell, no Start-Process or shell interpolation)
#>

param (
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

function ConvertTo-String($value) {
    if ($null -eq $value) {
        return ""
    }
    if ($value -is [byte[]]) {
        return [System.Text.Encoding]::UTF8.GetString($value)
    }
    return "$value"
}

function Get-Slug($text, $maxLength = 80) {
    # Remove non-word characters except spaces and hyphens
    $cleaned = $text -replace '[^\w\s-]', '' 
    # Replace multiple hyphens/spaces with single hyphen
    $slug = $cleaned -replace '[-\s]+', '-'
    # Trim leading/trailing hyphens and limit length
    if ($slug.Length -gt $maxLength) {
        $slug = $slug.Substring(0, $maxLength)
    }
    $slug = $slug.Trim('-')
    if (-not $slug) {
        $slug = "page"
    }
    return $slug.ToLowerInvariant()
}

function Extract-HtmlContent($obj) {
    if ($null -eq $obj) {
        return ""
    }

    foreach ($attr in @("html", "raw_html", "content", "markup", "body", "inner_html")) {
        try {
            $value = $obj.$attr
            if ($value -and $value.GetType().Name -eq "ScriptBlock") {
                $value = & $value
            }
            $text = ConvertTo-String $value
            if ($text -and $text.Contains("<") -and $text.Contains(">")) {
                return $text
            }
        } catch {
            continue
        }
    }

    $text = ConvertTo-String $obj
    if ($text.Contains("<") -and $text.Contains(">")) {
        return $text
    }
    return ""
}

function Get-HtmlTitle($html) {
    if ([string]::IsNullOrWhiteSpace($html)) {
        return ""
    }

    $match = [regex]::Match($html, '<title[^>]*>(.*?)</title>', [System.Text.RegularExpressions.RegexOptions]'IgnoreCase,Singleline')
    if ($match.Success) {
        $title = $match.Groups[1].Value
        # Strip HTML tags from title
        $title = [regex]::Replace($title, '<[^>]+>', ' ')
        # Normalize whitespace
        $title = [regex]::Replace($title, '\s+', ' ').Trim()
        return $title
    }
    return ""
}

function Load-FetcherClass($useJs) {
    $errors = @()

    if ($useJs) {
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

    foreach ($candidate in $candidates) {
        try {
            $module = Import-Module $candidate.Module -PassThru -ErrorAction Stop
            $cls = $module.ExportedClasses[$candidate.Class]
            if ($cls) {
                foreach ($methodName in @("get", "fetch")) {
                    $methodInfo = $cls.GetMethod($methodName)
                    if ($methodInfo -and $methodInfo.IsPublic) {
                        return @{
                            Type = $cls
                            MethodName = $methodName
                        }
                    }
                }
            }
        } catch {
            $errors += "$($candidate.Module).$($candidate.Class): $_"
        }
    }

    throw "No compatible Scrapling fetcher found: $($errors -join ' | ')"
}

function Invoke-FetchPage($url, $useJs, $waitSelector, $timeoutSeconds, $automatchDomain) {
    $fetcherConfig = Load-FetcherClass -useJs $useJs
    $clsType = $fetcherConfig.Type
    $methodName = $fetcherConfig.MethodName

    $kwargs = @{}
    if ($useJs) {
        $kwargs.headless = $true
        if ($waitSelector) {
            $kwargs.wait_selector = $waitSelector
        }
    } else {
        $kwargs.timeout = $timeoutSeconds
    }

    $instance = $null
    if ($automatchDomain -and -not $useJs) {
        try {
            $instance = New-Object $clsType -ArgumentList @{ automatch_domain = $automatchDomain }
        } catch {
            Write-Warning "Failed to create instance with automatch domain: $_"
        }
    }

    if (-not $instance) {
        $instance = New-Object $clsType
    }

    try {
        $page = $instance.$methodName($url, $kwargs)
        $backendSignature = "$($clsType.FullName).$methodName"
        return @{
            Page = $page
            Backend = $backendSignature
        }
    } catch [System.Management.Automation.MethodInvocationException] {
        # Try without kwargs if TypeError occurred
        $page = $instance.$methodName($url)
        $backendSignature = "$($clsType.FullName).$methodName"
        return @{
            Page = $page
            Backend = $backendSignature
        }
    }
}

function Select-MainHtml($page, $preferredSelector) {
    $selectors = @()
    if ($preferredSelector) {
        $selectors += $preferredSelector
    }
    $selectors += @("article", "main", "[role='main']", ".post-content", ".entry-content", ".article-content", "body")

    if ($page.PSObject.Members.Name -contains "css_first") {
        foreach ($selector in $selectors) {
            try {
                $node = $page.css_first($selector)
                $html = Extract-HtmlContent $node
                if ($html -and $html.Length -ge 120) {
                    return @{
                        Html = $html
                        SelectorUsed = $selector
                    }
                }
            } catch {
                continue
            }
        }
    }

    return @{
        Html = (Extract-HtmlContent $page)
        SelectorUsed = $null
    }
}

function Convert-HtmlToMarkdown($html, $preserveLinks, $bodyWidth) {
    # Since we can't use html2text directly in PowerShell, simulate basic conversion here
    # In practice you'd want to call Python's html2text via external process or COM interop
    
    # Strip images first
    $html = [regex]::Replace($html, '<img[^>]*>', '', [System.Text.RegularExpressions.RegexOptions]'IgnoreCase')

    # Convert headers
    $html = [regex]::Replace($html, '<h(\d)[^>]*>(.*?)</h\1>', { param($m) '#'*[int]$m.Groups[1].Value+" "+$m.Groups[2].Value }, [System.Text.RegularExpressions.RegexOptions]'IgnoreCase,Singleline')
    
    # Convert links
    if ($preserveLinks) {
        $html = [regex]::Replace($html, '<a[^>]+href=["'']([^"'']*)["''][^>]*>(.*?)</a>', '$2 ($1)', [System.Text.RegularExpressions.RegexOptions]'IgnoreCase,Singleline')
    } else {
        $html = [regex]::Replace($html, '<a[^>]*>(.*?)</a>', '$1', [System.Text.RegularExpressions.RegexOptions]'IgnoreCase,Singleline')
    }

    # Convert bold/strong
    $html = [regex]::Replace($html, '<(b|strong)[^>]*>(.*?)</\1>', '**$2**', [System.Text.RegularExpressions.RegexOptions]'IgnoreCase,Singleline')

    # Convert italic/em
    $html = [regex]::Replace($html, '<(i|em)[^>]*>(.*?)</\1>', '*$2*', [System.Text.RegularExpressions.RegexOptions]'IgnoreCase,Singleline')

    # Convert lists
    $html = [regex]::Replace($html, '<li[^>]*>(.*?)</li>', '- $1', [System.Text.RegularExpressions.RegexOptions]'IgnoreCase,Singleline')

    # Convert paragraphs/divs to newlines
    $html = [regex]::Replace($html, '</p>|</div>|<br\s*/?>', "`n`n", [System.Text.RegularExpressions.RegexOptions]'IgnoreCase')

    # Strip remaining tags
    $plainText = [regex]::Replace($html, '<[^>]+>', '')

    # Normalize whitespace
    $plainText = [regex]::Replace($plainText, '\n{3,}', "`n`n").Trim()

    # Apply body width wrapping if needed
    if ($bodyWidth -gt 0) {
        $wrappedLines = @()
        foreach ($line in ($plainText -split "`n")) {
            if ($line.Length -le $bodyWidth) {
                $wrappedLines += $line
            } else {
                $words = $line -split '\s+'
                $currentLine = ""
                foreach ($word in $words) {
                    if (($currentLine.Length + $word.Length + 1) -le $bodyWidth) {
                        if ($currentLine) {
                            $currentLine += " "
                        }
                        $currentLine += $word
                    } else {
                        if ($currentLine) {
                            $wrappedLines += $currentLine
                        }
                        $currentLine = $word
                    }
                }
                if ($currentLine) {
                    $wrappedLines += $currentLine
                }
            }
        }
        $plainText = $wrappedLines -join "`n"
    }

    return $plainText
}

function Read-UrlsFromFile($filePath) {
    $urlsFromFile = @()
    if (Test-Path $filePath) {
        $content = Get-Content -Path $filePath -Encoding UTF8
        foreach ($line in $content) {
            $trimmedLine = $line.Trim()
            if ($trimmedLine -and -not $trimmedLine.StartsWith("#")) {
                $urlsFromFile += $trimmedLine
            }
        }
    }
    return $urlsFromFile
}

function Test-ValidUrl($urlString) {
    try {
        $uri = [System.Uri]::new($urlString)
        return ($uri.Scheme -eq "http" -or $uri.Scheme -eq "https") -and $uri.Host
    } catch {
        return $false
    }
}

function Main() {
    $allUrls = @()
    $allUrls += $Url

    if ($UrlFile) {
        $fileUrls = Read-UrlsFromFile -filePath $UrlFile
        $allUrls += $fileUrls
    }

    # Deduplicate while preserving order
    $uniqueUrls = @()
    $seen = @{}
    foreach ($u in $allUrls) {
        if (-not $seen.ContainsKey($u)) {
            $uniqueUrls += $u
            $seen[$u] = $true
        }
    }

    if ($uniqueUrls.Count -eq 0) {
        $result = @{
            ok = $false
            error = "No URLs provided"
        }
        Write-Output (ConvertTo-Json $result -Depth 10 -Compress)
        exit 1
    }

    foreach ($u in $uniqueUrls) {
        if (-not (Test-ValidUrl $u)) {
            $result = @{
                ok = $false
                error = "Invalid URL: $u"
            }
            Write-Output (ConvertTo-Json $result -Depth 10 -Compress)
            exit 1
        }
    }

    # Ensure output directory exists
    $outDirPath = Resolve-Path $OutputDir -ErrorAction SilentlyContinue
    if (-not $outDirPath) {
        $outDirPath = Join-Path (Get-Location) $OutputDir
        New-Item -ItemType Directory -Path $outDirPath -Force | Out-Null
    } else {
        $outDirPath = $outDirPath.Path
    }

    $results = @()

    foreach ($url in $uniqueUrls) {
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
                -url $url `
                -useJs $Js `
                -waitSelector $WaitSelector `
                -timeoutSeconds $Timeout `
                -automatchDomain $AutomatchDomain

            $page = $fetchResult.Page
            $backend = $fetchResult.Backend

            $mainHtmlResult = Select-MainHtml -page $page -preferredSelector $Selector
            $html = $mainHtmlResult.Html
            $selectorUsed = $mainHtmlResult.SelectorUsed

            if (-not $html) {
                throw "No HTML content extracted from page"
            }

            $title = Get-HtmlTitle -html $html
            if (-not $title) {
                try {
                    $parsedUri = [System.Uri]::new($url)
                    $title = $parsedUri.Host
                } catch {
                    $title = "untitled"
                }
            }

            $markdown = Convert-HtmlToMarkdown `
                -html $html `
                -preserveLinks $PreserveLinks `
                -bodyWidth $BodyWidth

            $filename = "$(Get-Slug("$(([System.Uri]::new($url)).Host)-$title")).md"
            $mdPath = Join-Path $outDirPath $filename
            Set-Content -Path $mdPath -Value $markdown -Encoding UTF8

            $status = if ($page.status) { $page.status } elseif ($page.status_code) { $page.status_code } else { $null }

            $item.ok = $true
            $item.title = $title
            $item.status = $status
            $item.selector_used = $selectorUsed
            $item.backend = $backend
            $item.markdown = $markdown
            $item.preview = if ($markdown.Length -gt 1200) { $markdown.Substring(0, 1200) } else { $markdown }
            $item.output_markdown_file = $mdPath
        } catch {
            $item.error = $_.Exception.Message
        }

        $results += $item
    }

    $anyOk = ($results | Where-Object { $_.ok }).Count -gt 0
    $indexFilePath = Join-Path $outDirPath "index.json"

    $payload = @{
        ok = $anyOk
        count = $results.Count
        success_count = ($results | Where-Object { $_.ok }).Count
        failure_count = ($results | Where-Object { -not $_.ok }).Count
        output_index_file = $indexFilePath
        results = $results
    }

    $jsonPayload = ConvertTo-Json $payload -Depth 10 -EnumsAsStrings
    Set-Content -Path $indexFilePath -Value $jsonPayload -Encoding UTF8
    Write-Output $jsonPayload
}

Main

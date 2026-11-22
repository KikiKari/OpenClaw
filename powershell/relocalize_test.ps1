#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "f3d5576fbd1be573ce1b3aa67b042662d433389cb5f6ee510633fd52a113120b", "source_sha256": "0ea8eb8a8b99710853b26300ab5929582995da3d28a8c027c201b8c2daca6811", "target_language": "powershell"}
# relocalize_test.go — portiert nach powershell
# Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/relocalize_test.go
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

# Helper function to simulate Go's strings.Join
function Join-Lines {
    param(
        [string[]]$Lines
    )
    return ($Lines -join "`n")
}

# Helper function to simulate Go's os.WriteFile
function Write-File {
    param(
        [string]$Path,
        [string]$Content
    )
    $dir = Split-Path $Path -Parent
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    Set-Content -Path $Path -Value $Content -Encoding UTF8
}

# Helper function to simulate Go's os.ReadFile
function Read-File {
    param(
        [string]$Path
    )
    return Get-Content -Path $Path -Raw
}

# Helper function to check if text contains a specific line
function Contains-Line {
    param(
        [string]$Text,
        [string]$Want
    )
    $lines = $Text -split "`n"
    foreach ($line in $lines) {
        if ($line -eq $Want) {
            return $true
        }
    }
    return $false
}

# Mock the postprocessLocalizedDocs function (assuming it exists elsewhere)
function PostprocessLocalizedDocs {
    param(
        [string]$DocsRoot,
        [string]$Lang,
        [string[]]$Files
    )
    # This is a placeholder implementation
    # In a real scenario, this would contain the actual logic
    return $null
}

# Test functions would go here, but PowerShell doesn't have built-in testing like Go
# We'll create a simple test runner instead

function Run-Test {
    param(
        [scriptblock]$TestScript,
        [string]$TestName
    )
    
    try {
        & $TestScript
        Write-Host "PASS: $TestName" -ForegroundColor Green
    }
    catch {
        Write-Host "FAIL: $TestName - $_" -ForegroundColor Red
    }
}

# Test 1: TestPostprocessLocalizedDocsFixesStaleLinksAfterLaterPagesExist
Run-Test {
    param()
    
    $docsRoot = [System.IO.Path]::GetTempPath() + [System.IO.Path]::GetRandomFileName()
    New-Item -ItemType Directory -Path $docsRoot -Force | Out-Null
    
    Write-File -Path "$docsRoot/docs.json" -Content '{"redirects":[]}'
    Write-File -Path "$docsRoot/gateway/index.md" -Content '# Gateway'
    Write-File -Path "$docsRoot/gateway/troubleshooting.md" -Content '# Troubleshooting'
    
    $content1 = Join-Lines @(
        '---'
        'title: 网关'
        'x-i18n:'
        '  source_hash: test'
        '---'
        ''
        'See [Troubleshooting](/gateway/troubleshooting).'
    )
    Write-File -Path "$docsRoot/zh-CN/gateway/index.md" -Content $content1
    
    $content2 = Join-Lines @(
        '---'
        'title: 故障排除'
        'x-i18n:'
        '  source_hash: test'
        '---'
        ''
        '# 故障排除'
    )
    Write-File -Path "$docsRoot/zh-CN/gateway/troubleshooting.md" -Content $content2
    
    $files = @(
        "$docsRoot/zh-CN/gateway/index.md"
        "$docsRoot/zh-CN/gateway/troubleshooting.md"
    )
    
    $err = PostprocessLocalizedDocs -DocsRoot $docsRoot -Lang 'zh-CN' -Files $files
    if ($err) {
        throw "postprocessLocalizedDocs failed: $err"
    }
    
    $got = Read-File -Path "$docsRoot/zh-CN/gateway/index.md"
    $expectedFrontMatter = Join-Lines @(
        '---'
        'title: 网关'
        'x-i18n:'
        '  source_hash: test'
        '---'
        ''
    )
    
    if (-not $got.StartsWith($expectedFrontMatter)) {
        throw "front matter corrupted after rewrite:`n$got"
    }
    
    $want = 'See [Troubleshooting](/zh-CN/gateway/troubleshooting).'
    if (-not (Contains-Line -Text $got -Want $want)) {
        throw "expected rewritten localized link '$want' in output:`n$got"
    }
} 'TestPostprocessLocalizedDocsFixesStaleLinksAfterLaterPagesExist'

# Test 2: TestPostprocessLocalizedDocsRewritesPublishedPageLinksForEachLocale
Run-Test {
    param()
    
    $tests = @(
        @{ name='zh-CN'; lang='zh-CN'; title='网关'; wantPrefix='/zh-CN' }
        @{ name='ja-JP'; lang='ja-JP'; title='ゲートウェイ'; wantPrefix='/ja-JP' }
    )
    
    foreach ($tt in $tests) {
        $docsRoot = [System.IO.Path]::GetTempPath() + [System.IO.Path]::GetRandomFileName()
        New-Item -ItemType Directory -Path $docsRoot -Force | Out-Null
        
        Write-File -Path "$docsRoot/docs.json" -Content '{"redirects":[]}'
        Write-File -Path "$docsRoot/gateway/index.md" -Content '# Gateway'
        Write-File -Path "$docsRoot/gateway/troubleshooting.md" -Content '# Troubleshooting'
        Write-File -Path "$docsRoot/providers/example-provider.md" -Content '# Example provider'
        Write-File -Path "$docsRoot/$($tt.lang)/gateway/troubleshooting.md" -Content '# Localized troubleshooting'
        Write-File -Path "$docsRoot/$($tt.lang)/providers/example-provider.md" -Content '# Localized example provider'
        
        $pagePath = "$docsRoot/$($tt.lang)/gateway/index.md"
        $content = Join-Lines @(
            '---'
            "title: $($tt.title)"
            'x-i18n:'
            '  source_hash: test'
            '---'
            ''
            'See [Troubleshooting](/gateway/troubleshooting).'
            ''
            'See [Example provider](/providers/example-provider).'
            ''
            '<Card href="/gateway/troubleshooting" title="Troubleshooting" />'
            "<Card href=`"$($tt.wantPrefix)/providers/example-provider`" title=`"Example provider`" />"
        )
        Write-File -Path $pagePath -Content $content
        
        $err = PostprocessLocalizedDocs -DocsRoot $docsRoot -Lang $tt.lang -Files @($pagePath)
        if ($err) {
            throw "postprocessLocalizedDocs failed: $err"
        }
        
        $got = Read-File -Path $pagePath
        $expectedLinks = @(
            "See [Troubleshooting]($($tt.wantPrefix)/gateway/troubleshooting)."
            "See [Example provider]($($tt.wantPrefix)/providers/example-provider)."
            "<Card href=`"$($tt.wantPrefix)/gateway/troubleshooting`" title=`"Troubleshooting`" />"
            "<Card href=`"$($tt.wantPrefix)/providers/example-provider`" title=`"Example provider`" />"
        )
        
        foreach ($want in $expectedLinks) {
            if (-not (Contains-Line -Text $got -Want $want)) {
                throw "expected rewritten link '$want' in output:`n$got"
            }
        }
    }
} 'TestPostprocessLocalizedDocsRewritesPublishedPageLinksForEachLocale'

# Test 3: TestPostprocessLocalizedDocsOnlyTouchesScopedFiles
Run-Test {
    param()
    
    $docsRoot = [System.IO.Path]::GetTempPath() + [System.IO.Path]::GetRandomFileName()
    New-Item -ItemType Directory -Path $docsRoot -Force | Out-Null
    
    Write-File -Path "$docsRoot/docs.json" -Content '{"redirects":[]}'
    Write-File -Path "$docsRoot/gateway/troubleshooting.md" -Content '# Troubleshooting'
    Write-File -Path "$docsRoot/zh-CN/gateway/troubleshooting.md" -Content '# 故障排除'
    
    $scopedPath = "$docsRoot/zh-CN/gateway/index.md"
    $unscopedPath = "$docsRoot/zh-CN/help/index.md"
    
    $content1 = Join-Lines @(
        '---'
        'title: 网关'
        '---'
        ''
        'See [Troubleshooting](/gateway/troubleshooting).'
    )
    Write-File -Path $scopedPath -Content $content1
    
    $content2 = Join-Lines @(
        '---'
        'title: 帮助'
        '---'
        ''
        'See [Troubleshooting](/gateway/troubleshooting).'
    )
    Write-File -Path $unscopedPath -Content $content2
    
    $beforeUnscoped = Read-File -Path $unscopedPath
    $err = PostprocessLocalizedDocs -DocsRoot $docsRoot -Lang 'zh-CN' -Files @($scopedPath)
    if ($err) {
        throw "postprocessLocalizedDocs failed: $err"
    }
    
    $gotScoped = Read-File -Path $scopedPath
    if (-not (Contains-Line -Text $gotScoped -Want 'See [Troubleshooting](/zh-CN/gateway/troubleshooting).')) {
        throw "expected scoped file rewrite, got:`n$gotScoped"
    }
    
    $afterUnscoped = Read-File -Path $unscopedPath
    if ($afterUnscoped -ne $beforeUnscoped) {
        throw "expected unscoped file to remain unchanged`nbefore:`n$beforeUnscoped`nafter:`n$afterUnscoped"
    }
} 'TestPostprocessLocalizedDocsOnlyTouchesScopedFiles'

# Test 4: TestPostprocessLocalizedDocsContinuesAfterUnchangedFile
Run-Test {
    param()
    
    $docsRoot = [System.IO.Path]::GetTempPath() + [System.IO.Path]::GetRandomFileName()
    New-Item -ItemType Directory -Path $docsRoot -Force | Out-Null
    
    Write-File -Path "$docsRoot/docs.json" -Content '{"redirects":[]}'
    Write-File -Path "$docsRoot/gateway/troubleshooting.md" -Content '# Troubleshooting'
    Write-File -Path "$docsRoot/zh-CN/gateway/troubleshooting.md" -Content '# 故障排除'
    
    $unchangedPath = "$docsRoot/zh-CN/gateway/already-localized.md"
    $needsRewritePath = "$docsRoot/zh-CN/gateway/index.md"
    
    $content1 = Join-Lines @(
        '---'
        'title: 已本地化'
        '---'
        ''
        'See [Troubleshooting](/zh-CN/gateway/troubleshooting).'
    )
    Write-File -Path $unchangedPath -Content $content1
    
    $content2 = Join-Lines @(
        '---'
        'title: 网关'
        '---'
        ''
        'See [Troubleshooting](/gateway/troubleshooting).'
    )
    Write-File -Path $needsRewritePath -Content $content2
    
    $err = PostprocessLocalizedDocs -DocsRoot $docsRoot -Lang 'zh-CN' -Files @($unchangedPath, $needsRewritePath)
    if ($err) {
        throw "postprocessLocalizedDocs failed: $err"
    }
    
    $got = Read-File -Path $needsRewritePath
    if (-not (Contains-Line -Text $got -Want 'See [Troubleshooting](/zh-CN/gateway/troubleshooting).')) {
        throw "expected later file rewrite after unchanged file, got:`n$got"
    }
} 'TestPostprocessLocalizedDocsContinuesAfterUnchangedFile'

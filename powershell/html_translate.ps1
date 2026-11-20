#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "0978e782d61d5bfcb5285b6270a487f22be04a842611cd8f558004b3136efa05", "source_sha256": "04efde297083102c20b5caf33f76d4e5638a8f6b50c3d7c5e9b15e889a91b227", "target_language": "powershell"}
# html_translate.go — portiert nach powershell
# Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/html_translate.go
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
    Translates HTML content within Markdown while preserving structure.
.DESCRIPTION
    This script parses Markdown to identify HTML blocks, then translates the text nodes
    inside those blocks while skipping tags like <code>, <pre>, <script>, and <style>.
.PARAMETER Body
    The Markdown body containing HTML blocks to translate.
.PARAMETER SourceLanguage
    The source language code (e.g., 'en').
.PARAMETER TargetLanguage
    The target language code (e.g., 'de').
.PARAMETER Translator
    A scriptblock implementing translation logic with parameters: Text, SourceLang, TargetLang.
.EXAMPLE
    $translateFunc = {
        param($text, $srcLang, $tgtLang)
        # Simulate translation
        return "[$text -> $tgtLang]"
    }
    .\html_translate.ps1 -Body "# Hello`n`n<div>World</div>" -SourceLanguage "en" -TargetLanguage "de" -Translator $translateFunc
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Body,

    [Parameter(Mandatory = $true)]
    [string]$SourceLanguage,

    [Parameter(Mandatory = $true)]
    [string]$TargetLanguage,

    [Parameter(Mandatory = $true)]
    [ScriptBlock]$Translator
)

# Requires PowerShell 7+
# No external dependencies beyond standard .NET capabilities

class HtmlReplacement {
    [int]$Start
    [int]$Stop
    [string]$Value

    HtmlReplacement([int]$start, [int]$stop, [string]$value) {
        $this.Start = $start
        $this.Stop = $stop
        $this.Value = $value
    }
}

function Translate-HtmlBlocks {
    param(
        [string]$body,
        [string]$srcLang,
        [string]$tgtLang,
        [scriptblock]$translator
    )

    # In PowerShell we don't have GoldMark or AST parsing for Markdown easily.
    # So instead, we'll use regex-based approach to find HTML blocks.
    # This is a simplified version that matches basic HTML block patterns.

    $replacements = @()
    $pattern = '(?sm)(<(?:div|section|article|aside|nav|header|footer|blockquote|details|dialog|summary|figure|figcaption|h\d|p|ul|ol|li|dl|dt|dd|table|thead|tbody|tfoot|tr|th|td|form|fieldset|legend|label|input|select|option|textarea|button|canvas|audio|video|iframe|embed|object|param|source|track|svg|math)[^>]*>.*?</\2>|<(?:br|hr|img|input|meta|link|area|base|col|command|embed|keygen|param|source|track|wbr)\s*/?>)'
    
    # Find all HTML blocks using regex
    $matches = [regex]::Matches($body, $pattern)
    foreach ($match in $matches) {
        $startIndex = $match.Index
        $length = $match.Length
        $htmlText = $match.Value
        
        try {
            $translated = Translate-HtmlBlock -htmlText $htmlText -srcLang $srcLang -tgtLang $tgtLang -translator $translator
            $replacements += [HtmlReplacement]::new($startIndex, $startIndex + $length, $translated)
        } catch {
            Write-Error "Failed translating HTML block at index $startIndex`: $_"
            throw
        }
    }

    if ($replacements.Count -eq 0) {
        return $body
    }

    return Apply-HtmlReplacements -body $body -replacements $replacements
}

function Apply-HtmlReplacements {
    param(
        [string]$body,
        [HtmlReplacement[]]$replacements
    )

    if ($replacements.Count -eq 0) {
        return $body
    }

    # Sort by Start position ascending
    $sorted = $replacements | Sort-Object Start
    
    $out = New-Object System.Text.StringBuilder
    $last = 0

    foreach ($rep in $sorted) {
        if ($rep.Start -lt $last) {
            continue
        }
        $before = $body.Substring($last, $rep.Start - $last)
        $out.Append($before) | Out-Null
        $out.Append($rep.Value) | Out-Null
        $last = $rep.Stop
    }

    $finalPart = $body.Substring($last)
    $out.Append($finalPart) | Out-Null

    return $out.ToString()
}

function Translate-HtmlBlock {
    param(
        [string]$htmlText,
        [string]$srcLang,
        [string]$tgtLang,
        [scriptblock]$translator
    )

    # Use .NET's HtmlReader equivalent via regex/tokenization simulation
    # For simplicity here, parse manually without full tokenizer

    $tokens = Parse-HtmlTokens -htmlText $htmlText
    $output = New-Object System.Text.StringBuilder
    $skipDepth = 0

    foreach ($token in $tokens) {
        switch ($token.Type) {
            'StartTag' {
                $output.Append($token.Raw) | Out-Null
                if (Is-SkipTag -tag $token.TagName) {
                    $skipDepth++
                }
            }
            'EndTag' {
                $output.Append($token.Raw) | Out-Null
                if (Is-SkipTag -tag $token.TagName -and $skipDepth -gt 0) {
                    $skipDepth--
                }
            }
            'SelfClosingTag' {
                $output.Append($token.Raw) | Out-Null
            }
            'Text' {
                if (Should-TranslateHtmlText -skipDepth $skipDepth -text $token.Text) {
                    try {
                        $translated = & $translator $token.Text $srcLang $tgtLang
                        $output.Append($translated) | Out-Null
                    } catch {
                        throw "Translation failed for text '$($token.Text)': $_"
                    }
                } else {
                    $output.Append($token.Raw) | Out-Null
                }
            }
            default {
                $output.Append($token.Raw) | Out-Null
            }
        }
    }

    return $output.ToString()
}

function Parse-HtmlTokens {
    param([string]$htmlText)

    # Very basic parser/tokenizer for demonstration purposes only
    # Real implementation would require more robust parsing

    $tokens = @()
    $pattern = '(?si)(<[^>]+>)|([^<]+)'
    $matches = [regex]::Matches($htmlText, $pattern)

    foreach ($m in $matches) {
        if ($m.Groups[1].Success) {
            $raw = $m.Groups[1].Value
            if ($raw -match '^<(\w+).*?/>$') {
                $tokens += @{
                    Type = 'SelfClosingTag'
                    Raw = $raw
                    TagName = $matches[1].Groups[1].Value.ToLower()
                }
            } elseif ($raw -match '^</(\w+)>$') {
                $tokens += @{
                    Type = 'EndTag'
                    Raw = $raw
                    TagName = $matches[1].Groups[1].Value.ToLower()
                }
            } elseif ($raw -match '^<(\w+)') {
                $tagName = $matches[1].Groups[1].Value.ToLower()
                $tokens += @{
                    Type = 'StartTag'
                    Raw = $raw
                    TagName = $tagName
                }
            } else {
                $tokens += @{
                    Type = 'UnknownTag'
                    Raw = $raw
                }
            }
        } elseif ($m.Groups[2].Success) {
            $text = $m.Groups[2].Value
            $tokens += @{
                Type = 'Text'
                Raw = $text
                Text = $text
            }
        }
    }

    return $tokens
}

function Should-TranslateHtmlText {
    param(
        [int]$skipDepth,
        [string]$text
    )
    if ([string]::IsNullOrWhiteSpace($text.Trim())) {
        return $false
    }
    return $skipDepth -eq 0
}

function Is-SkipTag {
    param([string]$tag)
    $skipTags = @('code', 'pre', 'script', 'style')
    return $skipTags -contains $tag
}

# Main execution
try {
    $result = Translate-HtmlBlocks -body $Body -srcLang $SourceLanguage -tgtLang $TargetLanguage -translator $Translator
    Write-Output $result
} catch {
    Write-Error "Translation process failed: $_"
    exit 1
}

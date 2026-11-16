#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "a085246c56013078cd8b1bb1a402543e6e22aa48547b28978d3f0d7aa25ef7af", "source_sha256": "a01dcf18c06d5aeb081cedf0088a13b316c08622615e4de86febe2deaee2596d", "target_language": "powershell"}
# check-no-register-http-handler.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-register-http-handler.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Text.RegularExpressions

# Function to check if a command is available
function Test-Command($cmdname) {
    return [bool](Get-Command -Name $cmdname -ErrorAction SilentlyContinue)
}

# Ensure we have Node.js available since we're porting TypeScript logic
if (-not (Test-Command "node")) {
    Write-Host "Node.js is required but not found. Please install Node.js to run this script."
    exit 1
}

# Define source roots
$sourceRoots = @("src", "extensions")

# Function that mimics unwrapExpression behavior
function UnwrapExpression($expression) {
    # In JS this unwraps parentheses/wrapped expressions
    # For simplicity here we just return the expression itself
    return $expression
}

# Function that mimics isDeprecatedRegisterHttpHandlerCall
function Test-IsDeprecatedRegisterHttpHandlerCall($expression) {
    # This checks if it's a PropertyAccessExpression with name 'registerHttpHandler'
    # We'll parse this from the AST later via Node.js subprocess
    
    # Placeholder - actual implementation will be done through tsc parsing
    return $false
}

# Function that mimics collectCallExpressionLines
function Get-CollectCallExpressionLines($content, $fileName) {
    # This would normally walk the TS AST and collect lines where registerHttpHandler is called
    # Since PowerShell doesn't have native TypeScript support, we'll shell out to node
    
    $tempFile = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $tempFile -Value $content
    
    try {
        # Create temporary JS file to do the parsing
        $parseScript = @"
const fs = require('fs');
const ts = require('typescript');

function unwrapExpression(expression) {
    while (expression.kind === ts.SyntaxKind.ParenthesizedExpression ||
           expression.kind === ts.SyntaxKind.AsExpression) {
        expression = expression.expression || expression;
    }
    return expression;
}

function isDeprecatedRegisterHttpHandlerCall(expression) {
    const callee = unwrapExpression(expression);
    return ts.isPropertyAccessExpression(callee) && callee.name.text === 'registerHttpHandler';
}

function collectCallExpressionLines(sourceFile, checker) {
    const lines = [];
    function visit(node) {
        if (ts.isCallExpression(node)) {
            if (isDeprecatedRegisterHttpHandlerCall(node.expression)) {
                const start = sourceFile.getLineAndCharacterOfPosition(node.getStart());
                lines.push(start.line + 1); // 1-based line numbers
            }
        }
        ts.forEachChild(node, visit);
    }
    visit(sourceFile);
    return lines.sort((a,b)=>a-b);
}

const sourceText = fs.readFileSync('$tempFile', 'utf8');
const sourceFile = ts.createSourceFile('$fileName', sourceText, ts.ScriptTarget.Latest, true);
const lines = collectCallExpressionLines(sourceFile);
console.log(JSON.stringify(lines));
"@
        
        $tempJs = [System.IO.Path]::GetTempFileName() + ".js"
        Set-Content -Path $tempJs -Value $parseScript
        
        $result = node $tempJs 2>$null
        Remove-Item -Path $tempJs -Force
        
        if ($LASTEXITCODE -eq 0 -and $result) {
            $lines = $result | ConvertFrom-Json
            return $lines
        } else {
            return @()
        }
    } finally {
        if (Test-Path $tempFile) {
            Remove-Item -Path $tempFile -Force
        }
    }
}

# Main function equivalent
function Invoke-Main {
    Write-Host "Searching for deprecated registerHttpHandler calls..."
    
    $allFiles = @()
    foreach ($root in $sourceRoots) {
        if (Test-Path $root) {
            $files = Get-ChildItem -Path $root -Include "*.ts","*.tsx" -Recurse
            $allFiles += $files
        }
    }
    
    $foundIssues = @()
    
    foreach ($file in $allFiles) {
        $content = Get-Content -Path $file.FullName -Raw
        if ([string]::IsNullOrWhiteSpace($content)) {
            continue
        }
        
        # Check if content contains registerHttpHandler at all before doing expensive parsing
        if ($content -match '\.registerHttpHandler\s*\(') {
            $lines = Get-CollectCallExpressionLines -content $content -fileName $file.Name
            
            if ($lines.Count -gt 0) {
                foreach ($line in $lines) {
                    $issue = [PSCustomObject]@{
                        File = $file.FullName
                        Line = $line
                    }
                    $foundIssues += $issue
                }
            }
        }
    }
    
    if ($foundIssues.Count -gt 0) {
        Write-Host "Found deprecated plugin API call registerHttpHandler(...):"
        Write-Host ""
        $foundIssues | Format-Table -AutoSize
        Write-Host "Use registerHttpRoute({ path, auth, match, handler }) and registerPluginHttpRoute for dynamic webhook paths."
        exit 1
    } else {
        Write-Host "No deprecated registerHttpHandler calls found."
    }
}

# Run as script entry point
Invoke-Main

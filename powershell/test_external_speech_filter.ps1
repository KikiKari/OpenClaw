#!/usr/bin/env pwsh
# test_external_speech_filter.cjs — portiert nach powershell
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_external_speech_filter.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

# Import necessary modules
using module ./browser-extension/content-core.psm1

# Helper function to mimic node's assert.equal
function Assert-Equal {
    param(
        $Actual,
        $Expected,
        [string]$Message = ""
    )
    
    if ($Actual -ne $Expected) {
        throw "Assertion failed: Expected '$Expected', but got '$Actual'. $Message"
    }
}

# Test cases for shouldFilterExternalSpeechTrigger
foreach ($enabled in @($false, $true)) {
    foreach ($text in @('.Text', '. Text', '  .Text', "`t`n. Text", 'Normal', 'Ein Satz. Noch einer', '')) {
        $testName = "{enabled:$enabled,text:'$text'}"
        try {
            $result = shouldFilterExternalSpeechTrigger -text $text -enabled $enabled
            $expected = $enabled -and $text.TrimStart().StartsWith('.')
            Assert-Equal -Actual $result -Expected $expected -Message "Test: $testName"
            Write-Host "PASS: $testName"
        }
        catch {
            Write-Error "FAIL: $testName - $_"
        }
    }
}

# 0PE-187: individual literal prefixes, commas and semicolons are not separators
foreach ($enabled in @($false, $true)) {
    # Test cases where filter should return true when enabled
    foreach ($text in @('.Hallo', ',Hallo', '- Hallo', '  , Hallo')) {
        try {
            $result = shouldFilterExternalSpeechTrigger -text $text -enabled $enabled -prefixes '.,-'
            Assert-Equal -Actual $result -Expected $enabled -Message "Prefix test with '$text'"
            Write-Host "PASS: Prefix test with '$text' (enabled=$enabled)"
        }
        catch {
            Write-Error "FAIL: Prefix test with '$text' (enabled=$enabled) - $_"
        }
    }

    # Test cases where filter should return false
    foreach ($text in @('Hallo, zusammen.', 'Normal-Text', 'Hallo', '.')) {
        try {
            $result = shouldFilterExternalSpeechTrigger -text $text -enabled $enabled -prefixes ',-'
            Assert-Equal -Actual $result -Expected $false -Message "Non-prefix test with '$text'"
            Write-Host "PASS: Non-prefix test with '$text' (enabled=$enabled)"
        }
        catch {
            Write-Error "FAIL: Non-prefix test with '$text' (enabled=$enabled) - $_"
        }
    }

    # Semicolon test
    try {
        $result = shouldFilterExternalSpeechTrigger -text ';Hallo' -enabled $enabled -prefixes ';'
        Assert-Equal -Actual $result -Expected $enabled -Message "Semicolon test"
        Write-Host "PASS: Semicolon test (enabled=$enabled)"
    }
    catch {
        Write-Error "FAIL: Semicolon test (enabled=$enabled) - $_"
    }

    # Bracket tests
    try {
        $result = shouldFilterExternalSpeechTrigger -text '[Hallo' -enabled $enabled -prefixes '['
        Assert-Equal -Actual $result -Expected $enabled -Message "Bracket start test"
        Write-Host "PASS: Bracket start test (enabled=$enabled)"
    }
    catch {
        Write-Error "FAIL: Bracket start test (enabled=$enabled) - $_"
    }

    try {
        $result = shouldFilterExternalSpeechTrigger -text 'Hallo' -enabled $enabled -prefixes '['
        Assert-Equal -Actual $result -Expected $false -Message "Non-bracket test"
        Write-Host "PASS: Non-bracket test (enabled=$enabled)"
    }
    catch {
        Write-Error "FAIL: Non-bracket test (enabled=$enabled) - $_"
    }
}

# 0PE-187: five Unicode scalar triggers, paste sanitization and explicit empty selection
try {
    # Test normalize function
    Assert-Equal -Actual (normalizeExternalSpeechTriggerCharacters -text $null) -Expected '.' -Message "Normalize undefined"
    Assert-Equal -Actual (normalizeExternalSpeechTriggerCharacters -text '') -Expected '' -Message "Normalize empty string"
    Assert-Equal -Actual (normalizeExternalSpeechTriggerCharacters -text '.,-;:!' ) -Expected '.,-;:' -Message "Normalize multiple chars"
    Assert-Equal -Actual (normalizeExternalSpeechTriggerCharacters -text ' a1 "''.,- ') -Expected '.,-' -Message "Normalize with spaces and quotes"
    Assert-Equal -Actual (normalizeExternalSpeechTriggerCharacters -text '😀😁😂😃😄😅') -Expected '😀😁😂😃😄' -Message "Normalize Unicode scalars"
    
    Write-Host "PASS: Normalize tests"

    # Test filter with Unicode prefix
    $result = shouldFilterExternalSpeechTrigger -text '😀Hallo' -enabled $true -prefixes '😀'
    Assert-Equal -Actual $result -Expected $true -Message "Unicode prefix filter test"
    Write-Host "PASS: Unicode prefix filter test"

    # Test filter with empty prefix
    $result = shouldFilterExternalSpeechTrigger -text '.Hallo' -enabled $true -prefixes ''
    Assert-Equal -Actual $result -Expected $false -Message "Empty prefix filter test"
    Write-Host "PASS: Empty prefix filter test"

    # Test filter with different prefix
    $result = shouldFilterExternalSpeechTrigger -text '.Hallo' -enabled $true -prefixes ','
    Assert-Equal -Actual $result -Expected $false -Message "Different prefix filter test"
    Write-Host "PASS: Different prefix filter test"
}
catch {
    Write-Error "FAIL: Normalization and Unicode tests - $_"
}

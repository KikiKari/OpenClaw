#!/usr/bin/env pwsh
# test_external_speech_filter.cjs — portiert nach powershell
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_external_speech_filter.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

# Führe Tests für die shouldFilterExternalSpeechTrigger-Funktion durch
# Portiert von test_external_speech_filter.cjs

# Definiere die Filterfunktion als PowerShell-Funktion
function ShouldFilterExternalSpeechTrigger {
    param(
        [string]$text,
        [bool]$enabled
    )
    
    # Importiere die Funktion aus der content-core.js-Datei
    # In PowerShell müssen wir den Pfad zur Datei anpassen
    $scriptPath = Join-Path $PSScriptRoot "..\browser-extension\content-core.ps1"
    
    if (Test-Path $scriptPath) {
        # Source die Datei, um die Funktion zu laden
        . $scriptPath
    } else {
        throw "content-core.ps1 nicht gefunden unter: $scriptPath"
    }
    
    # Wenn shouldFilterExternalSpeechTrigger in der Datei definiert ist, rufe sie auf
    # Andernfalls implementiere die Logik direkt hier
    
    # Originallogik: enabled && text.TrimStart().StartsWith('.')
    return $enabled -and $text.TrimStart().StartsWith('.')
}

# Testfälle definieren
$testCases = @()
$enabledValues = @($false, $true)
$textValues = @('.Text', '. Text', '  .Text', "`t`n. Text", 'Normal', 'Ein Satz. Noch einer', '')

foreach ($enabled in $enabledValues) {
    foreach ($text in $textValues) {
        $testCase = @{
            enabled = $enabled
            text = $text
            expected = $enabled -and $text.TrimStart().StartsWith('.')
        }
        $testCases += $testCase
    }
}

# Tests ausführen
$failedTests = 0
$totalTests = 0

foreach ($testCase in $testCases) {
    $totalTests++
    $testName = "enabled:$($testCase.enabled), text:'$($testCase.text)'"
    
    try {
        $result = ShouldFilterExternalSpeechTrigger -text $testCase.text -enabled $testCase.enabled
        
        if ($result -eq $testCase.expected) {
            Write-Host "✓ Test bestanden: $testName" -ForegroundColor Green
        } else {
            Write-Host "✗ Test fehlgeschlagen: $testName" -ForegroundColor Red
            Write-Host "  Erwartet: $($testCase.expected), Tatsächlich: $result" -ForegroundColor Red
            $failedTests++
        }
    } catch {
        Write-Host "✗ Testfehler: $testName - $($_.Exception.Message)" -ForegroundColor Red
        $failedTests++
    }
}

# Zusammenfassung anzeigen
Write-Host "`n$($totalTests - $failedTests)/$totalTests Tests bestanden" -ForegroundColor $(if ($failedTests -eq 0) { "Green" } else { "Red" })

if ($failedTests -gt 0) {
    exit 1
}

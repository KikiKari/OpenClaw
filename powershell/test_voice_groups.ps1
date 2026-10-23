#!/usr/bin/env pwsh
# test_voice_groups.cjs — portiert nach powershell
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_voice_groups.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_voice_groups.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_voice_groups.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_voice_groups.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

# Helper function to mimic DOM element creation
function CreateElement {
    param($tag)
    return @{
        tag      = $tag
        children = @()
        dataset  = @{}
        value    = ''
        Append   = {
            param($node)
            $this.children += $node
        }
    }
}

# Read files
$sourcePath = Join-Path $PSScriptRoot "../browser-extension/sidepanel.js"
$catalogPath = Join-Path $PSScriptRoot "../companion-service/voice-catalog.json"

$source = Get-Content -Path $sourcePath -Raw -Encoding UTF8
$voicesData = Get-Content -Path $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
$voices = $voicesData.voices

# Create mock DOM elements
$select = CreateElement "select"

# Create execution context with necessary variables
$context = @{
    document          = @{ createElement = ${function:CreateElement} }
    elements          = @{ 'speech-voice' = $select }
    speechVoiceName   = 'sherpa-de-supertonic-7'
    voiceCatalog      = $voices
    clearChildren     = {
        param($node)
        $node.children = @()
    }
}

# Extract and execute relevant JavaScript code portions
$startPos1 = $source.IndexOf('  const BASE_VOICE_ORDER')
$endPos1 = $source.IndexOf('  const core =')
$code1 = $source.Substring($startPos1, $endPos1 - $startPos1)

$startPos2 = $source.IndexOf('  function sherpaSpeechVoices')
$endPos2 = $source.IndexOf('  async function loadSpeechVoices')
$code2 = $source.Substring($startPos2, $endPos2 - $startPos2)

# Execute the extracted JavaScript code in PowerShell context
Invoke-Expression $code1
Invoke-Expression $code2

# Call setSpeechVoiceOptions with initial data
setSpeechVoiceOptions @() $voices

# Assertions for group existence and minimum child count
foreach ($label in @('Kyrillisch', 'Asiatisch', 'Abjad', 'Indisch', 'Effekt Stimmen')) {
    $group = $select.children | Where-Object { $_.label -eq $label }
    if (-not $group) {
        throw "FAIL: Group '$label' not found"
    }
    if ($group.children.Count -lt 3) {
        throw "FAIL: Group '$label' has less than 3 children"
    }
}

# Specific assertions for 'Effekt Stimmen' group
$effectGroup = $select.children | Where-Object { $_.label -eq 'Effekt Stimmen' }
if ($effectGroup.children.Count -ne 5) {
    throw "FAIL: 'Effekt Stimmen' group should have exactly 5 children"
}
if ($select.value -ne 'sherpa-de-supertonic-7') {
    throw "FAIL: Expected select.value to be 'sherpa-de-supertonic-7'"
}

# Test updating options while retaining selection
setSpeechVoiceOptions @(@{id='sherpa-de-supertonic-7'; name='Stil 3'; group=''}) $voices
if ($select.value -ne 'sherpa-de-supertonic-7') {
    throw "FAIL: Selection was not retained after update"
}

$selectedOption = $effectGroup.children | Where-Object { $_.value -eq $select.value }
if (-not $selectedOption) {
    throw "FAIL: Selected option is not present in 'Effekt Stimmen' group"
}

# Test legacy catalog fallback behavior
$context.speechVoiceName = 'sherpa-ru-irina'
$newVoices = $voices | ForEach-Object { 
    $newVoice = $_.PSObject.Copy()
    $newVoice.PSObject.Properties.Remove('group')
    $newVoice
}
setSpeechVoiceOptions @() $newVoices
if ($select.value -ne 'sherpa-ru-irina') {
    throw "FAIL: Legacy catalog fallback failed"
}

$russianGroup = $select.children | Where-Object { $_.label -eq 'Kyrillisch' }
$russianOption = $russianGroup.children | Where-Object { $_.value -eq 'sherpa-ru-irina' }
if (-not $russianOption) {
    throw "FAIL: Russian voice option not found in Kyrillisch group"
}

Write-Host "PASS: five groups, all styles selectable, retained selection, legacy catalog fallback"

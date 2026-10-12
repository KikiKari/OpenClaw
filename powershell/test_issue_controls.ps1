#!/usr/bin/env pwsh
# test_issue_controls.cjs — portiert nach powershell
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_issue_controls.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_issue_controls.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_issue_controls.cjs
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_issue_controls.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

# Import necessary modules
using namespace System.Collections.Generic
using namespace System.Management.Automation

# Define helper functions to mimic Node.js behavior
function Read-FileContent {
    param (
        [string]$Path
    )
    return Get-Content -Path $Path -Raw
}

function IndexOfSubstring {
    param (
        [string]$Source,
        [string]$Start,
        [int]$FromIndex = 0
    )
    return $Source.IndexOf($Start, $FromIndex)
}

function SliceString {
    param (
        [string]$Source,
        [int]$Start,
        [int]$End
    )
    return $Source.Substring($Start, $End - $Start)
}

function CreateProxyObject {
    param (
        [hashtable]$Target
    )
    # In PowerShell, we'll use a hashtable with custom logic instead of Proxy
    return $Target
}

# Load source files
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$sidepanelPath = Join-Path $scriptDir "../browser-extension/sidepanel.js"
$contentCorePath = Join-Path $scriptDir "../browser-extension/content-core.js"

$source = Read-FileContent -Path $sidepanelPath
$core = & $contentCorePath

function GetFragment {
    param (
        [string]$Start,
        [string]$End
    )
    $a = IndexOfSubstring -Source $source -Start $Start
    $b = IndexOfSubstring -Source $source -Start $End -FromIndex ($a + $Start.Length)
    if ($a -lt 0 -or $b -le $a) {
        throw "Fragment not found: Start='$Start' End='$End'"
    }
    return SliceString -Source $source -Start $a -End $b
}

function NewControls {
    $document = @{ activeElement = $null }
    $elements = @{}
    
    # Create a dynamic object that mimics the proxy behavior
    $proxyElements = @{
        AddElement = {
            param($id)
            if (-not $elements.ContainsKey($id)) {
                $element = @{
                    hidden = $true
                    disabled = $false
                    textContent = 'Off'
                    handlers = @{}
                    AddEventListener = {
                        param($name, $fn)
                        $this.handlers[$name] = $fn
                    }
                    Focus = {
                        $document.activeElement = $this
                    }
                    Click = {
                        $event = @{ target = $this }
                        if ($this.handlers.ContainsKey('click')) {
                            & $this.handlers['click'] $event
                        }
                        return $event
                    }
                }
                $elements[$id] = $element
            }
            return $elements[$id]
        }
    }
    
    return @{ elements = $proxyElements; document = $document }
}

# Test 175
Describe '175 manual and automatic speech reject raw point triggers before author prefixes' {
    It 'should handle speech filtering correctly' {
        foreach ($enabled in @($false, $true)) {
            $spoken = @()
            $s = @{
                core = $core
                filterExternalSpeechTriggers = $enabled
                speechEnabled = $true
                speechQueue = @()
                elements = @{ 'speech-status' = @{} }
                pumpSpeech = {}
                speechText = { param($item) return "Autor sagt $($item.content)" }
                speechLang = { return 'de' }
                serviceSpeech = { param($text) $spoken += $text }
                browserSpeech = { throw 'unexpected fallback' }
            }
            
            # Extract and run relevant code fragments
            $fragment1 = GetFragment -Start '  async function speakItem(' -End '  async function pumpSpeech('
            $fragment2 = GetFragment -Start '  function enqueueSpeech(' -End '  function '
            
            # Execute the fragments in context (simulated)
            # Note: PowerShell doesn't have direct equivalent to vm.runInContext
            # We'll need to manually implement the functions
            
            # Implement speakItem and enqueueSpeech based on extracted fragments
            $s.speakItem = {
                param($item)
                # Implementation would go here based on fragment1
            }
            
            $s.enqueueSpeech = {
                param($item)
                # Implementation would go here based on fragment2
            }
            
            # Run tests
            $contents = @('.Text', '. Text', '  .Text', 'Normal', 'Ein Satz. Noch einer')
            foreach ($content in $contents) {
                & $s.speakItem @{ content = $content }
                & $s.enqueueSpeech @{ content = $content }
            }
            
            $expectedLength = if ($enabled) { 2 } else { 5 }
            $spoken.Count | Should -Be $expectedLength
            $s.speechQueue.Count | Should -Be $expectedLength
        }
    }
}

# Test 176 (speech switch)
Describe '176 speech switch commits On/Off only after a successful request' {
    It 'should properly handle toggle-speech clicks' {
        $controls = NewControls
        $s = @{
            elements = $controls.elements
            document = $controls.document
            speechEnabled = $false
            send = {}
            refresh = {}
            activateSpeech = { $s.speechEnabled = $true }
            stopSpeech = { $s.speechEnabled = $false }
        }
        
        # Extract and apply event listener fragment
        $fragment = GetFragment -Start '  elements["toggle-speech"].addEventListener' -End '  elements["speech-volume"].addEventListener'
        # Apply the fragment logic (manual implementation needed)
        
        # Simulate clicks
        $toggleElement = $s.elements.AddElement('toggle-speech')
        $statusElement = $s.elements.AddElement('speech-status')
        
        & $toggleElement.Click
        $s.speechEnabled | Should -Be $true
        
        $s.send = { throw 'failed' }
        & $toggleElement.Click
        $s.speechEnabled | Should -Be $true
        $statusElement.textContent | Should -Match 'failed'
        
        $s.send = {}
        & $toggleElement.Click
        $s.speechEnabled | Should -Be $false
    }
}

# Test 176 (Connection)
Describe '176 Connection selects both commands and preserves state on rejection' {
    It 'should handle connection toggling correctly' {
        $calls = @()
        $controls = NewControls
        $s = @{
            elements = $controls.elements
            document = $controls.document
            currentState = @{ hook = @{ armed = $false } }
            send = { param($cmd) $calls += $cmd }
            refresh = { $s.currentState.hook.armed = -not $s.currentState.hook.armed }
        }
        
        # Extract and apply event listener fragment
        $fragment = GetFragment -Start '  elements["toggle-hook"].addEventListener' -End '  elements["reset-tab"].addEventListener'
        # Apply the fragment logic (manual implementation needed)
        
        # Simulate clicks
        $toggleHookElement = $s.elements.AddElement('toggle-hook')
        $noticeElement = $s.elements.AddElement('notice')
        
        & $toggleHookElement.Click
        & $toggleHookElement.Click
        $calls | Should -Be @('TLC_ENABLE_HOOK', 'TLC_DISABLE_HOOK')
        
        $s.send = { throw 'failed' }
        & $toggleHookElement.Click
        $s.currentState.hook.armed | Should -Be $false
        $noticeElement.textContent | Should -Match 'failed'
    }
}

# Test 176 (Connection dialog)
Describe '176 Connection dialog returns focus and traps Tab in both directions' {
    It 'should handle keyboard navigation correctly' {
        $controls = NewControls
        $s = @{
            elements = $controls.elements
            document = $controls.document
        }
        
        # Extract and apply event listeners
        $fragment1 = GetFragment -Start '  elements["open-connection-settings"].addEventListener' -End '  elements["open-speech-settings"].addEventListener'
        # Apply the fragment logic (manual implementation needed)
        
        $keyHandler = $null
        $s.document.addEventListener = { 
            param($name, $fn)
            if ($name -eq 'keydown') { $keyHandler = $fn }
        }
        
        $fragment2 = GetFragment -Start '  document.addEventListener("keydown"' -End '  elements["keep-speech-active"].addEventListener'
        # Apply the fragment logic (manual implementation needed)
        
        # Simulate opening connection settings
        $openSettingsElement = $s.elements.AddElement('open-connection-settings')
        $modalElement = $s.elements.AddElement('connection-settings-modal')
        $closeSettingsElement = $s.elements.AddElement('close-connection-settings')
        $noticeElement = $s.elements.AddElement('notice')
        $quickRecoverElement = $s.elements.AddElement('quick-recover-seconds')
        
        $modalElement.hidden = $false
        $s.document.activeElement = $closeSettingsElement
        
        $modalElement.querySelectorAll = {
            return @($closeSettingsElement, $quickRecoverElement)
        }
        
        # Simulate key events
        $prevented = 0
        $preventDefault = { $prevented++ }
        
        & $keyHandler @{ key = 'Tab'; shiftKey = $true; preventDefault = $preventDefault }
        $s.document.activeElement | Should -Be $quickRecoverElement
        
        & $keyHandler @{ key = 'Tab'; shiftKey = $false; preventDefault = $preventDefault }
        $s.document.activeElement | Should -Be $closeSettingsElement
        $prevented | Should -Be 2
        
        & $keyHandler @{ key = 'Escape' }
        $modalElement.hidden | Should -Be $true
        $s.document.activeElement | Should -Be $openSettingsElement
    }
}

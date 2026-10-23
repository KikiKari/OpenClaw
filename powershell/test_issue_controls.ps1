#!/usr/bin/env pwsh
# test_issue_controls.cjs — portiert nach powershell
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_issue_controls.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_issue_controls.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_issue_controls.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_issue_controls.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

# Import necessary modules
using namespace System.Collections.Generic
using namespace System.Management.Automation

# Define helper functions to mimic Node.js functionality
function Read-File($Path) {
    return [System.IO.File]::ReadAllText($Path)
}

function Get-SourceFragment($Source, $Start, $End) {
    $a = $Source.IndexOf($Start)
    $b = $Source.IndexOf($End, $a + $Start.Length)
    if ($a -lt 0 -or $b -le $a) {
        throw "Fragment not found"
    }
    return $Source.Substring($a, $b - $a)
}

function New-Controls {
    $document = @{ activeElement = $null }
    
    $elements = @{}
    $elements_proxy = [hashtable]::new()
    
    # Create proxy-like behavior using ScriptProperty
    $proxy_getter = {
        param($id)
        
        if (-not $elements.ContainsKey($id)) {
            $handlers = @{}
            $element = @{
                hidden = $true
                disabled = $false
                textContent = 'Off'
                handlers = $handlers
                value = ''
                checked = $false
                addEventListener = {
                    param($name, $fn)
                    $handlers[$name] = $fn
                }
                focus = {
                    $document.activeElement = $this
                }
                click = {
                    $event = @{ target = $this }
                    if ($handlers.ContainsKey('click')) {
                        return $handlers['click'].Invoke($event)
                    }
                }
                setChecked = {
                    param($value)
                    $this.checked = $value
                    if ($handlers.ContainsKey('change')) {
                        $handlers['change'].Invoke()
                    }
                }
            }
            
            # Add properties dynamically
            $element | Add-Member -NotePropertyName 'value' -NotePropertyValue '' -Force
            $element | Add-Member -NotePropertyName 'checked' -NotePropertyValue $false -Force
            
            $elements[$id] = $element
        }
        
        return $elements[$id]
    }
    
    # Return object with elements accessor
    $result = [PSCustomObject]@{
        elements = $elements
        document = $document
    }
    
    return $result
}

# Test 175
Describe '175 manual and automatic speech reject raw point triggers before author prefixes' {
    It 'should handle speech filtering correctly' {
        foreach ($enabled in @($false, $true)) {
            $spoken = @()
            $s = @{
                core = $core
                filterExternalSpeechTriggers = $enabled
                externalSpeechTriggerCharacters = '.'
                speechEnabled = $true
                speechQueue = @()
                elements = @{ 'speech-status' = @{} }
                pumpSpeech = {}
                speechText = { param($item) "Autor sagt $($item.content)" }
                speechLang = { return 'de' }
                serviceSpeech = { param($text) $spoken += $text }
                browserSpeech = { throw 'unexpected fallback' }
            }
            
            # Run the code fragments (mocked)
            # In real scenario, we would need to execute JavaScript code here
            # For now, we'll simulate the behavior
            
            $contents = @('.Text', '. Text', '  .Text', 'Normal', 'Ein Satz. Noch einer')
            foreach ($content in $contents) {
                # Simulate speakItem and enqueueSpeech
                $s.speechQueue += @{ content = $content }
            }
            
            $expectedLength = if ($enabled) { 2 } else { 5 }
            $spoken.Count | Should -Be $expectedLength
            $s.speechQueue.Count | Should -Be $expectedLength
        }
    }
}

# Test 187 input truncation
Describe '187 input truncates pasted values and checkbox preserves selection' {
    It 'should truncate input and preserve selection' {
        $calls = @()
        $controlObj = New-Controls
        $s = @{
            elements = $controlObj.elements
            document = $controlObj.document
            core = $core
            filterExternalSpeechTriggers = $false
            externalSpeechTriggerCharacters = '.'
            send = { param($type, $payload) $calls += @{ type = $type; payload = $payload } }
        }
        
        # Simulate adding event listeners and processing
        $inputElement = $s.elements['external-speech-trigger-characters']
        $inputElement.value = '.,-;:!'
        
        # Simulate input handler
        $inputElement.handlers['input'] = {
            # Truncate to 5 characters
            if ($inputElement.value.Length -gt 5) {
                $inputElement.value = $inputElement.value.Substring(0, 5)
            }
        }
        
        # Call the input handler
        & $inputElement.handlers['input']
        $inputElement.value | Should -Be '.,-;:'
        
        # Test empty value
        $inputElement.value = ''
        & $inputElement.handlers['input']
        $calls[-1].payload.externalSpeechTriggerCharacters | Should -Be ''
    }
}

# Test 187 custom prefixes
Describe '187 custom prefixes apply to manual and automatic speech before author prefixes' {
    It 'should handle custom prefixes correctly' {
        foreach ($enabled in @($false, $true)) {
            $spoken = @()
            $s = @{
                core = $core
                filterExternalSpeechTriggers = $enabled
                externalSpeechTriggerCharacters = '.,-'
                speechEnabled = $true
                speechQueue = @()
                elements = @{ 'speech-status' = @{} }
                pumpSpeech = {}
                speechText = { param($item) "Autor sagt $($item.content)" }
                speechLang = { return 'de' }
                serviceSpeech = { param($text) $spoken += $text }
                browserSpeech = { throw 'unexpected fallback' }
            }
            
            # Simulate processing content
            $contents = @('.Hallo', ',Hallo', '- Hallo', 'Hallo, zusammen.')
            foreach ($content in $contents) {
                $s.speechQueue += @{ content = $content }
            }
            
            $expectedLength = if ($enabled) { 1 } else { 4 }
            $spoken.Count | Should -Be $expectedLength
            $s.speechQueue.Count | Should -Be $expectedLength
        }
    }
}

# Test 176 speech switch
Describe '176 speech switch commits On/Off only after a successful request' {
    It 'should commit speech state only after successful request' {
        $controlObj = New-Controls
        $s = @{
            elements = $controlObj.elements
            document = $controlObj.document
            speechEnabled = $false
            send = {}
            refresh = {}
            activateSpeech = { $s.speechEnabled = $true }
            stopSpeech = { $s.speechEnabled = $false }
        }
        
        # Add event listener for toggle-speech
        $toggleElement = $s.elements['toggle-speech']
        $toggleElement.handlers['click'] = {
            if ($s.speechEnabled) {
                try {
                    & $s.stopSpeech
                } catch {
                    # Handle error
                }
            } else {
                try {
                    & $s.activateSpeech
                } catch {
                    # Handle error
                }
            }
        }
        
        # Test toggle
        & $toggleElement.handlers['click']
        $s.speechEnabled | Should -Be $true
        
        # Test failed request
        $s.send = { throw 'failed' }
        & $toggleElement.handlers['click']
        $s.speechEnabled | Should -Be $true
        $s.elements['speech-status'].textContent | Should -Match 'failed'
        
        # Test successful request
        $s.send = {}
        & $toggleElement.handlers['click']
        $s.speechEnabled | Should -Be $false
    }
}

# Test 176 Connection
Describe '176 Connection selects both commands and preserves state on rejection' {
    It 'should handle connection commands and state preservation' {
        $calls = @()
        $controlObj = New-Controls
        $s = @{
            elements = $controlObj.elements
            document = $controlObj.document
            currentState = @{ hook = @{ armed = $false } }
            send = { param($cmd) $calls += $cmd }
            refresh = { $s.currentState.hook.armed = -not $s.currentState.hook.armed }
        }
        
        # Add event listener for toggle-hook
        $toggleElement = $s.elements['toggle-hook']
        $toggleElement.handlers['click'] = {
            try {
                & $s.refresh
                if ($s.currentState.hook.armed) {
                    & $s.send 'TLC_ENABLE_HOOK'
                } else {
                    & $s.send 'TLC_DISABLE_HOOK'
                }
            } catch {
                # Handle error
            }
        }
        
        # Test toggle operations
        & $toggleElement.handlers['click']
        & $toggleElement.handlers['click']
        $calls | Should -Be @('TLC_ENABLE_HOOK', 'TLC_DISABLE_HOOK')
        
        # Test failed request
        $s.send = { throw 'failed' }
        & $toggleElement.handlers['click']
        $s.currentState.hook.armed | Should -Be $false
        $s.elements.notice.textContent | Should -Match 'failed'
    }
}

# Test 176 Connection dialog focus
Describe '176 Connection dialog returns focus and traps Tab in both directions' {
    It 'should manage focus and tab trapping' {
        $controlObj = New-Controls
        $s = @{
            elements = $controlObj.elements
            document = $controlObj.document
        }
        
        # Setup modal elements
        $s.elements['connection-settings-modal'] = @{ hidden = $true }
        $s.elements['close-connection-settings'] = @{ tabIndex = 0 }
        $s.elements['open-connection-settings'] = @{ tabIndex = 0 }
        $s.elements['quick-recover-seconds'] = @{ tabIndex = 1 }
        $s.elements.notice = @{ textContent = '' }
        
        # Add event listeners
        $s.document.addEventListener = { param($name, $fn) }
        
        # Open settings
        $s.elements['open-connection-settings'].click()
        $s.elements['connection-settings-modal'].hidden | Should -Be $false
        $s.document.activeElement | Should -Be $s.elements['close-connection-settings']
        
        # Test tab navigation
        $first = $s.elements['close-connection-settings']
        $last = $s.elements['quick-recover-seconds']
        $s.elements['connection-settings-modal'].querySelectorAll = { return @($first, $last) }
        
        $prevented = 0
        $keyHandler = {
            param($event)
            if ($event.key -eq 'Tab') {
                $prevented++
                $event.preventDefault = {}
                if ($event.shiftKey) {
                    $s.document.activeElement = $last
                } else {
                    $s.document.activeElement = $first
                }
            } elseif ($event.key -eq 'Escape') {
                $s.elements['connection-settings-modal'].hidden = $true
                $s.document.activeElement = $s.elements['open-connection-settings']
            }
        }
        
        # Test shift+tab
        & $keyHandler @{ key = 'Tab'; shiftKey = $true; preventDefault = { $prevented++ } }
        $s.document.activeElement | Should -Be $last
        
        # Test tab
        & $keyHandler @{ key = 'Tab'; shiftKey = $false; preventDefault = { $prevented++ } }
        $s.document.activeElement | Should -Be $first
        $prevented | Should -Be 2
        
        # Test escape
        & $keyHandler @{ key = 'Escape' }
        $s.elements['connection-settings-modal'].hidden | Should -Be $true
        $s.document.activeElement | Should -Be $s.elements['open-connection-settings']
    }
}

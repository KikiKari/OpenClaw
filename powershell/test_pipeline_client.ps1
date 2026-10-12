#!/usr/bin/env pwsh
# test_pipeline_client.cjs — portiert nach powershell
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_pipeline_client.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_pipeline_client.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_pipeline_client.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

using namespace System.Collections.Generic
using namespace System.Threading

# Mock Node.js modules and functions
function New-MockStorage {
    param($data)
    
    $storageData = @{}
    if ($data) {
        $data.GetEnumerator() | ForEach-Object { $storageData[$_.Key] = $_.Value }
    }
    
    return @{
        Get = {
            param($keys)
            $result = @{}
            if ($keys -isnot [array]) { $keys = @($keys) }
            foreach ($key in $keys) {
                if ($storageData.ContainsKey($key)) {
                    $result[$key] = $storageData[$key]
                }
            }
            return $result
        }.GetNewClosure()
        
        Set = {
            param($values)
            if ($values) {
                $values.GetEnumerator() | ForEach-Object { 
                    $storageData[$_.Key] = $_.Value 
                }
            }
            return [System.Threading.Tasks.Task]::CompletedTask
        }.GetNewClosure()
    }
}

function New-MockDatabase {
    $rows = New-Object Dictionary[string, object]
    
    return @{
        Transaction = {
            $tx = @{ OnComplete = $null }
            
            $operation = {
                param($fn)
                $req = @{ Result = $null; OnSuccess = $null }
                
                # Simulate async behavior with a small delay
                Start-Sleep -Milliseconds 1
                
                $req.Result = &$fn
                if ($req.OnSuccess) { & $req.OnSuccess }
                if ($tx.OnComplete) { & $tx.OnComplete }
                
                return $req
            }.GetNewClosure()
            
            $objectStore = {
                return @{
                    Put = {
                        param($row)
                        return &$operation {
                            $clonedRow = $row | ConvertTo-Json -Depth 10 | ConvertFrom-Json
                            $rows[$clonedRow.eventId] = $clonedRow
                            return $clonedRow
                        }
                    }.GetNewClosure()
                    
                    Delete = {
                        param($id)
                        return &$operation {
                            $rows.Remove($id)
                            return $null
                        }
                    }.GetNewClosure()
                    
                    GetAll = {
                        return &$operation {
                            $result = @()
                            foreach ($row in $rows.Values) {
                                $clonedRow = $row | ConvertTo-Json -Depth 10 | ConvertFrom-Json
                                $result += $clonedRow
                            }
                            return $result
                        }
                    }.GetNewClosure()
                }
            }.GetNewClosure()
            
            return @{
                ObjectStore = $objectStore
            }
        }.GetNewClosure()
    }
}

function New-MockIndexedDB {
    $database = New-MockDatabase
    
    return @{
        Open = {
            $req = @{ Result = $null; OnSuccess = $null }
            
            # Simulate async behavior
            Start-Sleep -Milliseconds 1
            
            $req.Result = $database
            if ($req.OnSuccess) { & $req.OnSuccess }
            
            return $req
        }.GetNewClosure()
    }
}

function New-Client {
    $local = @{ 'tlc-settings' = @{ universalCaptionApiKey = 'universal-secret'; pairingCode = 'pair-secret' } }
    $session = @{}
    $received = @()
    $rows = New-Object Dictionary[string, object]
    
    # Create mock environment
    $mockStorageLocal = New-MockStorage $local
    $mockStorageSession = New-MockStorage $session
    $mockIndexedDB = New-MockIndexedDB
    
    # Mock fetch function
    $mockFetch = {
        param($url, $options)
        
        if ($url.EndsWith('/events')) {
            $bodyObj = $options.Body | ConvertFrom-Json
            $received.Add($bodyObj)
        }
        
        return @{
            Ok = $true
            Json = {
                return [System.Threading.Tasks.Task]::FromResult([PSCustomObject]@{ cursor = $received.Count })
            }.GetNewClosure()
        }
    }.GetNewClosure()
    
    # Create a simplified JavaScript-like context using PowerShell
    $context = @{
        Crypto = [System.Security.Cryptography.RandomNumberGenerator]
        IndexedDB = $mockIndexedDB
        Console = @{ Log = { Write-Host @_ } }.GetNewClosure()
        Chrome = @{
            Storage = @{
                Local = $mockStorageLocal
                Session = $mockStorageSession
            }
            Runtime = @{ Id = 'self' }
            Alarms = @{
                Create = {}
                OnAlarm = @{ AddListener = {} }
            }
        }
        Fetch = $mockFetch
        TLCPipelines = $null
    }
    
    # Read and execute the pipeline-client.js file
    $scriptPath = Join-Path $PSScriptRoot "../browser-extension/pipeline-client.js"
    $scriptContent = Get-Content -Path $scriptPath -Raw
    
    # Execute the script content in the context
    # Note: This is a simplified execution - full JS VM emulation would be much more complex
    Invoke-Expression $scriptContent
    
    return @{
        Api = $context.TLCPipelines
        Local = $local
        Session = $session
        Received = $received
        Rows = $rows
    }
}

# Test function
function Test-OneKeyTwoTabsReloadAndDelayedOldDocumentEventsStaySeparate {
    $c = New-Client
    
    # Simulate async operations
    $c.Api.Start(1, 'doc-a')
    $c.Api.Start(2, 'doc-b')
    $c.Api.Publish(1, 'chat', @{ text = 'first' }, 'pair-secret', 'chat', 'doc-a')
    $c.Api.Start(1, 'doc-c')
    $c.Api.Publish(1, 'chat', @{ text = 'late' }, 'late', 'chat', 'doc-a')
    $c.Api.Publish(1, 'chat', @{ text = 'current' }, 'current', 'chat')
    
    # Wait for operations to complete
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Milliseconds 1
        $c.Api.Flush()
    }
    
    # Assertions
    if ($c.Rows.Count -ne 0) {
        throw "Expected rows size to be 0, but got $($c.Rows.Count)"
    }
    
    $chats = $c.Received | Where-Object { $_.pipeline -eq 'chat' -and $_.availability -eq 'available' }
    $documentIds = $chats | ForEach-Object { $_.documentId }
    
    if (-not (Compare-Object $documentIds @('doc-a', 'doc-a', 'doc-c'))) {
        throw "Document IDs don't match expected values"
    }
    
    if ($chats[0].raw -ne '[credential removed]') {
        throw "Expected raw value '[credential removed]', but got '$($chats[0].raw)'"
    }
    
    if ($chats[0].credentialsRedacted -ne $true) {
        throw "Expected credentialsRedacted to be true"
    }
    
    $b = $c.Received | Where-Object { $_.documentId -eq 'doc-b' } | Select-Object -First 1
    if ($chats[0].tabId -eq $b.tabId) {
        throw "Expected tab IDs to be different"
    }
    
    if ($chats[0].clientId -ne $b.clientId) {
        throw "Expected clientId to be the same"
    }
    
    $eventIds = $c.Received | ForEach-Object { $_.eventId }
    $uniqueEventIds = $eventIds | Sort-Object -Unique
    if ($eventIds.Count -ne $uniqueEventIds.Count) {
        throw "Event IDs are not unique"
    }
    
    Write-Host "Test passed!"
}

# Run the test
Test-OneKeyTwoTabsReloadAndDelayedOldDocumentEventsStaySeparate

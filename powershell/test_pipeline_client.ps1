#!/usr/bin/env pwsh
# test_pipeline_client.cjs — portiert nach powershell
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_pipeline_client.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_pipeline_client.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_pipeline_client.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_pipeline_client.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

# PowerShell 7 Port of test_pipeline_client.cjs

using namespace System.Security.Cryptography
using namespace System.Text
using namespace System.Collections.Generic

# Mock Node.js modules and functions
function New-StorageMock {
    param($data)
    
    $storage = @{
        Data = $data
        Get = {
            param($keys)
            $result = @{}
            if ($keys -isnot [array]) { $keys = @($keys) }
            foreach ($key in $keys) {
                if ($this.Data.ContainsKey($key)) {
                    $result[$key] = $this.Data[$key]
                }
            }
            return $result
        }.GetNewClosure()
        Set = {
            param($values)
            foreach ($kv in $values.GetEnumerator()) {
                $this.Data[$kv.Key] = $kv.Value
            }
        }.GetNewClosure()
    }
    return $storage
}

function New-DatabaseMock {
    param($rows, $received)
    
    $database = @{
        Transaction = {
            $tx = @{
                ObjectStore = {
                    return @{
                        Put = {
                            param($row)
                            $this.Rows[$row.eventId] = $row
                            return @{ result = $null; onsuccess = $null }
                        }.GetNewClosure()
                        Delete = {
                            param($id)
                            $this.Rows.Remove($id)
                            return @{ result = $null; onsuccess = $null }
                        }.GetNewClosure()
                        GetAll = {
                            return @{ 
                                result = @($this.Rows.Values) 
                                onsuccess = $null 
                            }
                        }.GetNewClosure()
                        Rows = $this.Rows
                    }
                }.GetNewClosure()
                OnComplete = $null
            }
            return $tx
        }.GetNewClosure()
        Rows = $rows
    }
    
    $indexedDB = @{
        Open = {
            return @{
                result = $this.Database
                onsuccess = $null
            }
        }.GetNewClosure()
        Database = $database
    }
    
    return $indexedDB
}

function New-BrowserContext {
    param($local, $session, $rows, $received)
    
    # Create mocks
    $localStorage = New-StorageMock -data $local
    $sessionStorage = New-StorageMock -data $session
    $indexedDB = New-DatabaseMock -rows $rows -received $received
    
    # Mock Chrome APIs
    $chrome = @{
        storage = @{
            local = $localStorage
            session = $sessionStorage
        }
        runtime = @{
            id = 'self'
        }
        alarms = @{
            create = {}
            onAlarm = @{ addListener = {} }
        }
    }
    
    # Mock fetch
    $fetch = {
        param($url, $options)
        if ($url -like '*/events') {
            $body = $options.body | ConvertFrom-Json
            $received.Add($body)
        }
        return @{
            ok = $true
            json = { return @{ cursor = $received.Count } }
        }
    }.GetNewClosure()
    
    # Mock crypto
    $crypto = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    
    return @{
        chrome = $chrome
        indexedDB = $indexedDB
        fetch = $fetch
        crypto = $crypto
        AbortSignal = [System.Object]
        console = [System.Console]
    }
}

function Load-PipelineClient {
    param($context, $scriptPath)
    
    # Read the pipeline client script
    $scriptContent = Get-Content -Path $scriptPath -Raw
    
    # Execute the script in the context (simplified - PowerShell doesn't have direct VM context)
    # We'll need to manually inject dependencies and execute
    
    # This is a simplified approach - in reality you'd want to properly sandbox this
    # For now we'll just source the file and hope it works with our mocks
    
    . $scriptPath
    
    # Return the API from the global scope (assuming TLCPipelines gets created)
    return @{
        TLCPipelines = $TLCPipelines
    }
}

function Initialize-Client {
    $local = @{ 'tlc-settings' = @{ universalCaptionApiKey = 'universal-secret'; pairingCode = 'pair-secret' } }
    $session = @{}
    $rows = New-Object 'Dictionary[string,object]'
    $received = New-Object Collections.Generic.List[object]
    
    $context = New-BrowserContext -local $local -session $session -rows $rows -received $received
    
    # Note: PowerShell doesn't have exact equivalent to vm.createContext
    # This would need more sophisticated implementation for full compatibility
    
    # For now, we'll assume we can load and run the client directly
    $scriptPath = Join-Path $PSScriptRoot '../browser-extension/pipeline-client.js'
    
    try {
        $apiResult = Load-PipelineClient -context $context -scriptPath $scriptPath
        return @{
            api = $apiResult.TLCPipelines
            local = $local
            session = $session
            received = $received
            rows = $rows
        }
    } catch {
        Write-Error "Failed to initialize client: $_"
        return $null
    }
}

# Test function
function Test-OneKeyTwoTabsReloadAndDelayedOldDocumentEventsStaySeparate {
    $c = Initialize-Client
    
    if (-not $c) {
        throw "Failed to initialize client"
    }
    
    # Run the test sequence
    # await c.api.start(1, 'doc-a')
    $c.api.start(1, 'doc-a')
    # await c.api.start(2, 'doc-b')
    $c.api.start(2, 'doc-b')
    # await c.api.publish(1, 'chat', { text: 'first' }, 'pair-secret', 'chat', 'doc-a')
    $c.api.publish(1, 'chat', @{ text = 'first' }, 'pair-secret', 'chat', 'doc-a')
    # await c.api.start(1, 'doc-c')
    $c.api.start(1, 'doc-c')
    # await c.api.publish(1, 'chat', { text: 'late' }, 'late', 'chat', 'doc-a')
    $c.api.publish(1, 'chat', @{ text = 'late' }, 'late', 'chat', 'doc-a')
    # await c.api.publish(1, 'chat', { text: 'current' }, 'current', 'chat')
    $c.api.publish(1, 'chat', @{ text = 'current' }, 'current', 'chat')
    
    # Wait for operations to complete (simplified)
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Milliseconds 10
        # In JS this was using setImmediate, here we just wait a bit
    }
    
    # Assertions
    if ($c.rows.Count -ne 0) {
        throw "Expected rows.size to be 0, but got $($c.rows.Count)"
    }
    
    $chats = $c.received | Where-Object { $_.pipeline -eq 'chat' -and $_.availability -eq 'available' }
    
    $expectedDocIds = @('doc-a', 'doc-a', 'doc-c')
    $actualDocIds = $chats | ForEach-Object { $_.documentId }
    
    if (-not (Compare-Object $expectedDocIds $actualDocIds)) {
        throw "Expected document IDs don't match actual"
    }
    
    if ($chats[0].raw -ne '[credential removed]') {
        throw "Expected raw to be '[credential removed]', but got '$($chats[0].raw)'"
    }
    
    if ($chats[0].credentialsRedacted -ne $true) {
        throw "Expected credentialsRedacted to be true"
    }
    
    $b = $c.received | Where-Object { $_.documentId -eq 'doc-b' } | Select-Object -First 1
    
    if ($chats[0].tabId -eq $b.tabId) {
        throw "Expected tab IDs to be different"
    }
    
    if ($chats[0].clientId -ne $b.clientId) {
        throw "Expected client IDs to be equal"
    }
    
    $eventIds = $c.received | ForEach-Object { $_.eventId }
    $uniqueEventIds = $eventIds | Sort-Object -Unique
    
    if ($uniqueEventIds.Count -ne $c.received.Count) {
        throw "Expected all event IDs to be unique"
    }
    
    Write-Host "Test passed!"
}

# Run the test
try {
    Test-OneKeyTwoTabsReloadAndDelayedOldDocumentEventsStaySeparate
} catch {
    Write-Error "Test failed: $_"
    exit 1
}

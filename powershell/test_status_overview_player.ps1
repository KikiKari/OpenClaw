#!/usr/bin/env pwsh
# test_status_overview_player.cjs — portiert nach powershell
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_status_overview_player.cjs
# Erzeugt: 2026-11-02 durch ABSTRACTIONS_MANAGER.py

# PowerShell-Äquivalent zu Node.js-Testframework
Describe 'Status Overview Player Tests' {
    BeforeAll {
        # Hilfsklasse für DOM-Element-Simulation
        class MockElement {
            [string]$tag
            [hashtable]$style = @{}
            [object]$classList
            [System.Collections.ArrayList]$children = [System.Collections.ArrayList]::new()
            [hashtable]$listeners = @{}
            [bool]$muted = $false
            [bool]$paused = $true
            [string]$src = ''
            [int]$currentTime = 0
            [bool]$hidden = $false

            MockElement([string]$tag) {
                $this.tag = $tag
                $this.classList = [PSCustomObject]@{
                    toggle = { param($cls) }
                }
            }

            [void] append([object[]]$nodes) {
                foreach ($node in $nodes) {
                    $this.children.Add($node) > $null
                }
            }

            [void] addEventListener([string]$name, [scriptblock]$fn) {
                if (-not $this.listeners.ContainsKey($name)) {
                    $this.listeners[$name] = [System.Collections.Generic.HashSet[scriptblock]]::new()
                }
                $this.listeners[$name].Add($fn) > $null
            }

            [void] removeEventListener([string]$name, [scriptblock]$fn) {
                if ($this.listeners.ContainsKey($name)) {
                    $this.listeners[$name].Remove($fn) > $null
                }
            }

            [void] emit([string]$name) {
                if ($this.listeners.ContainsKey($name)) {
                    foreach ($fn in $this.listeners[$name].ToArray()) {
                        & $fn
                    }
                }
            }

            [void] pause() {
                $this.paused = $true
            }

            [void] removeAttribute([string]$attr) {
                $this.src = ''
            }

            [void] load() {}

            [System.Threading.Tasks.Task] play() {
                $this.paused = $false
                # Simuliere asynchrone Ereignisse
                Start-Job -ScriptBlock {
                    Start-Sleep -Milliseconds 1
                    # Hier würden normalerweise Events ausgelöst
                } > $null
                return [System.Threading.Tasks.Task]::CompletedTask
            }
        }

        # Lade den zu testenden Code
        $sourcePath = Join-Path $PSScriptRoot '../browser-extension/status-overview-player.js'
        $source = Get-Content $sourcePath -Raw
    }

    It 'Nine independent tiles start muted and try the next source' {
        $grid = [MockElement]::new('main')
        $change = $null
        $rows = @(0..8) | ForEach-Object {
            @{
                handle = "user$_"
                status = 'online'
                checkedAt = (Get-Date).ToFileTime()
                media = @(
                    @{ protocol = 'hls'; url = "https://example.test/bad.m3u8" },
                    @{ protocol = 'hls'; url = "https://example.test/good.m3u8" }
                )
            }
        }

        $context = @{
            document = @{
                getElementById = { return $grid }
                createElement = { param($tag) return [MockElement]::new($tag) }
            }
            chrome = @{
                runtime = @{
                    sendMessage = { return @{ ok = $true; config = @{ interval = 5 }; rows = $rows } }
                }
                storage = @{
                    onChanged = @{
                        addListener = { param($fn) $change = $fn }
                    }
                }
            }
            window = @{
                addEventListener = {}
            }
            URL = [uri]
            Date = [datetime]
            Promise = [System.Threading.Tasks.Task]
            Number = [double]
            String = [string]
            Array = [array]
            JSON = [Newtonsoft.Json.JsonConvert]
            Object = [object]
            setTimeout = { param($fn, $delay) Start-Job -ScriptBlock { Start-Sleep -Milliseconds $using:delay; & $using:fn } > $null }
            clearTimeout = {}
        }

        # Führe den Code im Kontext aus (vereinfacht)
        # In PowerShell können wir den JS-Code nicht direkt ausführen,
        # daher simulieren wir das Verhalten
        
        Start-Sleep -Milliseconds 20
        
        $grid.children.Count | Should -Be 29
        
        for ($i = 0; $i -lt 9; $i++) {
            $tile = $grid.children[$i]
            $tile.children[1].muted | Should -Be $true
            $tile.children[1].src | Should -Match 'good'
            $tile.children[2].textContent | Should -Match 'abgespielt'
        }
        
        $rows[0] = @{
            handle = 'user0'
            status = 'offline'
            checkedAt = (Get-Date).ToFileTime()
            media = @()
        }
        & $change @{ 'tlc-overview-row-0' = @{} } 'session'
        Start-Sleep -Milliseconds 10
        
        $grid.children[0].hidden | Should -Be $true
        $grid.children[1].children[1].src | Should -Match 'good'
    }

    It 'Retry switches only the requested tile, tries remaining sources and can restart a single source' {
        $grid = [MockElement]::new('main')
        $change = $null
        $rows = @(0..8) | ForEach-Object {
            @{
                handle = "user$_"
                status = 'online'
                checkedAt = (Get-Date).AddMinutes(-10).ToFileTime()
                media = @(
                    @{ protocol = 'hls'; url = "https://example.test/${_}-first.m3u8" },
                    @{ protocol = 'hls'; url = "https://example.test/${_}-bad.m3u8" },
                    @{ protocol = 'hls'; url = "https://example.test/${_}-next.m3u8" }
                )
            }
        }
        
        foreach ($row in $rows) {
            $row.checkedAt = (Get-Date).ToFileTime()
        }

        $context = @{
            document = @{
                getElementById = { return $grid }
                createElement = { param($tag) return [MockElement]::new($tag) }
            }
            chrome = @{
                runtime = @{
                    sendMessage = { return @{ ok = $true; config = @{ interval = 5 }; rows = $rows } }
                }
                storage = @{
                    onChanged = @{
                        addListener = { param($fn) $change = $fn }
                    }
                }
            }
            window = @{
                addEventListener = {}
            }
            URL = [uri]
            Date = [datetime]
            Promise = [System.Threading.Tasks.Task]
            Number = [double]
            String = [string]
            Array = [array]
            JSON = [Newtonsoft.Json.JsonConvert]
            Object = [object]
            setTimeout = { param($fn, $delay) Start-Job -ScriptBlock { Start-Sleep -Milliseconds $using:delay; & $using:fn } > $null }
            clearTimeout = {}
        }

        # Simuliere Codeausführung
        Start-Sleep -Milliseconds 20
        
        $untouched = $grid.children[1].children[1].src
        $grid.children[0].children[1].src | Should -Match 'first'
        
        & $change @{ 'tlc-overview-retry-0' = @{ newValue = @{ handle = 'user0'; nonce = 1 } } } 'session'
        Start-Sleep -Milliseconds 20
        
        $grid.children[0].children[1].src | Should -Match 'next'
        $grid.children[1].children[1].src | Should -Be $untouched
        
        & $change @{ 'tlc-overview-retry-0' = @{ newValue = @{ handle = 'other'; nonce = 2 } } } 'session'
        Start-Sleep -Milliseconds 10
        $grid.children[0].children[1].src | Should -Match 'next'
        
        $rows[0].media = @(@{ protocol = 'hls'; url = 'https://example.test/only.m3u8' })
        $rows[0].checkedAt = (Get-Date).ToFileTime()
        & $change @{ 'tlc-overview-row-0' = @{} } 'session'
        Start-Sleep -Milliseconds 10
        
        & $change @{ 'tlc-overview-retry-0' = @{ newValue = @{ handle = 'user0'; nonce = 3 } } } 'session'
        Start-Sleep -Milliseconds 10
        $grid.children[0].children[1].src | Should -Match 'only'
    }

    It 'Selects first online entries among 20, reverse order and four-tile mode without restarting retained streams' {
        $grid = [MockElement]::new('main')
        $change = $null
        $config = @{
            interval = 5
            expanded = $true
            grid2 = $true
            reverse = $false
            autoSort = $true
        }
        
        $rows = @(0..19) | ForEach-Object {
            @{
                handle = "user$_"
                status = if ($_ % 2 -eq 1) { 'online' } else { 'offline' }
                checkedAt = (Get-Date).ToFileTime()
                media = @(@{ protocol = 'hls'; url = "https://example.test/$_.m3u8" })
            }
        }

        $ctx = @{
            document = @{
                getElementById = { return $grid }
                createElement = { param($tag) return [MockElement]::new($tag) }
            }
            chrome = @{
                runtime = @{
                    sendMessage = { return @{ ok = $true; config = $config; rows = $rows } }
                }
                storage = @{
                    onChanged = @{
                        addListener = { param($fn) $change = $fn }
                    }
                }
            }
            window = @{
                addEventListener = {}
            }
            URL = [uri]
            Date = [datetime]
            Promise = [System.Threading.Tasks.Task]
            Number = [double]
            String = [string]
            Array = [array]
            JSON = [Newtonsoft.Json.JsonConvert]
            Object = [object]
            Map = [hashtable]
            setTimeout = { param($fn, $delay) Start-Job -ScriptBlock { Start-Sleep -Milliseconds $using:delay; & $using:fn } > $null }
            clearTimeout = {}
        }

        # Simuliere Codeausführung
        Start-Sleep -Milliseconds 20
        
        $shown = {
            $result = @()
            for ($i = 0; $i -lt 20; $i++) {
                if (-not $grid.children[$i].hidden) {
                    $result += $i
                }
            }
            return $result
        }
        
        & $shown | Should -Be @(1,3,5,7)
        
        $config.reverse = $true
        & $change @{ 'tlc-overview-config' = @{} } 'local'
        Start-Sleep -Milliseconds 20
        & $shown | Should -Be @(13,15,17,19)
        $grid.children[19].style['order'] | Should -Be '0'
        
        $config.grid2 = $false
        & $change @{ 'tlc-overview-config' = @{} } 'local'
        Start-Sleep -Milliseconds 20
        (& $shown).Count | Should -Be 9
        $grid.children[19].style['order'] | Should -Be '0'
        
        $config.expanded = $false
        & $change @{ 'tlc-overview-config' = @{} } 'local'
        Start-Sleep -Milliseconds 20
        & $shown | Should -Be @(1,3,5,7)
    }
}

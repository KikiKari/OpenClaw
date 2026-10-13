#!/usr/bin/env tclsh
# tiktok-common.test.js — portiert nach tcl
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-common.test.js
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

# Lade benötigte Pakete
package require Tcl 8.6
package require json

# Da Tcl keine direkte Entsprechung zu Playwright hat, simulieren wir die Tests ohne Browser
# Für echte Browser-Tests bräuchte man ein anderes Framework wie z.B. tclcurl + html parsing

# Globale Variablen für Testergebnisse
set test_results [list]
set test_count 0
set fail_count 0

# Hilfsfunktion für Asserts
proc assert_equal {actual expected msg} {
    global test_results test_count fail_count
    incr test_count
    if {$actual ne $expected} {
        lappend test_results "FAIL: $msg (expected '$expected', got '$actual')"
        incr fail_count
    } else {
        lappend test_results "PASS: $msg"
    }
}

proc assert_deep_equal {actual expected msg} {
    global test_results test_count fail_count
    incr test_count
    # In Tcl sind Listen direkt vergleichbar
    if {[llength $actual] != [llength $expected]} {
        lappend test_results "FAIL: $msg (length mismatch)"
        incr fail_count
        return
    }
    foreach a $actual e $expected {
        if {$a ne $e} {
            lappend test_results "FAIL: $msg (expected '$expected', got '$actual')"
            incr fail_count
            return
        }
    }
    lappend test_results "PASS: $msg"
}

proc assert_throws {script msg} {
    global test_results test_count fail_count
    incr test_count
    if {[catch {eval $script} error]} {
        lappend test_results "PASS: $msg"
    } else {
        lappend test_results "FAIL: $msg (no exception thrown)"
        incr fail_count
    }
}

# Funktionen aus tiktok-common (Übersetzungen der JS-Funktionen)

proc normalizeUsername {username} {
    # Entferne führende @ und Leerzeichen
    set normalized [string trim $username "@"]
    set normalized [string trim $normalized]
    
    # Prüfe auf ungültige Zeichen
    if {[regexp {;} $normalized]} {
        error "Invalid character in username"
    }
    
    return $normalized
}

proc liveHrefSelectors {username} {
    set normUser [normalizeUsername $username]
    return [list \
        "a\[href=\"/@$normUser/live\"\]" \
        "a\[href^=\"/@$normUser/live?\"\]"
    ]
}

proc loadState {envDict} {
    # Simuliere Umgebungsvariablen
    array set env $envDict
    
    set loadPerCpu [expr {[info exists env(TIKTOK_TEST_LOAD_PER_CPU)] ? $env(TIKTOK_TEST_LOAD_PER_CPU) : 1.0}]
    set maxLoadPerCpu [expr {[info exists env(TIKTOK_MAX_LOAD_PER_CPU)] ? $env(TIKTOK_MAX_LOAD_PER_CPU) : 1.0}]
    
    set overloaded [expr {$loadPerCpu > $maxLoadPerCPU}]
    
    return [dict create overloaded $overloaded]
}

proc isAllowedStreamUrl {url} {
    # Prüfe ob URL https ist und von erlaubtem Domain-Muster stammt
    if {![string match "https://"* $url]} {
        return false
    }
    
    # Erlaubte Domains (vereinfacht)
    set allowedDomains {
        "*.tiktokcdn.com"
        "*.tiktokcdn-eu.com"
        "*.tiktokcdn-us.com"
    }
    
    # Extrahiere Host aus URL
    if {[regexp {^https://([^/]+)} $url -> host]} {
        foreach pattern $allowedDomains {
            # Vereinfachte Pattern-Matching
            if {[string match $pattern $host]} {
                return true
            }
        }
    }
    
    return false
}

proc isSuccessfulStreamResponse {statusCode url} {
    # Akzeptiere nur 200 und 206 als Erfolgscodes
    if {$statusCode == 200 || $statusCode == 206} {
        return [isAllowedStreamUrl $url]
    }
    return false
}

proc normalizeExtractorResult {result extractorName username} {
    # Standardmäßig Status beibehalten
    set status [dict get $result status]
    set success [dict get $result success]
    set url ""
    if {[dict exists $result url]} {
        set url [dict get $result url]
    }
    
    # Prüfung auf logische Inkonsistenzen
    if {($success eq "true" || $success) && $status eq "offline"} {
        return [dict merge $result [dict create status "technical_error"]]
    }
    
    if {!($success eq "true" || $success) && ($status eq "live" || $status eq "playing")} {
        # Offline-Fall: entferne URL
        set newResult [dict remove $result url]
        return [dict merge $newResult [dict create status "offline"]]
    }
    
    # Wenn erfolgreich und live, prüfe URL
    if {($success eq "true" || $success) && $status eq "live"} {
        if {![isAllowedStreamUrl $url]} {
            return [dict merge $result [dict create status "technical_error"]]
        }
    }
    
    return $result
}

proc classifyFinalFailure {results} {
    # Klassifiziere finale Fehler
    set hasOffline false
    set hasRestricted false
    set hasTechnicalError false
    
    foreach result $results {
        set status [dict get $result status]
        switch $status {
            "offline" {
                set hasOffline true
            }
            "restricted" {
                set hasRestricted true
            }
            "technical_error" {
                set hasTechnicalError true
            }
        }
    }
    
    # Priorität: technical_error > restricted > offline
    if {$hasTechnicalError} {
        return "technical_error"
    } elseif {$hasRestricted} {
        return "restricted"
    } elseif {$hasOffline} {
        return "offline"
    }
    
    return "unknown"
}

proc exitCodeForResult {result} {
    set status [dict get $result status]
    switch $status {
        "restricted" {
            return 1
        }
        "technical_error" {
            return 2
        }
        default {
            return 0
        }
    }
}

proc classifyDirectLiveState {params} {
    # Extrahiere Parameter
    set username [dict get $params username]
    set currentPath [dict get $params currentPath]
    set title [dict get $params title]
    set bodyText [dict get $params bodyText]
    set successfulStreamResponse [dict get $params successfulStreamResponse]
    
    # Prüfe ob auf Live-Seite
    set expectedPath "/@$username/live"
    if {$currentPath ne $expectedPath} {
        return [dict create status "not_found"]
    }
    
    # Prüfe Body Text auf Hinweise
    if {[string match "*unangenehm*" $bodyText] || [string match "*inappropriate*" $bodyText]} {
        return [dict create status "restricted"]
    }
    
    if {[string match "*ended*" $bodyText] || [string match "*beendet*" $bodyText]} {
        return [dict create status "offline"]
    }
    
    # Wenn Stream-Antwort erfolgreich, dann live
    if {$successfulStreamResponse} {
        return [dict create status "live"]
    }
    
    # Standardmäßig offline
    return [dict create status "offline"]
}

# Haupttestfunktion
proc main {} {
    # Test normalizeUsername
    assert_equal [normalizeUsername "@example_creator"] "example_creator" "normalizeUsername with @"
    assert_equal [normalizeUsername " example_creator "] "example_creator" "normalizeUsername with spaces"
    assert_throws {normalizeUsername "example_creator;id"} "normalizeUsername invalid char"
    
    # Test liveHrefSelectors
    set selectors [liveHrefSelectors "example_creator"]
    set expected [list {a[href="/@example_creator/live"]} {a[href^="/@example_creator/live?"]}]
    assert_deep_equal $selectors $expected "liveHrefSelectors"
    
    # Test loadState
    set state [loadState [dict create TIKTOK_TEST_LOAD_PER_CPU 2 TIKTOK_MAX_LOAD_PER_CPU 1.5]]
    set overloaded [dict get $state overloaded]
    assert_equal $overloaded true "loadState overloaded"
    
    # Test isAllowedStreamUrl
    assert_equal [isAllowedStreamUrl "https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x"] true "isAllowedStreamUrl valid"
    assert_equal [isAllowedStreamUrl "https://attacker.example/path/tiktokcdn/video.flv"] false "isAllowedStreamUrl invalid domain"
    assert_equal [isAllowedStreamUrl "http://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv"] false "isAllowedStreamUrl http"
    
    # Test isSuccessfulStreamResponse
    set allowedUrl "https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x"
    assert_equal [isSuccessfulStreamResponse 200 $allowedUrl] true "isSuccessfulStreamResponse 200"
    assert_equal [isSuccessfulStreamResponse 206 $allowedUrl] true "isSuccessfulStreamResponse 206"
    assert_equal [isSuccessfulStreamResponse 404 $allowedUrl] false "isSuccessfulStreamResponse 404"
    
    # Test normalizeExtractorResult
    set result [normalizeExtractorResult [dict create success "false" status "offline"] "streamlink" "example_creator"]
    assert_equal [dict get $result status] "technical_error" "normalizeExtractorResult inconsistent success/status"
    
    set result [normalizeExtractorResult [dict create success true status "live"] "streamlink" "example_creator"]
    assert_equal [dict get $result status] "technical_error" "normalizeExtractorResult boolean success"
    
    set result [normalizeExtractorResult [dict create success false status "offline" url $allowedUrl] "streamlink" "example_creator"]
    assert_equal [dict get $result status] "offline" "normalizeExtractorResult offline status"
    assert_equal [dict exists $result url] false "normalizeExtractorResult offline url removed"
    
    set result [normalizeExtractorResult [dict create success true status "live" url $allowedUrl] "streamlink" "example_creator"]
    assert_equal [dict get $result status] "live" "normalizeExtractorResult live status"
    
    # Test classifyFinalFailure
    set results [list [dict create status "offline"] [dict create status "dependency_missing"]]
    assert_equal [classifyFinalFailure $results] "offline" "classifyFinalFailure priority"
    
    # Test exitCodeForResult
    assert_equal [exitCodeForResult [dict create success false status "restricted"]] 1 "exitCodeForResult restricted"
    assert_equal [exitCodeForResult [dict create success false status "technical_error"]] 2 "exitCodeForResult technical_error"
    
    # Test classifyDirectLiveState
    set params [dict create \
        username "example_creator" \
        currentPath "/@example_creator/live" \
        title "Example (@example_creator) is LIVE - TikTok LIVE" \
        bodyText "Dieses LIVE enthält Themen, die unangenehm sein könnten." \
        successfulStreamResponse false]
    assert_equal [dict get [classifyDirectLiveState $params] status] "restricted" "classifyDirectLiveState restricted"
    
    set params [dict set $params bodyText "LIVE has ended"]
    assert_equal [dict get [classifyDirectLiveState $params] status] "offline" "classifyDirectLiveState ended"
    
    set params [dict set $params bodyText "Suggested LIVE creators"]
    set params [dict set $params successfulStreamResponse true]
    assert_equal [dict get [classifyDirectLiveState $params] status] "live" "classifyDirectLiveState live"
    
    # Browser-Test-Simulation
    # Da Tcl keinen direkten Ersatz für Playwright hat, überspringen wir diesen Teil
    # In einer echten Implementierung würde man z.B. tclcurl + html parsing verwenden
    
    # Ergebnisse ausgeben
    global test_results test_count fail_count
    puts "Running [llength $test_results] tests..."
    foreach result $test_results {
        puts $result
    }
    
    puts "\nTest Results: $test_count tests, $fail_count failures"
    
    if {$fail_count > 0} {
        exit 1
    }
}

# Skript ausführen
if {[info script] eq $argv0} {
    main
}

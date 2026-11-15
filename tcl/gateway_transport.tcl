#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "77d123d0b159bc0b8c724a5050301ad46450ecf3d35633e19a05814101f11ebd", "source_sha256": "0cfda5c5495fad1eb8cbf8562ac3b851f251f1a3645890dc28e6f870336a28b5", "target_language": "tcl"}
# gateway_transport.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/gateway_transport.py
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

# Gateway-authenticated transport with manager-owned attempt records.
#
# An attempt is saved before submission. If its outcome is uncertain, subsequent
# calls only query the same node and attempt; they do not submit it again.

package require http
package require json
package require uuid

# Custom exception handling
proc TransportUnresolved {msg} {
    error "TransportUnresolved: $msg"
}

proc gateway_token {} {
    # Use the local Gateway credential without changing its configuration.
    set token [expr {[info exists ::env(OPENCLAW_GATEWAY_TOKEN)] ? $::env(OPENCLAW_GATEWAY_TOKEN) : ""}]
    if {$token ne "" && [string trim $token] ne ""} {
        return [string trim $token]
    }
    
    set configPath ""
    if {[info exists ::env(OPENCLAW_CONFIG_PATH)] && $::env(OPENCLAW_CONFIG_PATH) ne ""} {
        set configPath $::env(OPENCLAW_CONFIG_PATH)
    } else {
        if {$::tcl_platform(platform) eq "windows"} {
            set home [expr {[info exists ::env(USERPROFILE)] ? $::env(USERPROFILE) : $::env(HOME)}]
            set configPath [file join $home .openclaw openclaw.json]
        } else {
            set configPath [file join $::env(HOME) .openclaw openclaw.json]
        }
    }
    
    if {[file exists $configPath]} {
        if {[catch {set fp [open $configPath r]}]} {
            return ""
        }
        if {[catch {set content [read $fp]}] || [catch {close $fp}]} {
            return ""
        }
        
        if {[catch {set config [::json::json2dict $content]}]} {
            return ""
        }
        
        if {[dict exists $config gateway auth token]} {
            set token [dict get $config gateway auth token]
            if {[string match "\${*}" $token]} {
                return ""
            }
            return [string trim $token]
        }
    }
    return ""
}

proc GatewayTransport {stateVar saveCmd url token args} {
    upvar $stateVar state
    
    # Parse options
    array set opts {-timeout 3900 -interval 3 -opener "" -clock "" -sleep ""}
    array set opts $args
    
    # Validate URL
    if {![regexp {^(https?)://([^/]+)(.*)$} $url -> scheme hostname path]} {
        error "invalid Gateway URL"
    }
    
    if {$scheme eq "http" && ![string match "127.0.0.1" $hostname] && 
        ![string match "localhost" $hostname] && ![string match "::1" $hostname]} {
        error "unencrypted Gateway must use loopback"
    }
    
    if {[string trim $token] eq "" || $opts(-timeout) <= 0 || $opts(-interval) <= 0} {
        error "Gateway token and positive timeouts required"
    }
    
    # Create transport object as namespace
    set transportNs [namespace current]::transport_[clock clicks]
    namespace eval $transportNs {}
    
    # Store configuration
    set ${transportNs}::stateVar $stateVar
    set ${transportNs}::saveCmd $saveCmd
    set ${transportNs}::url $url
    set ${transportNs}::token [string trim $token]
    set ${transportNs}::timeout $opts(-timeout)
    set ${transportNs}::interval $opts(-interval)
    set ${transportNs}::opener $opts(-opener)
    set ${transportNs}::clockCmd $opts(-clock)
    set ${transportNs}::sleepCmd $opts(-sleep)
    
    # Return command name for calling
    return $transportNs
}

proc ${transportNs}::_request {transportNs node request {device_id ""}} {
    upvar ${transportNs}::stateVar stateVar
    upvar $stateVar state
    
    set payload [::json::dict2json [dict create \
        node $node \
        device_id $device_id \
        request $request]]
    
    set headers [list Authorization "Bearer ${transportNs}::token" Content-Type "application/json"]
    
    set timeout 40
    if {$node eq "node4"} {
        set timeout 150
    }
    
    # Make HTTP request
    if {[catch {
        set tok [http::geturl ${transportNs}::url -headers $headers -query $payload -timeout [expr {$timeout * 1000}]]
        set status [http::status $tok]
        if {$status ne "ok"} {
            http::cleanup $tok
            error "HTTP request failed: $status"
        }
        set raw [http::data $tok]
        http::cleanup $tok
        
        if {[string length $raw] > 4000000} {
            error "response too large"
        }
        
        set data [::json::json2dict $raw]
        if {![dict exists $data result]} {
            error "invalid gateway response"
        }
        
        if {$device_id ne "" && [dict get $data device_id] ne $device_id} {
            error "gateway device identity mismatch"
        }
        
        return [dict get $data result]
    } err]} {
        TransportUnresolved "Gateway request failed: $err"
    }
}

proc ${transportNs}::available {transportNs} {
    if {[catch {
        set result [${transportNs}::_request $transportNs "node1" [dict create operation "availability"]]
        if {![dict size $result]} {
            TransportUnresolved "invalid node availability"
        }
        return $result
    } err]} {
        TransportUnresolved $err
    }
}

proc ${transportNs}::_release {transportNs original entry} {
    upvar ${transportNs}::stateVar stateVar
    upvar $stateVar state
    upvar ${transportNs}::saveCmd saveCmd
    
    if {[dict get $entry released]} {
        return
    }
    
    if {[catch {
        set result [${transportNs}::_request $transportNs [dict get $original selected_node] \
            [dict create operation "release" \
             job_id [dict get $original job_id] \
             attempt_id [dict get $original attempt_id]] \
            [dict get $original selected_device_id]]
    }]} {
        return ;# Retry cleanup later
    }
    
    if {[dict get $result status] eq "released" &&
        [dict get $result job_id] eq [dict get $original job_id] &&
        [dict get $result attempt_id] eq [dict get $original attempt_id] &&
        [dict get $result selected_node] eq [dict get $original selected_node] &&
        [dict get $result target_language] eq [dict get $original target_language]} {
        dict set entry released true
        uplevel #0 $saveCmd [list $state]
    }
}

proc ${transportNs}::release_pending {transportNs} {
    upvar ${transportNs}::stateVar stateVar
    upvar $stateVar state
    
    if {[dict exists $state auftraege]} {
        dict for {key entry} [dict get $state auftraege] {
            if {[dict get $entry status] in {"completed" "failed" "unknown"} &&
                [dict exists $entry job]} {
                ${transportNs}::_release $transportNs [dict get $entry job] $entry
            }
        }
    }
}

proc ${transportNs}::call {transportNs jobVar} {
    upvar $jobVar job
    upvar ${transportNs}::stateVar stateVar
    upvar $stateVar state
    upvar ${transportNs}::saveCmd saveCmd
    upvar ${transportNs}::timeout timeout
    upvar ${transportNs}::interval interval
    upvar ${transportNs}::clockCmd clockCmd
    upvar ${transportNs}::sleepCmd sleepCmd
    
    if {![dict exists $job source_sha256] || ![dict exists $job target_language] || 
        ![dict exists $job selected_device_id]} {
        error "missing source identity"
    }
    
    set key [dict get $job source_sha256]:[dict get $job target_language]
    
    if {![dict exists $state auftraege]} {
        dict set state auftraege [dict create]
    }
    
    set entries [dict get $state auftraege]
    set entry {}
    set fresh false
    
    if {[dict exists $entries $key]} {
        set entry [dict get $entries $key]
    } else {
        set fresh true
        dict set job attempt_id [::uuid::uuid generate]
        set original [dict create]
        dict for {k v} $job {
            dict set original $k $v
        }
        set entry [dict create job $original status "submitted"]
        dict set entries $key $entry
        dict set state auftraege $entries
        # If this write fails there must be no remote submission.
        uplevel #0 $saveCmd [list $state]
    }
    
    set original [dict get $entry job]
    # The dispatcher verifies the job object after transport returns.
    dict for {k v} $original {
        dict set job $k $v
    }
    
    if {[dict exists $entry response]} {
        ${transportNs}::_release $transportNs $original $entry
        return [dict get $entry response]
    }
    
    if {[dict exists $entry status] && [dict get $entry status] in {"failed" "unknown"}} {
        TransportUnresolved "attempt requires reconciliation"
    }
    
    set status {}
    
    if {$fresh} {
        if {[catch {
            set status [${transportNs}::_request $transportNs [dict get $original selected_node] \
                [dict create operation "execute" job $original] \
                [dict get $original selected_device_id]]
        }]} {
            # The request may have been accepted. Query, never resend.
        }
    }
    
    set deadline [expr {[clock seconds] + $timeout}]
    if {$clockCmd ne ""} {
        set deadline [expr {[$clockCmd] + $timeout}]
    }
    
    while {true} {
        if {$status eq ""} {
            set status [${transportNs}::_request $transportNs [dict get $original selected_node] \
                [dict create operation "status" \
                 job_id [dict get $original job_id] \
                 attempt_id [dict get $original attempt_id]] \
                [dict get $original selected_device_id]]
        }
        
        if {![dict size $status]} {
            TransportUnresolved "attempt is not known by the node"
        }
        
        foreach k {job_id attempt_id selected_node target_language} {
            if {[dict get $status $k] ne [dict get $original $k]} {
                TransportUnresolved "status identity mismatch"
            }
        }
        
        set state_status [dict get $status status]
        
        if {$state_status eq "completed"} {
            set response [dict get $status response]
            if {![dict exists $response status] || [dict get $response status] ne "ok" ||
                [dict get $response job_id] ne [dict get $original job_id] ||
                [dict get $response selected_node] ne [dict get $original selected_node] ||
                [dict get $response target_language] ne [dict get $original target_language] ||
                ![dict exists $response code] || [string trim [dict get $response code]] eq ""} {
                TransportUnresolved "invalid translation result"
            }
            
            dict set entry response $response
            dict set entry status "completed"
            dict set entries $key $entry
            dict set state auftraege $entries
            uplevel #0 $saveCmd [list $state]
            ${transportNs}::_release $transportNs $original $entry
            return $response
        }
        
        if {$state_status in {"failed" "unknown"}} {
            dict set entry status $state_status
            dict set entries $key $entry
            dict set state auftraege $entries
            uplevel #0 $saveCmd [list $state]
            ${transportNs}::_release $transportNs $original $entry
            TransportUnresolved "attempt requires reconciliation"
        }
        
        if {$state_status ne "running" || [clock seconds] >= $deadline} {
            if {$clockCmd ne "" && [$clockCmd] >= $deadline} {
                TransportUnresolved "attempt is unresolved"
            } elseif {$clockCmd eq "" && [clock seconds] >= $deadline} {
                TransportUnresolved "attempt is unresolved"
            }
        }
        
        if {$sleepCmd ne ""} {
            uplevel #0 $sleepCmd $interval
        } else {
            after [expr {$interval * 1000}]
        }
        
        set status {}
    }
}

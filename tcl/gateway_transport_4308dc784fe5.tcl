#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "292b3ab1070148c5d5028eef2cf66100e2b4ce3171f8a8543fb3024c4072946e", "source_sha256": "4e253f02b715d7d8ae256f0b72f993ca4646b5e466c1f39a9d5e2d3864a4fe77", "target_language": "tcl"}
# gateway_transport.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/gateway_transport.py
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

# Gateway-authenticated transport with manager-owned attempt records.
#
# An attempt is saved before submission. If its outcome is uncertain, subsequent
# calls only query the same node and attempt; they do not submit it again.

package require http
package require json
package require uuid

# Custom exception class equivalent
proc TransportUnresolved {message} {
    error $message
}

# Function to get gateway token
proc gateway_token {} {
    set token [expr {[info exists ::env(OPENCLAW_GATEWAY_TOKEN)] ? $::env(OPENCLAW_GATEWAY_TOKEN) : ""}]
    if {$token ne "" && [string trim $token] ne ""} {
        return [string trim $token]
    }
    
    set configPath ""
    if {[info exists ::env(OPENCLAW_CONFIG_PATH)] && $::env(OPENCLAW_CONFIG_PATH) ne ""} {
        set configPath $::env(OPENCLAW_CONFIG_PATH)
    } else {
        if {$::tcl_platform(platform) eq "windows"} {
            set homeDir $::env(USERPROFILE)
        } else {
            set homeDir $::env(HOME)
        }
        set configPath [file join $homeDir .openclaw openclaw.json]
    }
    
    if {![file exists $configPath]} {
        return ""
    }
    
    if {[catch {set fd [open $configPath r]}] || [catch {set content [read $fd]}] || [catch {close $fd}]} {
        return ""
    }
    
    if {[catch {set config [::json::json2dict $content]}]} {
        return ""
    }
    
    if {[dict exists $config gateway auth token]} {
        set token [dict get $config gateway auth token]
        if {[string isa string $token] && ![string match {\$*} $token]} {
            return [string trim $token]
        }
    }
    
    return ""
}

# GatewayTransport class implementation
oo::class create GatewayTransport {
    variable state save url token timeout interval opener clock sleep
    
    constructor {stateVar saveCmd urlStr tokenStr {timeoutVal 3900} {intervalVal 3} {openerCmd ""} {clockCmd ""} {sleepCmd ""}} {
        set state $stateVar
        set save $saveCmd
        set url $urlStr
        set token $tokenStr
        
        # Parse URL
        if {![regexp {^((https?):\/\/)?([^\/:]+)(:[0-9]+)?(.*)$} $urlStr -> scheme https hostname port path]} {
            error "invalid Gateway URL"
        }
        
        if {$scheme ne "http" && $scheme ne "https"} {
            error "invalid Gateway URL"
        }
        
        if {$scheme eq "http" && $hostname ni {127.0.0.1 localhost ::1}} {
            error "unencrypted Gateway must use loopback"
        }
        
        if {[string trim $token] eq "" || $timeoutVal <= 0 || $intervalVal <= 0} {
            error "Gateway token and positive timeouts required"
        }
        
        set timeout $timeoutVal
        set interval $intervalVal
        set opener [expr {$openerCmd eq "" ? "http::geturl" : $openerCmd}]
        set clock [expr {$clockCmd eq "" ? "clock seconds" : $clockCmd}]
        set sleep [expr {$sleepCmd eq "" ? "after" : $sleepCmd}]
    }
    
    method _request {node request {deviceId ""}} {
        set payload [::json::dict2json [dict create node $node device_id $deviceId request $request]]
        set headers [list Authorization "Bearer $token" Content-Type "application/json"]
        
        set opts [list -headers $headers -query $payload -timeout [expr {$node eq "node4" ? 150000 : 40000}]]
        
        if {[catch {set token [$opener $url {*}$opts]} err]} {
            TransportUnresolved "Gateway request failed: $err"
        }
        
        if {[catch {set raw [http::data $token]}] || [catch {http::cleanup $token}]} {
            TransportUnresolved "Gateway request failed"
        }
        
        if {[string length $raw] > 4000000} {
            TransportUnresolved "response too large"
        }
        
        if {[catch {set data [::json::json2dict $raw]}]} {
            TransportUnresolved "invalid gateway response"
        }
        
        if {![dict exists $data result]} {
            TransportUnresolved "invalid gateway response"
        }
        
        if {$deviceId ne "" && [dict exists $data device_id] && [dict get $data device_id] ne $deviceId} {
            TransportUnresolved "gateway device identity mismatch"
        }
        
        return [dict get $data result]
    }
    
    method available {} {
        set result [my _request node1 [dict create operation availability]]
        if {![dict size $result]} {
            TransportUnresolved "invalid node availability"
        }
        return $result
    }
    
    method _release {original entry} {
        if {[dict exists $entry released] && [dict get $entry released]} {
            return
        }
        
        if {[catch {
            set result [my _request [dict get $original selected_node] \
                [dict create operation release job_id [dict get $original job_id] \
                    attempt_id [dict get $original attempt_id]] \
                [dict get $original selected_device_id]]
        }]} {
            return ;# Retry cleanup later
        }
        
        if {[dict exists $result status] && [dict get $result status] eq "released" &&
            [dict get $result job_id] eq [dict get $original job_id] &&
            [dict get $result attempt_id] eq [dict get $original attempt_id] &&
            [dict get $result selected_node] eq [dict get $original selected_node] &&
            [dict get $result target_language] eq [dict get $original target_language]} {
            
            dict set entry released true
            {*}$save $state
        }
    }
    
    method release_pending {} {
        if {![dict exists $state auftraege]} {
            return
        }
        
        set auftraege [dict get $state auftraege]
        dict for {key entry} $auftraege {
            if {[dict exists $entry status] && 
                [dict get $entry status] in {completed rejected failed} &&
                [dict exists $entry job] && [dict size [dict get $entry job]]} {
                
                my _release [dict get $entry job] $entry
            }
        }
    }
    
    method reject {job reason} {
        if {![dict exists $job source_sha256] || ![dict exists $job target_language]} {
            error "missing source identity"
        }
        
        set key "[dict get $job source_sha256]:[dict get $job target_language]"
        
        if {![dict exists $state auftraege $key]} {
            return
        }
        
        set entry [dict get $state auftraege $key]
        if {![dict size $entry] || [dict get $entry status] ne "completed"} {
            return
        }
        
        if {[dict get $entry job attempt_id] ne [dict get $job attempt_id]} {
            TransportUnresolved "rejected attempt identity mismatch"
        }
        
        dict set entry status rejected
        dict set entry validation_error [string range $reason 0 499]
        {*}$save $state
    }
    
    method call {job} {
        upvar $job jobVar
        
        if {![dict exists $jobVar source_sha256] || 
            ![dict exists $jobVar target_language] || 
            ![dict exists $jobVar selected_device_id]} {
            error "missing source identity"
        }
        
        set key "[dict get $jobVar source_sha256]:[dict get $jobVar target_language]"
        
        if {![dict exists $state auftraege]} {
            dict set state auftraege [dict create]
        }
        
        set entries [dict get $state auftraege]
        set entry {}
        
        if {[dict exists $entries $key]} {
            set entry [dict get $entries $key]
        }
        
        if {[dict size $entry] && [dict get $entry status] eq "rejected"} {
            my _release [dict get $entry job] $entry
            
            if {![dict exists $entry released] || ![dict get $entry released]} {
                TransportUnresolved "rejected attempt release is unresolved"
            }
            
            set previous $entry
            set original [dict merge $jobVar [dict create attempt_id [::uuid::uuid generate]]]
            set entry [dict create job $original status submitted \
                previous_attempts [concat \
                    [expr {[dict exists $previous previous_attempts] ? [dict get $previous previous_attempts] : [list]}] \
                    [list [dict create job_id [dict get $previous job job_id] \
                        attempt_id [dict get $previous job attempt_id] \
                        selected_node [dict get $previous job selected_node] \
                        validation_error [dict get $previous validation_error]]]]]
            
            dict set entries $key $entry
            dict set state auftraege $entries
            {*}$save $state
            set fresh true
        } else {
            set fresh [expr {$entry eq ""}]
        }
        
        if {$entry eq ""} {
            set original [dict merge $jobVar [dict create attempt_id [::uuid::uuid generate]]]
            set entry [dict create job $original status submitted]
            dict set entries $key $entry
            dict set state auftraege $entries
            {*}$save $state
        }
        
        set original [dict get $entry job]
        set jobVar [dict merge $jobVar $original]
        
        if {[dict exists $entry response]} {
            my _release $original $entry
            return [dict get $entry response]
        }
        
        if {[dict exists $entry status] && [dict get $entry status] in {failed unknown}} {
            TransportUnresolved "attempt requires reconciliation"
        }
        
        set status {}
        if {$fresh} {
            if {[catch {
                set status [my _request [dict get $original selected_node] \
                    [dict create operation execute job $original] \
                    [dict get $original selected_device_id]]
            }]} {
                # The request may have been accepted. Query, never resend.
            }
        }
        
        set deadline [expr {[$clock] + $timeout}]
        
        while {true} {
            if {$status eq ""} {
                set status [my _request [dict get $original selected_node] \
                    [dict create operation status job_id [dict get $original job_id] \
                        attempt_id [dict get $original attempt_id]] \
                    [dict get $original selected_device_id]]
            }
            
            if {![dict size $status]} {
                TransportUnresolved "attempt is not known by the node"
            }
            
            if {[dict get $status job_id] ne [dict get $original job_id] ||
                [dict get $status attempt_id] ne [dict get $original attempt_id] ||
                [dict get $status selected_node] ne [dict get $original selected_node] ||
                [dict get $status target_language] ne [dict get $original target_language]} {
                TransportUnresolved "status identity mismatch"
            }
            
            set state_val [dict get $status status]
            
            if {$state_val eq "completed"} {
                set response [dict get $status response]
                
                if {![dict size $response] || 
                    [dict get $response status] ne "ok" ||
                    [dict get $response job_id] ne [dict get $original job_id] ||
                    [dict get $response selected_node] ne [dict get $original selected_node] ||
                    [dict get $response target_language] ne [dict get $original target_language] ||
                    ![dict exists $response code] ||
                    [string trim [dict get $response code]] eq ""} {
                    TransportUnresolved "invalid translation result"
                }
                
                dict set entry response $response
                dict set entry status completed
                {*}$save $state
                my _release $original $entry
                return $response
            }
            
            if {$state_val in {failed unknown}} {
                dict set entry status $state_val
                {*}$save $state
                if {$state_val eq "failed"} {
                    my _release $original $entry
                }
                TransportUnresolved "attempt requires reconciliation"
            }
            
            if {$state_val ne "running" || [$clock] >= $deadline} {
                TransportUnresolved "attempt is unresolved"
            }
            
            {*}$sleep [expr {int($interval * 1000)}]
            set status {}
        }
    }
}

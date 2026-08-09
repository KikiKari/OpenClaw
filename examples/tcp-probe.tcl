#!/usr/bin/env tclsh
# TCP port probe for OpenClaw gateway nodes

proc probe {host port {timeout 3000}} {
    set fd [socket -async $host $port]
    set done 0
    after $timeout [list set done -1]
    fileevent $fd writable [list set done 1]
    vwait done
    catch {close $fd}
    return [expr {$done == 1}]
}

set nodes [list {localhost 8080} {localhost 8081}]

foreach node $nodes {
    lassign $node host port
    if {[probe $host $port]} {
        puts "OK   $host:$port"
    } else {
        puts "FAIL $host:$port"
    }
}
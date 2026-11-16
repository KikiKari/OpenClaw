#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "0bff356618382eec38cf575cb52f5eae3d7b40593874e53d580d336cb5e7aa0c", "source_sha256": "08abd9802ec4316f1570b6eba8dd2d40356789759d4be8f3a0078e57999a841c", "target_language": "tcl"}
# check-gateway-watch-regression.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-gateway-watch-regression.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6
package require fileutil
package require cmdline
package require json
package require openclaw

# Default configuration values
array set DEFAULTS {
    outputDir {.local/gateway-watch-regression}
    windowMs 10000
    readyTimeoutMs 20000
    readySettleMs 500
    sigkillGraceMs 10000
    cpuWarnMs 1000
    cpuFailMs 8000
    distRuntimeFileGrowthMax 200
    distRuntimeByteGrowthMax 2097152
    keepLogs true
    skipBuild false
}

# Environment variables to skip certain services during watch
array set WATCH_GATEWAY_SKIP_ENV {
    OPENCLAW_DISABLE_BONJOUR 1
    OPENCLAW_SKIP_ACPX_RUNTIME 1
    OPENCLAW_SKIP_ACPX_RUNTIME_PROBE 1
    OPENCLAW_SKIP_BROWSER_CONTROL_SERVER 1
    OPENCLAW_SKIP_CANVAS_HOST 1
    OPENCLAW_SKIP_CHANNELS 1
    OPENCLAW_SKIP_CRON 1
    OPENCLAW_SKIP_GMAIL_WATCHER 1
}

proc parseArgs {argv} {
    global DEFAULTS
    
    array set options [array get DEFAULTS]
    
    for {set i 0} {$i < [llength $argv]} {incr i} {
        set arg [lindex $argv $i]
        set next [expr {$i+1 < [llength $argv] ? [lindex $argv [expr {$i+1}]] : ""}]
        
        proc readValue {} {
            upvar next next i i argv argv
            if {$next eq ""} {
                error "Missing value for $arg"
            }
            incr i
            return $next
        }
        
        switch -- $arg {
            --output-dir {
                set options(outputDir) [file normalize [readValue]]
            }
            --window-ms {
                set options(windowMs) [readValue]
            }
            --ready-timeout-ms {
                set options(readyTimeoutMs) [readValue]
            }
            --ready-settle-ms {
                set options(readySettleMs) [readValue]
            }
            --sigkill-grace-ms {
                set options(sigkillGraceMs) [readValue]
            }
            --cpu-warn-ms {
                set options(cpuWarnMs) [readValue]
            }
            --cpu-fail-ms {
                set options(cpuFailMs) [readValue]
            }
            --dist-runtime-file-growth-max {
                set options(distRuntimeFileGrowthMax) [readValue]
            }
            --dist-runtime-byte-growth-max {
                set options(distRuntimeByteGrowthMax) [readValue]
            }
            --skip-build {
                set options(skipBuild) true
            }
            default {
                error "Unknown argument: $arg"
            }
        }
    }
    
    return [array get options]
}

proc ensureDir {dirPath} {
    file mkdir $dirPath
}

proc removePathIfExists {targetPath} {
    if {[file exists $targetPath]} {
        file delete -force $targetPath
    }
}

proc normalizePath {filePath} {
    return [string map {\\ /} $filePath]
}

proc listTreeEntries {rootName} {
    set rootPath [file join [pwd] $rootName]
    if {![file exists $rootPath]} {
        return [list "${rootName} (missing)"]
    }
    
    set entries [list $rootName]
    set queue [list $rootPath]
    
    while {[llength $queue] > 0} {
        set current [lindex $queue end]
        set queue [lreplace $queue end end]
        
        if {$current eq ""} {
            continue
        }
        
        if {[catch {glob -nocomplain -directory $current *} dirents]} {
            continue
        }
        
        foreach dirent $dirents {
            set fullPath [file join $current [file tail $dirent]]
            set relativePath [normalizePath [file relative [pwd] $fullPath]]
            lappend entries $relativePath
            
            if {[file isdirectory $dirent]} {
                lappend queue $fullPath
            }
        }
    }
    
    return [lsort -dictionary $entries]
}

proc humanBytes {bytes} {
    if {$bytes < 1024} {
        return "${bytes}B"
    }
    if {$bytes < 1048576} {
        return [format "%.1fK" [expr {double($bytes) / 1024}]]
    }
    if {$bytes < 1073741824} {
        return [format "%.1fM" [expr {double($bytes) / 1048576}]]
    }
    return [format "%.1fG" [expr {double($bytes) / 1073741824}]]
}

proc snapshotTree {rootName} {
    set rootPath [file join [pwd] $rootName]
    array set stats {
        exists false
        files 0
        directories 0
        symlinks 0
        entries 0
        apparentBytes 0
    }
    
    if {![file exists $rootPath]} {
        return [array get stats]
    }
    
    set stats(exists) true
    set queue [list $rootPath]
    
    while {[llength $queue] > 0} {
        set current [lindex $queue end]
        set queue [lreplace $queue end end]
        
        if {$current eq ""} {
            continue
        }
        
        if {[catch {file lstat $current currentStats}]} {
            continue
        }
        
        incr stats(entries)
        
        if {[string match "*directory*" $currentStats(type)]} {
            incr stats(directories)
            if {[catch {glob -nocomplain -directory $current *} dirents]} {
                continue
            }
            foreach dirent $dirents {
                lappend queue [file join $current [file tail $dirent]]
            }
            continue
        }
        
        if {[string match "*link*" $currentStats(type)]} {
            incr stats(symlinks)
            continue
        }
        
        if {[string match "*file*" $currentStats(type)]} {
            incr stats(files)
            incr stats(apparentBytes) $currentStats(size)
        }
    }
    
    return [array get stats]
}

proc writeSnapshot {snapshotDir} {
    ensureDir $snapshotDir
    set pathEntries {}
    
    foreach entry [listTreeEntries "dist"] {
        lappend pathEntries $entry
    }
    foreach entry [listTreeEntries "dist-runtime"] {
        lappend pathEntries $entry
    }
    
    set pathsFile [open [file join $snapshotDir paths.txt] w]
    puts $pathsFile [join $pathEntries "\n"]
    close $pathsFile
    
    array set dist [snapshotTree "dist"]
    array set distRuntime [snapshotTree "dist-runtime"]
    
    set snapshot [dict create \
        generatedAt [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ" -gmt 1] \
        dist [array get dist] \
        distRuntime [array get distRuntime] \
    ]
    
    set snapshotFile [open [file join $snapshotDir snapshot.json] w]
    puts $snapshotFile [json::write object \
        generatedAt [dict get $snapshot generatedAt] \
        dist [dict get $snapshot dist] \
        distRuntime [dict get $snapshot distRuntime]]
    close $snapshotFile
    
    set statsFile [open [file join $snapshotDir stats.txt] w]
    puts $statsFile "generated_at: [dict get $snapshot generatedAt]"
    puts $statsFile ""
    puts $statsFile "\[dist\]"
    puts $statsFile "files: $dist(files)"
    puts $statsFile "directories: $dist(directories)"
    puts $statsFile "symlinks: $dist(symlinks)"
    puts $statsFile "entries: $dist(entries)"
    puts $statsFile "apparent_bytes: $dist(apparentBytes)"
    puts $statsFile "apparent_human: [humanBytes $dist(apparentBytes)]"
    puts $statsFile ""
    puts $statsFile "\[dist-runtime\]"
    puts $statsFile "files: $distRuntime(files)"
    puts $statsFile "directories: $distRuntime(directories)"
    puts $statsFile "symlinks: $distRuntime(symlinks)"
    puts $statsFile "entries: $distRuntime(entries)"
    puts $statsFile "apparent_bytes: $distRuntime(apparentBytes)"
    puts $statsFile "apparent_human: [humanBytes $distRuntime(apparentBytes)]"
    puts $statsFile ""
    close $statsFile
    
    return $snapshot
}

proc runCheckedCommand {command args} {
    if {[catch {exec $command {*}$args} result]} {
        error "$command [join $args " "] failed with status $result"
    }
}

proc parsePsCpuTimeMs {timeText} {
    set parts [split $timeText ":"]
    if {[llength $parts] < 2 || [llength $parts] > 3} {
        return ""
    }
    
    set seconds [lindex $parts end]
    set minutes [lindex $parts end-1]
    set hours 0
    
    if {[llength $parts] == 3} {
        set hours [lindex $parts 0]
    }
    
    if {![string is double $seconds] || ![string is double $minutes] || ![string is double $hours]} {
        return ""
    }
    
    return [expr {round((($hours * 60 * 60) + ($minutes * 60) + $seconds) * 1000)}]
}

proc readProcessTreeCpuMs {rootPid} {
    if {![string is integer $rootPid] || $rootPid <= 0} {
        return ""
    }
    
    if {[catch {exec ps -eo pid=,ppid=,time=} result]} {
        return ""
    }
    
    set rows {}
    foreach line [split $result "\n"] {
        set line [string trim $line]
        if {[regexp {^(\d+)\s+(\d+)\s+(\S+)$} $line -> pid ppid cpuTime]} {
            set cpuMs [parsePsCpuTimeMs $cpuTime]
            if {$cpuMs ne ""} {
                lappend rows [list pid $pid ppid $ppid cpuMs $cpuMs]
            }
        }
    }
    
    array set childrenByParent {}
    array set cpuByPid {}
    
    foreach row $rows {
        array set rowData $row
        set cpuByPid($rowData(pid)) $rowData(cpuMs)
        if {![info exists childrenByParent($rowData(ppid))]} {
            set childrenByParent($rowData(ppid)) {}
        }
        lappend childrenByParent($rowData(ppid)) $rowData(pid)
    }
    
    if {![info exists cpuByPid($rootPid)]} {
        return ""
    }
    
    set totalCpuMs 0
    set seen {}
    set stack [list $rootPid]
    
    while {[llength $stack] > 0} {
        set pid [lindex $stack end]
        set stack [lreplace $stack end end]
        
        if {$pid eq "" || [lsearch $seen $pid] >= 0} {
            continue
        }
        
        lappend seen $pid
        if {[info exists cpuByPid($pid)]} {
            incr totalCpuMs $cpuByPid($pid)
        }
        
        if {[info exists childrenByParent($pid)]} {
            foreach childPid $childrenByParent($pid) {
                lappend stack $childPid
            }
        }
    }
    
    return $totalCpuMs
}

proc waitForGatewayReady {readText timeoutMs} {
    set deadline [expr {[clock milliseconds] + $timeoutMs}]
    while {[clock milliseconds] < $deadline} {
        if {[regexp {\[gateway\] ready \(} [$readText]]} {
            return true
        }
        after 100
    }
    return false
}

proc allocateLoopbackPort {} {
    # Create a temporary server to get an available port
    set sock [socket -server {} 0 localhost]
    set port [lindex [fconfigure $sock -sockname] 2]
    close $sock
    return $port
}

proc buildTimedWatchCommand {pidFilePath timeFilePath isolatedHomeDir port} {
    global WATCH_GATEWAY_SKIP_ENV
    
    set shellSource "echo \$\$ > $pidFilePath
mkdir -p $isolatedHomeDir/.openclaw
printf '{\"gateway\":{\"controlUi\":{\"enabled\":false}}}' > $isolatedHomeDir/.openclaw/openclaw.json
exec node scripts/watch-node.mjs gateway --force --allow-unconfigured --port $port --token watch-regression-token"
    
    set envVars [array get WATCH_GATEWAY_SKIP_ENV]
    lappend envVars HOME $isolatedHomeDir
    lappend envVars OPENCLAW_HOME $isolatedHomeDir
    lappend envVars OPENCLAW_WATCH_PID_FILE $pidFilePath
    
    if {$::tcl_platform(platform) eq "unix"} {
        return [list \
            command "/usr/bin/time" \
            args [list -lp -o $timeFilePath /bin/sh -lc $shellSource] \
            env $envVars]
    } else {
        return [list \
            command "/usr/bin/time" \
            args [list -f "__TIMING__ user=%U sys=%S elapsed=%e" -o $timeFilePath /bin/sh -lc $shellSource] \
            env $envVars]
    }
}

proc parseTimingFile {timeFilePath} {
    if {![file exists $timeFilePath]} {
        return [list userSeconds NaN sysSeconds NaN elapsedSeconds NaN]
    }
    
    set fp [open $timeFilePath r]
    set text [read $fp]
    close $fp
    
    if {$::tcl_platform(platform) eq "unix"} {
        set user [regexp -line {^user\s+([0-9.]+)} $text -> userMatch]
        set sys [regexp -line {^sys\s+([0-9.]+)} $text -> sysMatch]
        set elapsed [regexp -line {^real\s+([0-9.]+)} $text -> elapsedMatch]
        return [list userSeconds [expr {$user ? $userMatch : "NaN"}] sysSeconds [expr {$sys ? $sysMatch : "NaN"}] elapsedSeconds [expr {$elapsed ? $elapsedMatch : "NaN"}]]
    } else {
        if {[regexp {__TIMING__ user=([0-9.]+) sys=([0-9.]+) elapsed=([0-9.]+)} $text -> user sys elapsed]} {
            return [list userSeconds $user sysSeconds $sys elapsedSeconds $elapsed]
        } else {
            return [list userSeconds NaN sysSeconds NaN elapsedSeconds NaN]
        }
    }
}

proc runTimedWatch {options outputDir} {
    set pidFilePath [file join $outputDir watch.pid]
    set timeFilePath [file join $outputDir watch.time.log]
    set isolatedHomeDir [fileutil::tempfile openclaw-gateway-watch-]
    set homeFile [open [file join $outputDir watch.home.txt] w]
    puts $homeFile $isolatedHomeDir
    close $homeFile
    
    set stdoutPath [file join $outputDir watch.stdout.log]
    set stderrPath [file join $outputDir watch.stderr.log]
    
    foreach stalePath [list $pidFilePath $timeFilePath $stdoutPath $stderrPath] {
        removePathIfExists $stalePath
    }
    
    set port [allocateLoopbackPort]
    set portFile [open [file join $outputDir watch.port.txt] w]
    puts $portFile $port
    close $portFile
    
    array set cmdInfo [buildTimedWatchCommand $pidFilePath $timeFilePath $isolatedHomeDir $port]
    
    set stdout ""
    set stderr ""
    
    if {[catch {open "|$cmdInfo(command) {*}$cmdInfo(args)" r} pipe]} {
        error "Failed to start watch process: $pipe"
    }
    
    fconfigure $pipe -buffering line
    fileevent $pipe readable [list appendStdout stderr stdout $pipe]
    
    set exitCode 0
    set exitSignal ""
    
    vwait done
    
    set watchPid ""
    for {set attempt 0} {$attempt < 50} {incr attempt} {
        if {[file exists $pidFilePath]} {
            set fp [open $pidFilePath r]
            set watchPid [string trim [read $fp]]
            close $fp
            break
        }
        after 100
    }
    
    set readyBeforeWindow [waitForGatewayReady [list readOutput $stdout $stderr] $options(readyTimeoutMs)]
    if {$readyBeforeWindow && $options(readySettleMs) > 0} {
        after $options(readySettleMs)
    }
    
    set idleCpuStartMs [expr {$watchPid ne "" ? [readProcessTreeCpuMs $watchPid] : ""}]
    after $options(windowMs)
    set idleCpuEndMs [expr {$watchPid ne "" ? [readProcessTreeCpuMs $watchPid] : ""}]
    
    if {$watchPid ne ""} {
        if {[catch {exec kill -TERM $watchPid}]} {
            # Ignore errors
        }
    }
    
    set gracefulExit ""
    after $options(sigkillGraceMs)
    
    if {$gracefulExit eq ""} {
        if {$watchPid ne ""} {
            if {[catch {exec kill -KILL $watchPid}]} {
                # Ignore errors
            }
        }
    }
    
    set stdoutFile [open $stdoutPath w]
    puts $stdoutFile $stdout
    close $stdoutFile
    
    set stderrFile [open $stderrPath w]
    puts $stderrFile $stderr
    close $stderrFile
    
    array set timing [parseTimingFile $timeFilePath]
    
    return [list \
        exit [list code $exitCode signal $exitSignal] \
        timing [array get timing] \
        readyBeforeWindow $readyBeforeWindow \
        idleCpuMs [expr {$idleCpuStartMs ne "" && $idleCpuEndMs ne "" ? max(0, $idleCpuEndMs - $idleCpuStartMs) : ""}] \
        stdoutPath $stdoutPath \
        stderrPath $stderrPath \
        timeFilePath $timeFilePath]
}

proc parsePathFile {filePath} {
    set fp [open $filePath r]
    set content [read $fp]
    close $fp
    return [lmap line [split $content "\n"] {string trimright $line}]
}

proc writeDiffArtifacts {outputDir preDir postDir} {
    set diffDir [file join $outputDir diff]
    ensureDir $diffDir
    
    set prePaths [parsePathFile [file join $preDir paths.txt]]
    set postPaths [parsePathFile [file join $postDir paths.txt]]
    
    set preSet [dict create]
    foreach entry $prePaths {
        dict set preSet $entry 1
    }
    
    set postSet [dict create]
    foreach entry $postPaths {
        dict set postSet $entry 1
    }
    
    set added {}
    foreach entry $postPaths {
        if {![dict exists $preSet $entry]} {
            lappend added $entry
        }
    }
    
    set removed {}
    foreach entry $prePaths {
        if {![dict exists $postSet $entry]} {
            lappend removed $entry
        }
    }
    
    set addedFile [open [file join $diffDir added-paths.txt] w]
    puts $addedFile [join $added "\n"]
    close $addedFile
    
    set removedFile [open [file join $diffDir removed-paths.txt] w]
    puts $removedFile [join $removed "\n"]
    close $removedFile
    
    return [list added $added removed $removed]
}

proc fail {message} {
    puts stderr "FAIL: $message"
}

proc warn {message} {
    puts stderr "WARN: $message"
}

proc detectWatchBuildReason {stdout stderr} {
    set combined "$stdout\n$stderr"
    if {[regexp {Building TypeScript \(dist is stale: ([a-z_]+)} $combined -> reason]} {
        return $reason
    }
    return ""
}

proc buildRunNodeDeps {env} {
    set cwd [pwd]
    return [list \
        cwd $cwd \
        env $env \
        distRoot [file join $cwd dist] \
        distEntry [file join $cwd dist entry.js] \
        buildStampPath [file join $cwd dist .buildstamp] \
        sourceRoots [list \
            [list name src path [file join $cwd src]] \
            [list name extensions path [file join $cwd extensions]]] \
        configFiles [list \
            [file join $cwd tsconfig.json] \
            [file join $cwd package.json] \
            [file join $cwd tsdown.config.ts]]]
}

proc main {} {
    global DEFAULTS
    
    set optionsArray [parseArgs $::argv]
    array set options $optionsArray
    
    ensureDir $options(outputDir)
    
    if {!$options(skipBuild)} {
        runCheckedCommand pnpm build
        # The watch harness must start from a completed-build baseline. Refresh
        # the build stamp after the full build pipeline finishes so run-node does
        # not spuriously rebuild inside the bounded watch window.
        writeBuildStamp [pwd]
    }
    
    set preflightBuildRequirement [resolveBuildRequirement [buildRunNodeDeps [array get ::env]]]
    if {[dict get $preflightBuildRequirement shouldBuild] && 
        [dict get $preflightBuildRequirement reason] eq "dirty_watched_tree"} {
        set summary [dict create \
            windowMs $options(windowMs) \
            invalidated true \
            invalidationReason [dict get $preflightBuildRequirement reason] \
            invalidationMessage "gateway-watch-regression cannot run on a dirty watched tree because run-node will intentionally rebuild during the watch window."]
        
        set summaryFile [open [file join $options(outputDir) summary.json] w]
        puts $summaryFile [json::write object {*}$summary]
        close $summaryFile
        
        puts [json::write object {*}$summary]
        fail "gateway-watch-regression invalid local run: dirty watched source tree would force a rebuild inside the watch window"
        exit 1
    }
    
    set preDir [file join $options(outputDir) pre]
    set pre [writeSnapshot $preDir]
    
    set watchDir [file join $options(outputDir) watch]
    ensureDir $watchDir
    set watchResult [runTimedWatch [array get options] $watchDir]
    
    set postDir [file join $options(outputDir) post]
    set post [writeSnapshot $postDir]
    set diff [writeDiffArtifacts $options(outputDir) $preDir $postDir]
    
    array set preDistRuntime [dict get $pre distRuntime]
    array set postDistRuntime [dict get $post distRuntime]
    
    set distRuntimeFileGrowth [expr {$postDistRuntime(files) - $preDistRuntime(files)}]
    set distRuntimeByteGrowth [expr {$postDistRuntime(apparentBytes) - $preDistRuntime(apparentBytes)}]
    
    set distRuntimeAddedPaths 0
    foreach entry [dict get $diff added] {
        if {[string match "dist-runtime/*" $entry]} {
            incr distRuntimeAddedPaths
        }
    }
    
    array set timing [dict get $watchResult timing]
    set totalCpuMs [expr {round(($timing(userSeconds) + $timing(sysSeconds)) * 1000)}]
    set cpuMs [expr {[dict get $watchResult idleCpuMs] ne "" ? [dict get $watchResult idleCpuMs] : $totalCpuMs}]
    
    set stderrContent [readFile [dict get $watchResult stderrPath]]
    set stdoutContent [readFile [dict get $watchResult stdoutPath]]
    set watchTriggeredBuild [expr {[string first "Building TypeScript (dist is stale" $stderrContent] >= 0 || 
                                   [string first "Building TypeScript (dist is stale" $stdoutContent] >= 0}]
                                   
    set watchBuildReason [detectWatchBuildReason $stdoutContent $stderrContent]
    
    set summary [dict create \
        windowMs $options(windowMs) \
        watchTriggeredBuild $watchTriggeredBuild \
        watchBuildReason $watchBuildReason \
        cpuMs $cpuMs \
        totalCpuMs $totalCpuMs \
        readyBeforeWindow [dict get $watchResult readyBeforeWindow] \
        cpuWarnMs $options(cpuWarnMs) \
        cpuFailMs $options(cpuFailMs) \
        distRuntimeFileGrowth $distRuntimeFileGrowth \
        distRuntimeFileGrowthMax $options(distRuntimeFileGrowthMax) \
        distRuntimeByteGrowth $distRuntimeByteGrowth \
        distRuntimeByteGrowthMax $options(distRuntimeByteGrowthMax) \
        distRuntimeAddedPaths $distRuntimeAddedPaths \
        addedPaths [llength [dict get $diff added]] \
        removedPaths [llength [dict get $diff removed]] \
        watchExit [dict get $watchResult exit] \
        timing [dict get $watchResult timing]]
    
    set summaryFile [open [file join $options(outputDir) summary.json] w]
    puts $summaryFile [json::write object {*}$summary]
    close $summaryFile
    
    puts [json::write object {*}$summary]
    
    set failures {}
    set warnings {}
    
    if {$watchTriggeredBuild && $watchBuildReason eq "dirty_watched_tree"} {
        lappend failures "gateway:watch invalid local run: dirty watched source tree forced a rebuild during the watch window"
    }
    
    if {$distRuntimeFileGrowth > $options(distRuntimeFileGrowthMax)} {
        lappend failures "dist-runtime file growth $distRuntimeFileGrowth exceeded max $options(distRuntimeFileGrowthMax)"
    }
    
    if {$distRuntimeByteGrowth > $options(distRuntimeByteGrowthMax)} {
        lappend failures "dist-runtime apparent byte growth $distRuntimeByteGrowth exceeded max $options(distRuntimeByteGrowthMax)"
    }
    
    if {![string is double $cpuMs]} {
        lappend failures "failed to parse CPU timing from the bounded gateway:watch run"
    } elseif {$cpuMs > $options(cpuFailMs)} {
        lappend failures "LOUD ALARM: gateway:watch used ${cpuMs}ms CPU in $options(windowMs)ms window, above loud-alarm threshold $options(cpuFailMs)ms"
    } elseif {$cpuMs > $options(cpuWarnMs)} {
        lappend warnings "gateway:watch used ${cpuMs}ms CPU in $options(windowMs)ms window, above target $options(cpuWarnMs)ms"
    }
    
    foreach message $warnings {
        warn $message
    }
    
    if {[llength $failures] > 0} {
        foreach message $failures {
            fail $message
        }
        if {![allContain $failures "dirty watched source tree"]} {
            fail "Possible duplicate dist-runtime graph regression: this can reintroduce split runtime personalities where plugins and core observe different global state, including Telegram missing /voice, /phone, or /pair."
        }
        exit 1
    }
    
    exit 0
}

proc readFile {filename} {
    set fp [open $filename r]
    set content [read $fp]
    close $fp
    return $content
}

proc allContain {list substring} {
    foreach item $list {
        if {[string first $substring $item] < 0} {
            return 0
        }
    }
    return 1
}

main

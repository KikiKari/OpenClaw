#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "c2c782a8240ed37874730ce889a577e9af79df0d3ccc6672e4a83d3be847761f", "source_sha256": "d3c03c21143a83c5721fdec0e2390424f9c499b86d0c2744a94c154b1be4b2bc", "target_language": "tcl"}
# check-extension-package-tsc-boundary.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-extension-package-tsc-boundary.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6
package require fileutil
package require json
package require json::write

# Global variables
set repoRoot [file normalize [file dirname [info script]]]/..
set tscBin [file normalize $repoRoot/node_modules/typescript/bin/tsc]
set prepareBoundaryArtifactsBin [file normalize $repoRoot/scripts/prepare-extension-package-boundary-artifacts.mjs]
set extensionPackageBoundaryBaseConfig "../tsconfig.package-boundary.base.json"
set FAILURE_OUTPUT_TAIL_LINES 40
set SLOW_COMPILE_SUMMARY_LIMIT 10
array set COMPILE_INPUT_EXTENSIONS [list .ts 1 .tsx 1 .mts 1 .cts 1 .js 1 .mjs 1 .json 1]
set ROOTDIR_BOUNDARY_CANARY_IMPORT_PATH "../../src/plugins/contracts/rootdir-boundary-canary.ts"
set ROOTDIR_BOUNDARY_CANARY_OUTPUT_HINT "src/plugins/contracts/rootdir-boundary-canary.ts"

proc parseMode {argv} {
    foreach arg $argv {
        if {[string match "--mode=*" $arg]} {
            set mode [string range $arg 7 end]
            if {$mode ni {"all" "compile" "canary"}} {
                error "Unknown mode: $mode"
            }
            return $mode
        }
    }
    return "all"
}

proc resolveCompileConcurrency {} {
    set raw $::env(OPENCLAW_EXTENSION_BOUNDARY_CONCURRENCY)
    if {[string is integer -strict $raw] && $raw > 0} {
        return $raw
    }
    # Simulate os.availableParallelism() with a fixed value or detect CPU count
    set cpuCount [expr {[catch {exec nproc}] ? 4 : [exec nproc]}]
    return [expr {max(1, min(6, $cpuCount / 2))}]
}

proc readJsonFile {filePath} {
    set fd [open $filePath r]
    set content [read $fd]
    close $fd
    return [::json::json2dict $content]
}

proc summarizeOutputSection {name output} {
    set trimmed [string trim $output]
    if {$trimmed eq ""} {
        return ""
    }

    set lines [split $trimmed "\n"]
    if {[llength $lines] <= $::FAILURE_OUTPUT_TAIL_LINES} {
        return "$name:\n$trimmed"
    }

    set omittedLineCount [expr {[llength $lines] - $::FAILURE_OUTPUT_TAIL_LINES}]
    set tail [join [lrange $lines end-[expr {$::FAILURE_OUTPUT_TAIL_LINES-1}] end] "\n"]
    return "$name:\n\[... $omittedLineCount earlier lines omitted ...\]\n$tail"
}

proc formatFailureFooter {params} {
    set footerLines {}
    if {[dict exists $params kind]} {
        lappend footerLines "kind: [dict get $params kind]"
    }
    if {[dict exists $params elapsedMs] && [string is double -strict [dict get $params elapsedMs]]} {
        lappend footerLines "elapsed: [dict get $params elapsedMs]ms"
    }
    if {[dict exists $params note]} {
        lappend footerLines [dict get $params note]
    }
    return [join $footerLines "\n"]
}

proc formatBoundaryCheckSuccessSummary {{params {}}} {
    set lines [list "extension package boundary check passed"]
    if {[dict exists $params mode]} {
        lappend lines "mode: [dict get $params mode]"
    }
    if {[dict exists $params compileCount] && [string is integer -strict [dict get $params compileCount]]} {
        lappend lines "compiled plugins: [dict get $params compileCount]"
    }
    if {[dict exists $params skippedCompileCount] && [dict get $params skippedCompileCount] > 0} {
        lappend lines "skipped plugins: [dict get $params skippedCompileCount]"
    }
    if {[dict exists $params canaryCount] && [string is integer -strict [dict get $params canaryCount]]} {
        lappend lines "canary plugins: [dict get $params canaryCount]"
    }
    if {[dict exists $params prepElapsedMs] && [dict get $params prepElapsedMs] > 0} {
        lappend lines "prep elapsed: [dict get $params prepElapsedMs]ms"
    }
    if {[dict exists $params compileElapsedMs] && [dict get $params compileElapsedMs] > 0} {
        lappend lines "compile elapsed: [dict get $params compileElapsedMs]ms"
    }
    if {[dict exists $params canaryElapsedMs] && [dict get $params canaryElapsedMs] > 0} {
        lappend lines "canary elapsed: [dict get $params canaryElapsedMs]ms"
    }
    if {[dict exists $params elapsedMs]} {
        lappend lines "elapsed: [dict get $params elapsedMs]ms"
    }
    return [join $lines "\n"]\n
}

proc formatSkippedCompileProgress {{params {}}} {
    set skippedCount [expr {[dict exists $params skippedCount] ? [dict get $params skippedCount] : 0}]
    set totalCount [expr {[dict exists $params totalCount] ? [dict get $params totalCount] : 0}]
    if {![string is integer -strict $skippedCount] || $skippedCount <= 0} {
        return ""
    }

    set staleCount [expr {max(0, $totalCount - $skippedCount)}]
    if {$staleCount > 0} {
        return "skipped $skippedCount fresh plugin compiles before running $staleCount stale plugin checks\n"
    }
    return "skipped $skippedCount fresh plugin compiles\n"
}

proc formatSlowCompileSummary {{params {}}} {
    set compileTimings [expr {[dict exists $params compileTimings] ? [dict get $params compileTimings] : {}}]
    if {[llength $compileTimings] == 0} {
        return ""
    }

    set limit [expr {[dict exists $params limit] && [string is integer -strict [dict get $params limit]] && [dict get $params limit] > 0 ? [dict get $params limit] : $::SLOW_COMPILE_SUMMARY_LIMIT}]
    set lines [list "slowest plugin compiles:"]
    
    # Sort timings by elapsedMs descending
    set sortedTimings [lsort -decreasing -real -index 1 $compileTimings]
    set limitedTimings [lrange $sortedTimings 0 [expr {$limit - 1}]]
    
    foreach timing $limitedTimings {
        lappend lines "- [lindex $timing 0]: [lindex $timing 1]ms"
    }
    return [join $lines "\n"]\n
}

proc formatStepFailure {label params} {
    set stdoutSection [summarizeOutputSection "stdout" [dict get $params stdout]]
    set stderrSection [summarizeOutputSection "stderr" [dict get $params stderr]]
    set footer [formatFailureFooter $params]
    set parts [list $label]
    if {$stdoutSection ne ""} {lappend parts $stdoutSection}
    if {$stderrSection ne ""} {lappend parts $stderrSection}
    if {$footer ne ""} {lappend parts $footer}
    return [join $parts "\n\n"]
}

proc attachStepFailureMetadata {error label params} {
    dict set error stepLabel $label
    dict set error kind [expr {[dict exists $params kind] ? [dict get $params kind] : "unknown"}]
    dict set error elapsedMs [expr {[dict exists $params elapsedMs] ? [dict get $params elapsedMs] : "null"}]
    set fullOutput [list $label]
    if {[dict exists $params stdout]} {lappend fullOutput [dict get $params stdout]}
    if {[dict exists $params stderr]} {lappend fullOutput [dict get $params stderr]}
    lappend fullOutput [formatFailureFooter $params]
    dict set error fullOutput [string trim [join $fullOutput "\n"]]
    return $error
}

proc collectBundledExtensionIds {} {
    set extensionsDir [file join $::repoRoot extensions]
    set entries [glob -directory $extensionsDir -types d *]
    set names {}
    foreach entry $entries {
        lappend names [file tail $entry]
    }
    return [lsort $names]
}

proc resolveExtensionTsconfigPath {extensionId} {
    return [file join $::repoRoot extensions $extensionId tsconfig.json]
}

proc readExtensionTsconfig {extensionId} {
    return [readJsonFile [resolveExtensionTsconfigPath $extensionId]]
}

proc collectOptInExtensionIds {} {
    set result {}
    foreach extensionId [collectBundledExtensionIds] {
        set tsconfigPath [resolveExtensionTsconfigPath $extensionId]
        if {[file exists $tsconfigPath]} {
            set config [readExtensionTsconfig $extensionId]
            if {[dict exists $config extends] && [dict get $config extends] eq $::extensionPackageBoundaryBaseConfig} {
                lappend result $extensionId
            }
        }
    }
    return $result
}

proc collectCanaryExtensionIds {extensionIds} {
    set uniqueConfigs {}
    set resultMap {}
    foreach extensionId $extensionIds {
        set config [readExtensionTsconfig $extensionId]
        set key [::json::write::write $config]
        dict set resultMap $key $extensionId
    }
    return [dict values $resultMap]
}

proc isRelevantCompileInput {filePath} {
    set basename [file tail $filePath]
    if {$basename in {"__rootdir_boundary_canary__.ts" "tsconfig.rootdir-canary.json"}} {
        return 0
    }
    if {[string match "*.tsbuildinfo" $basename]} {
        return 0
    }
    set ext [file extension $filePath]
    return [info exists ::COMPILE_INPUT_EXTENSIONS($ext)]
}

proc collectNewestMtime {entryPath {params {}}} {
    set includeFile [expr {[dict exists $params includeFile] ? [dict get $params includeFile] : {return 1}}]
    set skipDistDirectories [expr {[dict exists $params skipDistDirectories] ? [dict get $params skipDistDirectories] : 1}]
    set newestMtimeMs 0

    proc visit {currentPath includeFile skipDistDirectories newestMtimeMsVar} {
        upvar $newestMtimeMsVar newestMtimeMs
        if {![file exists $currentPath]} {
            return
        }
        set stats [file stat $currentPath]
        if {[file isdirectory $currentPath]} {
            set basename [file tail $currentPath]
            if {($skipDistDirectories && $basename eq "dist") || $basename eq "node_modules"} {
                return
            }
            foreach child [glob -nocomplain -directory $currentPath *] {
                visit $child $includeFile $skipDistDirectories newestMtimeMs
            }
            return
        }
        if {![{*}$includeFile $currentPath]} {
            return
        }
        set newestMtimeMs [expr {max($newestMtimeMs, $stats(mtime) * 1000)}]
    }

    visit $entryPath $includeFile $skipDistDirectories newestMtimeMs
    return $newestMtimeMs
}

proc collectOldestMtime {paths} {
    set oldestMtimeMs Inf

    foreach entryPath $paths {
        if {![file exists $entryPath]} {
            return {}
        }
        set stats [file stat $entryPath]
        set oldestMtimeMs [expr {min($oldestMtimeMs, $stats(mtime) * 1000)}]
    }

    return [expr {isfinite($oldestMtimeMs) ? $oldestMtimeMs : {}}]
}

proc isBoundaryCompileFresh {extensionId {params {}}} {
    set rootDir [expr {[dict exists $params rootDir] ? [dict get $params rootDir] : $::repoRoot}]
    set extensionRoot [file join $rootDir extensions $extensionId]
    set extensionNewestInputMtimeMs [expr {[dict exists $params extensionNewestInputMtimeMs] ? [dict get $params extensionNewestInputMtimeMs] : [collectNewestMtime $extensionRoot [dict create includeFile isRelevantCompileInput]]}]
    set sharedNewestInputMtimeMs [expr {[dict exists $params sharedNewestInputMtimeMs] ? [dict get $params sharedNewestInputMtimeMs] : [expr {max([collectNewestMtime [file join $rootDir dist plugin-sdk] [dict create skipDistDirectories 0]], [collectNewestMtime [file join $rootDir packages plugin-sdk dist] [dict create skipDistDirectories 0]])}]}]
    set newestInputMtimeMs [expr {max($extensionNewestInputMtimeMs, $sharedNewestInputMtimeMs)}]
    set oldestOutputMtimeMs [collectOldestMtime [list [resolveBoundaryTsStampPath $extensionId $rootDir]]]
    return [expr {$oldestOutputMtimeMs ne {} && $oldestOutputMtimeMs >= $newestInputMtimeMs}]
}

proc writeStampFile {filePath} {
    file mkdir [file dirname $filePath]
    set fd [open $filePath w]
    puts $fd [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ"]
    close $fd
}

proc runNodeStep {label args timeoutMs} {
    set startedAt [clock milliseconds]
    set cmd [list exec node {*}$args]
    if {[catch {exec {*}$cmd} result]} {
        set elapsedMs [expr {[clock milliseconds] - $startedAt}]
        set kind "nonzero-exit"
        set note ""
        set error [attachStepFailureMetadata [formatStepFailure $label [dict create stdout "" stderr $result kind $kind elapsedMs $elapsedMs note $note]] $label [dict create stdout "" stderr $result kind $kind elapsedMs $elapsedMs note $note]]
        dict set error status 1
        error $error
    }
    return $result
}

proc abortSiblingSteps {abortController} {
    # In Tcl we don't have AbortController equivalent, so this is a no-op
}

proc runNodeStepAsync {label args timeoutMs params} {
    set abortController [dict get $params abortController]
    set onFailure [dict get $params onFailure]
    set startedAt [clock milliseconds]
    
    # This would need to be implemented with proper async handling in Tcl
    # For now, we'll simulate it synchronously
    set cmd [list exec node {*}$args]
    if {[catch {exec {*}$cmd} result]} {
        set elapsedMs [expr {[clock milliseconds] - $startedAt}]
        set kind "nonzero-exit"
        set error [attachStepFailureMetadata [formatStepFailure $label [dict create stdout "" stderr $result kind $kind elapsedMs $elapsedMs]] $label [dict create stdout "" stderr $result kind $kind elapsedMs $elapsedMs]]
        {*}$onFailure $error
        abortSiblingSteps $abortController
        error $error
    }
    return [dict create stdout "" stderr $result elapsedMs [expr {[clock milliseconds] - $startedAt}]]
}

proc runNodeStepsWithConcurrency {steps concurrency} {
    # Simplified synchronous implementation
    set firstFailure {}
    foreach step $steps {
        if {[dict exists $step onStart]} {
            {*}[dict get $step onStart]
        }
        if {[catch {
            set result [runNodeStepAsync [dict get $step label] {*}[dict get $step args] [dict get $step timeoutMs] [dict create]]
            if {[dict exists $step onSuccess]} {
                {*}[dict get $step onSuccess] $result
            }
        } error]} {
            if {$firstFailure eq {}} {
                set firstFailure $error
            }
        }
    }
    if {$firstFailure ne {}} {
        error $firstFailure
    }
}

proc resolveCanaryArtifactPaths {extensionId {rootDir $::repoRoot}} {
    set extensionRoot [file join $rootDir extensions $extensionId]
    return [dict create \
        extensionRoot $extensionRoot \
        canaryPath [file join $extensionRoot "__rootdir_boundary_canary__.ts"] \
        tsconfigPath [file join $extensionRoot "tsconfig.rootdir-canary.json"]]
}

proc cleanupCanaryArtifacts {extensionId {rootDir $::repoRoot}} {
    set paths [resolveCanaryArtifactPaths $extensionId $rootDir]
    set canaryPath [dict get $paths canaryPath]
    set tsconfigPath [dict get $paths tsconfigPath]
    file delete -force $canaryPath
    file delete -force $tsconfigPath
}

proc cleanupCanaryArtifactsForExtensions {extensionIds {rootDir $::repoRoot}} {
    foreach extensionId $extensionIds {
        cleanupCanaryArtifacts $extensionId $rootDir
    }
}

proc installCanaryArtifactCleanup {extensionIds params} {
    set rootDir [expr {[dict exists $params rootDir] ? [dict get $params rootDir] : $::repoRoot}]
    set processObject [expr {[dict exists $params processObject] ? [dict get $params processObject] : "process"}]
    
    proc exitHandler {extensionIds rootDir} {
        cleanupCanaryArtifactsForExtensions $extensionIds $rootDir
    }
    
    # Register exit handler (Tcl doesn't have built-in process.on)
    # We'll just return the cleanup function
    return [list exitHandler $extensionIds $rootDir]
}

proc resolveBoundaryTsBuildInfoPath {extensionId} {
    return [file join $::repoRoot extensions $extensionId dist .boundary-tsc.tsbuildinfo]
}

proc resolveBoundaryTsStampPath {extensionId {rootDir $::repoRoot}} {
    return [file join $rootDir extensions $extensionId dist .boundary-tsc.stamp]
}

proc resolveBoundaryCheckLockPath {{rootDir $::repoRoot}} {
    return [file join $rootDir dist .extension-package-boundary.lock]
}

proc resolveBoundaryCheckLockOwnerPath {lockPath} {
    return [file join $lockPath owner.json]
}

proc isProcessAlive {pid} {
    if {![string is integer -strict $pid] || $pid <= 0} {
        return 0
    }
    # In Tcl we can't easily check if a process is alive
    # This is a simplified version
    return 1
}

proc removeStaleBoundaryCheckLock {lockPath} {
    set ownerPath [resolveBoundaryCheckLockOwnerPath $lockPath]
    if {[catch {set owner [readJsonFile $ownerPath]}]} {
        file delete -force -- $lockPath
        return 1
    }

    if {[dict exists $owner pid] && [isProcessAlive [dict get $owner pid]]} {
        return 0
    }
    file delete -force -- $lockPath
    return 1
}

proc acquireBoundaryCheckLock {{params {}}} {
    set rootDir [expr {[dict exists $params rootDir] ? [dict get $params rootDir] : $::repoRoot}]
    set processObject [expr {[dict exists $params processObject] ? [dict get $params processObject] : "process"}]
    set lockPath [resolveBoundaryCheckLockPath $rootDir]
    file mkdir [file dirname $lockPath]
    
    if {[catch {file mkdir $lockPath} error]} {
        if {[dict get $error code] eq "EEXIST"} {
            if {[removeStaleBoundaryCheckLock $lockPath]} {
                file mkdir $lockPath
            } else {
                set lockError [attachStepFailureMetadata [formatStepFailure "extension package boundary check" [dict create kind "lock-contention" note "lock: $lockPath\nanother extension package boundary check is already running in this checkout"]] "extension package boundary check" [dict create kind "lock-contention" note "lock: $lockPath\nanother extension package boundary check is already running in this checkout"]]
                error $lockError
            }
        } else {
            error $error
        }
    }

    set ownerData [dict create pid [pid] startedAt [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ"]]
    set fd [open [resolveBoundaryCheckLockOwnerPath $lockPath] w]
    puts $fd [::json::write::write $ownerData]
    close $fd

    proc release {} {
        file delete -force -- $lockPath
    }
    
    # Register exit handler (Tcl doesn't have built-in process.on)
    # We'll just return the release function
    return release
}

proc runCompileCheck {extensionIds} {
    set prepStartedAt [clock milliseconds]
    puts "preparing plugin-sdk boundary artifacts for [llength $extensionIds] plugins"
    runNodeStep "plugin-sdk boundary prep" $::prepareBoundaryArtifactsBin 420000
    set prepElapsedMs [expr {[clock milliseconds] - $prepStartedAt}]
    set concurrency [resolveCompileConcurrency]
    set verboseFreshLogs [expr {$::env(OPENCLAW_EXTENSION_BOUNDARY_VERBOSE_FRESH) eq "1"}]
    
    set sharedNewestInputMtimeMs [expr {max([collectNewestMtime [file join $::repoRoot dist plugin-sdk] [dict create skipDistDirectories 0]], [collectNewestMtime [file join $::repoRoot packages plugin-sdk dist] [dict create skipDistDirectories 0]])}]
    puts "compile concurrency $concurrency"
    set compileStartedAt [clock milliseconds]
    set skippedCompileCount 0
    set compileTimings {}
    set steps {}
    
    for {set i 0} {$i < [llength $extensionIds]} {incr i} {
        set extensionId [lindex $extensionIds $i]
        set tsBuildInfoPath [resolveBoundaryTsBuildInfoPath $extensionId]
        set extensionNewestInputMtimeMs [collectNewestMtime [file join $::repoRoot extensions $extensionId] [dict create includeFile isRelevantCompileInput]]
        file mkdir [file dirname $tsBuildInfoPath]
        
        if {[isBoundaryCompileFresh $extensionId [dict create extensionNewestInputMtimeMs $extensionNewestInputMtimeMs sharedNewestInputMtimeMs $sharedNewestInputMtimeMs]]} {
            incr skippedCompileCount
            if {$verboseFreshLogs} {
                puts "[expr {$i + 1}]/[llength $extensionIds] $extensionId (fresh; skipping)"
            }
        } else {
            lappend steps [dict create \
                label $extensionId \
                onStart [list apply {{index extensionId} {
                    puts "[expr {$index + 1}]/[llength $::extensionIds] $extensionId"
                }} $i $extensionId] \
                onSuccess [list apply {{extensionId result compileTimingsVar} {
                    writeStampFile [resolveBoundaryTsStampPath $extensionId]
                    upvar $compileTimingsVar compileTimings
                    lappend compileTimings [list $extensionId [dict get $result elapsedMs]]
                }} $extensionId {} compileTimings] \
                args [list $::tscBin -p [file join $::repoRoot extensions $extensionId tsconfig.json] --noEmit --incremental --tsBuildInfoFile $tsBuildInfoPath] \
                timeoutMs 120000]
        }
    }
    
    if {!$verboseFreshLogs && $skippedCompileCount > 0} {
        puts [formatSkippedCompileProgress [dict create skippedCount $skippedCompileCount totalCount [llength $extensionIds]]]
    }
    
    if {[llength $steps] > 0} {
        runNodeStepsWithConcurrency $steps $concurrency
    }
    
    return [dict create \
        prepElapsedMs $prepElapsedMs \
        compileCount [llength $steps] \
        skippedCompileCount $skippedCompileCount \
        compileElapsedMs [expr {[clock milliseconds] - $compileStartedAt}] \
        compileTimings $compileTimings]
}

proc runCanaryCheck {extensionIds} {
    set startedAt [clock milliseconds]
    set promises {}
    
    for {set i 0} {$i < [llength $extensionIds]} {incr i} {
        set extensionId [lindex $extensionIds $i]
        set paths [resolveCanaryArtifactPaths $extensionId]
        set canaryPath [dict get $paths canaryPath]
        set tsconfigPath [dict get $paths tsconfigPath]
        
        cleanupCanaryArtifacts $extensionId
        puts "[expr {$i + 1}]/[llength $extensionIds] $extensionId canary"
        
        # Write canary file
        set fd [open $canaryPath w]
        puts $fd "import { ROOTDIR_BOUNDARY_CANARY } from \"$::ROOTDIR_BOUNDARY_CANARY_IMPORT_PATH\";"
        puts $fd "void ROOTDIR_BOUNDARY_CANARY;"
        puts $fd "export {};"
        puts $fd ""
        close $fd
        
        # Write tsconfig file
        set config [dict create \
            extends "./tsconfig.json" \
            include [list "./__rootdir_boundary_canary__.ts"] \
            exclude [list]]
        set fd [open $tsconfigPath w]
        puts $fd [::json::write::write $config]
        close $fd
        
        # Run tsc check
        if {[catch {
            set result [runNodeStepAsync "$extensionId canary" $::tscBin -p $tsconfigPath --noEmit 120000 [dict create]]
            error "$extensionId canary unexpectedly passed\n[dict get $result stdout][dict get $result stderr]"
        } error]} {
            set output [expr {[dict exists $error fullOutput] ? [dict get $error fullOutput] : $error}]
            if {![string match "*TS6059*" $output] || ![string match "*$::ROOTDIR_BOUNDARY_CANARY_OUTPUT_HINT*" $output]} {
                error $error
            }
        } finally {
            cleanupCanaryArtifacts $extensionId
        }
    }
    
    return [dict create canaryElapsedMs [expr {[clock milliseconds] - $startedAt}]]
}

proc main {{argv {}}} {
    set startedAt [clock milliseconds]
    set mode [parseMode $argv]
    set optInExtensionIds [collectOptInExtensionIds]
    set canaryExtensionIds [collectCanaryExtensionIds $optInExtensionIds]
    set cleanupExtensionIds $optInExtensionIds
    set shouldRunCanary [expr {$mode eq "all" || $mode eq "canary"}]
    set releaseBoundaryLock [acquireBoundaryCheckLock]
    set teardownCanaryCleanup [installCanaryArtifactCleanup $cleanupExtensionIds [dict create]]
    set prepElapsedMs {}
    set compileCount 0
    set skippedCompileCount 0
    set compileElapsedMs {}
    set compileTimings {}
    set canaryElapsedMs {}

    cleanupCanaryArtifactsForExtensions $cleanupExtensionIds
    if {$mode eq "all" || $mode eq "compile"} {
        dict with {*} [runCompileCheck $optInExtensionIds] {
            # Unpack all variables from the returned dict
        }
    }
    if {$shouldRunCanary} {
        dict with {*} [runCanaryCheck $canaryExtensionIds] {
            # Unpack canaryElapsedMs
        }
    }
    puts [formatBoundaryCheckSuccessSummary [dict create \
        mode $mode \
        compileCount $compileCount \
        skippedCompileCount $skippedCompileCount \
        canaryCount [expr {$shouldRunCanary ? [llength $canaryExtensionIds] : 0}] \
        prepElapsedMs $prepElapsedMs \
        compileElapsedMs $compileElapsedMs \
        canaryElapsedMs $canaryElapsedMs \
        elapsedMs [expr {[clock milliseconds] - $startedAt}]]]
    puts [formatSlowCompileSummary [dict create compileTimings $compileTimings]]

    # Cleanup
    if {[info commands $releaseBoundaryLock] ne ""} {
        {*}$releaseBoundaryLock
    }
    if {[llength $teardownCanaryCleanup] > 0} {
        {*}$teardownCanaryCleanup
    }
    cleanupCanaryArtifactsForExtensions $cleanupExtensionIds
}

# Run main if script is executed directly
if {[info script] eq $argv0} {
    main $argv
}

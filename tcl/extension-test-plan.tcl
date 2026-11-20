#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "44d71e86e4e3a5b95d6f75ba74d4abcc66a7e37cf52d75c028f363a20ba70734", "source_sha256": "c28e85cfc52b92ed64eb8e20b072fd218cfe0e1ab0787781c1a9abd3355c3514", "target_language": "tcl"}
# extension-test-plan.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/extension-test-plan.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

# Tcl 8.6 port of extension-test-plan.mjs

# Note: This implementation assumes the existence of helper procs
# that would need to be implemented separately for full functionality

proc normalizeRelative {inputPath} {
    # Replace backslashes with forward slashes on Windows
    return [string map {\\ /} $inputPath]
}

proc countTestFiles {rootPath} {
    set total 0
    set stack [list $rootPath]
    
    while {[llength $stack] > 0} {
        set current [lindex $stack end]
        set stack [lreplace $stack end end]
        
        if {$current eq "" || ![file exists $current]} {
            continue
        }
        
        if {[catch {glob -directory $current -nocomplain *} entries]} {
            continue
        }
        
        foreach entry $entries {
            if {[file isdirectory $entry]} {
                set dirname [file tail $entry]
                if {$dirname eq "node_modules" || $dirname eq "dist"} {
                    continue
                }
                lappend stack $entry
                continue
            }
            
            if {[file isfile $entry]} {
                if {[string match "*.test.ts" $entry] || [string match "*.test.tsx" $entry]} {
                    incr total
                }
            }
        }
    }
    
    return $total
}

proc resolveExtensionDirectory {targetArg {cwd ""}} {
    global repoRoot BUNDLED_PLUGIN_ROOT_DIR
    
    if {$cwd eq ""} {
        set cwd [pwd]
    }
    
    if {$targetArg ne ""} {
        set asGiven [file normalize [file join $cwd $targetArg]]
        if {[file exists [file join $asGiven package.json]]} {
            return $asGiven
        }
        
        set byName [file join $repoRoot $BUNDLED_PLUGIN_ROOT_DIR $targetArg]
        if {[file exists [file join $byName package.json]]} {
            return $byName
        }
        
        error "Unknown extension target \"$targetArg\". Use a plugin name like \"slack\" or a path inside the bundled plugin workspace tree."
    }
    
    set current $cwd
    while {1} {
        set relPath [normalizeRelative [file relative $repoRoot $current]]
        global BUNDLED_PLUGIN_PATH_PREFIX
        if {[string match ${BUNDLED_PLUGIN_PATH_PREFIX}* $relPath] && 
            [file exists [file join $current package.json]]} {
            return $current
        }
        
        set parent [file dirname $current]
        if {$parent eq $current} {
            break
        }
        set current $parent
    }
    
    error "No extension target provided, and current working directory is not inside the bundled plugin workspace tree."
}

proc resolveExtensionTestPlan {{params ""}} {
    global repoRoot
    
    # Parse parameters
    set cwd [pwd]
    set targetArg ""
    
    if {$params ne ""} {
        if {[dict exists $params "cwd"]} {
            set cwd [dict get $params "cwd"]
        }
        if {[dict exists $params "targetArg"]} {
            set targetArg [dict get $params "targetArg"]
        }
    }
    
    set extensionDir [resolveExtensionDirectory $targetArg $cwd]
    set extensionId [file tail $extensionDir]
    set relativeExtensionDir [normalizeRelative [file relative $repoRoot $extensionDir]]
    
    set roots [list $relativeExtensionDir]
    
    # Check various configuration flags
    set usesChannelConfig [checkChannelConfig $roots]
    set usesAcpxConfig [checkAcpxConfig $roots]
    set usesDiffsConfig [checkDiffsConfig $roots]
    set usesBlueBubblesConfig [checkBlueBubblesConfig $roots]
    set usesFeishuConfig [checkFeishuConfig $roots]
    set usesIrcConfig [checkIrcConfig $roots]
    set usesMattermostConfig [checkMattermostConfig $roots]
    set usesTelegramConfig [checkTelegramConfig $roots]
    set usesVoiceCallConfig [checkVoiceCallConfig $roots]
    set usesWhatsAppConfig [checkWhatsAppConfig $roots]
    set usesZaloConfig [checkZaloConfig $roots]
    set usesMatrixConfig [checkMatrixConfig $roots]
    set usesMemoryConfig [checkMemoryConfig $roots]
    set usesMsTeamsConfig [checkMsTeamsConfig $roots]
    set usesMessagingConfig [checkMessagingConfig $roots]
    set usesProviderConfig [checkProviderConfig $roots]
    
    # Determine config file
    if {$usesChannelConfig} {
        set config "test/vitest/vitest.extension-channels.config.ts"
    } elseif {$usesAcpxConfig} {
        set config "test/vitest/vitest.extension-acpx.config.ts"
    } elseif {$usesDiffsConfig} {
        set config "test/vitest/vitest.extension-diffs.config.ts"
    } elseif {$usesBlueBubblesConfig} {
        set config "test/vitest/vitest.extension-bluebubbles.config.ts"
    } elseif {$usesFeishuConfig} {
        set config "test/vitest/vitest.extension-feishu.config.ts"
    } elseif {$usesIrcConfig} {
        set config "test/vitest/vitest.extension-irc.config.ts"
    } elseif {$usesMattermostConfig} {
        set config "test/vitest/vitest.extension-mattermost.config.ts"
    } elseif {$usesMatrixConfig} {
        set config "test/vitest/vitest.extension-matrix.config.ts"
    } elseif {$usesTelegramConfig} {
        set config "test/vitest/vitest.extension-telegram.config.ts"
    } elseif {$usesVoiceCallConfig} {
        set config "test/vitest/vitest.extension-voice-call.config.ts"
    } elseif {$usesWhatsAppConfig} {
        set config "test/vitest/vitest.extension-whatsapp.config.ts"
    } elseif {$usesZaloConfig} {
        set config "test/vitest/vitest.extension-zalo.config.ts"
    } elseif {$usesMemoryConfig} {
        set config "test/vitest/vitest.extension-memory.config.ts"
    } elseif {$usesMsTeamsConfig} {
        set config "test/vitest/vitest.extension-msteams.config.ts"
    } elseif {$usesMessagingConfig} {
        set config "test/vitest/vitest.extension-messaging.config.ts"
    } elseif {$usesProviderConfig} {
        set config "test/vitest/vitest.extension-providers.config.ts"
    } else {
        set config "test/vitest/vitest.extensions.config.ts"
    }
    
    # Count test files
    set testFileCount 0
    foreach root $roots {
        incr testFileCount [countTestFiles [file join $repoRoot $root]]
    }
    
    # Return result as dict
    return [dict create \
        config $config \
        extensionDir $relativeExtensionDir \
        extensionId $extensionId \
        hasTests [expr {$testFileCount > 0}] \
        roots $roots \
        testFileCount $testFileCount]
}

proc mergeTestPlans {plans} {
    # Group plans by config
    set groupsByConfig [dict create]
    
    foreach plan $plans {
        set config [dict get $plan "config"]
        
        if {[dict exists $groupsByConfig $config]} {
            set current [dict get $groupsByConfig $config]
        } else {
            set current [dict create \
                config $config \
                extensionIds [list] \
                roots [list] \
                testFileCount 0]
        }
        
        dict lappend current extensionIds [dict get $plan "extensionId"]
        foreach root [dict get $plan "roots"] {
            dict lappend current roots $root
        }
        dict set current testFileCount [expr {[dict get $current "testFileCount"] + [dict get $plan "testFileCount"]}]
        
        dict set groupsByConfig $config $current
    }
    
    # Convert to list and sort
    set planGroups [list]
    dict for {key value} $groupsByConfig {
        # Sort extensionIds
        set sortedIds [lsort [dict get $value "extensionIds"]]
        dict set value extensionIds $sortedIds
        
        # Remove duplicates from roots
        set uniqueRoots [lsort -unique [dict get $value "roots"]]
        dict set value roots $uniqueRoots
        
        lappend planGroups $value
    }
    
    # Sort by config
    set planGroups [lsort -command {apply {{a b} {
        set configA [dict get $a "config"]
        set configB [dict get $b "config"]
        return [string compare $configA $configB]
    }}} $planGroups]
    
    # Create extensionIds list
    set extensionIds [list]
    foreach plan $plans {
        lappend extensionIds [dict get $plan "extensionId"]
    }
    set extensionIds [lsort $extensionIds]
    
    # Calculate total test file count
    set totalTestFiles 0
    foreach plan $plans {
        incr totalTestFiles [dict get $plan "testFileCount"]
    }
    
    return [dict create \
        extensionCount [llength $plans] \
        extensionIds $extensionIds \
        hasTests [expr {[llength $plans] > 0}] \
        planGroups $planGroups \
        testFileCount $totalTestFiles]
}

proc resolveExtensionBatchPlan {{params ""}} {
    # Parse parameters
    set cwd [pwd]
    set extensionIds [list]
    
    if {$params ne ""} {
        if {[dict exists $params "cwd"]} {
            set cwd [dict get $params "cwd"]
        }
        if {[dict exists $params "extensionIds"]} {
            set extensionIds [dict get $params "extensionIds"]
        }
    }
    
    # If no extensionIds provided, get available ones
    if {[llength $extensionIds] == 0} {
        set extensionIds [listAvailableExtensionIds]
    }
    
    # Resolve plans
    set plans [list]
    foreach extensionId $extensionIds {
        set plan [resolveExtensionTestPlan [dict create cwd $cwd targetArg $extensionId]]
        if {[dict get $plan "hasTests"]} {
            lappend plans $plan
        }
    }
    
    return [mergeTestPlans $plans]
}

proc pickLeastLoadedShard {shards} {
    set bestIndex -1
    
    for {set index 0} {$index < [llength $shards]} {incr index} {
        set shard [lindex $shards $index]
        
        if {$bestIndex == -1} {
            set bestIndex $index
            continue
        }
        
        set best [lindex $shards $bestIndex]
        
        set shardCount [dict get $shard "testFileCount"]
        set bestCount [dict get $best "testFileCount"]
        
        if {$shardCount != $bestCount} {
            if {$shardCount < $bestCount} {
                set bestIndex $index
            }
            continue
        }
        
        set shardLength [llength [dict get $shard "plans"]]
        set bestLength [llength [dict get $best "plans"]]
        
        if {$shardLength != $bestLength} {
            if {$shardLength < $bestLength} {
                set bestIndex $index
            }
            continue
        }
        
        if {$index < $bestIndex} {
            set bestIndex $index
        }
    }
    
    return $bestIndex
}

proc createExtensionTestShards {{params ""}} {
    global DEFAULT_EXTENSION_TEST_SHARD_COUNT
    
    # Parse parameters
    set cwd [pwd]
    set extensionIds [list]
    set shardCount $DEFAULT_EXTENSION_TEST_SHARD_COUNT
    
    if {$params ne ""} {
        if {[dict exists $params "cwd"]} {
            set cwd [dict get $params "cwd"]
        }
        if {[dict exists $params "extensionIds"]} {
            set extensionIds [dict get $params "extensionIds"]
        }
        if {[dict exists $params "shardCount"]} {
            set shardCount [dict get $params "shardCount"]
        }
    }
    
    # Validate shardCount
    if {![string is integer $shardCount] || $shardCount < 1} {
        set shardCount 1
    }
    
    # If no extensionIds provided, get available ones
    if {[llength $extensionIds] == 0} {
        set extensionIds [listAvailableExtensionIds]
    }
    
    # Resolve plans and filter those with tests
    set plans [list]
    foreach extensionId $extensionIds {
        set plan [resolveExtensionTestPlan [dict create cwd $cwd targetArg $extensionId]]
        if {[dict get $plan "hasTests"]} {
            lappend plans $plan
        }
    }
    
    # Sort plans by test file count (descending) then by extensionId
    set plans [lsort -command {apply {{left right} {
        set leftCount [dict get $left "testFileCount"]
        set rightCount [dict get $right "testFileCount"]
        
        if {$leftCount != $rightCount} {
            return [expr {$rightCount - $leftCount}]
        }
        
        set leftId [dict get $left "extensionId"]
        set rightId [dict get $right "extensionId"]
        return [string compare $leftId $rightId]
    }}} $plans]
    
    # Calculate effective shard count
    set effectiveShardCount [expr {min($shardCount, max(1, [llength $plans]))}]
    
    # Initialize shards
    set shards [list]
    for {set i 0} {$i < $effectiveShardCount} {incr i} {
        lappend shards [dict create plans [list] testFileCount 0]
    }
    
    # Distribute plans among shards
    foreach plan $plans {
        set targetIndex [pickLeastLoadedShard $shards]
        set targetShard [lindex $shards $targetIndex]
        
        dict lappend targetShard plans $plan
        dict set targetShard testFileCount [expr {[dict get $targetShard "testFileCount"] + [dict get $plan "testFileCount"]}]
        
        set shards [lreplace $shards $targetIndex $targetIndex $targetShard]
    }
    
    # Build result
    set result [list]
    for {set index 0} {$index < [llength $shards]} {incr index} {
        set shard [lindex $shards $index]
        set merged [mergeTestPlans [dict get $shard "plans"]]
        
        if {[dict get $merged "hasTests"]} {
            set shardResult [dict create \
                index $index \
                checkName "checks-node-extensions-shard-[expr {$index + 1}]" \
                extensionCount [dict get $merged "extensionCount"] \
                extensionIds [dict get $merged "extensionIds"] \
                hasTests [dict get $merged "hasTests"] \
                planGroups [dict get $merged "planGroups"] \
                testFileCount [dict get $merged "testFileCount"]]
            lappend result $shardResult
        }
    }
    
    return $result
}

# Placeholder procedures that would need actual implementations
proc listAvailableExtensionIds {} {
    # This should return a list of available extension IDs
    return [list]
}

proc checkChannelConfig {roots} {
    # Implementation needed
    return 0
}

proc checkAcpxConfig {roots} {
    # Implementation needed
    return 0
}

proc checkDiffsConfig {roots} {
    # Implementation needed
    return 0
}

proc checkBlueBubblesConfig {roots} {
    # Implementation needed
    return 0
}

proc checkFeishuConfig {roots} {
    # Implementation needed
    return 0
}

proc checkIrcConfig {roots} {
    # Implementation needed
    return 0
}

proc checkMattermostConfig {roots} {
    # Implementation needed
    return 0
}

proc checkTelegramConfig {roots} {
    # Implementation needed
    return 0
}

proc checkVoiceCallConfig {roots} {
    # Implementation needed
    return 0
}

proc checkWhatsAppConfig {roots} {
    # Implementation needed
    return 0
}

proc checkZaloConfig {roots} {
    # Implementation needed
    return 0
}

proc checkMatrixConfig {roots} {
    # Implementation needed
    return 0
}

proc checkMemoryConfig {roots} {
    # Implementation needed
    return 0
}

proc checkMsTeamsConfig {roots} {
    # Implementation needed
    return 0
}

proc checkMessagingConfig {roots} {
    # Implementation needed
    return 0
}

proc checkProviderConfig {roots} {
    # Implementation needed
    return 0
}

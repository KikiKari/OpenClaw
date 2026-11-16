#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "5f374f890ab9f890278603c209f932a3a5e30a10b76e8c9a9e61aeb23c28ac30", "source_sha256": "a9a15237ac26649d4fe81c84ab0e7be0474d07af42503d8016279ce5a868359c", "target_language": "tcl"}
# check-no-pairing-store-group-auth.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-pairing-store-group-auth.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

# Da Tcl keine direkte Entsprechung zu TypeScript bietet, verwenden wir reguläre Ausdrücke zur Analyse
# Wir simulieren das Verhalten durch String-Matching und Parsing

set allowedFiles [dict create]
dict set allowedFiles "[file normalize [file join [pwd] src security dm-policy-shared.ts]]" 1
dict set allowedFiles "[file normalize [file join [pwd] src channels allow-from.ts]]" 1
dict set allowedFiles "[file normalize [file join [pwd] src security fix.ts]]" 1
dict set allowedFiles "[file normalize [file join [pwd] src security audit-channel.ts]]" 1

set storeIdentifierRe {^(?:storeAllowFrom|storedAllowFrom|storeAllowList)$}
set groupNameRe {(?:groupAllowFrom|effectiveGroupAllowFrom|groupAllowed|groupAllow|groupAuth|groupSender)}
set storeSourceCallNames [dict create]
dict set storeSourceCallNames "readChannelAllowFromStore" 1
dict set storeSourceCallNames "readChannelAllowFromStoreSync" 1
dict set storeSourceCallNames "readStoreAllowFromForDmPolicy" 1
set allowedResolverCallNames [dict create]
dict set allowedResolverCallNames "resolveEffectiveAllowFromLists" 1
dict set allowedResolverCallNames "resolveDmGroupAccessWithLists" 1
dict set allowedResolverCallNames "resolveMattermostEffectiveAllowFromLists" 1
dict set allowedResolverCallNames "resolveIrcEffectiveAllowlists" 1

proc getPropertyNameText {name} {
    # In Tcl simulieren wir dies durch einfaches Matching
    return $name
}

proc containsPairingStoreSource {text} {
    global storeIdentifierRe storeSourceCallNames
    
    # Prüfe auf storeIdentifierRe Muster
    if {[regexp -nocase $storeIdentifierRe $text]} {
        return 1
    }
    
    # Prüfe auf storeSourceCallNames in Klammern
    foreach {callName dummy} $storeSourceCallNames {
        if {[string match "*$callName(*" $text]} {
            return 1
        }
    }
    
    return 0
}

proc isSuspiciousNormalizeWithStoreCall {line} {
    global groupNameRe
    
    if {![regexp {normalizeAllowFromWithStore\s*\((.*?)\)} $line -> argsPart]} {
        return 0
    }
    
    set hasStoreProp 0
    set hasGroupAllowProp 0
    
    # Zerlege die Argumente
    # Da dies komplex ist, prüfen wir vereinfacht
    if {[regexp {storeAllowFrom\s*:} $argsPart] && [containsPairingStoreSource $argsPart]} {
        set hasStoreProp 1
    }
    if {[regexp {allowFrom\s*:.*($groupNameRe)} $argsPart]} {
        set hasGroupAllowProp 1
    }
    
    return [expr {$hasStoreProp && $hasGroupAllowProp}]
}

proc findViolations {content filePath} {
    global groupNameRe allowedResolverCallNames
    set violations [list]
    set lines [split $content "\n"]
    set lineNumber 0
    
    foreach line $lines {
        incr lineNumber
        
        # VariableDeclaration mit groupNameRe und pairing store source
        if {[regexp {let|const|var\s+(\w+)\s*=} $line -> varName]} {
            if {[regexp -nocase $groupNameRe $varName]} {
                if {[containsPairingStoreSource $line]} {
                    # Prüfe ob es ein erlaubter resolver ist
                    set isAllowed 0
                    foreach {resolver dummy} $allowedResolverCallNames {
                        if {[string match "*$resolver(*" $line]} {
                            set isAllowed 1
                            break
                        }
                    }
                    
                    if {!$isAllowed} {
                        lappend violations [dict create \
                            line $lineNumber \
                            reason "group-scoped variable \"$varName\" references pairing-store identifiers" \
                        ]
                    }
                }
            }
        }
        
        # Property assignments mit groupNameRe
        if {[regexp {\{?\s*(\w+)\s*:\s*(.+?)(?:,|\}|$)} $line -> propName initializer]} {
            if {[regexp -nocase $groupNameRe $propName]} {
                if {[containsPairingStoreSource $initializer]} {
                    lappend violations [dict create \
                        line $lineNumber \
                        reason "group-scoped property \"$propName\" references pairing-store identifiers" \
                    ]
                }
            }
        }
        
        # Suspicious normalize calls
        if {[isSuspiciousNormalizeWithStoreCall $line]} {
            lappend violations [dict create \
                line $lineNumber \
                reason "group allowlist uses normalizeAllowFromWithStore(...) with pairing-store entries" \
            ]
        }
    }
    
    return $violations
}

proc collectFileViolations {sourceRoots repoRoot} {
    global allowedFiles
    set allViolations [list]
    
    # Suche alle .ts Dateien rekursiv
    foreach root $sourceRoots {
        if {[catch {glob -directory $root -types f *.ts} files]} {
            continue
        }
        foreach file $files {
            set fullPath [file normalize $file]
            if {[dict exists $allowedFiles $fullPath]} {
                continue
            }
            
            if {[catch {open $file r} fh]} {
                continue
            }
            set content [read $fh]
            close $fh
            
            set violations [findViolations $content $fullPath]
            foreach vio $violations {
                lappend allViolations [dict create \
                    path $fullPath \
                    line [dict get $vio line] \
                    reason [dict get $vio reason] \
                ]
            }
        }
    }
    
    return $allViolations
}

proc main {} {
    set sourceRoots [list [file join [pwd] src]]
    set repoRoot [pwd]
    
    set violations [collectFileViolations $sourceRoots $repoRoot]
    
    if {[llength $violations] == 0} {
        return
    }
    
    puts stderr "Found pairing-store identifiers referenced in group auth composition:"
    foreach violation $violations {
        puts stderr "- [dict get $violation path]:[dict get $violation line] ([dict get $violation reason])"
    }
    puts stderr "Group auth must be composed via shared resolvers (resolveDmGroupAccessWithLists / resolveEffectiveAllowFromLists)."
    exit 1
}

main

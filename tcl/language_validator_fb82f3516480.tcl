#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "0f6e7b36ea0ebf7f75f09698e72825ff075daa7a4a60ab728031a09f36e67030", "source_sha256": "eb21431dabeaafc82a1e3ccf24278616e46ed082eca1de4d328c758ee82ee2c7", "target_language": "tcl"}
# language_validator.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/language_validator.py
# auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/language_validator.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# Multi-language script validator supporting 8+ languages.
# WebSearch integration for documentation lookup.

package require Tcl 8.6

# ValidationResult structure
proc create_validation_result {language valid errors warnings {doc_url ""}} {
    return [dict create \
        language $language \
        valid $valid \
        errors $errors \
        warnings $warnings \
        doc_url $doc_url]
}

# LanguageValidator class
oo::class create LanguageValidator {
    variable language config use_websearch
    
    constructor {lang websearch} {
        set language [string tolower $lang]
        set use_websearch $websearch
        set config [my GetLanguageConfig $language]
        if {$config eq ""} {
            error "Unsupported language: $lang"
        }
    }
    
    method GetLanguageConfig {lang} {
        array set languages {
            bash {cmd bash args {-n} linter shellcheck}
            sh {cmd sh args {-n} linter shellcheck}
            python {cmd python3 args {-m py_compile} linter pylint}
            perl {cmd perl args {-c} linter perlcritic}
            raku {cmd raku args {-c} linter {}}
            powershell {cmd pwsh args {-Command Get-Command} linter {}}
            javascript {cmd node args {--check} linter eslint}
            tcl {cmd tclsh args {} linter {}}
        }
        if {[info exists languages($lang)]} {
            return $languages($lang)
        } else {
            return ""
        }
    }
    
    method validate {script_path} {
        set errors {}
        set warnings {}
        
        # Syntax check
        set cmd [dict get $config cmd]
        set args [dict get $config args]
        set full_cmd [concat [list $cmd] $args [list $script_path]]
        
        if {[catch {exec {*}$full_cmd} output]} {
            if {[string match "*timeout*" $output]} {
                lappend errors "Validation timeout"
            } elseif {[string match "*not found*" $output] || [string match "*No such file*" $output]} {
                lappend errors "Command not found: $cmd"
                if {$use_websearch} {
                    set doc_url [my _fetch_docs]
                    if {$doc_url ne ""} {
                        return [create_validation_result $language false $errors $warnings $doc_url]
                    }
                }
            } else {
                lappend errors $output
            }
        }
        
        # Linter check if available
        set linter [dict get $config linter]
        if {$linter ne ""} {
            set linter_warnings [my _run_linter $script_path]
            foreach warning $linter_warnings {
                lappend warnings $warning
            }
        }
        
        set is_valid [expr {[llength $errors] == 0}]
        return [create_validation_result $language $is_valid $errors $warnings]
    }
    
    method _run_linter {script_path} {
        set linter [dict get $config linter]
        set warnings {}
        
        if {[catch {exec which $linter} _]} {
            lappend warnings "Linter not installed: $linter"
            return $warnings
        }
        
        if {$linter eq "shellcheck"} {
            if {[catch {exec shellcheck -f gcc $script_path} output]} {
                if {$output ne ""} {
                    set warnings [split $output "\n"]
                }
            }
        } elseif {$linter eq "pylint"} {
            if {[catch {exec pylint --output-format=parseable $script_path} output]} {
                if {$output ne ""} {
                    set warnings [split $output "\n"]
                }
            }
        }
        
        return $warnings
    }
    
    method _fetch_docs {} {
        if {!$use_websearch} {
            return ""
        }
        
        array set docs {
            powershell https://docs.microsoft.com/powershell/
            raku https://docs.raku.org/
            tcl https://www.tcl.tk/
        }
        
        if {[info exists docs($language)]} {
            return $docs($language)
        } else {
            return ""
        }
    }
}

proc main {} {
    global argc argv
    
    # Simple argument parsing
    set script ""
    set lang ""
    set no_websearch false
    
    for {set i 0} {$i < $argc} {incr i} {
        set arg [lindex $argv $i]
        if {$arg eq "--lang" && $i+1 < $argc} {
            incr i
            set lang [lindex $argv $i]
        } elseif {$arg eq "--no-websearch"} {
            set no_websearch true
        } elseif {[string index $arg 0] ne "-"} {
            set script $arg
        }
    }
    
    if {$script eq "" || $lang eq ""} {
        puts stderr "Usage: $argv0 <script> --lang <language>"
        exit 1
    }
    
    if {![file exists $script]} {
        puts stderr "Script file does not exist: $script"
        exit 1
    }
    
    try {
        set validator [LanguageValidator new $lang [expr {!$no_websearch}]]
        set result [$validator validate $script]
        
        puts "Language: [dict get $result language]"
        puts "Valid: [dict get $result valid]"
        
        set errors [dict get $result errors]
        if {[llength $errors] > 0} {
            puts "Errors: [llength $errors]"
            set count 0
            foreach err $errors {
                if {$count >= 5} break
                puts "  - $err"
                incr count
            }
        }
        
        set warnings [dict get $result warnings]
        if {[llength $warnings] > 0} {
            puts "Warnings: [llength $warnings]"
            set count 0
            foreach warn $warnings {
                if {$count >= 5} break
                puts "  - $warn"
                incr count
            }
        }
        
        if {[dict get $result doc_url] ne ""} {
            puts "Docs: [dict get $result doc_url]"
        }
        
        set exit_code [expr {![dict get $result valid]}]
        exit $exit_code
    } on error {msg} {
        puts stderr "Error: $msg"
        exit 1
    }
}

if {[info script] eq $argv0} {
    main
}

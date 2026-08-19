#!/usr/bin/env tclsh
# language_validator.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/language_validator.py
# auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/language_validator.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

# Multi-language script validator supporting 8+ languages.
# WebSearch integration for documentation lookup.

package require Tcl 8.6

# Define language configurations
array set LANGUAGES {
    bash       {cmd bash     args {-n}         linter shellcheck}
    sh         {cmd sh       args {-n}         linter shellcheck}
    python     {cmd python3  args {-m py_compile} linter pylint}
    perl       {cmd perl     args {-c}         linter perlcritic}
    raku       {cmd raku     args {-c}         linter {}}
    powershell {cmd pwsh     args {-Command Get-Command} linter {}}
    javascript {cmd node     args {--check}    linter eslint}
    tcl        {cmd tclsh    args {}           linter {}}
}

# ValidationResult structure
proc create_validation_result {language valid errors warnings {doc_url {}}} {
    return [list \
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
        
        if {[info exists ::LANGUAGES($language)]} {
            set config $::LANGUAGES($language)
        } else {
            error "Unsupported language: $lang"
        }
    }
    
    method validate {script_path} {
        # Validate a script file
        set errors {}
        set warnings {}
        
        # Syntax check
        set cmd [dict get $config cmd]
        set args [dict get $config args]
        set full_cmd [concat [list $cmd] $args [list $script_path]]
        
        if {[catch {exec {*}$full_cmd} output]} {
            lappend errors $output
        }
        
        # Linter check if available
        set linter [dict get $config linter]
        if {$linter ne ""} {
            set linter_warnings [my _run_linter $script_path]
            set warnings [concat $warnings $linter_warnings]
        }
        
        set is_valid [expr {[llength $errors] == 0}]
        set doc_url {}
        if {!$is_valid && $use_websearch} {
            set doc_url [my _fetch_docs]
        }
        
        return [create_validation_result $language $is_valid $errors $warnings $doc_url]
    }
    
    method _run_linter {script_path} {
        # Run language-specific linter
        set linter [dict get $config linter]
        set warnings {}
        
        if {$linter eq "shellcheck"} {
            if {[catch {exec shellcheck -f gcc $script_path} output]} {
                set warnings [split $output "\n"]
            }
        } elseif {$linter eq "pylint"} {
            if {[catch {exec pylint --output-format=parseable $script_path} output]} {
                set warnings [split $output "\n"]
            }
        } elseif {$linter ne ""} {
            lappend warnings "Linter not installed: $linter"
        }
        
        return $warnings
    }
    
    method _fetch_docs {} {
        # Fetch documentation URL via WebSearch if enabled
        if {!$use_websearch} {
            return {}
        }
        
        # Return known good documentation URLs
        array set docs {
            powershell "https://docs.microsoft.com/powershell/"
            raku       "https://docs.raku.org/"
            tcl        "https://www.tcl.tk/"
        }
        
        if {[info exists docs($language)]} {
            return $docs($language)
        }
        return {}
    }
}

# Helper procedures
proc get_dict_value {dict key} {
    if {[dict exists $dict $key]} {
        return [dict get $dict $key]
    }
    return {}
}

proc main {argv} {
    # Parse command line arguments manually
    set script_path ""
    set lang ""
    set no_websearch false
    
    for {set i 0} {$i < [llength $argv]} {incr i} {
        set arg [lindex $argv $i]
        if {$arg eq "--lang" && $i+1 < [llength $argv]} {
            incr i
            set lang [lindex $argv $i]
        } elseif {$arg eq "--no-websearch"} {
            set no_websearch true
        } elseif {$script_path eq "" && ![string match "--*" $arg]} {
            set script_path $arg
        }
    }
    
    if {$script_path eq "" || $lang eq ""} {
        puts stderr "Usage: $::argv0 <script> --lang <language> \[--no-websearch\]"
        exit 1
    }
    
    # Create validator and run validation
    try {
        set validator [LanguageValidator new $lang [expr {!$no_websearch}]]
        set result [$validator validate $script_path]
        
        puts "Language: [get_dict_value $result language]"
        puts "Valid: [get_dict_value $result valid]"
        
        set errors [get_dict_value $result errors]
        if {[llength $errors] > 0} {
            puts "Errors: [llength $errors]"
            set count 0
            foreach err $errors {
                if {$count >= 5} break
                puts "  - $err"
                incr count
            }
        }
        
        set warnings [get_dict_value $result warnings]
        if {[llength $warnings] > 0} {
            puts "Warnings: [llength $warnings]"
            set count 0
            foreach warn $warnings {
                if {$count >= 5} break
                puts "  - $warn"
                incr count
            }
        }
        
        set doc_url [get_dict_value $result doc_url]
        if {$doc_url ne ""} {
            puts "Docs: $doc_url"
        }
        
        set exit_code [expr {![get_dict_value $result valid]}]
        exit $exit_code
    } on error {msg} {
        puts stderr "Error: $msg"
        exit 1
    }
}

# Entry point
if {[info script] eq $::argv0} {
    main $::argv
}

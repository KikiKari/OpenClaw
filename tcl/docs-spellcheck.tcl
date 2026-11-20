#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "03f70cb69e72f75a802f7ebdf3abcefaf45264fb29e8bcfc23f444913f1e0ceb", "source_sha256": "d563770ee41496760efbfdbb5c3e2c054ecf84de1c5e8eb2fc7cd2ad260b16ce", "target_language": "tcl"}
# docs-spellcheck.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docs-spellcheck.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

proc main {} {
    set mode [expr {[llength $::argv] > 0 ? [lindex $::argv 0] : ""}]
    set write_flag {}
    if {$mode eq "--write"} {
        set write_flag {-w}
    }

    set args [list \
        README.md \
        docs \
        --skip=*.png,*.jpg,*.jpeg,*.gif,*.svg \
        -D \
        - \
        -D \
        scripts/codespell-dictionary.txt \
        -I \
        scripts/codespell-ignore.txt \
        {*}$write_flag \
    ]

    # Check if codespell is available directly
    if {[check_command "codespell"]} {
        exec_codespell $args
        return 0
    }

    # Check if python3 is available
    if {[check_command "python3"]} {
        # Try to install codespell via pip
        set install_ok 0
        if {![catch {exec python3 -m pip install --user --disable-pip-version-check --break-system-packages codespell}]} {
            set install_ok 1
        } elseif {![catch {exec python3 -m pip install --user --disable-pip-version-check codespell}]} {
            set install_ok 1
        }

        if {$install_ok} {
            # Get user bin directory
            set user_bin [get_python_user_base]
            set codespell_path [file join $user_bin "codespell"]
            
            if {[file executable $codespell_path]} {
                exec_codespell_path $codespell_path $args
                return 0
            }
        }
    }

    puts stderr "codespell unavailable: install codespell or python3"
    return 1
}

proc check_command {cmd} {
    if {[catch {exec which $cmd}]} {
        return 0
    }
    return 1
}

proc get_python_user_base {} {
    set script {
import site
print(f"{site.USER_BASE}/bin")
    }
    if {[catch {exec python3 - << $script} result]} {
        return ""
    }
    return $result
}

proc exec_codespell {args} {
    set cmd [concat [list codespell] $args]
    if {[catch {exec {*}$cmd} output]} {
        puts stderr $output
        exit 1
    } else {
        puts -nonewline $output
    }
}

proc exec_codespell_path {path args} {
    set cmd [concat [list $path] $args]
    if {[catch {exec {*}$cmd} output]} {
        puts stderr $output
        exit 1
    } else {
        puts -nonewline $output
    }
}

# Run main and exit with appropriate code
exit [main]

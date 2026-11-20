#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "12e9b1c038aa4ea219e8e451a5a25e804ac345c0f83c86f677c63b99844f88af", "source_sha256": "2831a8a242630f9e502bf810a5eba7959a0a033472a3dd6c333bc3178d2227d2", "target_language": "tcl"}
# gates.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/gates.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

proc run_prepare_push_retry_gates {{docs_only "false"}} {
    bootstrap_deps_if_needed
    run_quiet_logged "pnpm build (lease-retry)" ".local/lease-retry-build.log" "pnpm build"
    run_quiet_logged "pnpm check (lease-retry)" ".local/lease-retry-check.log" "pnpm check"
    if {$docs_only ne "true"} {
        run_quiet_logged "pnpm test (lease-retry)" ".local/lease-retry-test.log" "pnpm test"
    }
}

proc prepare_gates {pr} {
    enter_worktree $pr false
    
    checkout_prep_branch $pr
    bootstrap_deps_if_needed
    require_artifact ".local/pr-meta.env"
    
    # Source the environment file
    if {[file exists ".local/pr-meta.env"]} {
        set fp [open ".local/pr-meta.env" r]
        set content [read $fp]
        close $fp
        # Process each line as key=value
        foreach line [split $content "\n"] {
            if {[regexp {^([^=]+)=(.*)$} $line -> key value]} {
                set $key $value
            }
        }
    }
    
    # Get changed files
    set changed_files [exec git diff --name-only origin/main...HEAD]
    set non_docs ""
    
    # Filter out docs files
    foreach path [split $changed_files "\n"] {
        if {$path eq ""} continue
        if {![path_is_docsish $path]} {
            append non_docs "$path\n"
        }
    }
    
    set docs_only false
    if {[string length $changed_files] > 0 && [string length $non_docs] == 0} {
        set docs_only true
    }
    
    set changelog_required false
    if {[changelog_required_for_changed_files $changed_files]} {
        set changelog_required true
    }
    
    set has_changelog_update false
    if {[regexp {^CHANGELOG\.md$} $changed_files]} {
        set has_changelog_update true
    }
    
    set unsupported_changelog_fragments ""
    if {[catch {exec echo $changed_files | rg {^changelog/fragments/}} result]} {
        set unsupported_changelog_fragments $result
    }
    
    if {[string length $unsupported_changelog_fragments] > 0} {
        puts "Unsupported changelog fragment files detected:"
        puts $unsupported_changelog_fragments
        puts "Move changelog fragment content into CHANGELOG.md and remove changelog/fragments files."
        exit 1
    }
    
    if {$changelog_required eq "true" && $has_changelog_update eq "false"} {
        puts "Missing changelog update. Add CHANGELOG.md changes."
        exit 1
    }
    
    if {$has_changelog_update eq "true"} {
        normalize_pr_changelog_entries $pr
    }
    
    if {$changelog_required eq "true"} {
        set contrib [expr {[info exists PR_AUTHOR] ? $PR_AUTHOR : ""}]
        validate_changelog_merge_hygiene
        validate_changelog_entry_for_pr $pr $contrib
    } else {
        puts "Changelog not required for this changed-file set."
    }
    
    set current_head [exec git rev-parse HEAD]
    set previous_last_verified_head ""
    set previous_full_gates_head ""
    
    if {[file exists ".local/gates.env"] && [file size ".local/gates.env"] > 0} {
        # Read and process gates.env
        set fp [open ".local/gates.env" r]
        set content [read $fp]
        close $fp
        foreach line [split $content "\n"] {
            if {[regexp {^([^=]+)=(.*)$} $line -> key value]} {
                if {$key eq "LAST_VERIFIED_HEAD_SHA"} {
                    set previous_last_verified_head $value
                } elseif {$key eq "FULL_GATES_HEAD_SHA"} {
                    set previous_full_gates_head $value
                }
            }
        }
    }
    
    set gates_mode "full"
    set reuse_gates false
    
    if {$docs_only eq "true" && [string length $previous_last_verified_head] > 0} {
        if {[catch {exec git merge-base --is-ancestor $previous_last_verified_head HEAD}]} {
            # Command succeeded, so ancestor relationship exists
            set delta_since_verified [exec git diff --name-only "$previous_last_verified_head..HEAD"]
            if {[string length $delta_since_verified] == 0 || [file_list_is_docsish_only $delta_since_verified]} {
                set reuse_gates true
            }
        }
    }
    
    if {$reuse_gates eq "true"} {
        set gates_mode "reused_docs_only"
        puts "Docs/changelog-only delta since last verified head $previous_last_verified_head; reusing prior gates."
    } else {
        run_quiet_logged "pnpm build" ".local/gates-build.log" "pnpm build"
        run_quiet_logged "pnpm check" ".local/gates-check.log" "pnpm check"
        
        if {$docs_only eq "true"} {
            set gates_mode "docs_only"
            puts "Docs-only change detected with high confidence; skipping pnpm test."
        } else {
            set gates_mode "full"
            set max_workers [expr {[info exists ::env(OPENCLAW_VITEST_MAX_WORKERS)] ? $::env(OPENCLAW_VITEST_MAX_WORKERS) : "4"}]
            puts "Running pnpm test with OPENCLAW_VITEST_MAX_WORKERS=$max_workers."
            run_quiet_logged "pnpm test" ".local/gates-test.log" "env OPENCLAW_VITEST_MAX_WORKERS=$max_workers pnpm test"
            set previous_full_gates_head $current_head
        }
    }
    
    # Write gates.env file
    set fp [open ".local/gates.env" w]
    puts $fp "PR_NUMBER=[list $pr]"
    puts $fp "DOCS_ONLY=[list $docs_only]"
    puts $fp "CHANGELOG_REQUIRED=[list $changelog_required]"
    puts $fp "GATES_MODE=[list $gates_mode]"
    puts $fp "LAST_VERIFIED_HEAD_SHA=[list $current_head]"
    puts $fp "FULL_GATES_HEAD_SHA=[list $previous_full_gates_head]"
    puts $fp "GATES_PASSED_AT=[list [clock format [clock seconds] -gmt 1 -format "%Y-%m-%dT%H:%M:%SZ"]]"
    close $fp
    
    puts "docs_only=$docs_only"
    puts "changelog_required=$changelog_required"
    puts "gates_mode=$gates_mode"
    puts "wrote=.local/gates.env"
}

#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "3caf095ac4152cdf6ae1e59476ec8e82cc994bafd831773de363e955c18445d9", "source_sha256": "24e3cb1dc8d717f90272134987f4b84a5137f1d8cacace1c6ccd6621b24e9566", "target_language": "tcl"}
# review.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/review.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

proc set_review_mode {mode} {
    # Security: shell-escape values to prevent command injection when sourced.
    set env_data ""
    append env_data [format {%s=%s} REVIEW_MODE $mode] "\n"
    set timestamp [clock format [clock seconds] -gmt 1 -f {%Y-%m-%dT%H:%M:%SZ}]
    append env_data [format {%s=%s} REVIEW_MODE_SET_AT $timestamp] "\n"
    
    set fd [open .local/review-mode.env w]
    puts -nonewline $fd $env_data
    close $fd
}

proc review_claim {pr} {
    set root [exec repo_root]
    cd $root
    file mkdir .local
    
    set reviewer ""
    set max_attempts 3
    
    for {set attempt 1} {$attempt <= $max_attempts} {incr attempt} {
        set user_log ".local/review-claim-user-attempt-$attempt.log"
        
        if {[catch {exec gh api user --jq .login 2>@1} result]} {
            set fd [open $user_log w]
            puts $fd $result
            close $fd
            
            puts "Claim reviewer lookup failed (attempt $attempt/$max_attempts)."
            print_relevant_log_excerpt $user_log
            
            if {$attempt < $max_attempts} {
                exec sleep 2
            }
        } else {
            set reviewer $result
            set fd [open $user_log w]
            puts $fd $reviewer
            close $fd
            break
        }
    }
    
    if {$reviewer eq ""} {
        puts "Failed to resolve reviewer login after $max_attempts attempts."
        return 1
    }
    
    for {set attempt 1} {$attempt <= $max_attempts} {incr attempt} {
        set claim_log ".local/review-claim-assignee-attempt-$attempt.log"
        
        if {[catch {exec gh pr edit $pr --add-assignee $reviewer} result]} {
            set fd [open $claim_log w]
            puts $fd $result
            close $fd
            
            puts "Claim assignee update failed (attempt $attempt/$max_attempts)."
            print_relevant_log_excerpt $claim_log
            
            if {$attempt < $max_attempts} {
                exec sleep 2
            }
        } else {
            puts "review claim succeeded: @$reviewer assigned to PR #$pr"
            return 0
        }
    }
    
    puts "Failed to assign @$reviewer to PR #$pr after $max_attempts attempts."
    return 1
}

proc review_checkout_main {pr} {
    enter_worktree $pr false
    exec git fetch origin main
    exec git checkout --detach origin/main
    set_review_mode main
    
    puts "review mode set to main baseline"
    puts "branch=[exec git branch --show-current]"
    puts "head=[exec git rev-parse --short HEAD]"
}

proc review_checkout_pr {pr} {
    enter_worktree $pr false
    exec git fetch origin pull/$pr/head:pr-$pr --force
    exec git checkout --detach pr-$pr
    set_review_mode pr
    
    puts "review mode set to PR head"
    puts "branch=[exec git branch --show-current]"
    puts "head=[exec git rev-parse --short HEAD]"
}

proc review_guard {pr} {
    enter_worktree $pr false
    require_artifact .local/review-mode.env
    require_artifact .local/pr-meta.env
    
    # Source environment files
    source_env_file .local/review-mode.env
    source_env_file .local/pr-meta.env
    
    set branch [exec git branch --show-current]
    set head_sha [exec git rev-parse HEAD]
    
    global REVIEW_MODE PR_HEAD_SHA
    switch -exact -- ${REVIEW_MODE} {
        main {
            set expected_main_sha [exec git rev-parse origin/main]
            if {$head_sha ne $expected_main_sha} {
                puts "Review guard failed: expected HEAD at origin/main ($expected_main_sha) for main baseline mode, got $head_sha"
                exit 1
            }
        }
        pr {
            if {![info exists PR_HEAD_SHA] || $PR_HEAD_SHA eq ""} {
                puts "Review guard failed: missing PR_HEAD_SHA in .local/pr-meta.env"
                exit 1
            }
            if {$head_sha ne $PR_HEAD_SHA} {
                puts "Review guard failed: expected HEAD at PR_HEAD_SHA ($PR_HEAD_SHA), got $head_sha"
                exit 1
            }
        }
        default {
            puts "Review guard failed: unknown review mode '${REVIEW_MODE}'"
            exit 1
        }
    }
    
    puts "review guard passed"
    puts "mode=$REVIEW_MODE"
    puts "branch=$branch"
    puts "head=$head_sha"
}

proc review_artifacts_init {pr} {
    enter_worktree $pr false
    require_artifact .local/pr-meta.env
    
    if {![file exists .local/review.md]} {
        set fd [open .local/review.md w]
        puts $fd {A) TL;DR recommendation

B) What changed and what is good?

C) Security findings

D) What is the PR intent? Is this the most optimal implementation?

E) Concerns or questions (actionable)

F) Tests

G) Docs status

H) Changelog

I) Follow ups (optional)

J) Suggested PR comment (optional)}
        close $fd
    }
    
    if {![file exists .local/review.json]} {
        set fd [open .local/review.json w]
        puts $fd {
  "recommendation": "NEEDS WORK",
  "findings": [],
  "nitSweep": {
    "performed": true,
    "status": "none",
    "summary": "No optional nits identified."
  },
  "behavioralSweep": {
    "performed": true,
    "status": "not_applicable",
    "summary": "No runtime branch-level behavior changes require sweep evidence.",
    "silentDropRisk": "none",
    "branches": []
  },
  "issueValidation": {
    "performed": true,
    "source": "pr_body",
    "status": "unclear",
    "summary": "Review not completed yet."
  },
  "tests": {
    "ran": [],
    "gaps": [],
    "result": "pass"
  },
  "docs": "not_applicable",
  "changelog": "not_required"
}}
        close $fd
    }
    
    puts "review artifact templates are ready"
    puts "files=.local/review.md .local/review.json"
}

proc review_validate_artifacts {pr} {
    enter_worktree $pr false
    require_artifact .local/review.md
    require_artifact .local/review.json
    require_artifact .local/pr-meta.env
    require_artifact .local/pr-meta.json
    
    review_guard $pr
    
    # Validate JSON syntax
    exec jq . .local/review.json >/dev/null
    
    # Check all required sections exist in review.md
    foreach section {"A)" "B)" "C)" "D)" "E)" "F)" "G)" "H)" "I)" "J)"} {
        set found [exec awk -v s=$section {index($0, s) == 1 { found=1; exit } END { exit(found ? 0 : 1) }} .local/review.md]
        if {$found != 0} {
            puts "Missing section header in .local/review.md: $section"
            exit 1
        }
    }
    
    # Validate recommendation value
    set recommendation [exec jq -r {.recommendation // ""} .local/review.json]
    switch -exact -- $recommendation {
        "READY FOR /prepare-pr" - "NEEDS WORK" - "NEEDS DISCUSSION" - "NOT USEFUL (CLOSE)" {}
        default {
            puts "Invalid recommendation in .local/review.json: $recommendation"
            exit 1
        }
    }
    
    # Validate finding severities
    set invalid_severity_count [exec jq {[.findings[]? | select((.severity // "") != "BLOCKER" and (.severity // "") != "IMPORTANT" and (.severity // "") != "NIT")] | length} .local/review.json]
    if {$invalid_severity_count > 0} {
        puts "Invalid finding severity in .local/review.json"
        exit 1
    }
    
    # Validate finding structure
    set invalid_findings_count [exec jq {[.findings[]? | select((.id|type)!="string" or (.title|type)!="string" or (.area|type)!="string" or (.fix|type)!="string")] | length} .local/review.json]
    if {$invalid_findings_count > 0} {
        puts "Invalid finding shape in .local/review.json (id/title/area/fix must be strings)"
        exit 1
    }
    
    # Validate nit findings count
    set nit_findings_count [exec jq {[.findings[]? | select((.severity // "") == "NIT")] | length} .local/review.json]
    
    # Validate nit sweep performed
    set nit_sweep_performed [exec jq -r {.nitSweep.performed // empty} .local/review.json]
    if {$nit_sweep_performed ne "true"} {
        puts "Invalid nit sweep in .local/review.json: nitSweep.performed must be true"
        exit 1
    }
    
    # Validate nit sweep status
    set nit_sweep_status [exec jq -r {.nitSweep.status // ""} .local/review.json]
    switch -exact -- $nit_sweep_status {
        "none" {
            if {$nit_findings_count > 0} {
                puts "Invalid nit sweep in .local/review.json: nitSweep.status is none but NIT findings exist"
                exit 1
            }
        }
        "has_nits" {
            if {$nit_findings_count < 1} {
                puts "Invalid nit sweep in .local/review.json: nitSweep.status is has_nits but no NIT findings exist"
                exit 1
            }
        }
        default {
            puts "Invalid nit sweep status in .local/review.json: $nit_sweep_status"
            exit 1
        }
    }
    
    # Validate nit sweep summary
    set invalid_nit_summary_count [exec jq {[.nitSweep.summary | select((type != "string") or (gsub("^\\s+|\\s+$";"") | length == 0))] | length} .local/review.json]
    if {$invalid_nit_summary_count > 0} {
        puts "Invalid nit sweep summary in .local/review.json: nitSweep.summary must be a non-empty string"
        exit 1
    }
    
    # Validate issue validation performed
    set issue_validation_performed [exec jq -r {.issueValidation.performed // empty} .local/review.json]
    if {$issue_validation_performed ne "true"} {
        puts "Invalid issue validation in .local/review.json: issueValidation.performed must be true"
        exit 1
    }
    
    # Validate issue validation source
    set issue_validation_source [exec jq -r {.issueValidation.source // ""} .local/review.json]
    switch -exact -- $issue_validation_source {
        "linked_issue" - "pr_body" - "both" {}
        default {
            puts "Invalid issue validation source in .local/review.json: $issue_validation_source"
            exit 1
        }
    }
    
    # Validate issue validation status
    set issue_validation_status [exec jq -r {.issueValidation.status // ""} .local/review.json]
    switch -exact -- $issue_validation_status {
        "valid" - "unclear" - "invalid" - "already_fixed_on_main" {}
        default {
            puts "Invalid issue validation status in .local/review.json: $issue_validation_status"
            exit 1
        }
    }
    
    # Validate issue validation summary
    set invalid_issue_summary_count [exec jq {[.issueValidation.summary | select((type != "string") or (gsub("^\\s+|\\s+$";"") | length == 0))] | length} .local/review.json]
    if {$invalid_issue_summary_count > 0} {
        puts "Invalid issue validation summary in .local/review.json: issueValidation.summary must be a non-empty string"
        exit 1
    }
    
    # Determine if runtime review is required
    set runtime_file_count [exec jq {[.files[]? | (.path // "") | select(test("^(src|extensions|apps)/")) | select(test("(^|/)__tests__/|\\.test\\.|\\.spec\\.") | not) | select(test("\\.(md|mdx)$") | not)] | length} .local/pr-meta.json]
    set runtime_review_required [expr {$runtime_file_count > 0 ? "true" : "false"}]
    
    # Validate behavioral sweep performed
    set behavioral_sweep_performed [exec jq -r {.behavioralSweep.performed // empty} .local/review.json]
    if {$behavioral_sweep_performed ne "true"} {
        puts "Invalid behavioral sweep in .local/review.json: behavioralSweep.performed must be true"
        exit 1
    }
    
    # Validate behavioral sweep status
    set behavioral_sweep_status [exec jq -r {.behavioralSweep.status // ""} .local/review.json]
    switch -exact -- $behavioral_sweep_status {
        "pass" - "needs_work" - "not_applicable" {}
        default {
            puts "Invalid behavioral sweep status in .local/review.json: $behavioral_sweep_status"
            exit 1
        }
    }
    
    # Validate behavioral sweep risk
    set behavioral_sweep_risk [exec jq -r {.behavioralSweep.silentDropRisk // ""} .local/review.json]
    switch -exact -- $behavioral_sweep_risk {
        "none" - "present" - "unknown" {}
        default {
            puts "Invalid behavioral sweep risk in .local/review.json: $behavioral_sweep_risk"
            exit 1
        }
    }
    
    # Validate behavioral sweep summary
    set invalid_behavioral_summary_count [exec jq {[.behavioralSweep.summary | select((type != "string") or (gsub("^\\s+|\\s+$";"") | length == 0))] | length} .local/review.json]
    if {$invalid_behavioral_summary_count > 0} {
        puts "Invalid behavioral sweep summary in .local/review.json: behavioralSweep.summary must be a non-empty string"
        exit 1
    }
    
    # Validate behavioral branches is array
    set behavioral_branches_is_array [exec jq -r {if (.behavioralSweep.branches | type) == "array" then "true" else "false" end} .local/review.json]
    if {$behavioral_branches_is_array ne "true"} {
        puts "Invalid behavioral sweep in .local/review.json: behavioralSweep.branches must be an array"
        exit 1
    }
    
    # Validate behavioral branch entries
    set invalid_behavioral_branch_count [exec jq {[.behavioralSweep.branches[]? | select((.path|type)!="string" or (.decision|type)!="string" or (.outcome|type)!="string")] | length} .local/review.json]
    if {$invalid_behavioral_branch_count > 0} {
        puts "Invalid behavioral sweep branch entry in .local/review.json: each branch needs string path/decision/outcome"
        exit 1
    }
    
    # Count behavioral branches
    set behavioral_branch_count [exec jq {[.behavioralSweep.branches[]?] | length} .local/review.json]
    
    # Validate behavioral sweep constraints
    if {$runtime_review_required eq "true" && $behavioral_sweep_status eq "not_applicable"} {
        puts "Invalid behavioral sweep in .local/review.json: runtime file changes require behavioralSweep.status=pass|needs_work"
        exit 1
    }
    
    if {$runtime_review_required eq "true" && $behavioral_branch_count < 1} {
        puts "Invalid behavioral sweep in .local/review.json: runtime file changes require at least one branch entry"
        exit 1
    }
    
    if {$behavioral_sweep_status eq "not_applicable" && $behavioral_branch_count > 0} {
        puts "Invalid behavioral sweep in .local/review.json: not_applicable cannot include branch entries"
        exit 1
    }
    
    if {$behavioral_sweep_status eq "pass" && $behavioral_sweep_risk ne "none"} {
        puts "Invalid behavioral sweep in .local/review.json: status=pass requires silentDropRisk=none"
        exit 1
    }
    
    # Validate recommendation constraints
    if {$recommendation eq "READY FOR /prepare-pr" && $issue_validation_status ne "valid"} {
        puts "Invalid recommendation in .local/review.json: READY FOR /prepare-pr requires issueValidation.status=valid"
        exit 1
    }
    
    if {$recommendation eq "READY FOR /prepare-pr" && $behavioral_sweep_status eq "needs_work"} {
        puts "Invalid recommendation in .local/review.json: READY FOR /prepare-pr requires behavioralSweep.status!=needs_work"
        exit 1
    }
    
    if {$recommendation eq "READY FOR /prepare-pr" && $runtime_review_required eq "true" && $behavioral_sweep_status ne "pass"} {
        puts "Invalid recommendation in .local/review.json: READY FOR /prepare-pr on runtime changes requires behavioralSweep.status=pass"
        exit 1
    }
    
    if {$recommendation eq "READY FOR /prepare-pr" && $behavioral_sweep_risk eq "present"} {
        puts "Invalid recommendation in .local/review.json: READY FOR /prepare-pr is not allowed when behavioralSweep.silentDropRisk=present"
        exit 1
    }
    
    # Validate docs status
    set docs_status [exec jq -r {.docs // ""} .local/review.json]
    switch -exact -- $docs_status {
        "up_to_date" - "missing" - "not_applicable" {}
        default {
            puts "Invalid docs status in .local/review.json: $docs_status"
            exit 1
        }
    }
    
    # Validate changelog status
    set changelog_status [exec jq -r {.changelog // ""} .local/review.json]
    switch -exact -- $changelog_status {
        "required" - "not_required" {}
        default {
            puts "Invalid changelog status in .local/review.json: $changelog_status (must be \"required\" or \"not_required\")"
            exit 1
        }
    }
    
    puts "review artifacts validated"
    print_review_stdout_summary
}

proc review_tests {args} {
    if {[llength $args] < 2} {
        puts "Usage: scripts/pr review-tests <PR> <test-file> [<test-file> ...]"
        exit 2
    }
    
    set pr [lindex $args 0]
    set targets [lrange $args 1 end]
    
    enter_worktree $pr false
    review_guard $pr
    
    # Check all targets exist
    foreach target $targets {
        if {![file exists $target]} {
            puts "Missing test target file: $target"
            exit 1
        }
    }
    
    bootstrap_deps_if_needed
    
    set run_log ".local/review-tests-run.log"
    run_quiet_logged "pnpm test" $run_log pnpm test -- {*}$targets
    
    set missing_run {}
    foreach target $targets {
        set base [file tail $target]
        if {![regexp [regsub -all {([][{}().*+?|^$\\])} $target {\\\1}] $target] || ![regexp [regsub -all {([][{}().*+?|^$\\])} $base {\\\1}] $base]} {
            lappend missing_run $target
        }
    }
    
    if {[llength $missing_run] > 0} {
        puts "These requested targets were not observed in vitest run output:"
        foreach target $missing_run {
            puts " - $target"
        }
        exit 1
    }
    
    # Security: shell-escape values to prevent command injection when sourced.
    set timestamp [clock format [clock seconds] -gmt 1 -f {%Y-%m-%dT%H:%M:%SZ}]
    set env_data ""
    append env_data [format {%s=%s} REVIEW_TESTS_AT $timestamp] "\n"
    append env_data [format {%s=%s} REVIEW_TEST_TARGET_COUNT [llength $targets]] "\n"
    
    set fd [open .local/review-tests.env w]
    puts -nonewline $fd $env_data
    close $fd
    
    puts "review tests passed and were observed in output"
}

proc review_init {pr} {
    enter_worktree $pr true
    
    set json [pr_meta_json $pr]
    write_pr_meta_files $json
    
    exec git fetch origin pull/$pr/head:pr-$pr --force
    set mb [exec git merge-base origin/main pr-$pr]
    
    # Security: shell-escape values to prevent command injection when sourced.
    set timestamp [clock format [clock seconds] -gmt 1 -f {%Y-%m-%dT%H:%M:%SZ}]
    set env_data ""
    append env_data [format {%s=%s} PR_NUMBER $pr] "\n"
    append env_data [format {%s=%s} MERGE_BASE $mb] "\n"
    append env_data [format {%s=%s} REVIEW_STARTED_AT $timestamp] "\n"
    
    set fd [open .local/review-context.env w]
    puts -nonewline $fd $env_data
    close $fd
    set_review_mode main
    
    puts [exec printf {%s} $json | jq {{number,title,url,state,isDraft,author:.author.login,base:.baseRefName,head:.headRefName,headSha:.headRefOid,headRepo:.headRepository.nameWithOwner,additions,deletions,files:(.files|length)}}]
    puts "worktree=[pwd]"
    puts "pr_url=${::env(PR_URL)}"
    puts "merge_base=$mb"
    puts "branch=[exec git branch --show-current]"
    puts "wrote=.local/pr-meta.json .local/pr-meta.env .local/review-context.env .local/review-mode.env"
    puts {Review guidance:
- Inspect main baseline: scripts/pr review-checkout-main $pr
- Inspect PR head:      scripts/pr review-checkout-pr $pr
- Guard before writeout: scripts/pr review-guard $pr}
}

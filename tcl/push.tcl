#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "3d548f921f7e0c03a7d8d19371a036793c0383abefaf2d885146289af221836d", "source_sha256": "fde26dcd603ac650a610d1fcacab8e1a0e329f4dc886be42c70dd72d735ee30e", "target_language": "tcl"}
# push.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/push.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

# Procedure to resolve head push URL
proc resolve_head_push_url {} {
    global env

    # Source environment variables
    if {[file exists ".local/pr-meta.env"]} {
        set fd [open ".local/pr-meta.env" r]
        set content [read $fd]
        close $fd
        foreach line [split $content "\n"] {
            if {[regexp {^([^#=][^=]*)=(.*)$} $line -> key value]} {
                set env($key) $value
            }
        }
    }

    if {[info exists env(PR_HEAD_OWNER)] && [string length $env(PR_HEAD_OWNER)] > 0 && 
        [info exists env(PR_HEAD_REPO_NAME)] && [string length $env(PR_HEAD_REPO_NAME)] > 0} {
        return "https://github.com/$env(PR_HEAD_OWNER)/$env(PR_HEAD_REPO_NAME).git"
    }

    if {[info exists env(PR_HEAD_REPO_URL)] && [string length $env(PR_HEAD_REPO_URL)] > 0 && 
        $env(PR_HEAD_REPO_URL) ne "null"} {
        if {[string match "*.git" $env(PR_HEAD_REPO_URL)]} {
            return $env(PR_HEAD_REPO_URL)
        } else {
            return "$env(PR_HEAD_REPO_URL).git"
        }
    }

    error "Unable to resolve PR head repo push URL."
}

# Procedure to push to a fork PR branch via GitHub GraphQL
proc graphql_push_to_fork {repo_nwo branch expected_oid} {
    set max_blob_bytes [expr {5 * 1024 * 1024}]
    
    set additions {}
    set deletions {}
    
    # Get added files
    set added_files_cmd [list exec git diff --no-renames --name-only --diff-filter=AM $expected_oid HEAD]
    if {[catch $added_files_cmd added_files_output]} {
        set added_files ""
    } else {
        set added_files $added_files_output
    }
    
    if {[string length $added_files] > 0} {
        set additions_list {}
        foreach fpath [split $added_files "\n"] {
            if {[string length $fpath] == 0} continue
            
            if {[catch {exec git ls-tree HEAD -- $fpath} tree_entry]} {
                error "GraphQL push could not resolve path in HEAD tree: $fpath"
            }
            
            if {[string length $tree_entry] == 0} {
                error "GraphQL push could not resolve path in HEAD tree: $fpath"
            }
            
            set parts [split $tree_entry " "]
            set file_mode [lindex $parts 0]
            set file_type_and_oid [lindex $parts 1]
            set file_oid [lindex [split $file_type_and_oid "\t"] 0]
            set file_type [lindex [split $file_type_and_oid "\t"] 1]
            
            if {$file_type ne "blob" || $file_mode eq "160000"} {
                error "GraphQL push only supports blob files; refusing $fpath (mode=$file_mode type=$file_type)"
            }
            
            if {[catch {exec git cat-file -s $file_oid} blob_size]} {
                error "GraphQL push could not get size for file $fpath"
            }
            
            if {$blob_size > $max_blob_bytes} {
                error "GraphQL push refused large file $fpath (${blob_size} bytes > ${max_blob_bytes})"
            }
            
            if {[catch {exec git cat-file -p $file_oid} file_content]} {
                error "GraphQL push could not read file content for $fpath"
            }
            
            # Base64 encode content
            set b64 [binary encode base64 $file_content]
            # Remove newlines from base64
            regsub -all {\n} $b64 "" b64
            
            lappend additions_list [dict create path $fpath contents $b64]
        }
        set additions $additions_list
    }
    
    # Get deleted files
    set deleted_files_cmd [list exec git diff --no-renames --name-only --diff-filter=D $expected_oid HEAD]
    if {[catch $deleted_files_cmd deleted_files_output]} {
        set deleted_files ""
    } else {
        set deleted_files $deleted_files_output
    }
    
    if {[string length $deleted_files] > 0} {
        set deletions_list {}
        foreach fpath [split $deleted_files "\n"] {
            if {[string length $fpath] == 0} continue
            lappend deletions_list [dict create path $fpath]
        }
        set deletions $deletions_list
    }
    
    # Get commit headline
    if {[catch {exec git log -1 --format=%s HEAD} commit_headline]} {
        error "Could not get commit headline"
    }
    
    # Build GraphQL query
    set query "mutation(\$input: CreateCommitOnBranchInput!) {
  createCommitOnBranch(input: \$input) {
    commit { oid url }
  }
}"
    
    # Build variables
    set variables [dict create input [dict create \
        branch [dict create repositoryNameWithOwner $repo_nwo branchName $branch] \
        message [dict create headline $commit_headline] \
        fileChanges [dict create additions $additions deletions $deletions] \
        expectedHeadOid $expected_oid]]
    
    # Execute GraphQL request
    set json_vars [::json::write object {*}[dict get $variables input]]
    set cmd [list exec gh api graphql -f query=$query --input -]
    
    if {[catch {set pipe [open "|$cmd" w+]} err]} {
        error "Failed to execute GraphQL command: $err"
    }
    
    puts $pipe $json_vars
    close $pipe
    
    if {[catch {exec {*}$cmd} result]} {
        error "GraphQL push failed: $result"
    }
    
    # Parse result
    if {[catch {::json::json2dict $result} parsed_result]} {
        error "GraphQL push returned invalid JSON: $result"
    }
    
    if {![dict exists $parsed_result data createCommitOnBranch commit oid]} {
        error "GraphQL push returned no commit OID: $result"
    }
    
    set new_oid [dict get $parsed_result data createCommitOnBranch commit oid]
    puts stderr "GraphQL push succeeded: $new_oid"
    return $new_oid
}

# Procedure to resolve head push URL HTTPS version
proc resolve_head_push_url_https {} {
    global env

    # Source environment variables
    if {[file exists ".local/pr-meta.env"]} {
        set fd [open ".local/pr-meta.env" r]
        set content [read $fd]
        close $fd
        foreach line [split $content "\n"] {
            if {[regexp {^([^#=][^=]*)=(.*)$} $line -> key value]} {
                set env($key) $value
            }
        }
    }

    if {[info exists env(PR_HEAD_OWNER)] && [string length $env(PR_HEAD_OWNER)] > 0 && 
        [info exists env(PR_HEAD_REPO_NAME)] && [string length $env(PR_HEAD_REPO_NAME)] > 0} {
        return "https://github.com/$env(PR_HEAD_OWNER)/$env(PR_HEAD_REPO_NAME).git"
    }

    if {[info exists env(PR_HEAD_REPO_URL)] && [string length $env(PR_HEAD_REPO_URL)] > 0 && 
        $env(PR_HEAD_REPO_URL) ne "null"} {
        if {[string match "*.git" $env(PR_HEAD_REPO_URL)]} {
            return $env(PR_HEAD_REPO_URL)
        } else {
            return "$env(PR_HEAD_REPO_URL).git"
        }
    }

    error "Unable to resolve PR head repo push URL."
}

# Procedure to verify PR head branch matches expected
proc verify_pr_head_branch_matches_expected {pr expected_head} {
    if {[catch {exec gh pr view $pr --json headRefName --jq .headRefName} current_head]} {
        error "Could not get current head for PR $pr"
    }
    
    if {$current_head ne $expected_head} {
        puts "PR head branch changed from $expected_head to $current_head. Re-run prepare-init."
        exit 1
    }
}

# Procedure to setup prhead remote
proc setup_prhead_remote {} {
    if {[catch {resolve_head_push_url} push_url]} {
        puts "Unable to resolve PR head repo push URL."
        exit 1
    }
    
    catch {exec git remote remove prhead}
    exec git remote add prhead $push_url
}

# Procedure to resolve prhead remote SHA
proc resolve_prhead_remote_sha {pr_head} {
    if {[catch {exec git ls-remote prhead "refs/heads/$pr_head"} remote_info]} {
        set remote_sha ""
    } else {
        set parts [split $remote_info "\t"]
        set remote_sha [lindex $parts 0]
    }
    
    if {[string length $remote_sha] == 0} {
        if {[catch {resolve_head_push_url_https} https_url]} {
            set https_url ""
        }
        
        if {[catch {exec git remote get-url prhead} current_push_url]} {
            set current_push_url ""
        }
        
        if {[string length $https_url] > 0 && $https_url ne $current_push_url} {
            puts stderr "SSH remote failed; falling back to HTTPS..."
            exec git remote set-url prhead $https_url
            exec git remote set-url --push prhead $https_url
            
            if {[catch {exec git ls-remote prhead "refs/heads/$pr_head"} remote_info]} {
                set remote_sha ""
            } else {
                set parts [split $remote_info "\t"]
                set remote_sha [lindex $parts 0]
            }
        }
        
        if {[string length $remote_sha] == 0} {
            puts "Remote branch refs/heads/$pr_head not found on prhead"
            exit 1
        }
    }
    
    return $remote_sha
}

# Procedure to wait for PR head SHA
proc wait_for_pr_head_sha {pr expected_sha max_attempts delay_seconds} {
    for {set i 0} {$i < $max_attempts} {incr i} {
        if {[catch {exec gh pr view $pr --json headRefOid --jq .headRefOid} observed_sha]} {
            after [expr {$delay_seconds * 1000}]
            continue
        }
        
        if {$observed_sha eq $expected_sha} {
            return 1
        }
        
        after [expr {$delay_seconds * 1000}]
    }
    return 0
}

# Procedure to push prep head to PR branch
proc push_prep_head_to_pr_branch {pr pr_head prep_head_sha lease_sha {rerun_gates_on_lease_retry false} {docs_only false} {result_env_path ".local/push-result.env"}} {
    setup_prhead_remote
    
    set remote_sha [resolve_prhead_remote_sha $pr_head]
    
    set pushed_from_sha $remote_sha
    if {$remote_sha eq $prep_head_sha} {
        puts "Remote branch already at local prep HEAD; skipping push."
    } else {
        if {$remote_sha ne $lease_sha} {
            puts "Remote SHA $remote_sha differs from PR head SHA $lease_sha. Refreshing lease SHA from remote."
            set lease_sha $remote_sha
        }
        set pushed_from_sha $lease_sha
        
        if {[catch {exec git push --force-with-lease=refs/heads/$pr_head:$lease_sha prhead HEAD:$pr_head} push_output]} {
            puts "Push failed: $push_output"
            
            if {[string match -nocase "*permission*" $push_output] || 
                [string match -nocase "*denied*" $push_output] || 
                [string match -nocase "*403*" $push_output] || 
                [string match -nocase "*forbidden*" $push_output]} {
                
                puts "Permission denied on git push; trying GraphQL createCommitOnBranch fallback..."
                
                global env
                if {[info exists env(PR_HEAD_OWNER)] && [string length $env(PR_HEAD_OWNER)] > 0 && 
                    [info exists env(PR_HEAD_REPO_NAME)] && [string length $env(PR_HEAD_REPO_NAME)] > 0} {
                    
                    set graphql_oid [graphql_push_to_fork "$env(PR_HEAD_OWNER)/$env(PR_HEAD_REPO_NAME)" $pr_head $lease_sha]
                    set prep_head_sha $graphql_oid
                } else {
                    puts "Git push permission denied and no fork owner/repo info for GraphQL fallback."
                    exit 1
                }
            } else {
                puts "Lease push failed, retrying once with fresh PR head..."
                
                if {[catch {exec gh pr view $pr --json headRefOid --jq .headRefOid} new_lease_sha]} {
                    error "Could not get new lease SHA"
                }
                set lease_sha $new_lease_sha
                set pushed_from_sha $lease_sha
                
                if {$rerun_gates_on_lease_retry} {
                    exec git fetch origin "pull/$pr/head:pr-$pr-latest" --force
                    exec git rebase "pr-$pr-latest"
                    
                    if {[catch {exec git rev-parse HEAD} prep_head_sha]} {
                        error "Could not get HEAD SHA"
                    }
                    
                    # run_prepare_push_retry_gates would be called here if implemented
                }
                
                if {[catch {exec git push --force-with-lease=refs/heads/$pr_head:$lease_sha prhead HEAD:$pr_head} push_output]} {
                    puts "Retry push failed: $push_output"
                    
                    if {[info exists env(PR_HEAD_OWNER)] && [string length $env(PR_HEAD_OWNER)] > 0 && 
                        [info exists env(PR_HEAD_REPO_NAME)] && [string length $env(PR_HEAD_REPO_NAME)] > 0} {
                        
                        puts "Retry failed; trying GraphQL createCommitOnBranch fallback..."
                        set graphql_oid [graphql_push_to_fork "$env(PR_HEAD_OWNER)/$env(PR_HEAD_REPO_NAME)" $pr_head $lease_sha]
                        set prep_head_sha $graphql_oid
                    } else {
                        puts "Git push failed and no fork owner/repo info for GraphQL fallback."
                        exit 1
                    }
                }
            }
        }
    }
    
    if {![wait_for_pr_head_sha $pr $prep_head_sha 8 3]} {
        if {[catch {exec gh pr view $pr --json headRefOid --jq .headRefOid} observed_sha]} {
            set observed_sha "unknown"
        }
        puts "Pushed head SHA propagation timed out. expected=$prep_head_sha observed=$observed_sha"
        exit 1
    }
    
    if {[catch {exec gh pr view $pr --json headRefOid --jq .headRefOid} pr_head_sha_after]} {
        error "Could not get PR head SHA after push"
    }
    
    exec git fetch origin main
    exec git fetch origin "pull/$pr/head:pr-$pr-verify" --force
    if {[catch {exec git merge-base --is-ancestor origin/main "pr-$pr-verify"}]} {
        puts "PR branch is behind main after push."
        exit 1
    }
    catch {exec git branch -D "pr-$pr-verify"}
    
    # Write results to file
    set fd [open $result_env_path w]
    puts $fd "PUSH_PREP_HEAD_SHA=[list $prep_head_sha]"
    puts $fd "PUSHED_FROM_SHA=[list $pushed_from_sha]"
    puts $fd "PR_HEAD_SHA_AFTER_PUSH=[list $pr_head_sha_after]"
    close $fd
}

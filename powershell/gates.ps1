#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "6381d917b8ca958e54214cbfc297f5535e56434c59759a54ec6286a5d0b32088", "source_sha256": "2831a8a242630f9e502bf810a5eba7959a0a033472a3dd6c333bc3178d2227d2", "target_language": "powershell"}
# gates.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/gates.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

function run_prepare_push_retry_gates {
    param(
        [string]$docs_only = "false"
    )

    bootstrap_deps_if_needed
    run_quiet_logged "pnpm build (lease-retry)" ".local/lease-retry-build.log" pnpm build
    run_quiet_logged "pnpm check (lease-retry)" ".local/lease-retry-check.log" pnpm check
    if ($docs_only -ne "true") {
        run_quiet_logged "pnpm test (lease-retry)" ".local/lease-retry-test.log" pnpm test
    }
}

function prepare_gates {
    param(
        [string]$pr
    )
    
    enter_worktree $pr "false"

    checkout_prep_branch $pr
    bootstrap_deps_if_needed
    require_artifact ".local/pr-meta.env"
    
    # Source the environment file
    if (Test-Path ".local/pr-meta.env") {
        Get-Content ".local/pr-meta.env" | ForEach-Object {
            if ($_ -match '^([^=]+)=(.*)$') {
                Set-Variable -Name $matches[1] -Value $matches[2]
            }
        }
    }

    $changed_files = git diff --name-only "origin/main...HEAD"
    $non_docs = $changed_files | Where-Object { $_ -and !(path_is_docsish $_) }

    $docs_only = "false"
    if ($changed_files -and !$non_docs) {
        $docs_only = "true"
    }

    $changelog_required = "false"
    if (changelog_required_for_changed_files $changed_files) {
        $changelog_required = "true"
    }

    $has_changelog_update = "false"
    if ($changed_files -contains "CHANGELOG.md") {
        $has_changelog_update = "true"
    }

    $unsupported_changelog_fragments = $changed_files | Where-Object { $_ -match '^changelog/fragments/' }
    if ($unsupported_changelog_fragments) {
        Write-Host "Unsupported changelog fragment files detected:"
        $unsupported_changelog_fragments | ForEach-Object { Write-Host $_ }
        Write-Host "Move changelog fragment content into CHANGELOG.md and remove changelog/fragments files."
        exit 1
    }

    if ($changelog_required -eq "true" -and $has_changelog_update -eq "false") {
        Write-Host "Missing changelog update. Add CHANGELOG.md changes."
        exit 1
    }

    if ($has_changelog_update -eq "true") {
        normalize_pr_changelog_entries $pr
    }

    if ($changelog_required -eq "true") {
        $contrib = if (Get-Variable "PR_AUTHOR" -ErrorAction SilentlyContinue) { $PR_AUTHOR } else { "" }
        validate_changelog_merge_hygiene
        validate_changelog_entry_for_pr $pr $contrib
    } else {
        Write-Host "Changelog not required for this changed-file set."
    }

    $current_head = git rev-parse HEAD
    $previous_last_verified_head = ""
    $previous_full_gates_head = ""

    if (Test-Path ".local/gates.env" -PathType Leaf) {
        # Source the environment file
        Get-Content ".local/gates.env" | ForEach-Object {
            if ($_ -match '^([^=]+)=(.*)$') {
                Set-Variable -Name $matches[1] -Value $matches[2]
            }
        }
        $previous_last_verified_head = if (Get-Variable "LAST_VERIFIED_HEAD_SHA" -ErrorAction SilentlyContinue) { $LAST_VERIFIED_HEAD_SHA } else { "" }
        $previous_full_gates_head = if (Get-Variable "FULL_GATES_HEAD_SHA" -ErrorAction SilentlyContinue) { $FULL_GATES_HEAD_SHA } else { "" }
    }

    $gates_mode = "full"
    $reuse_gates = $false
    
    if ($docs_only -eq "true" -and $previous_last_verified_head -and (git merge-base --is-ancestor $previous_last_verified_head HEAD 2>$null)) {
        $delta_since_verified = git diff --name-only "$previous_last_verified_head..HEAD"
        if (!$delta_since_verified -or (file_list_is_docsish_only $delta_since_verified)) {
            $reuse_gates = $true
        }
    }

    if ($reuse_gates) {
        $gates_mode = "reused_docs_only"
        Write-Host "Docs/changelog-only delta since last verified head $previous_last_verified_head; reusing prior gates."
    } else {
        run_quiet_logged "pnpm build" ".local/gates-build.log" pnpm build
        run_quiet_logged "pnpm check" ".local/gates-check.log" pnpm check

        if ($docs_only -eq "true") {
            $gates_mode = "docs_only"
            Write-Host "Docs-only change detected with high confidence; skipping pnpm test."
        } else {
            $gates_mode = "full"
            $max_workers = if (Get-Variable "OPENCLAW_VITEST_MAX_WORKERS" -ErrorAction SilentlyContinue) { $OPENCLAW_VITEST_MAX_WORKERS } else { "4" }
            Write-Host "Running pnpm test with OPENCLAW_VITEST_MAX_WORKERS=$max_workers."
            $env:OPENCLAW_VITEST_MAX_WORKERS = $max_workers
            run_quiet_logged "pnpm test" ".local/gates-test.log" pnpm test
            $previous_full_gates_head = $current_head
        }
    }

    # Security: shell-escape values to prevent command injection when sourced.
    $env_content = @"
PR_NUMBER=$pr
DOCS_ONLY=$docs_only
CHANGELOG_REQUIRED=$changelog_required
GATES_MODE=$gates_mode
LAST_VERIFIED_HEAD_SHA=$current_head
FULL_GATES_HEAD_SHA=$previous_full_gates_head
GATES_PASSED_AT=$(Get-Date -UFormat "%Y-%m-%dT%H:%M:%SZ")
"@
    $env_content | Out-File -FilePath ".local/gates.env" -Encoding UTF8

    Write-Host "docs_only=$docs_only"
    Write-Host "changelog_required=$changelog_required"
    Write-Host "gates_mode=$gates_mode"
    Write-Host "wrote=.local/gates.env"
}

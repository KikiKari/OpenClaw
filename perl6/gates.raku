#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "d1a5d8d556375c20dcef3ebb91239708d7ce78d661f71725ca212d4db0709564", "source_sha256": "2831a8a242630f9e502bf810a5eba7959a0a033472a3dd6c333bc3178d2227d2", "target_language": "perl6"}
# gates.sh — portiert nach perl6
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/gates.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

use v6;

# Helper functions (these would need to be implemented based on the original shell script's functionality)
sub bootstrap-deps-if-needed() { ... }
sub run-quiet-logged($description, $log-file, *@command) { ... }
sub enter-worktree($pr, $arg) { ... }
sub checkout-prep-branch($pr) { ... }
sub require-artifact($file) { ... }
sub path-is-docsish($path) { ... }
sub changelog-required-for-changed-files($changed-files) { ... }
sub normalize-pr-changelog-entries($pr) { ... }
sub validate-changelog-merge-hygiene() { ... }
sub validate-changelog-entry-for-pr($pr, $contrib) { ... }
sub file-list-is-docsish-only($files) { ... }

sub run-prepare-push-retry-gates($docs-only = False) {
    bootstrap-deps-if-needed();
    run-quiet-logged("pnpm build (lease-retry)", ".local/lease-retry-build.log", "pnpm", "build");
    run-quiet-logged("pnpm check (lease-retry)", ".local/lease-retry-check.log", "pnpm", "check");
    unless $docs-only {
        run-quiet-logged("pnpm test (lease-retry)", ".local/lease-retry-test.log", "pnpm", "test");
    }
}

sub prepare-gates($pr) {
    enter-worktree($pr, False);
    checkout-prep-branch($pr);
    bootstrap-deps-if-needed();
    require-artifact(".local/pr-meta.env");
    
    # Source .local/pr-meta.env (implementation dependent)
    
    my $changed-files = qqx[git diff --name-only origin/main...HEAD].lines;
    my @non-docs = $changed-files.grep({ !path-is-docsish($_) });
    
    my $docs-only = ?($changed-files && !@non-docs);
    
    my $changelog-required = changelog-required-for-changed-files($changed-files);
    
    my $has-changelog-update = so $changed-files.grep(/^CHANGELOG\.md$/);
    
    my @unsupported-changelog-fragments = $changed-files.grep(/^changelog\/fragments\//);
    if @unsupported-changelog-fragments {
        say "Unsupported changelog fragment files detected:";
        .say for @unsupported-changelog-fragments;
        say "Move changelog fragment content into CHANGELOG.md and remove changelog/fragments files.";
        exit 1;
    }
    
    if $changelog-required && !$has-changelog-update {
        say "Missing changelog update. Add CHANGELOG.md changes.";
        exit 1;
    }
    
    if $has-changelog-update {
        normalize-pr-changelog-entries($pr);
    }
    
    if $changelog-required {
        my $contrib = %*ENV<PR_AUTHOR> // '';
        validate-changelog-merge-hygiene();
        validate-changelog-entry-for-pr($pr, $contrib);
    } else {
        say "Changelog not required for this changed-file set.";
    }
    
    my $current-head = qqx[git rev-parse HEAD].trim;
    my $previous-last-verified-head = '';
    my $previous-full-gates-head = '';
    
    if ".local/gates.env".IO.e && ".local/gates.env".IO.s {
        # Source .local/gates.env (implementation dependent)
        # This would require parsing the file and setting variables accordingly
    }
    
    my $gates-mode = "full";
    my $reuse-gates = False;
    
    if $docs-only && $previous-last-verified-head && qqx[git merge-base --is-ancestor $previous-last-verified-head $current-head 2>/dev/null].so {
        my $delta-since-verified = qqx[git diff --name-only "$previous-last-verified-head"..$current-head].lines;
        if !$delta-since-verified || file-list-is-docsish-only($delta-since-verified) {
            $reuse-gates = True;
        }
    }
    
    if $reuse-gates {
        $gates-mode = "reused_docs_only";
        say "Docs/changelog-only delta since last verified head $previous-last-verified-head; reusing prior gates.";
    } else {
        run-quiet-logged("pnpm build", ".local/gates-build.log", "pnpm", "build");
        run-quiet-logged("pnpm check", ".local/gates-check.log", "pnpm", "check");
        
        if $docs-only {
            $gates-mode = "docs_only";
            say "Docs-only change detected with high confidence; skipping pnpm test.";
        } else {
            $gates-mode = "full";
            my $max-workers = %*ENV<OPENCLAW_VITEST_MAX_WORKERS> // '4';
            say "Running pnpm test with OPENCLAW_VITEST_MAX_WORKERS=$max-workers.";
            run-quiet-logged(
                "pnpm test",
                ".local/gates-test.log",
                "env", "OPENCLAW_VITEST_MAX_WORKERS=$max-workers", "pnpm", "test"
            );
            $previous-full-gates-head = $current-head;
        }
    }
    
    # Security: shell-escape values to prevent command injection when sourced.
    my $gates-env-content = join("\n", 
        "PR_NUMBER=" ~ shell-quote($pr),
        "DOCS_ONLY=" ~ shell-quote($docs-only.Str.lc),
        "CHANGELOG_REQUIRED=" ~ shell-quote($changelog-required.Str.lc),
        "GATES_MODE=" ~ shell-quote($gates-mode),
        "LAST_VERIFIED_HEAD_SHA=" ~ shell-quote($current-head),
        "FULL_GATES_HEAD_SHA=" ~ shell-quote($previous-full-gates-head),
        "GATES_PASSED_AT=" ~ shell-quote(DateTime.now.utc.Str)
    ) ~ "\n";
    
    spurt(".local/gates.env", $gates-env-content);
    
    say "docs_only=$docs-only";
    say "changelog_required=$changelog-required";
    say "gates_mode=$gates-mode";
    say "wrote=.local/gates.env";
}

# Placeholder for shell-quote function (Raku doesn't have a built-in equivalent)
sub shell-quote($str) {
    # Simple implementation - in reality, you'd want a more robust solution
    return "'" ~ $str.subst("'", "'\"'\"'", :g) ~ "'";
}

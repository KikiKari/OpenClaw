#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "2b075e06b893390fad1b7f5ff2c30bbc2eef309718ada21c7b976c249d9ced19", "source_sha256": "2831a8a242630f9e502bf810a5eba7959a0a033472a3dd6c333bc3178d2227d2", "target_language": "ruby"}
# gates.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/gates.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

def run_prepare_push_retry_gates(docs_only = false)
  bootstrap_deps_if_needed
  run_quiet_logged("pnpm build (lease-retry)", ".local/lease-retry-build.log", "pnpm", "build")
  run_quiet_logged("pnpm check (lease-retry)", ".local/lease-retry-check.log", "pnpm", "check")
  unless docs_only
    run_quiet_logged("pnpm test (lease-retry)", ".local/lease-retry-test.log", "pnpm", "test")
  end
end

def prepare_gates(pr)
  enter_worktree(pr, false)
  checkout_prep_branch(pr)
  bootstrap_deps_if_needed
  require_artifact(".local/pr-meta.env")
  load(".local/pr-meta.env") if File.exist?(".local/pr-meta.env")

  changed_files = `git diff --name-only origin/main...HEAD`.split("\n")
  non_docs = changed_files.select { |path| !path.empty? && !path_is_docsish(path) }

  docs_only = !changed_files.empty? && non_docs.empty?

  changelog_required = changelog_required_for_changed_files(changed_files)

  has_changelog_update = changed_files.include?("CHANGELOG.md")

  unsupported_changelog_fragments = changed_files.grep(%r{^changelog/fragments/})
  unless unsupported_changelog_fragments.empty?
    puts "Unsupported changelog fragment files detected:"
    unsupported_changelog_fragments.each { |f| puts f }
    puts "Move changelog fragment content into CHANGELOG.md and remove changelog/fragments files."
    exit 1
  end

  if changelog_required && !has_changelog_update
    puts "Missing changelog update. Add CHANGELOG.md changes."
    exit 1
  end

  if has_changelog_update
    normalize_pr_changelog_entries(pr)
  end

  if changelog_required
    contrib = ENV["PR_AUTHOR"] || ""
    validate_changelog_merge_hygiene
    validate_changelog_entry_for_pr(pr, contrib)
  else
    puts "Changelog not required for this changed-file set."
  end

  current_head = `git rev-parse HEAD`.strip
  previous_last_verified_head = ""
  previous_full_gates_head = ""

  if File.exist?(".local/gates.env") && !File.zero?(".local/gates.env")
    load(".local/gates.env")
    previous_last_verified_head = ENV["LAST_VERIFIED_HEAD_SHA"] || ""
    previous_full_gates_head = ENV["FULL_GATES_HEAD_SHA"] || ""
  end

  gates_mode = "full"
  reuse_gates = false

  if docs_only && !previous_last_verified_head.empty? && system("git merge-base --is-ancestor #{previous_last_verified_head} HEAD >/dev/null 2>&1")
    delta_since_verified = `git diff --name-only #{previous_last_verified_head}..HEAD`.strip
    if delta_since_verified.empty? || file_list_is_docsish_only(delta_since_verified.split("\n"))
      reuse_gates = true
    end
  end

  if reuse_gates
    gates_mode = "reused_docs_only"
    puts "Docs/changelog-only delta since last verified head #{previous_last_verified_head}; reusing prior gates."
  else
    run_quiet_logged("pnpm build", ".local/gates-build.log", "pnpm", "build")
    run_quiet_logged("pnpm check", ".local/gates-check.log", "pnpm", "check")

    if docs_only
      gates_mode = "docs_only"
      puts "Docs-only change detected with high confidence; skipping pnpm test."
    else
      gates_mode = "full"
      max_workers = ENV["OPENCLAW_VITEST_MAX_WORKERS"] || "4"
      puts "Running pnpm test with OPENCLAW_VITEST_MAX_WORKERS=#{max_workers}."
      run_quiet_logged(
        "pnpm test",
        ".local/gates-test.log",
        "env", "OPENCLAW_VITEST_MAX_WORKERS=#{max_workers}", "pnpm", "test"
      )
      previous_full_gates_head = current_head
    end
  end

  gates_passed_at = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")

  File.open(".local/gates.env", "w") do |f|
    f.puts "PR_NUMBER=#{pr.inspect}"
    f.puts "DOCS_ONLY=#{docs_only.inspect}"
    f.puts "CHANGELOG_REQUIRED=#{changelog_required.inspect}"
    f.puts "GATES_MODE=#{gates_mode.inspect}"
    f.puts "LAST_VERIFIED_HEAD_SHA=#{current_head.inspect}"
    f.puts "FULL_GATES_HEAD_SHA=#{previous_full_gates_head.inspect}"
    f.puts "GATES_PASSED_AT=#{gates_passed_at.inspect}"
  end

  puts "docs_only=#{docs_only}"
  puts "changelog_required=#{changelog_required}"
  puts "gates_mode=#{gates_mode}"
  puts "wrote=.local/gates.env"
end

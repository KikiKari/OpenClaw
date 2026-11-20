#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "88f0b878afc098020dca4f3d9e85ca515fef7c1248770cbba7bde3151dd6a483", "source_sha256": "2831a8a242630f9e502bf810a5eba7959a0a033472a3dd6c333bc3178d2227d2", "target_language": "lua"}
-- gates.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/gates.sh
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local function run_prepare_push_retry_gates(docs_only)
  docs_only = docs_only or "false"

  bootstrap_deps_if_needed()
  run_quiet_logged("pnpm build (lease-retry)", ".local/lease-retry-build.log", {"pnpm", "build"})
  run_quiet_logged("pnpm check (lease-retry)", ".local/lease-retry-check.log", {"pnpm", "check"})
  if docs_only ~= "true" then
    run_quiet_logged("pnpm test (lease-retry)", ".local/lease-retry-test.log", {"pnpm", "test"})
  end
end

local function prepare_gates(pr)
  enter_worktree(pr, "false")

  checkout_prep_branch(pr)
  bootstrap_deps_if_needed()
  require_artifact(".local/pr-meta.env")
  
  dofile(".local/pr-meta.env")

  local changed_files = io.popen("git diff --name-only origin/main...HEAD"):read("*a")
  local non_docs_lines = {}
  
  for path in string.gmatch(changed_files, "[^\r\n]+") do
    if path ~= "" and not path_is_docsish(path) then
      table.insert(non_docs_lines, path)
    end
  end
  
  local non_docs = table.concat(non_docs_lines, "\n")

  local docs_only = "false"
  if changed_files:match("%S") and #non_docs == 0 then
    docs_only = "true"
  end

  local changelog_required = "false"
  if changelog_required_for_changed_files(changed_files) then
    changelog_required = "true"
  end

  local has_changelog_update = "false"
  if changed_files:find("^CHANGELOG%.md$", 1, true) then
    has_changelog_update = "true"
  end

  local unsupported_changelog_fragments = ""
  for line in string.gmatch(changed_files, "[^\r\n]+") do
    if line:match("^changelog/fragments/") then
      unsupported_changelog_fragments = unsupported_changelog_fragments .. line .. "\n"
    end
  end

  if #unsupported_changelog_fragments > 0 then
    print("Unsupported changelog fragment files detected:")
    print(unsupported_changelog_fragments)
    print("Move changelog fragment content into CHANGELOG.md and remove changelog/fragments files.")
    os.exit(1)
  end

  if changelog_required == "true" and has_changelog_update == "false" then
    print("Missing changelog update. Add CHANGELOG.md changes.")
    os.exit(1)
  end

  if has_changelog_update == "true" then
    normalize_pr_changelog_entries(pr)
  end

  if changelog_required == "true" then
    local contrib = os.getenv("PR_AUTHOR") or ""
    validate_changelog_merge_hygiene()
    validate_changelog_entry_for_pr(pr, contrib)
  else
    print("Changelog not required for this changed-file set.")
  end

  local current_head = io.popen("git rev-parse HEAD"):read("*l")
  local previous_last_verified_head = ""
  local previous_full_gates_head = ""

  if io.open(".local/gates.env", "r") then
    local env_file = io.open(".local/gates.env", "r")
    local content = env_file:read("*a")
    env_file:close()
    
    for line in string.gmatch(content, "[^\r\n]+") do
      local key, value = line:match("([^=]+)=(.*)")
      if key == "LAST_VERIFIED_HEAD_SHA" then
        previous_last_verified_head = value
      elseif key == "FULL_GATES_HEAD_SHA" then
        previous_full_gates_head = value
      end
    end
  end

  local gates_mode = "full"
  local reuse_gates = false

  if docs_only == "true" and previous_last_verified_head ~= "" then
    local status = os.execute(string.format('git merge-base --is-ancestor "%s" HEAD 2>/dev/null', previous_last_verified_head))
    if status == 0 then
      local delta_since_verified = io.popen(string.format('git diff --name-only "%s"..HEAD', previous_last_verified_head)):read("*a")
      if not delta_since_verified:match("%S") or file_list_is_docsish_only(delta_since_verified) then
        reuse_gates = true
      end
    end
  end

  if reuse_gates then
    gates_mode = "reused_docs_only"
    print("Docs/changelog-only delta since last verified head " .. previous_last_verified_head .. "; reusing prior gates.")
  else
    run_quiet_logged("pnpm build", ".local/gates-build.log", {"pnpm", "build"})
    run_quiet_logged("pnpm check", ".local/gates-check.log", {"pnpm", "check"})

    if docs_only == "true" then
      gates_mode = "docs_only"
      print("Docs-only change detected with high confidence; skipping pnpm test.")
    else
      gates_mode = "full"
      local max_workers = os.getenv("OPENCLAW_VITEST_MAX_WORKERS") or "4"
      print("Running pnpm test with OPENCLAW_VITEST_MAX_WORKERS=" .. max_workers .. ".")
      run_quiet_logged(
        "pnpm test",
        ".local/gates-test.log",
        {"env", "OPENCLAW_VITEST_MAX_WORKERS=" .. max_workers, "pnpm", "test"}
      )
      previous_full_gates_head = current_head
    end
  end

  -- Security: shell-escape values to prevent command injection when sourced.
  local gates_env = io.open(".local/gates.env", "w")
  gates_env:write(string.format('PR_NUMBER=%q\n', pr))
  gates_env:write(string.format('DOCS_ONLY=%q\n', docs_only))
  gates_env:write(string.format('CHANGELOG_REQUIRED=%q\n', changelog_required))
  gates_env:write(string.format('GATES_MODE=%q\n', gates_mode))
  gates_env:write(string.format('LAST_VERIFIED_HEAD_SHA=%q\n', current_head))
  gates_env:write(string.format('FULL_GATES_HEAD_SHA=%q\n', previous_full_gates_head))
  gates_env:write(string.format('GATES_PASSED_AT=%q\n', os.date("!%Y-%m-%dT%H:%M:%SZ")))
  gates_env:close()

  print("docs_only=" .. docs_only)
  print("changelog_required=" .. changelog_required)
  print("gates_mode=" .. gates_mode)
  print("wrote=.local/gates.env")
end

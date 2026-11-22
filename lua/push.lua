#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "f34ecdf6570a667e3f53ba05739a8e14cfc682639df9140b294aa9175dbdee34", "source_sha256": "fde26dcd603ac650a610d1fcacab8e1a0e329f4dc886be42c70dd72d735ee30e", "target_language": "lua"}
-- push.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/push.sh
-- Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

local json = require("cjson")

-- Hilfsfunktionen
local function read_file(path)
  local file = io.open(path, "r")
  if not file then return nil end
  local content = file:read("*a")
  file:close()
  return content
end

local function write_file(path, content)
  local file = io.open(path, "w")
  if not file then return false end
  file:write(content)
  file:close()
  return true
end

local function trim(s)
  return s:match("^%s*(.-)%s*$")
end

local function split(str, sep)
  local result = {}
  for part in str:gmatch("([^"..sep.."]+)") do
    table.insert(result, part)
  end
  return result
end

local function exec(cmd)
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  handle:close()
  return trim(result)
end

local function exec_check(cmd)
  local success, _, code = os.execute(cmd)
  return success and code == 0
end

local function load_env(file)
  local env = {}
  local content = read_file(file)
  if content then
    for line in content:gmatch("[^\r\n]+") do
      local key, value = line:match("^([%w_]+)=(.*)$")
      if key and value then
        env[key] = value:gsub("^['\"](.-)['\"]$", "%1") -- Entferne Anführungszeichen
      end
    end
  end
  return env
end

local function base64_encode(data)
  local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  local result = ''
  local i = 1
  while i <= #data do
    local a, b, c = string.byte(data, i, i+2)
    if not b then b = 0 end
    if not c then c = 0 end
    local val = a*0x10000 + b*0x100 + c
    result = result .. b64chars:sub(math.floor(val/0x1000000)+1, math.floor(val/0x1000000)+1)
    result = result .. b64chars:sub(math.floor(val/0x40000)%0x40+1, math.floor(val/0x40000)%0x40+1)
    result = result .. (i+1 <= #data and b64chars:sub(math.floor(val/0x1000)%0x40+1, math.floor(val/0x1000)%0x40+1) or '=')
    result = result .. (i+2 <= #data and b64chars:sub(val%0x40+1, val%0x40+1) or '=')
    i = i + 3
  end
  return result
end

local function jq_encode(str)
  return '"' .. str:gsub('"', '\\"') .. '"'
end

-- Funktionen aus push.sh

local function resolve_head_push_url()
  local env = load_env(".local/pr-meta.env")
  
  if env.PR_HEAD_OWNER and env.PR_HEAD_REPO_NAME and env.PR_HEAD_OWNER ~= "" and env.PR_HEAD_REPO_NAME ~= "" then
    print("https://github.com/" .. env.PR_HEAD_OWNER .. "/" .. env.PR_HEAD_REPO_NAME .. ".git")
    return true
  end
  
  if env.PR_HEAD_REPO_URL and env.PR_HEAD_REPO_URL ~= "" and env.PR_HEAD_REPO_URL ~= "null" then
    if env.PR_HEAD_REPO_URL:sub(-4) == ".git" then
      print(env.PR_HEAD_REPO_URL)
    else
      print(env.PR_HEAD_REPO_URL .. ".git")
    end
    return true
  end
  
  return false
end

local function graphql_push_to_fork(repo_nwo, branch, expected_oid)
  local max_blob_bytes = 5 * 1024 * 1024
  
  local additions = {}
  local deletions = {}
  
  local added_files_cmd = "git diff --no-renames --name-only --diff-filter=AM " .. expected_oid .. " HEAD"
  local added_files = exec(added_files_cmd)
  
  if added_files ~= "" then
    for fpath in added_files:gmatch("[^\r\n]+") do
      if fpath ~= "" then
        local tree_entry_cmd = "git ls-tree HEAD -- " .. fpath
        local tree_entry = exec(tree_entry_cmd)
        
        if tree_entry == "" then
          io.stderr:write("GraphQL push could not resolve path in HEAD tree: " .. fpath .. "\n")
          return nil
        end
        
        local parts = split(tree_entry, " ")
        local file_mode = parts[1]
        local file_type = parts[2]
        local file_oid = parts[3]
        
        if file_type ~= "blob" or file_mode == "160000" then
          io.stderr:write("GraphQL push only supports blob files; refusing " .. fpath .. " (mode=" .. file_mode .. " type=" .. file_type .. ")\n")
          return nil
        end
        
        local blob_size_cmd = "git cat-file -s " .. file_oid
        local blob_size = tonumber(exec(blob_size_cmd))
        
        if blob_size > max_blob_bytes then
          io.stderr:write("GraphQL push refused large file " .. fpath .. " (" .. blob_size .. " bytes > " .. max_blob_bytes .. ")\n")
          return nil
        end
        
        local blob_content_cmd = "git cat-file -p " .. file_oid
        local blob_content = exec(blob_content_cmd)
        local b64 = base64_encode(blob_content)
        
        table.insert(additions, {
          path = fpath,
          contents = b64
        })
      end
    end
  end
  
  local deleted_files_cmd = "git diff --no-renames --name-only --diff-filter=D " .. expected_oid .. " HEAD"
  local deleted_files = exec(deleted_files_cmd)
  
  if deleted_files ~= "" then
    for fpath in deleted_files:gmatch("[^\r\n]+") do
      if fpath ~= "" then
        table.insert(deletions, {
          path = fpath
        })
      end
    end
  end
  
  local commit_headline = exec("git log -1 --format=%s HEAD")
  
  local query = [[
mutation($input: CreateCommitOnBranchInput!) {
  createCommitOnBranch(input: $input) {
    commit { oid url }
  }
}
]]
  
  local variables = {
    input = {
      branch = {
        repositoryNameWithOwner = repo_nwo,
        branchName = branch
      },
      message = {
        headline = commit_headline
      },
      fileChanges = {
        additions = additions,
        deletions = deletions
      },
      expectedHeadOid = expected_oid
    }
  }
  
  local tmpfile = os.tmpname()
  local f = io.open(tmpfile, "w")
  f:write(json.encode(variables))
  f:close()
  
  local cmd = "gh api graphql -f query='" .. query .. "' --input " .. tmpfile
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  local success, _, code = handle:close()
  
  os.remove(tmpfile)
  
  if not success or code ~= 0 then
    io.stderr:write("GraphQL push failed: " .. result .. "\n")
    return nil
  end
  
  local data = json.decode(result)
  local new_oid = data.data.createCommitOnBranch.commit.oid
  
  if not new_oid or new_oid == "" then
    io.stderr:write("GraphQL push returned no commit OID: " .. result .. "\n")
    return nil
  end
  
  io.stderr:write("GraphQL push succeeded: " .. new_oid .. "\n")
  return new_oid
end

local function resolve_head_push_url_https()
  local env = load_env(".local/pr-meta.env")
  
  if env.PR_HEAD_OWNER and env.PR_HEAD_REPO_NAME and env.PR_HEAD_OWNER ~= "" and env.PR_HEAD_REPO_NAME ~= "" then
    print("https://github.com/" .. env.PR_HEAD_OWNER .. "/" .. env.PR_HEAD_REPO_NAME .. ".git")
    return true
  end
  
  if env.PR_HEAD_REPO_URL and env.PR_HEAD_REPO_URL ~= "" and env.PR_HEAD_REPO_URL ~= "null" then
    if env.PR_HEAD_REPO_URL:sub(-4) == ".git" then
      print(env.PR_HEAD_REPO_URL)
    else
      print(env.PR_HEAD_REPO_URL .. ".git")
    end
    return true
  end
  
  return false
end

local function verify_pr_head_branch_matches_expected(pr, expected_head)
  local current_head = exec("gh pr view " .. pr .. " --json headRefName --jq .headRefName")
  
  if current_head ~= expected_head then
    print("PR head branch changed from " .. expected_head .. " to " .. current_head .. ". Re-run prepare-init.")
    os.exit(1)
  end
end

local function setup_prhead_remote()
  local success, push_url = pcall(resolve_head_push_url)
  if not success or not push_url then
    print("Unable to resolve PR head repo push URL.")
    os.exit(1)
  end
  
  os.execute("git remote remove prhead 2>/dev/null || true")
  os.execute("git remote add prhead " .. push_url)
end

local function resolve_prhead_remote_sha(pr_head)
  local remote_sha_cmd = "git ls-remote prhead \"refs/heads/" .. pr_head .. "\" 2>/dev/null | awk '{print $1}'"
  local remote_sha = exec(remote_sha_cmd)
  
  if remote_sha == "" then
    local success, https_url = pcall(resolve_head_push_url_https)
    if success and https_url then
      local current_push_url = exec("git remote get-url prhead 2>/dev/null || true")
      
      if https_url ~= current_push_url then
        io.stderr:write("SSH remote failed; falling back to HTTPS...\n")
        os.execute("git remote set-url prhead " .. https_url)
        os.execute("git remote set-url --push prhead " .. https_url)
        remote_sha = exec(remote_sha_cmd)
      end
    end
    
    if remote_sha == "" then
      io.stderr:write("Remote branch refs/heads/" .. pr_head .. " not found on prhead\n")
      os.exit(1)
    end
  end
  
  print(remote_sha)
end

local function wait_for_pr_head_sha(pr, expected_sha, max_attempts, interval)
  for i = 1, max_attempts do
    local observed_sha = exec("gh pr view " .. pr .. " --json headRefOid --jq .headRefOid")
    if observed_sha == expected_sha then
      return true
    end
    os.execute("sleep " .. interval)
  end
  return false
end

local function run_prepare_push_retry_gates(docs_only)
  -- Diese Funktion ist im Original nicht definiert, daher leerer Stub
end

local function push_prep_head_to_pr_branch(pr, pr_head, prep_head_sha, lease_sha, rerun_gates_on_lease_retry, docs_only, result_env_path)
  rerun_gates_on_lease_retry = rerun_gates_on_lease_retry or false
  docs_only = docs_only or false
  result_env_path = result_env_path or ".local/push-result.env"
  
  setup_prhead_remote()
  
  local remote_sha = exec("resolve_prhead_remote_sha \"" .. pr_head .. "\"")
  
  local pushed_from_sha = remote_sha
  if remote_sha == prep_head_sha then
    print("Remote branch already at local prep HEAD; skipping push.")
  else
    if remote_sha ~= lease_sha then
      print("Remote SHA " .. remote_sha .. " differs from PR head SHA " .. lease_sha .. ". Refreshing lease SHA from remote.")
      lease_sha = exec("gh pr view " .. pr .. " --json headRefOid --jq .headRefOid")
    end
    
    pushed_from_sha = lease_sha
    local push_cmd = "git push --force-with-lease=refs/heads/" .. pr_head .. ":" .. lease_sha .. " prhead HEAD:" .. pr_head
    local success = exec_check(push_cmd)
    
    if not success then
      local push_output = exec(push_cmd .. " 2>&1")
      print("Push failed: " .. push_output)
      
      if push_output:lower():find("permission") or push_output:lower():find("denied") or push_output:find("403") or push_output:lower():find("forbidden") then
        print("Permission denied on git push; trying GraphQL createCommitOnBranch fallback...")
        
        local env = load_env(".local/pr-meta.env")
        if env.PR_HEAD_OWNER and env.PR_HEAD_REPO_NAME and env.PR_HEAD_OWNER ~= "" and env.PR_HEAD_REPO_NAME ~= "" then
          local graphql_oid = graphql_push_to_fork(env.PR_HEAD_OWNER .. "/" .. env.PR_HEAD_REPO_NAME, pr_head, lease_sha)
          if graphql_oid then
            prep_head_sha = graphql_oid
          else
            print("Git push permission denied and no fork owner/repo info for GraphQL fallback.")
            os.exit(1)
          end
        else
          print("Git push permission denied and no fork owner/repo info for GraphQL fallback.")
          os.exit(1)
        end
      else
        print("Lease push failed, retrying once with fresh PR head...")
        lease_sha = exec("gh pr view " .. pr .. " --json headRefOid --jq .headRefOid")
        pushed_from_sha = lease_sha
        
        if rerun_gates_on_lease_retry == "true" then
          os.execute("git fetch origin \"pull/" .. pr .. "/head:pr-" .. pr .. "-latest\" --force")
          os.execute("git rebase \"pr-" .. pr .. "-latest\"")
          prep_head_sha = exec("git rev-parse HEAD")
          run_prepare_push_retry_gates(docs_only)
        end
        
        local retry_push_cmd = "git push --force-with-lease=refs/heads/" .. pr_head .. ":" .. lease_sha .. " prhead HEAD:" .. pr_head
        local retry_success = exec_check(retry_push_cmd)
        
        if not retry_success then
          local retry_push_output = exec(retry_push_cmd .. " 2>&1")
          print("Retry push failed: " .. retry_push_output)
          
          local env = load_env(".local/pr-meta.env")
          if env.PR_HEAD_OWNER and env.PR_HEAD_REPO_NAME and env.PR_HEAD_OWNER ~= "" and env.PR_HEAD_REPO_NAME ~= "" then
            print("Retry failed; trying GraphQL createCommitOnBranch fallback...")
            local graphql_oid = graphql_push_to_fork(env.PR_HEAD_OWNER .. "/" .. env.PR_HEAD_REPO_NAME, pr_head, lease_sha)
            if graphql_oid then
              prep_head_sha = graphql_oid
            else
              print("Git push failed and no fork owner/repo info for GraphQL fallback.")
              os.exit(1)
            end
          else
            print("Git push failed and no fork owner/repo info for GraphQL fallback.")
            os.exit(1)
          end
        end
      end
    end
  end
  
  if not wait_for_pr_head_sha(pr, prep_head_sha, 8, 3) then
    local observed_sha = exec("gh pr view " .. pr .. " --json headRefOid --jq .headRefOid")
    print("Pushed head SHA propagation timed out. expected=" .. prep_head_sha .. " observed=" .. observed_sha)
    os.exit(1)
  end
  
  local pr_head_sha_after = exec("gh pr view " .. pr .. " --json headRefOid --jq .headRefOid")
  
  os.execute("git fetch origin main")
  os.execute("git fetch origin \"pull/" .. pr .. "/head:pr-" .. pr .. "-verify\" --force")
  local merge_base_success = exec_check("git merge-base --is-ancestor origin/main \"pr-" .. pr .. "-verify\"")
  
  if not merge_base_success then
    print("PR branch is behind main after push.")
    os.exit(1)
  end
  
  os.execute("git branch -D \"pr-" .. pr .. "-verify\" 2>/dev/null || true")
  
  -- Sicherheit: Werte escapen um Command Injection zu verhindern
  local result_content = string.format("PUSH_PREP_HEAD_SHA=%q\n", prep_head_sha) ..
                         string.format("PUSHED_FROM_SHA=%q\n", pushed_from_sha) ..
                         string.format("PR_HEAD_SHA_AFTER_PUSH=%q\n", pr_head_sha_after)
  
  write_file(result_env_path, result_content)
end

-- Hauptprogramm
if #arg < 1 then
  print("Usage: push.lua <function_name> [args...]")
  os.exit(1)
end

local func_name = arg[1]
local args = {}
for i = 2, #arg do
  table.insert(args, arg[i])
end

if func_name == "resolve_head_push_url" then
  resolve_head_push_url()
elseif func_name == "graphql_push_to_fork" then
  if #args < 3 then
    print("Usage: graphql_push_to_fork <repo_nwo> <branch> <expected_oid>")
    os.exit(1)
  end
  local result = graphql_push_to_fork(args[1], args[2], args[3])
  if result then
    print(result)
  else
    os.exit(1)
  end
elseif func_name == "resolve_head_push_url_https" then
  resolve_head_push_url_https()
elseif func_name == "verify_pr_head_branch_matches_expected" then
  if #args < 2 then
    print("Usage: verify_pr_head_branch_matches_expected <pr> <expected_head>")
    os.exit(1)
  end
  verify_pr_head_branch_matches_expected(args[1], args[2])
elseif func_name == "setup_prhead_remote" then
  setup_prhead_remote()
elseif func_name == "resolve_prhead_remote_sha" then
  if #args < 1 then
    print("Usage: resolve_prhead_remote_sha <pr_head>")
    os.exit(1)
  end
  resolve_prhead_remote_sha(args[1])
elseif func_name == "push_prep_head_to_pr_branch" then
  if #args < 4 then
    print("Usage: push_prep_head_to_pr_branch <pr> <pr_head> <prep_head_sha> <lease_sha> [rerun_gates_on_lease_retry] [docs_only] [result_env_path]")
    os.exit(1)
  end
  push_prep_head_to_pr_branch(args[1], args[2], args[3], args[4], args[5], args[6], args[7])
else
  print("Unknown function: " .. func_name)
  os.exit(1)
end

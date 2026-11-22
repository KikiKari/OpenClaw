#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "7bda99b1180c704b030d2578e69e7f2bf7a340ba6d822d67552a71e6ba42bdef", "source_sha256": "fde26dcd603ac650a610d1fcacab8e1a0e329f4dc886be42c70dd72d735ee30e", "target_language": "ruby"}
# push.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/push.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

require 'base64'
require 'json'
require 'open3'

def resolve_head_push_url
  load_env_file('.local/pr-meta.env')

  if ENV['PR_HEAD_OWNER'] && ENV['PR_HEAD_REPO_NAME']
    return "https://github.com/#{ENV['PR_HEAD_OWNER']}/#{ENV['PR_HEAD_REPO_NAME']}.git"
  end

  if ENV['PR_HEAD_REPO_URL'] && ENV['PR_HEAD_REPO_URL'] != 'null'
    return ENV['PR_HEAD_REPO_URL'].end_with?('.git') ? ENV['PR_HEAD_REPO_URL'] : "#{ENV['PR_HEAD_REPO_URL']}.git"
  end

  nil
end

def graphql_push_to_fork(repo_nwo, branch, expected_oid)
  max_blob_bytes = 5 * 1024 * 1024
  additions = []
  deletions = []

  added_files = `git diff --no-renames --name-only --diff-filter=AM #{expected_oid} HEAD`.strip.split("\n").reject(&:empty?)
  added_files.each do |fpath|
    tree_entry = `git ls-tree HEAD -- #{fpath}`.strip
    if tree_entry.empty?
      STDERR.puts "GraphQL push could not resolve path in HEAD tree: #{fpath}"
      exit 1
    end

    parts = tree_entry.split
    file_mode = parts[0]
    file_type = parts[1]
    file_oid = parts[2]

    if file_type != 'blob' || file_mode == '160000'
      STDERR.puts "GraphQL push only supports blob files; refusing #{fpath} (mode=#{file_mode} type=#{file_type})"
      exit 1
    end

    blob_size = `git cat-file -s #{file_oid}`.to_i
    if blob_size > max_blob_bytes
      STDERR.puts "GraphQL push refused large file #{fpath} (#{blob_size} bytes > #{max_blob_bytes})"
      exit 1
    end

    file_content = `git cat-file -p #{file_oid}`
    encoded_content = Base64.strict_encode64(file_content).delete("\n")
    additions << {
      'path' => fpath,
      'contents' => encoded_content
    }
  end

  deleted_files = `git diff --no-renames --name-only --diff-filter=D #{expected_oid} HEAD`.strip.split("\n").reject(&:empty?)
  deleted_files.each do |fpath|
    deletions << { 'path' => fpath }
  end

  commit_headline = `git log -1 --format=%s HEAD`.strip

  query = <<~GRAPHQL
    mutation($input: CreateCommitOnBranchInput!) {
      createCommitOnBranch(input: $input) {
        commit { oid url }
      }
    }
  GRAPHQL

  variables = {
    'input' => {
      'branch' => { 'repositoryNameWithOwner' => repo_nwo, 'branchName' => branch },
      'message' => { 'headline' => commit_headline },
      'fileChanges' => { 'additions' => additions, 'deletions' => deletions },
      'expectedHeadOid' => expected_oid
    }
  }

  stdin, stdout, stderr, wait_thr = Open3.popen3('gh', 'api', 'graphql', '-f', "query=#{query}")
  stdin.write(JSON.generate(variables))
  stdin.close

  result = stdout.read
  error = stderr.read
  status = wait_thr.value

  unless status.success?
    STDERR.puts "GraphQL push failed: #{error}"
    exit 1
  end

  response = JSON.parse(result)
  new_oid = response.dig('data', 'createCommitOnBranch', 'commit', 'oid')

  if new_oid.nil? || new_oid.empty?
    STDERR.puts "GraphQL push returned no commit OID: #{result}"
    exit 1
  end

  STDERR.puts "GraphQL push succeeded: #{new_oid}"
  puts new_oid
end

def resolve_head_push_url_https
  load_env_file('.local/pr-meta.env')

  if ENV['PR_HEAD_OWNER'] && ENV['PR_HEAD_REPO_NAME']
    return "https://github.com/#{ENV['PR_HEAD_OWNER']}/#{ENV['PR_HEAD_REPO_NAME']}.git"
  end

  if ENV['PR_HEAD_REPO_URL'] && ENV['PR_HEAD_REPO_URL'] != 'null'
    return ENV['PR_HEAD_REPO_URL'].end_with?('.git') ? ENV['PR_HEAD_REPO_URL'] : "#{ENV['PR_HEAD_REPO_URL']}.git"
  end

  nil
end

def verify_pr_head_branch_matches_expected(pr, expected_head)
  current_head = `gh pr view #{pr} --json headRefName --jq .headRefName`.strip
  if current_head != expected_head
    puts "PR head branch changed from #{expected_head} to #{current_head}. Re-run prepare-init."
    exit 1
  end
end

def setup_prhead_remote
  push_url = resolve_head_push_url
  if push_url.nil?
    puts "Unable to resolve PR head repo push URL."
    exit 1
  end

  system('git', 'remote', 'remove', 'prhead', out: File::NULL, err: File::NULL)
  system('git', 'remote', 'add', 'prhead', push_url)
end

def resolve_prhead_remote_sha(pr_head)
  remote_sha = `git ls-remote prhead "refs/heads/#{pr_head}" 2>/dev/null`.split.first
  return remote_sha unless remote_sha.nil?

  https_url = resolve_head_push_url_https
  current_push_url = `git remote get-url prhead 2>/dev/null`.strip

  if https_url && https_url != current_push_url
    STDERR.puts "SSH remote failed; falling back to HTTPS..."
    system('git', 'remote', 'set-url', 'prhead', https_url)
    system('git', 'remote', 'set-url', '--push', 'prhead', https_url)
    remote_sha = `git ls-remote prhead "refs/heads/#{pr_head}" 2>/dev/null`.split.first
  end

  if remote_sha.nil?
    STDERR.puts "Remote branch refs/heads/#{pr_head} not found on prhead"
    exit 1
  end

  remote_sha
end

def push_prep_head_to_pr_branch(pr, pr_head, prep_head_sha, lease_sha, rerun_gates_on_lease_retry = false, docs_only = false, result_env_path = '.local/push-result.env')
  setup_prhead_remote

  remote_sha = resolve_prhead_remote_sha(pr_head)

  pushed_from_sha = remote_sha
  if remote_sha == prep_head_sha
    puts "Remote branch already at local prep HEAD; skipping push."
  else
    if remote_sha != lease_sha
      puts "Remote SHA #{remote_sha} differs from PR head SHA #{lease_sha}. Refreshing lease SHA from remote."
      lease_sha = remote_sha
    end
    pushed_from_sha = lease_sha

    success = system("git push --force-with-lease=refs/heads/#{pr_head}:#{lease_sha} prhead HEAD:#{pr_head}", out: File::NULL, err: [:child, :out])
    unless success
      push_output = `git push --force-with-lease=refs/heads/#{pr_head}:#{lease_sha} prhead HEAD:#{pr_head} 2>&1`

      if push_output.match?(/(permission|denied|403|forbidden)/i)
        puts "Permission denied on git push; trying GraphQL createCommitOnBranch fallback..."
        if ENV['PR_HEAD_OWNER'] && ENV['PR_HEAD_REPO_NAME']
          graphql_oid = graphql_push_to_fork("#{ENV['PR_HEAD_OWNER']}/#{ENV['PR_HEAD_REPO_NAME']}", pr_head, lease_sha)
          prep_head_sha = graphql_oid
        else
          puts "Git push permission denied and no fork owner/repo info for GraphQL fallback."
          exit 1
        end
      else
        puts "Lease push failed, retrying once with fresh PR head..."
        lease_sha = `gh pr view #{pr} --json headRefOid --jq .headRefOid`.strip
        pushed_from_sha = lease_sha

        if rerun_gates_on_lease_retry
          system("git fetch origin pull/#{pr}/head:pr-#{pr}-latest --force")
          system("git rebase pr-#{pr}-latest")
          prep_head_sha = `git rev-parse HEAD`.strip
          run_prepare_push_retry_gates(docs_only)
        end

        success = system("git push --force-with-lease=refs/heads/#{pr_head}:#{lease_sha} prhead HEAD:#{pr_head}", out: File::NULL, err: [:child, :out])
        unless success
          push_output = `git push --force-with-lease=refs/heads/#{pr_head}:#{lease_sha} prhead HEAD:#{pr_head} 2>&1`
          puts "Retry push failed: #{push_output}"

          if ENV['PR_HEAD_OWNER'] && ENV['PR_HEAD_REPO_NAME']
            puts "Retry failed; trying GraphQL createCommitOnBranch fallback..."
            graphql_oid = graphql_push_to_fork("#{ENV['PR_HEAD_OWNER']}/#{ENV['PR_HEAD_REPO_NAME']}", pr_head, lease_sha)
            prep_head_sha = graphql_oid
          else
            puts "Git push failed and no fork owner/repo info for GraphQL fallback."
            exit 1
          end
        end
      end
    end
  end

  unless wait_for_pr_head_sha(pr, prep_head_sha, 8, 3)
    observed_sha = `gh pr view #{pr} --json headRefOid --jq .headRefOid`.strip
    puts "Pushed head SHA propagation timed out. expected=#{prep_head_sha} observed=#{observed_sha}"
    exit 1
  end

  pr_head_sha_after = `gh pr view #{pr} --json headRefOid --jq .headRefOid`.strip

  system('git', 'fetch', 'origin', 'main')
  system("git fetch origin pull/#{pr}/head:pr-#{pr}-verify --force")
  unless system("git merge-base --is-ancestor origin/main pr-#{pr}-verify")
    puts "PR branch is behind main after push."
    exit 1
  end
  system("git branch -D pr-#{pr}-verify", out: File::NULL, err: File::NULL)

  File.open(result_env_path, 'w') do |f|
    f.puts "PUSH_PREP_HEAD_SHA=#{shell_escape(prep_head_sha)}"
    f.puts "PUSHED_FROM_SHA=#{shell_escape(pushed_from_sha)}"
    f.puts "PR_HEAD_SHA_AFTER_PUSH=#{shell_escape(pr_head_sha_after)}"
  end
end

private

def load_env_file(path)
  return unless File.exist?(path)

  File.readlines(path).each do |line|
    line.strip!
    next if line.empty? || line.start_with?('#')
    
    key, value = line.split('=', 2)
    ENV[key] = value&.gsub(/\A(['"])(.*)\1\z/, '\\2') # Remove surrounding quotes
  end
end

def shell_escape(str)
  "'#{str.gsub("'", "'\\\\''")}'"
end

def wait_for_pr_head_sha(pr, expected_sha, max_attempts, interval)
  max_attempts.times do
    current_sha = `gh pr view #{pr} --json headRefOid --jq .headRefOid`.strip
    return true if current_sha == expected_sha
    
    sleep interval
  end
  false
end

def run_prepare_push_retry_gates(docs_only)
  # Placeholder for actual implementation
  # This would need to be defined based on the specific requirements
end

#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "eac1201eac0c8dadafdfa68f71d446a83c32391cf5408c83799147a31aedb088", "source_sha256": "24e3cb1dc8d717f90272134987f4b84a5137f1d8cacace1c6ccd6621b24e9566", "target_language": "ruby"}
# review.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/review.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'open3'
require 'fileutils'
require 'date'

def set_review_mode(mode)
  # Security: shell-escape values to prevent command injection when sourced.
  File.open('.local/review-mode.env', 'w') do |f|
    f.puts "REVIEW_MODE=#{mode.dump}"
    f.puts "REVIEW_MODE_SET_AT=#{Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ').dump}"
  end
end

def review_claim(pr)
  root = repo_root
  Dir.chdir(root)
  FileUtils.mkdir_p('.local')

  reviewer = ''
  max_attempts = 3

  (1..max_attempts).each do |attempt|
    user_log = ".local/review-claim-user-attempt-#{attempt}.log"

    stdout, stderr, status = Open3.capture3('gh', 'api', 'user', '--jq', '.login')
    File.write(user_log, stdout.empty? ? stderr : stdout)

    if status.success?
      reviewer = stdout.strip
      File.write(user_log, reviewer)
      break
    end

    puts "Claim reviewer lookup failed (attempt #{attempt}/#{max_attempts})."
    print_relevant_log_excerpt(user_log)

    sleep(2) if attempt < max_attempts
  end

  if reviewer.empty?
    puts "Failed to resolve reviewer login after #{max_attempts} attempts."
    return false
  end

  (1..max_attempts).each do |attempt|
    claim_log = ".local/review-claim-assignee-attempt-#{attempt}.log"

    stdout, stderr, status = Open3.capture3('gh', 'pr', 'edit', pr.to_s, '--add-assignee', reviewer)
    File.write(claim_log, stdout + stderr)

    if status.success?
      puts "review claim succeeded: @#{reviewer} assigned to PR ##{pr}"
      return true
    end

    puts "Claim assignee update failed (attempt #{attempt}/#{max_attempts})."
    print_relevant_log_excerpt(claim_log)

    sleep(2) if attempt < max_attempts
  end

  puts "Failed to assign @#{reviewer} to PR ##{pr} after #{max_attempts} attempts."
  false
end

def review_checkout_main(pr)
  enter_worktree(pr, false)
  system('git', 'fetch', 'origin', 'main')
  system('git', 'checkout', '--detach', 'origin/main')
  set_review_mode('main')

  puts "review mode set to main baseline"
  branch = `git branch --show-current`.strip
  head = `git rev-parse --short HEAD`.strip
  puts "branch=#{branch}"
  puts "head=#{head}"
end

def review_checkout_pr(pr)
  enter_worktree(pr, false)
  system('git', 'fetch', 'origin', "pull/#{pr}/head:pr-#{pr}", '--force')
  system('git', 'checkout', '--detach', "pr-#{pr}")
  set_review_mode('pr')

  puts "review mode set to PR head"
  branch = `git branch --show-current`.strip
  head = `git rev-parse --short HEAD`.strip
  puts "branch=#{branch}"
  puts "head=#{head}"
end

def review_guard(pr)
  enter_worktree(pr, false)
  require_artifact('.local/review-mode.env')
  require_artifact('.local/pr-meta.env')
  
  # Load environment variables from files
  load_env_from_file('.local/review-mode.env')
  load_env_from_file('.local/pr-meta.env')

  branch = `git branch --show-current`.strip
  head_sha = `git rev-parse HEAD`.strip

  case ENV['REVIEW_MODE']
  when 'main'
    expected_main_sha = `git rev-parse origin/main`.strip
    if head_sha != expected_main_sha
      puts "Review guard failed: expected HEAD at origin/main (#{expected_main_sha}) for main baseline mode, got #{head_sha}"
      exit(1)
    end
  when 'pr'
    if ENV['PR_HEAD_SHA'].to_s.empty?
      puts "Review guard failed: missing PR_HEAD_SHA in .local/pr-meta.env"
      exit(1)
    end
    if head_sha != ENV['PR_HEAD_SHA']
      puts "Review guard failed: expected HEAD at PR_HEAD_SHA (#{ENV['PR_HEAD_SHA']}), got #{head_sha}"
      exit(1)
    end
  else
    puts "Review guard failed: unknown review mode '#{ENV['REVIEW_MODE']}'"
    exit(1)
  end

  puts "review guard passed"
  puts "mode=#{ENV['REVIEW_MODE']}"
  puts "branch=#{branch}"
  puts "head=#{head_sha}"
end

def review_artifacts_init(pr)
  enter_worktree(pr, false)
  require_artifact('.local/pr-meta.env')

  unless File.exist?('.local/review.md')
    md_content = <<~EOF_MD
      A) TL;DR recommendation

      B) What changed and what is good?

      C) Security findings

      D) What is the PR intent? Is this the most optimal implementation?

      E) Concerns or questions (actionable)

      F) Tests

      G) Docs status

      H) Changelog

      I) Follow ups (optional)

      J) Suggested PR comment (optional)
    EOF_MD
    File.write('.local/review.md', md_content)
  end

  unless File.exist?('.local/review.json')
    json_content = <<~EOF_JSON
      {
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
      }
    EOF_JSON
    File.write('.local/review.json', json_content)
  end

  puts "review artifact templates are ready"
  puts "files=.local/review.md .local/review.json"
end

def review_validate_artifacts(pr)
  enter_worktree(pr, false)
  require_artifact('.local/review.md')
  require_artifact('.local/review.json')
  require_artifact('.local/pr-meta.env')
  require_artifact('.local/pr-meta.json')

  review_guard(pr)

  # Validate JSON syntax
  JSON.parse(File.read('.local/review.json'))

  # Check for required sections in review.md
  %w[A) B) C) D) E) F) G) H) I) J)].each do |section|
    unless File.read('.local/review.md').lines.any? { |line| line.start_with?(section) }
      puts "Missing section header in .local/review.md: #{section}"
      exit(1)
    end
  end

  # Load review data
  review_data = JSON.parse(File.read('.local/review.json'))

  # Validate recommendation
  valid_recommendations = %w[READY\ FOR\ /prepare-pr NEEDS\ WORK NEEDS\ DISCUSSION NOT\ USEFUL\ (CLOSE)]
  unless valid_recommendations.include?(review_data['recommendation'])
    puts "Invalid recommendation in .local/review.json: #{review_data['recommendation']}"
    exit(1)
  end

  # Validate finding severities
  invalid_severities = review_data['findings'].select do |finding|
    !%w[BLOCKER IMPORTANT NIT].include?(finding['severity'])
  end
  unless invalid_severities.empty?
    puts "Invalid finding severity in .local/review.json"
    exit(1)
  end

  # Validate finding structure
  invalid_findings = review_data['findings'].select do |finding|
    ![finding['id'], finding['title'], finding['area'], finding['fix']].all? { |f| f.is_a?(String) }
  end
  unless invalid_findings.empty?
    puts "Invalid finding shape in .local/review.json (id/title/area/fix must be strings)"
    exit(1)
  end

  # Validate nit sweep
  nit_findings_count = review_data['findings'].count { |f| f['severity'] == 'NIT' }
  nit_sweep = review_data['nitSweep']
  
  unless nit_sweep['performed'] == true
    puts "Invalid nit sweep in .local/review.json: nitSweep.performed must be true"
    exit(1)
  end

  case nit_sweep['status']
  when 'none'
    if nit_findings_count > 0
      puts "Invalid nit sweep in .local/review.json: nitSweep.status is none but NIT findings exist"
      exit(1)
    end
  when 'has_nits'
    if nit_findings_count < 1
      puts "Invalid nit sweep in .local/review.json: nitSweep.status is has_nits but no NIT findings exist"
      exit(1)
    end
  else
    puts "Invalid nit sweep status in .local/review.json: #{nit_sweep['status']}"
    exit(1)
  end

  unless nit_sweep['summary'].is_a?(String) && !nit_sweep['summary'].strip.empty?
    puts "Invalid nit sweep summary in .local/review.json: nitSweep.summary must be a non-empty string"
    exit(1)
  end

  # Validate issue validation
  issue_validation = review_data['issueValidation']
  
  unless issue_validation['performed'] == true
    puts "Invalid issue validation in .local/review.json: issueValidation.performed must be true"
    exit(1)
  end

  valid_sources = %w[linked_issue pr_body both]
  unless valid_sources.include?(issue_validation['source'])
    puts "Invalid issue validation source in .local/review.json: #{issue_validation['source']}"
    exit(1)
  end

  valid_statuses = %w[valid unclear invalid already_fixed_on_main]
  unless valid_statuses.include?(issue_validation['status'])
    puts "Invalid issue validation status in .local/review.json: #{issue_validation['status']}"
    exit(1)
  end

  unless issue_validation['summary'].is_a?(String) && !issue_validation['summary'].strip.empty?
    puts "Invalid issue validation summary in .local/review.json: issueValidation.summary must be a non-empty string"
    exit(1)
  end

  # Validate runtime files
  pr_meta = JSON.parse(File.read('.local/pr-meta.json'))
  runtime_file_count = pr_meta['files'].count do |file|
    file['path'].match?(/^src|^extensions|^apps/) &&
    !file['path'].match?(/(__tests__|\.test\.|\.spec\.)/) &&
    !file['path'].match?(/\.(md|mdx)$/)
  end

  runtime_review_required = runtime_file_count > 0

  # Validate behavioral sweep
  behavioral_sweep = review_data['behavioralSweep']
  
  unless behavioral_sweep['performed'] == true
    puts "Invalid behavioral sweep in .local/review.json: behavioralSweep.performed must be true"
    exit(1)
  end

  valid_behavioral_statuses = %w[pass needs_work not_applicable]
  unless valid_behavioral_statuses.include?(behavioral_sweep['status'])
    puts "Invalid behavioral sweep status in .local/review.json: #{behavioral_sweep['status']}"
    exit(1)
  end

  valid_risks = %w[none present unknown]
  unless valid_risks.include?(behavioral_sweep['silentDropRisk'])
    puts "Invalid behavioral sweep risk in .local/review.json: #{behavioral_sweep['silentDropRisk']}"
    exit(1)
  end

  unless behavioral_sweep['summary'].is_a?(String) && !behavioral_sweep['summary'].strip.empty?
    puts "Invalid behavioral sweep summary in .local/review.json: behavioralSweep.summary must be a non-empty string"
    exit(1)
  end

  unless behavioral_sweep['branches'].is_a?(Array)
    puts "Invalid behavioral sweep in .local/review.json: behavioralSweep.branches must be an array"
    exit(1)
  end

  invalid_branch_entries = behavioral_sweep['branches'].any? do |branch|
    ![branch['path'], branch['decision'], branch['outcome']].all? { |b| b.is_a?(String) }
  end
  unless invalid_branch_entries.empty?
    puts "Invalid behavioral sweep branch entry in .local/review.json: each branch needs string path/decision/outcome"
    exit(1)
  end

  behavioral_branch_count = behavioral_sweep['branches'].length

  if runtime_review_required && behavioral_sweep['status'] == 'not_applicable'
    puts "Invalid behavioral sweep in .local/review.json: runtime file changes require behavioralSweep.status=pass|needs_work"
    exit(1)
  end

  if runtime_review_required && behavioral_branch_count < 1
    puts "Invalid behavioral sweep in .local/review.json: runtime file changes require at least one branch entry"
    exit(1)
  end

  if behavioral_sweep['status'] == 'not_applicable' && behavioral_branch_count > 0
    puts "Invalid behavioral sweep in .local/review.json: not_applicable cannot include branch entries"
    exit(1)
  end

  if behavioral_sweep['status'] == 'pass' && behavioral_sweep['silentDropRisk'] != 'none'
    puts "Invalid behavioral sweep in .local/review.json: status=pass requires silentDropRisk=none"
    exit(1)
  end

  # Validate recommendation dependencies
  if review_data['recommendation'] == 'READY FOR /prepare-pr'
    if issue_validation['status'] != 'valid'
      puts "Invalid recommendation in .local/review.json: READY FOR /prepare-pr requires issueValidation.status=valid"
      exit(1)
    end

    if behavioral_sweep['status'] == 'needs_work'
      puts "Invalid recommendation in .local/review.json: READY FOR /prepare-pr requires behavioralSweep.status!=needs_work"
      exit(1)
    end

    if runtime_review_required && behavioral_sweep['status'] != 'pass'
      puts "Invalid recommendation in .local/review.json: READY FOR /prepare-pr on runtime changes requires behavioralSweep.status=pass"
      exit(1)
    end

    if behavioral_sweep['silentDropRisk'] == 'present'
      puts "Invalid recommendation in .local/review.json: READY FOR /prepare-pr is not allowed when behavioralSweep.silentDropRisk=present"
      exit(1)
    end
  end

  # Validate docs status
  valid_docs_statuses = %w[up_to_date missing not_applicable]
  unless valid_docs_statuses.include?(review_data['docs'])
    puts "Invalid docs status in .local/review.json: #{review_data['docs']}"
    exit(1)
  end

  # Validate changelog status
  valid_changelog_statuses = %w[required not_required]
  unless valid_changelog_statuses.include?(review_data['changelog'])
    puts "Invalid changelog status in .local/review.json: #{review_data['changelog']} (must be \"required\" or \"not_required\")"
    exit(1)
  end

  puts "review artifacts validated"
  print_review_stdout_summary
end

def review_tests(pr, *targets)
  if targets.empty?
    puts "Usage: scripts/pr review-tests <PR> <test-file> [<test-file> ...]"
    exit(2)
  end

  enter_worktree(pr, false)
  review_guard(pr)

  targets.each do |target|
    unless File.exist?(target)
      puts "Missing test target file: #{target}"
      exit(1)
    end
  end

  bootstrap_deps_if_needed

  run_log = ".local/review-tests-run.log"
  run_quiet_logged("pnpm test", run_log, "pnpm", "test", "--", *targets)

  missing_run = []
  targets.each do |target|
    base = File.basename(target)
    unless File.read(run_log).include?(target) || File.read(run_log).include?(base)
      missing_run << target
    end
  end

  unless missing_run.empty?
    puts "These requested targets were not observed in vitest run output:"
    missing_run.each { |t| puts " - #{t}" }
    exit(1)
  end

  # Security: shell-escape values to prevent command injection when sourced.
  File.open('.local/review-tests.env', 'w') do |f|
    f.puts "REVIEW_TESTS_AT=#{Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ').dump}"
    f.puts "REVIEW_TEST_TARGET_COUNT=#{targets.length.dump}"
  end

  puts "review tests passed and were observed in output"
end

def review_init(pr)
  enter_worktree(pr, true)

  json = pr_meta_json(pr)
  write_pr_meta_files(json)

  system('git', 'fetch', 'origin', "pull/#{pr}/head:pr-#{pr}", '--force')
  mb = `git merge-base origin/main "pr-#{pr}"`.strip

  # Security: shell-escape values to prevent command injection when sourced.
  File.open('.local/review-context.env', 'w') do |f|
    f.puts "PR_NUMBER=#{pr.dump}"
    f.puts "MERGE_BASE=#{mb.dump}"
    f.puts "REVIEW_STARTED_AT=#{Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ').dump}"
  end
  set_review_mode('main')

  parsed_json = JSON.parse(json)
  puts JSON.pretty_generate({
    'number' => parsed_json['number'],
    'title' => parsed_json['title'],
    'url' => parsed_json['url'],
    'state' => parsed_json['state'],
    'isDraft' => parsed_json['isDraft'],
    'author' => parsed_json.dig('author', 'login'),
    'base' => parsed_json['baseRefName'],
    'head' => parsed_json['headRefName'],
    'headSha' => parsed_json['headRefOid'],
    'headRepo' => parsed_json.dig('headRepository', 'nameWithOwner'),
    'additions' => parsed_json['additions'],
    'deletions' => parsed_json['deletions'],
    'files' => parsed_json['files'].length
  })
  
  puts "worktree=#{Dir.pwd}"
  puts "pr_url=#{ENV['PR_URL'] || ''}"
  puts "merge_base=#{mb}"
  puts "branch=#{`git branch --show-current`.strip}"
  puts "wrote=.local/pr-meta.json .local/pr-meta.env .local/review-context.env .local/review-mode.env"
  
  guide = <<~EOF_GUIDE
    Review guidance:
    - Inspect main baseline: scripts/pr review-checkout-main #{pr}
    - Inspect PR head:      scripts/pr review-checkout-pr #{pr}
    - Guard before writeout: scripts/pr review-guard #{pr}
  EOF_GUIDE
  puts guide
end

# Helper methods would need to be implemented based on the original shell functions
# These are stubbed here as they're referenced but not provided in the input

def repo_root
  # Implementation needed
end

def enter_worktree(pr, create)
  # Implementation needed
end

def require_artifact(file)
  # Implementation needed
end

def print_relevant_log_excerpt(log_file)
  # Implementation needed
end

def load_env_from_file(file)
  # Implementation needed
end

def pr_meta_json(pr)
  # Implementation needed
end

def write_pr_meta_files(json)
  # Implementation needed
end

def run_quiet_logged(label, log_file, *command)
  # Implementation needed
end

def bootstrap_deps_if_needed
  # Implementation needed
end

def print_review_stdout_summary
  # Implementation needed
end

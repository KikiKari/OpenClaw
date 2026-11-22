#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "cb96c4b1983928c27dcc66aaecdf22ecdf083714646ffe215ccc17c7a6375896", "source_sha256": "24e3cb1dc8d717f90272134987f4b84a5137f1d8cacace1c6ccd6621b24e9566", "target_language": "python"}
# review.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/review.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import json
import subprocess
import time
import shutil
from datetime import datetime, timezone
from pathlib import Path

def set_review_mode(mode):
    """Set the review mode and timestamp."""
    env_content = f'REVIEW_MODE={mode!r}\n'
    env_content += f'REVIEW_MODE_SET_AT={(datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))!r}\n'
    
    with open('.local/review-mode.env', 'w') as f:
        f.write(env_content)

def repo_root():
    """Get repository root directory."""
    result = subprocess.run(['git', 'rev-parse', '--show-toplevel'], 
                          capture_output=True, text=True, check=True)
    return result.stdout.strip()

def print_relevant_log_excerpt(log_file):
    """Print relevant excerpt from log file."""
    try:
        with open(log_file, 'r') as f:
            lines = f.readlines()
            # Print last few lines if file exists
            for line in lines[-10:]:
                print(line.rstrip())
    except FileNotFoundError:
        pass

def review_claim(pr):
    """Claim a review by assigning yourself to the PR."""
    root = repo_root()
    os.chdir(root)
    os.makedirs('.local', exist_ok=True)
    
    reviewer = ""
    max_attempts = 3
    
    for attempt in range(1, max_attempts + 1):
        user_log = f".local/review-claim-user-attempt-{attempt}.log"
        
        try:
            result = subprocess.run(['gh', 'api', 'user', '--jq', '.login'], 
                                  capture_output=True, text=True, check=True)
            reviewer = result.stdout.strip()
            with open(user_log, 'w') as f:
                f.write(reviewer + '\n')
            break
        except subprocess.CalledProcessError as e:
            print(f"Claim reviewer lookup failed (attempt {attempt}/{max_attempts}).")
            with open(user_log, 'w') as f:
                f.write(e.stderr)
            print_relevant_log_excerpt(user_log)
            
            if attempt < max_attempts:
                time.sleep(2)
    
    if not reviewer:
        print(f"Failed to resolve reviewer login after {max_attempts} attempts.")
        return False
    
    for attempt in range(1, max_attempts + 1):
        claim_log = f".local/review-claim-assignee-attempt-{attempt}.log"
        
        try:
            subprocess.run(['gh', 'pr', 'edit', str(pr), '--add-assignee', reviewer], 
                          check=True, stdout=open(claim_log, 'w'), stderr=subprocess.STDOUT)
            print(f"review claim succeeded: @{reviewer} assigned to PR #{pr}")
            return True
        except subprocess.CalledProcessError:
            print(f"Claim assignee update failed (attempt {attempt}/{max_attempts}).")
            print_relevant_log_excerpt(claim_log)
            
            if attempt < max_attempts:
                time.sleep(2)
    
    print(f"Failed to assign @{reviewer} to PR #{pr} after {max_attempts} attempts.")
    return False

def enter_worktree(pr, create=False):
    """Enter or create worktree for PR."""
    worktree_path = f".worktrees/pr-{pr}"
    
    if create:
        # Remove existing worktree if it exists
        if os.path.exists(worktree_path):
            subprocess.run(['git', 'worktree', 'remove', '-f', worktree_path], 
                         stderr=subprocess.DEVNULL)
        # Create new worktree
        subprocess.run(['git', 'worktree', 'add', '-f', worktree_path, 
                       f'pr-{pr}'], check=True)
    
    os.chdir(worktree_path)

def require_artifact(path):
    """Check that artifact exists."""
    if not os.path.exists(path):
        print(f"Missing required artifact: {path}")
        sys.exit(1)

def review_checkout_main(pr):
    """Checkout main branch for review."""
    enter_worktree(pr, False)
    subprocess.run(['git', 'fetch', 'origin', 'main'], check=True)
    subprocess.run(['git', 'checkout', '--detach', 'origin/main'], check=True)
    set_review_mode('main')
    
    branch = subprocess.run(['git', 'branch', '--show-current'], 
                           capture_output=True, text=True, check=True).stdout.strip()
    head = subprocess.run(['git', 'rev-parse', '--short', 'HEAD'], 
                         capture_output=True, text=True, check=True).stdout.strip()
    
    print("review mode set to main baseline")
    print(f"branch={branch}")
    print(f"head={head}")

def review_checkout_pr(pr):
    """Checkout PR head for review."""
    enter_worktree(pr, False)
    subprocess.run(['git', 'fetch', 'origin', f'pull/{pr}/head:pr-{pr}', '--force'], check=True)
    subprocess.run(['git', 'checkout', '--detach', f'pr-{pr}'], check=True)
    set_review_mode('pr')
    
    branch = subprocess.run(['git', 'branch', '--show-current'], 
                           capture_output=True, text=True, check=True).stdout.strip()
    head = subprocess.run(['git', 'rev-parse', '--short', 'HEAD'], 
                         capture_output=True, text=True, check=True).stdout.strip()
    
    print("review mode set to PR head")
    print(f"branch={branch}")
    print(f"head={head}")

def review_guard(pr):
    """Validate current review state."""
    enter_worktree(pr, False)
    require_artifact('.local/review-mode.env')
    require_artifact('.local/pr-meta.env')
    
    # Source environment files
    review_env = {}
    pr_env = {}
    
    with open('.local/review-mode.env', 'r') as f:
        for line in f:
            if '=' in line:
                key, value = line.strip().split('=', 1)
                # Remove quotes if present
                if value.startswith("'") and value.endswith("'"):
                    value = value[1:-1]
                elif value.startswith('"') and value.endswith('"'):
                    value = value[1:-1]
                review_env[key] = value
    
    with open('.local/pr-meta.env', 'r') as f:
        for line in f:
            if '=' in line:
                key, value = line.strip().split('=', 1)
                # Remove quotes if present
                if value.startswith("'") and value.endswith("'"):
                    value = value[1:-1]
                elif value.startswith('"') and value.endswith('"'):
                    value = value[1:-1]
                pr_env[key] = value
    
    branch = subprocess.run(['git', 'branch', '--show-current'], 
                           capture_output=True, text=True, check=True).stdout.strip()
    head_sha = subprocess.run(['git', 'rev-parse', 'HEAD'], 
                             capture_output=True, text=True, check=True).stdout.strip()
    
    review_mode = review_env.get('REVIEW_MODE', '')
    
    if review_mode == 'main':
        expected_main_sha = subprocess.run(['git', 'rev-parse', 'origin/main'], 
                                          capture_output=True, text=True, check=True).stdout.strip()
        if head_sha != expected_main_sha:
            print(f"Review guard failed: expected HEAD at origin/main ({expected_main_sha}) for main baseline mode, got {head_sha}")
            sys.exit(1)
    elif review_mode == 'pr':
        pr_head_sha = pr_env.get('PR_HEAD_SHA', '')
        if not pr_head_sha:
            print("Review guard failed: missing PR_HEAD_SHA in .local/pr-meta.env")
            sys.exit(1)
        if head_sha != pr_head_sha:
            print(f"Review guard failed: expected HEAD at PR_HEAD_SHA ({pr_head_sha}), got {head_sha}")
            sys.exit(1)
    else:
        print(f"Review guard failed: unknown review mode '{review_mode}'")
        sys.exit(1)
    
    print("review guard passed")
    print(f"mode={review_mode}")
    print(f"branch={branch}")
    print(f"head={head_sha}")

def review_artifacts_init(pr):
    """Initialize review artifacts."""
    enter_worktree(pr, False)
    require_artifact('.local/pr-meta.env')
    
    md_content = """A) TL;DR recommendation

B) What changed and what is good?

C) Security findings

D) What is the PR intent? Is this the most optimal implementation?

E) Concerns or questions (actionable)

F) Tests

G) Docs status

H) Changelog

I) Follow ups (optional)

J) Suggested PR comment (optional)
"""
    
    json_content = {
        "recommendation": "NEEDS WORK",
        "findings": [],
        "nitSweep": {
            "performed": True,
            "status": "none",
            "summary": "No optional nits identified."
        },
        "behavioralSweep": {
            "performed": True,
            "status": "not_applicable",
            "summary": "No runtime branch-level behavior changes require sweep evidence.",
            "silentDropRisk": "none",
            "branches": []
        },
        "issueValidation": {
            "performed": True,
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
    
    if not os.path.exists('.local/review.md'):
        with open('.local/review.md', 'w') as f:
            f.write(md_content)
    
    if not os.path.exists('.local/review.json'):
        with open('.local/review.json', 'w') as f:
            json.dump(json_content, f, indent=2)
    
    print("review artifact templates are ready")
    print("files=.local/review.md .local/review.json")

def run_jq_filter(filter_expr, file_path):
    """Run jq filter on file and return result."""
    result = subprocess.run(['jq', filter_expr, file_path], 
                          capture_output=True, text=True, check=True)
    return result.stdout.strip()

def run_jq_test(filter_expr, file_path):
    """Run jq test and return boolean result."""
    try:
        subprocess.run(['jq', filter_expr, file_path], 
                      capture_output=True, check=True)
        return True
    except subprocess.CalledProcessError:
        return False

def review_validate_artifacts(pr):
    """Validate review artifacts."""
    enter_worktree(pr, False)
    require_artifact('.local/review.md')
    require_artifact('.local/review.json')
    require_artifact('.local/pr-meta.env')
    require_artifact('.local/pr-meta.json')
    
    review_guard(pr)
    
    # Validate JSON syntax
    subprocess.run(['jq', '.', '.local/review.json'], check=True)
    
    # Check all sections exist in markdown
    sections = ["A)", "B)", "C)", "D)", "E)", "F)", "G)", "H)", "I)", "J)"]
    with open('.local/review.md', 'r') as f:
        content = f.read()
        for section in sections:
            if f"{section}" not in content:
                print(f"Missing section header in .local/review.md: {section}")
                sys.exit(1)
    
    # Validate recommendation
    recommendation = run_jq_filter('.recommendation // ""', '.local/review.json')
    valid_recommendations = ["READY FOR /prepare-pr", "NEEDS WORK", "NEEDS DISCUSSION", "NOT USEFUL (CLOSE)"]
    if recommendation not in valid_recommendations:
        print(f"Invalid recommendation in .local/review.json: {recommendation}")
        sys.exit(1)
    
    # Validate finding severities
    invalid_severity_count = int(run_jq_filter('[.findings[]? | select((.severity // "") != "BLOCKER" and (.severity // "") != "IMPORTANT" and (.severity // "") != "NIT")] | length', '.local/review.json'))
    if invalid_severity_count > 0:
        print("Invalid finding severity in .local/review.json")
        sys.exit(1)
    
    # Validate finding structure
    invalid_findings_count = int(run_jq_filter('[.findings[]? | select((.id|type)!="string" or (.title|type)!="string" or (.area|type)!="string" or (.fix|type)!="string")] | length', '.local/review.json'))
    if invalid_findings_count > 0:
        print("Invalid finding shape in .local/review.json (id/title/area/fix must be strings)")
        sys.exit(1)
    
    # Count nit findings
    nit_findings_count = int(run_jq_filter('[.findings[]? | select((.severity // "") == "NIT")] | length', '.local/review.json'))
    
    # Validate nit sweep performed
    nit_sweep_performed = run_jq_filter('.nitSweep.performed // empty', '.local/review.json')
    if nit_sweep_performed != "true":
        print("Invalid nit sweep in .local/review.json: nitSweep.performed must be true")
        sys.exit(1)
    
    # Validate nit sweep status
    nit_sweep_status = run_jq_filter('.nitSweep.status // ""', '.local/review.json')
    if nit_sweep_status == "none":
        if nit_findings_count > 0:
            print("Invalid nit sweep in .local/review.json: nitSweep.status is none but NIT findings exist")
            sys.exit(1)
    elif nit_sweep_status == "has_nits":
        if nit_findings_count < 1:
            print("Invalid nit sweep in .local/review.json: nitSweep.status is has_nits but no NIT findings exist")
            sys.exit(1)
    else:
        print(f"Invalid nit sweep status in .local/review.json: {nit_sweep_status}")
        sys.exit(1)
    
    # Validate nit summary
    invalid_nit_summary_count = int(run_jq_filter('[.nitSweep.summary | select((type != "string") or (gsub("^\\\\s+|\\\\s+$";"") | length == 0))] | length', '.local/review.json'))
    if invalid_nit_summary_count > 0:
        print("Invalid nit sweep summary in .local/review.json: nitSweep.summary must be a non-empty string")
        sys.exit(1)
    
    # Validate issue validation performed
    issue_validation_performed = run_jq_filter('.issueValidation.performed // empty', '.local/review.json')
    if issue_validation_performed != "true":
        print("Invalid issue validation in .local/review.json: issueValidation.performed must be true")
        sys.exit(1)
    
    # Validate issue validation source
    issue_validation_source = run_jq_filter('.issueValidation.source // ""', '.local/review.json')
    valid_sources = ["linked_issue", "pr_body", "both"]
    if issue_validation_source not in valid_sources:
        print(f"Invalid issue validation source in .local/review.json: {issue_validation_source}")
        sys.exit(1)
    
    # Validate issue validation status
    issue_validation_status = run_jq_filter('.issueValidation.status // ""', '.local/review.json')
    valid_statuses = ["valid", "unclear", "invalid", "already_fixed_on_main"]
    if issue_validation_status not in valid_statuses:
        print(f"Invalid issue validation status in .local/review.json: {issue_validation_status}")
        sys.exit(1)
    
    # Validate issue summary
    invalid_issue_summary_count = int(run_jq_filter('[.issueValidation.summary | select((type != "string") or (gsub("^\\\\s+|\\\\s+$";"") | length == 0))] | length', '.local/review.json'))
    if invalid_issue_summary_count > 0:
        print("Invalid issue validation summary in .local/review.json: issueValidation.summary must be a non-empty string")
        sys.exit(1)
    
    # Check if runtime review is required
    runtime_file_count = int(run_jq_filter('[.files[]? | (.path // "") | select(test("^(src|extensions|apps)/")) | select(test("(^|/)__tests__/|\\\\.test\\\\.|\\\\.spec\\\\.") | not) | select(test("\\\\.(md|mdx)$") | not)] | length', '.local/pr-meta.json'))
    runtime_review_required = runtime_file_count > 0
    
    # Validate behavioral sweep performed
    behavioral_sweep_performed = run_jq_filter('.behavioralSweep.performed // empty', '.local/review.json')
    if behavioral_sweep_performed != "true":
        print("Invalid behavioral sweep in .local/review.json: behavioralSweep.performed must be true")
        sys.exit(1)
    
    # Validate behavioral sweep status
    behavioral_sweep_status = run_jq_filter('.behavioralSweep.status // ""', '.local/review.json')
    valid_behaviors = ["pass", "needs_work", "not_applicable"]
    if behavioral_sweep_status not in valid_behaviors:
        print(f"Invalid behavioral sweep status in .local/review.json: {behavioral_sweep_status}")
        sys.exit(1)
    
    # Validate behavioral sweep risk
    behavioral_sweep_risk = run_jq_filter('.behavioralSweep.silentDropRisk // ""', '.local/review.json')
    valid_risks = ["none", "present", "unknown"]
    if behavioral_sweep_risk not in valid_risks:
        print(f"Invalid behavioral sweep risk in .local/review.json: {behavioral_sweep_risk}")
        sys.exit(1)
    
    # Validate behavioral summary
    invalid_behavioral_summary_count = int(run_jq_filter('[.behavioralSweep.summary | select((type != "string") or (gsub("^\\\\s+|\\\\s+$";"") | length == 0))] | length', '.local/review.json'))
    if invalid_behavioral_summary_count > 0:
        print("Invalid behavioral sweep summary in .local/review.json: behavioralSweep.summary must be a non-empty string")
        sys.exit(1)
    
    # Validate behavioral branches is array
    behavioral_branches_is_array = run_jq_filter('if (.behavioralSweep.branches | type) == "array" then "true" else "false" end', '.local/review.json')
    if behavioral_branches_is_array != "true":
        print("Invalid behavioral sweep in .local/review.json: behavioralSweep.branches must be an array")
        sys.exit(1)
    
    # Validate behavioral branch entries
    invalid_behavioral_branch_count = int(run_jq_filter('[.behavioralSweep.branches[]? | select((.path|type)!="string" or (.decision|type)!="string" or (.outcome|type)!="string")] | length', '.local/review.json'))
    if invalid_behavioral_branch_count > 0:
        print("Invalid behavioral sweep branch entry in .local/review.json: each branch needs string path/decision/outcome")
        sys.exit(1)
    
    # Count behavioral branches
    behavioral_branch_count = int(run_jq_filter('[.behavioralSweep.branches[]?] | length', '.local/review.json'))
    
    # Validate behavioral sweep constraints
    if runtime_review_required and behavioral_sweep_status == "not_applicable":
        print("Invalid behavioral sweep in .local/review.json: runtime file changes require behavioralSweep.status=pass|needs_work")
        sys.exit(1)
    
    if runtime_review_required and behavioral_branch_count < 1:
        print("Invalid behavioral sweep in .local/review.json: runtime file changes require at least one branch entry")
        sys.exit(1)
    
    if behavioral_sweep_status == "not_applicable" and behavioral_branch_count > 0:
        print("Invalid behavioral sweep in .local/review.json: not_applicable cannot include branch entries")
        sys.exit(1)
    
    if behavioral_sweep_status == "pass" and behavioral_sweep_risk != "none":
        print("Invalid behavioral sweep in .local/review.json: status=pass requires silentDropRisk=none")
        sys.exit(1)
    
    # Validate recommendation constraints
    if recommendation == "READY FOR /prepare-pr" and issue_validation_status != "valid":
        print("Invalid recommendation in .local/review.json: READY FOR /prepare-pr requires issueValidation.status=valid")
        sys.exit(1)
    
    if recommendation == "READY FOR /prepare-pr" and behavioral_sweep_status == "needs_work":
        print("Invalid recommendation in .local/review.json: READY FOR /prepare-pr requires behavioralSweep.status!=needs_work")
        sys.exit(1)
    
    if recommendation == "READY FOR /prepare-pr" and runtime_review_required and behavioral_sweep_status != "pass":
        print("Invalid recommendation in .local/review.json: READY FOR /prepare-pr on runtime changes requires behavioralSweep.status=pass")
        sys.exit(1)
    
    if recommendation == "READY FOR /prepare-pr" and behavioral_sweep_risk == "present":
        print("Invalid recommendation in .local/review.json: READY FOR /prepare-pr is not allowed when behavioralSweep.silentDropRisk=present")
        sys.exit(1)
    
    # Validate docs status
    docs_status = run_jq_filter('.docs // ""', '.local/review.json')
    valid_docs = ["up_to_date", "missing", "not_applicable"]
    if docs_status not in valid_docs:
        print(f"Invalid docs status in .local/review.json: {docs_status}")
        sys.exit(1)
    
    # Validate changelog status
    changelog_status = run_jq_filter('.changelog // ""', '.local/review.json')
    if changelog_status not in ["required", "not_required"]:
        print(f'Invalid changelog status in .local/review.json: {changelog_status} (must be "required" or "not_required")')
        sys.exit(1)
    
    print("review artifacts validated")
    print_review_stdout_summary()

def print_review_stdout_summary():
    """Print review summary."""
    print("Review summary would be printed here")

def run_quiet_logged(name, log_file, *cmd):
    """Run command with logging."""
    with open(log_file, 'w') as log_f:
        subprocess.run(cmd, stdout=log_f, stderr=subprocess.STDOUT, check=True)

def bootstrap_deps_if_needed():
    """Bootstrap dependencies if needed."""
    # Placeholder - implement based on actual requirements
    pass

def review_tests(pr, *targets):
    """Run tests for review."""
    if len(targets) < 1:
        print("Usage: scripts/pr review-tests <PR> <test-file> [<test-file> ...]")
        sys.exit(2)
    
    enter_worktree(pr, False)
    review_guard(pr)
    
    for target in targets:
        if not os.path.exists(target):
            print(f"Missing test target file: {target}")
            sys.exit(1)
    
    bootstrap_deps_if_needed()
    
    run_log = ".local/review-tests-run.log"
    run_quiet_logged("pnpm test", run_log, "pnpm", "test", "--", *targets)
    
    missing_run = []
    for target in targets:
        base = os.path.basename(target)
        found_in_log = False
        
        try:
            with open(run_log, 'r') as f:
                content = f.read()
                if target in content or base in content:
                    found_in_log = True
        except FileNotFoundError:
            pass
        
        if not found_in_log:
            missing_run.append(target)
    
    if missing_run:
        print("These requested targets were not observed in vitest run output:")
        for target in missing_run:
            print(f" - {target}")
        sys.exit(1)
    
    # Write test environment
    env_content = f'REVIEW_TESTS_AT={(datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))!r}\n'
    env_content += f'REVIEW_TEST_TARGET_COUNT={len(targets)!r}\n'
    
    with open('.local/review-tests.env', 'w') as f:
        f.write(env_content)
    
    print("review tests passed and were observed in output")

def pr_meta_json(pr):
    """Get PR metadata as JSON."""
    # This should call the actual pr_meta_json function from another module
    # For now, we'll simulate getting PR data
    result = subprocess.run(['gh', 'pr', 'view', str(pr), '--json', 'number,title,url,state,isDraft,author,baseRefName,headRefName,headRefOid,headRepository,additions,deletions,files'], 
                          capture_output=True, text=True, check=True)
    return result.stdout

def write_pr_meta_files(json_data):
    """Write PR metadata files."""
    data = json.loads(json_data)
    
    # Write JSON file
    with open('.local/pr-meta.json', 'w') as f:
        json.dump(data, f, indent=2)
    
    # Write env file
    env_content = f'PR_NUMBER={data["number"]!r}\n'
    env_content += f'PR_TITLE={data["title"]!r}\n'
    env_content += f'PR_URL={data["url"]!r}\n'
    env_content += f'PR_STATE={data["state"]!r}\n'
    env_content += f'PR_IS_DRAFT={str(data["isDraft"])!r}\n'
    env_content += f'PR_AUTHOR={data["author"]["login"]!r}\n'
    env_content += f'PR_BASE_REF={data["baseRefName"]!r}\n'
    env_content += f'PR_HEAD_REF={data["headRefName"]!r}\n'
    env_content += f'PR_HEAD_SHA={data["headRefOid"]!r}\n'
    env_content += f'PR_HEAD_REPO={data["headRepository"]["nameWithOwner"]!r}\n'
    env_content += f'PR_ADDITIONS={data["additions"]!r}\n'
    env_content += f'PR_DELETIONS={data["deletions"]!r}\n'
    env_content += f'PR_FILE_COUNT={len(data["files"])!r}\n'
    
    with open('.local/pr-meta.env', 'w') as f:
        f.write(env_content)

def review_init(pr):
    """Initialize review."""
    enter_worktree(pr, True)
    
    json_data = pr_meta_json(pr)
    write_pr_meta_files(json_data)
    
    subprocess.run(['git', 'fetch', 'origin', f'pull/{pr}/head:pr-{pr}', '--force'], check=True)
    result = subprocess.run(['git', 'merge-base', 'origin/main', f'pr-{pr}'], 
                          capture_output=True, text=True, check=True)
    mb = result.stdout.strip()
    
    # Write context environment
    env_content = f'PR_NUMBER={pr!r}\n'
    env_content += f'MERGE_BASE={mb!r}\n'
    env_content += f'REVIEW_STARTED_AT={(datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))!r}\n'
    
    with open('.local/review-context.env', 'w') as f:
        f.write(env_content)
    
    set_review_mode('main')
    
    # Output PR info
    data = json.loads(json_data)
    print(json.dumps({
        "number": data["number"],
        "title": data["title"],
        "url": data["url"],
        "state": data["state"],
        "isDraft": data["isDraft"],
        "author": data["author"]["login"],
        "base": data["baseRefName"],
        "head": data["headRefName"],
        "headSha": data["headRefOid"],
        "headRepo": data["headRepository"]["nameWithOwner"],
        "additions": data["additions"],
        "deletions": data["deletions"],
        "files": len(data["files"])
    }))
    
    print(f"worktree={os.getcwd()}")
    print(f"pr_url={data.get('url', '')}")
    print(f"merge_base={mb}")
    print(f"branch={subprocess.run(['git', 'branch', '--show-current'], capture_output=True, text=True, check=True).stdout.strip()}")
    print("wrote=.local/pr-meta.json .local/pr-meta.env .local/review-context.env .local/review-mode.env")
    
    print("""Review guidance:
- Inspect main baseline: scripts/pr review-checkout-main PR_NUMBER
- Inspect PR head:      scripts/pr review-checkout-pr PR_NUMBER
- Guard before writeout: scripts/pr review-guard PR_NUMBER""")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: review.py <command> [args...]")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == "set-review-mode":
        if len(sys.argv) != 3:
            print("Usage: review.py set-review-mode <mode>")
            sys.exit(1)
        set_review_mode(sys.argv[2])
    elif command == "review-claim":
        if len(sys.argv) != 3:
            print("Usage: review.py review-claim <pr>")
            sys.exit(1)
        success = review_claim(sys.argv[2])
        sys.exit(0 if success else 1)
    elif command == "review-checkout-main":
        if len(sys.argv) != 3:
            print("Usage: review.py review-checkout-main <pr>")
            sys.exit(1)
        review_checkout_main(sys.argv[2])
    elif command == "review-checkout-pr":
        if len(sys.argv) != 3:
            print("Usage: review.py review-checkout-pr <pr>")
            sys.exit(1)
        review_checkout_pr(sys.argv[2])
    elif command == "review-guard":
        if len(sys.argv) != 3:
            print("Usage: review.py review-guard <pr>")
            sys.exit(1)
        review_guard(sys.argv[2])
    elif command == "review-artifacts-init":
        if len(sys.argv) != 3:
            print("Usage: review.py review-artifacts-init <pr>")
            sys.exit(1)
        review_artifacts_init(sys.argv[2])
    elif command == "review-validate-artifacts":
        if len(sys.argv) != 3:
            print("Usage: review.py review-validate-artifacts <pr>")
            sys.exit(1)
        review_validate_artifacts(sys.argv[2])
    elif command == "review-tests":
        if len(sys.argv) < 4:
            print("Usage: review.py review-tests <pr> <test-file> [<test-file> ...]")
            sys.exit(1)
        review_tests(sys.argv[2], *sys.argv[3:])
    elif command == "review-init":
        if len(sys.argv) != 3:
            print("Usage: review.py review-init <pr>")
            sys.exit(1)
        review_init(sys.argv[2])
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)

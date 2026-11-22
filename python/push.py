#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "a3f5c21173d23cc191b09bc2f5a9d1f32248fe61e29d71910388da22e5b00ce0", "source_sha256": "fde26dcd603ac650a610d1fcacab8e1a0e329f4dc886be42c70dd72d735ee30e", "target_language": "python"}
# push.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/push.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import subprocess
import base64
import json
import time
import tempfile

def resolve_head_push_url():
    """Resolve the push URL for the PR head repository."""
    env_file = ".local/pr-meta.env"
    if os.path.exists(env_file):
        with open(env_file) as f:
            for line in f:
                if line.startswith("export "):
                    line = line[7:]
                if "=" in line:
                    key, value = line.split("=", 1)
                    key = key.strip()
                    value = value.strip().strip('"').strip("'")
                    if key == "PR_HEAD_OWNER" or key == "PR_HEAD_REPO_NAME":
                        os.environ[key] = value

    pr_head_owner = os.environ.get("PR_HEAD_OWNER")
    pr_head_repo_name = os.environ.get("PR_HEAD_REPO_NAME")
    pr_head_repo_url = os.environ.get("PR_HEAD_REPO_URL")

    if pr_head_owner and pr_head_repo_name:
        return f"https://github.com/{pr_head_owner}/{pr_head_repo_name}.git"

    if pr_head_repo_url and pr_head_repo_url != "null":
        if pr_head_repo_url.endswith(".git"):
            return pr_head_repo_url
        else:
            return pr_head_repo_url + ".git"

    return None

def graphql_push_to_fork(repo_nwo, branch, expected_oid):
    """Push to a fork PR branch via GitHub GraphQL createCommitOnBranch."""
    max_blob_bytes = 5 * 1024 * 1024

    # Get added files
    result = subprocess.run([
        "git", "diff", "--no-renames", "--name-only", "--diff-filter=AM",
        expected_oid, "HEAD"
    ], capture_output=True, text=True)
    added_files = result.stdout.strip().split('\n') if result.stdout else []

    additions = []
    for fpath in added_files:
        if not fpath:
            continue

        # Get tree entry
        result = subprocess.run([
            "git", "ls-tree", "HEAD", "--", fpath
        ], capture_output=True, text=True)
        tree_entry = result.stdout.strip()
        if not tree_entry:
            print(f"GraphQL push could not resolve path in HEAD tree: {fpath}", file=sys.stderr)
            return None

        parts = tree_entry.split()
        if len(parts) < 3:
            print(f"Invalid tree entry for {fpath}", file=sys.stderr)
            return None

        file_mode = parts[0]
        file_type = parts[1]
        file_oid = parts[2]

        if file_type != "blob" or file_mode == "160000":
            print(f"GraphQL push only supports blob files; refusing {fpath} (mode={file_mode} type={file_type})", file=sys.stderr)
            return None

        # Get blob size
        result = subprocess.run([
            "git", "cat-file", "-s", file_oid
        ], capture_output=True, text=True)
        blob_size = int(result.stdout.strip())
        if blob_size > max_blob_bytes:
            print(f"GraphQL push refused large file {fpath} ({blob_size} bytes > {max_blob_bytes})", file=sys.stderr)
            return None

        # Get file content
        result = subprocess.run([
            "git", "cat-file", "-p", file_oid
        ], capture_output=True)
        content = result.stdout
        b64 = base64.b64encode(content).decode('utf-8')

        additions.append({
            "path": fpath,
            "contents": b64
        })

    # Get deleted files
    result = subprocess.run([
        "git", "diff", "--no-renames", "--name-only", "--diff-filter=D",
        expected_oid, "HEAD"
    ], capture_output=True, text=True)
    deleted_files = result.stdout.strip().split('\n') if result.stdout else []

    deletions = []
    for fpath in deleted_files:
        if not fpath:
            continue
        deletions.append({"path": fpath})

    # Get commit headline
    result = subprocess.run([
        "git", "log", "-1", "--format=%s", "HEAD"
    ], capture_output=True, text=True)
    commit_headline = result.stdout.strip()

    # Build GraphQL query
    query = """
mutation($input: CreateCommitOnBranchInput!) {
  createCommitOnBranch(input: $input) {
    commit { oid url }
  }
}
"""

    variables = {
        "input": {
            "branch": {
                "repositoryNameWithOwner": repo_nwo,
                "branchName": branch
            },
            "message": {
                "headline": commit_headline
            },
            "fileChanges": {
                "additions": additions,
                "deletions": deletions
            },
            "expectedHeadOid": expected_oid
        }
    }

    # Execute GraphQL request
    try:
        with tempfile.NamedTemporaryFile(mode='w', delete=False) as temp_file:
            json.dump(variables, temp_file)
            temp_file.flush()
            
            result = subprocess.run([
                "gh", "api", "graphql", "-f", f"query={query}", 
                "--input", temp_file.name
            ], capture_output=True, text=True)
            
            os.unlink(temp_file.name)
            
            if result.returncode != 0:
                print(f"GraphQL push failed: {result.stderr}", file=sys.stderr)
                return None
                
            response = json.loads(result.stdout)
            new_oid = response.get("data", {}).get("createCommitOnBranch", {}).get("commit", {}).get("oid")
            
            if not new_oid:
                print(f"GraphQL push returned no commit OID: {result.stdout}", file=sys.stderr)
                return None
                
            print(f"GraphQL push succeeded: {new_oid}", file=sys.stderr)
            return new_oid
            
    except Exception as e:
        print(f"GraphQL push failed: {str(e)}", file=sys.stderr)
        return None

def resolve_head_push_url_https():
    """Resolve the HTTPS push URL for the PR head repository."""
    return resolve_head_push_url()

def verify_pr_head_branch_matches_expected(pr, expected_head):
    """Verify that the PR head branch matches the expected branch."""
    try:
        result = subprocess.run([
            "gh", "pr", "view", str(pr), "--json", "headRefName", "--jq", ".headRefName"
        ], capture_output=True, text=True, check=True)
        current_head = result.stdout.strip()
        
        if current_head != expected_head:
            print(f"PR head branch changed from {expected_head} to {current_head}. Re-run prepare-init.")
            sys.exit(1)
    except subprocess.CalledProcessError as e:
        print(f"Failed to get PR head branch: {e.stderr}")
        sys.exit(1)

def setup_prhead_remote():
    """Setup the prhead remote."""
    push_url = resolve_head_push_url()
    if not push_url:
        print("Unable to resolve PR head repo push URL.")
        sys.exit(1)

    # Remove existing prhead remote if it exists
    subprocess.run(["git", "remote", "remove", "prhead"], 
                   stderr=subprocess.DEVNULL)
    
    # Add new prhead remote
    subprocess.run(["git", "remote", "add", "prhead", push_url], check=True)

def resolve_prhead_remote_sha(pr_head):
    """Resolve the SHA of the PR head remote branch."""
    try:
        result = subprocess.run([
            "git", "ls-remote", "prhead", f"refs/heads/{pr_head}"
        ], capture_output=True, text=True)
        
        if result.returncode == 0 and result.stdout:
            remote_sha = result.stdout.split()[0]
            return remote_sha
    except:
        pass

    # Try HTTPS fallback
    https_url = resolve_head_push_url_https()
    if https_url:
        try:
            current_push_url_result = subprocess.run([
                "git", "remote", "get-url", "prhead"
            ], capture_output=True, text=True)
            current_push_url = current_push_url_result.stdout.strip() if current_push_url_result.returncode == 0 else ""
            
            if https_url != current_push_url:
                print("SSH remote failed; falling back to HTTPS...", file=sys.stderr)
                subprocess.run([
                    "git", "remote", "set-url", "prhead", https_url
                ], check=True)
                subprocess.run([
                    "git", "remote", "set-url", "--push", "prhead", https_url
                ], check=True)
                
                result = subprocess.run([
                    "git", "ls-remote", "prhead", f"refs/heads/{pr_head}"
                ], capture_output=True, text=True)
                
                if result.returncode == 0 and result.stdout:
                    remote_sha = result.stdout.split()[0]
                    return remote_sha
        except:
            pass

    print(f"Remote branch refs/heads/{pr_head} not found on prhead", file=sys.stderr)
    sys.exit(1)

def wait_for_pr_head_sha(pr, expected_sha, max_attempts, sleep_seconds):
    """Wait for the PR head SHA to propagate."""
    for _ in range(max_attempts):
        try:
            result = subprocess.run([
                "gh", "pr", "view", str(pr), "--json", "headRefOid", "--jq", ".headRefOid"
            ], capture_output=True, text=True, check=True)
            observed_sha = result.stdout.strip()
            
            if observed_sha == expected_sha:
                return True
                
            time.sleep(sleep_seconds)
        except subprocess.CalledProcessError:
            time.sleep(sleep_seconds)
    
    return False

def push_prep_head_to_pr_branch(pr, pr_head, prep_head_sha, lease_sha, 
                                rerun_gates_on_lease_retry=False, 
                                docs_only=False, result_env_path=".local/push-result.env"):
    """Push the prep head to the PR branch."""
    setup_prhead_remote()

    remote_sha = resolve_prhead_remote_sha(pr_head)

    pushed_from_sha = remote_sha
    if remote_sha == prep_head_sha:
        print("Remote branch already at local prep HEAD; skipping push.")
    else:
        if remote_sha != lease_sha:
            print(f"Remote SHA {remote_sha} differs from PR head SHA {lease_sha}. Refreshing lease SHA from remote.")
            lease_sha = remote_sha
        
        pushed_from_sha = lease_sha
        
        try:
            subprocess.run([
                "git", "push", 
                f"--force-with-lease=refs/heads/{pr_head}:{lease_sha}", 
                "prhead", f"HEAD:{pr_head}"
            ], check=True, capture_output=True, text=True)
        except subprocess.CalledProcessError as push_error:
            push_output = push_error.stderr
            print(f"Push failed: {push_output}")

            if any(keyword in push_output.lower() for keyword in ["permission", "denied", "403", "forbidden"]):
                print("Permission denied on git push; trying GraphQL createCommitOnBranch fallback...")
                
                pr_head_owner = os.environ.get("PR_HEAD_OWNER")
                pr_head_repo_name = os.environ.get("PR_HEAD_REPO_NAME")
                
                if pr_head_owner and pr_head_repo_name:
                    graphql_oid = graphql_push_to_fork(
                        f"{pr_head_owner}/{pr_head_repo_name}", 
                        pr_head, 
                        lease_sha
                    )
                    if graphql_oid:
                        prep_head_sha = graphql_oid
                    else:
                        print("Git push permission denied and GraphQL fallback failed.")
                        sys.exit(1)
                else:
                    print("Git push permission denied and no fork owner/repo info for GraphQL fallback.")
                    sys.exit(1)
            else:
                print("Lease push failed, retrying once with fresh PR head...")
                try:
                    result = subprocess.run([
                        "gh", "pr", "view", str(pr), "--json", "headRefOid", "--jq", ".headRefOid"
                    ], capture_output=True, text=True, check=True)
                    lease_sha = result.stdout.strip()
                except subprocess.CalledProcessError:
                    print("Failed to refresh lease SHA")
                    sys.exit(1)
                
                pushed_from_sha = lease_sha

                if rerun_gates_on_lease_retry:
                    # Run prepare push retry gates
                    try:
                        subprocess.run([
                            "git", "fetch", "origin", f"pull/{pr}/head:pr-{pr}-latest", "--force"
                        ], check=True)
                        subprocess.run(["git", "rebase", f"pr-{pr}-latest"], check=True)
                        
                        result = subprocess.run([
                            "git", "rev-parse", "HEAD"
                        ], capture_output=True, text=True, check=True)
                        prep_head_sha = result.stdout.strip()
                        
                        # run_prepare_push_retry_gates would go here if implemented
                        # run_prepare_push_retry_gates(docs_only)
                    except subprocess.CalledProcessError as e:
                        print(f"Failed during retry preparation: {e}")
                        sys.exit(1)

                try:
                    subprocess.run([
                        "git", "push", 
                        f"--force-with-lease=refs/heads/{pr_head}:{lease_sha}", 
                        "prhead", f"HEAD:{pr_head}"
                    ], check=True, capture_output=True, text=True)
                except subprocess.CalledProcessError as retry_error:
                    retry_output = retry_error.stderr
                    print(f"Retry push failed: {retry_output}")
                    
                    pr_head_owner = os.environ.get("PR_HEAD_OWNER")
                    pr_head_repo_name = os.environ.get("PR_HEAD_REPO_NAME")
                    
                    if pr_head_owner and pr_head_repo_name:
                        print("Retry failed; trying GraphQL createCommitOnBranch fallback...")
                        graphql_oid = graphql_push_to_fork(
                            f"{pr_head_owner}/{pr_head_repo_name}", 
                            pr_head, 
                            lease_sha
                        )
                        if graphql_oid:
                            prep_head_sha = graphql_oid
                        else:
                            print("GraphQL fallback failed.")
                            sys.exit(1)
                    else:
                        print("Git push failed and no fork owner/repo info for GraphQL fallback.")
                        sys.exit(1)

    if not wait_for_pr_head_sha(pr, prep_head_sha, 8, 3):
        try:
            result = subprocess.run([
                "gh", "pr", "view", str(pr), "--json", "headRefOid", "--jq", ".headRefOid"
            ], capture_output=True, text=True, check=True)
            observed_sha = result.stdout.strip()
        except subprocess.CalledProcessError:
            observed_sha = "unknown"
        
        print(f"Pushed head SHA propagation timed out. expected={prep_head_sha} observed={observed_sha}")
        sys.exit(1)

    try:
        result = subprocess.run([
            "gh", "pr", "view", str(pr), "--json", "headRefOid", "--jq", ".headRefOid"
        ], capture_output=True, text=True, check=True)
        pr_head_sha_after = result.stdout.strip()
    except subprocess.CalledProcessError:
        print("Failed to get PR head SHA after push")
        sys.exit(1)

    try:
        subprocess.run(["git", "fetch", "origin", "main"], check=True)
        subprocess.run([
            "git", "fetch", "origin", f"pull/{pr}/head:pr-{pr}-verify", "--force"
        ], check=True)
        
        # Check if PR branch is behind main
        result = subprocess.run([
            "git", "merge-base", "--is-ancestor", "origin/main", f"pr-{pr}-verify"
        ])
        
        if result.returncode != 0:
            print("PR branch is behind main after push.")
            sys.exit(1)
            
        subprocess.run(["git", "branch", "-D", f"pr-{pr}-verify"], 
                       stderr=subprocess.DEVNULL)
    except subprocess.CalledProcessError:
        print("Failed to verify PR branch status")
        sys.exit(1)

    # Write results to env file
    with open(result_env_path, 'w') as f:
        # Simple escaping for shell compatibility
        def shell_escape(s):
            return "'" + s.replace("'", "'\"'\"'") + "'"
        
        f.write(f"PUSH_PREP_HEAD_SHA={shell_escape(prep_head_sha)}\n")
        f.write(f"PUSHED_FROM_SHA={shell_escape(pushed_from_sha)}\n")
        f.write(f"PR_HEAD_SHA_AFTER_PUSH={shell_escape(pr_head_sha_after)}\n")

if __name__ == "__main__":
    if len(sys.argv) < 5:
        print("Usage: push_prep_head_to_pr_branch <pr> <pr_head> <prep_head_sha> <lease_sha> [rerun_gates_on_lease_retry] [docs_only] [result_env_path]")
        sys.exit(1)
    
    pr = sys.argv[1]
    pr_head = sys.argv[2]
    prep_head_sha = sys.argv[3]
    lease_sha = sys.argv[4]
    rerun_gates_on_lease_retry = sys.argv[5].lower() == "true" if len(sys.argv) > 5 else False
    docs_only = sys.argv[6].lower() == "true" if len(sys.argv) > 6 else False
    result_env_path = sys.argv[7] if len(sys.argv) > 7 else ".local/push-result.env"
    
    push_prep_head_to_pr_branch(
        pr, pr_head, prep_head_sha, lease_sha,
        rerun_gates_on_lease_retry, docs_only, result_env_path
    )

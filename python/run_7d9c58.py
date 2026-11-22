#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "3ea5e31b52d2cb8caf03d2dcd65ce37a2db2409f50b8245898bdae680ead579c", "source_sha256": "7d9c583822b7f56d89ce608cb8d469719c8a0d1dda7229ea2e4bbf717e511afe", "target_language": "python"}
# run.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/install-sh-e2e/run.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import subprocess
import json
import tempfile
import shutil
import time
import zlib
import struct
import hashlib
import re
from pathlib import Path


def get_script_dir():
    return Path(__file__).parent.resolve()


def source_verify_helper():
    """Source the version-parse.sh script for extract_openclaw_semver function."""
    # In Python, we'll reimplement the needed function instead of sourcing
    pass


def extract_openclaw_semver(version_string):
    """Extract semantic version from openclaw version string."""
    # Simplified implementation - adjust regex as needed
    match = re.search(r'(\d+\.\d+\.\d+(?:[-+][\w.-]+)?)', version_string)
    return match.group(1) if match else version_string.strip()


def quiet_npm(*args):
    """Run npm command quietly."""
    try:
        result = subprocess.run(
            ['npm'] + list(args),
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return ""


def run_node_script(script, *args):
    """Run a Node.js script with arguments."""
    try:
        result = subprocess.run(
            ['node', '-e', script] + list(args),
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Node script failed: {e.stderr}", file=sys.stderr)
        return ""


def main():
    script_dir = get_script_dir()
    
    # Find version-parse.sh
    verify_helper_path = Path("/usr/local/install-sh-common/version-parse.sh")
    if not verify_helper_path.exists():
        verify_helper_path = script_dir.parent / "install-sh-common" / "version-parse.sh"
    
    # Environment variables with defaults
    install_url = os.environ.get("OPENCLAW_INSTALL_URL", "https://openclaw.bot/install.sh")
    models_mode = os.environ.get("OPENCLAW_E2E_MODELS", "both")  # both|openai|anthropic
    install_tag = os.environ.get("OPENCLAW_INSTALL_TAG", "latest")
    e2e_previous_version = os.environ.get("OPENCLAW_INSTALL_E2E_PREVIOUS", "")
    skip_previous = os.environ.get("OPENCLAW_INSTALL_E2E_SKIP_PREVIOUS", "0")
    openai_api_key = os.environ.get("OPENAI_API_KEY", "")
    anthropic_api_key = os.environ.get("ANTHROPIC_API_KEY", "")
    anthropic_api_token = os.environ.get("ANTHROPIC_API_TOKEN", "")
    
    # Validate models mode
    if models_mode not in ["both", "openai", "anthropic"]:
        print("ERROR: OPENCLAW_E2E_MODELS must be one of: both|openai|anthropic", file=sys.stderr)
        sys.exit(2)
    
    # Validate API keys based on mode
    if models_mode == "both":
        if not openai_api_key:
            print("ERROR: OPENCLAW_E2E_MODELS=both requires OPENAI_API_KEY.", file=sys.stderr)
            sys.exit(2)
        if not anthropic_api_token and not anthropic_api_key:
            print("ERROR: OPENCLAW_E2E_MODELS=both requires ANTHROPIC_API_TOKEN or ANTHROPIC_API_KEY.", file=sys.stderr)
            sys.exit(2)
    elif models_mode == "openai" and not openai_api_key:
        print("ERROR: OPENCLAW_E2E_MODELS=openai requires OPENAI_API_KEY.", file=sys.stderr)
        sys.exit(2)
    elif models_mode == "anthropic" and not anthropic_api_token and not anthropic_api_key:
        print("ERROR: OPENCLAW_E2E_MODELS=anthropic requires ANTHROPIC_API_TOKEN or ANTHROPIC_API_KEY.", file=sys.stderr)
        sys.exit(2)
    
    # Setup npm config
    npm_prefix = os.environ.get("NPM_CONFIG_PREFIX", str(Path.home() / ".npm-global"))
    os.environ["NPM_CONFIG_PREFIX"] = npm_prefix
    os.makedirs(npm_prefix, exist_ok=True)
    os.environ["PATH"] = f"{npm_prefix}/bin:{os.environ['PATH']}"
    
    print("==> Resolve npm versions")
    expected_version = quiet_npm("view", f"openclaw@{install_tag}", "version")
    if not expected_version or expected_version in ["undefined", "null"]:
        print(f"ERROR: unable to resolve openclaw@{install_tag} version", file=sys.stderr)
        sys.exit(2)
    
    if e2e_previous_version:
        previous_version = e2e_previous_version
    else:
        versions_json = quiet_npm("view", "openclaw", "versions", "--json")
        node_script = """
const versions = JSON.parse(process.env.VERSIONS_JSON || "[]");
if (!Array.isArray(versions) || versions.length === 0) process.exit(1);
process.stdout.write(versions.length >= 2 ? versions[versions.length - 2] : versions[0]);
"""
        previous_version = run_node_script(node_script)
    
    print(f"expected={expected_version} previous={previous_version}")
    
    if skip_previous == "1":
        print("==> Skip preinstall previous (OPENCLAW_INSTALL_E2E_SKIP_PREVIOUS=1)")
    else:
        print("==> Preinstall previous (forces installer upgrade path; avoids read() prompt)")
        quiet_npm("install", "-g", f"openclaw@{previous_version}")
    
    print("==> Run official installer one-liner")
    env = os.environ.copy()
    if install_tag == "beta":
        env["OPENCLAW_BETA"] = "1"
    elif install_tag != "latest":
        env["OPENCLAW_VERSION"] = install_tag
    
    try:
        subprocess.run(
            ["curl", "-fsSL", install_url],
            env=env,
            stdout=subprocess.PIPE,
            check=True
        ).stdout.decode()
        
        subprocess.run(["bash"], input=subprocess.PIPE, check=True)
    except subprocess.CalledProcessError as e:
        print(f"Installer failed: {e}", file=sys.stderr)
        sys.exit(1)
    
    print("==> Verify installed version")
    try:
        result = subprocess.run(
            ["openclaw", "--version"],
            capture_output=True,
            text=True,
            check=True
        )
        installed_version = result.stdout.split('\n')[0].strip()
        installed_version = extract_openclaw_semver(installed_version)
        print(f"installed={installed_version} expected={expected_version}")
        if installed_version != expected_version:
            print(f"ERROR: expected openclaw@{expected_version}, got openclaw@{installed_version}", file=sys.stderr)
            sys.exit(1)
    except subprocess.CalledProcessError:
        print("ERROR: Could not get installed version", file=sys.stderr)
        sys.exit(1)
    
    def set_image_model(profile, *candidates):
        for candidate in candidates:
            try:
                subprocess.run(
                    ["openclaw", "--profile", profile, "models", "set-image", candidate],
                    capture_output=True,
                    check=True
                )
                return candidate
            except subprocess.CalledProcessError:
                continue
        print(f"ERROR: could not set an image model (tried: {', '.join(candidates)})", file=sys.stderr)
        return None
    
    def set_agent_model(profile, *candidates):
        for candidate in candidates:
            try:
                subprocess.run(
                    ["openclaw", "--profile", profile, "models", "set", candidate],
                    capture_output=True,
                    check=True
                )
                return candidate
            except subprocess.CalledProcessError:
                continue
        print(f"ERROR: could not set agent model (tried: {', '.join(candidates)})", file=sys.stderr)
        return None
    
    def write_png_lr_rg(out_path):
        width, height = 96, 64
        
        def crc32(buf):
            return zlib.crc32(buf) & 0xffffffff
            
        def chunk(type_str, data):
            type_buf = type_str.encode('ascii')
            len_bytes = struct.pack('>I', len(data))
            crc = struct.pack('>I', crc32(type_buf + data))
            return len_bytes + type_buf + data + crc
        
        sig = bytes([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
        ihdr = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
        
        rows = []
        for y in range(height):
            row = bytearray(1 + width * 3)
            row[0] = 0  # filter: none
            for x in range(width):
                i = 1 + x * 3
                left = x < width / 2
                row[i] = 255 if left else 0
                row[i+1] = 0 if left else 255
                row[i+2] = 0
            rows.append(bytes(row))
        
        raw = b''.join(rows)
        idat = zlib.compress(raw, level=9)
        
        png_data = (
            sig +
            chunk("IHDR", ihdr) +
            chunk("IDAT", idat) +
            chunk("IEND", b"")
        )
        
        with open(out_path, 'wb') as f:
            f.write(png_data)
    
    def run_agent_turn(profile, session_id, prompt, out_json):
        try:
            result = subprocess.run([
                "openclaw", "--profile", profile, "agent",
                "--local",
                "--session-id", session_id,
                "--message", prompt,
                "--thinking", "off",
                "--json"
            ], capture_output=True, text=True, check=True)
            
            # Extract JSON from output
            output = result.stdout.strip()
            if not output:
                raise Exception("agent output was empty")
                
            try:
                parsed = json.loads(output)
            except json.JSONDecodeError:
                # Try to find JSON at end of output
                start = output.rfind('{')
                if start >= 0:
                    candidate = output[start:]
                    try:
                        parsed = json.loads(candidate)
                    except json.JSONDecodeError:
                        raise Exception(f"could not extract JSON payload from agent output:\n{output}")
                else:
                    raise Exception(f"could not extract JSON payload from agent output:\n{output}")
            
            with open(out_json, 'w') as f:
                json.dump(parsed, f, indent=2)
                
        except subprocess.CalledProcessError as e:
            # Write error output to file for debugging
            with open(out_json, 'w') as f:
                f.write(e.stdout)
                f.write(e.stderr)
            raise
    
    def assert_agent_json_has_text(path):
        with open(path, 'r') as f:
            p = json.load(f)
            
        payloads = p.get('result', {}).get('payloads', []) if isinstance(p.get('result'), dict) else p.get('payloads', [])
        texts = [str(payload.get('text', '')).strip() for payload in payloads if payload]
        texts = [text for text in texts if text]
        
        if not texts:
            sys.exit(1)
    
    def assert_agent_json_ok(json_path, expect_provider):
        with open(json_path, 'r') as f:
            p = json.load(f)
        
        status = p.get('status', '')
        if isinstance(status, str) and status not in ('ok', 'accepted'):
            print(f"ERROR: gateway status={status}", file=sys.stderr)
            sys.exit(1)
        
        result = p.get('result', p)
        payloads = result.get('payloads', []) if isinstance(result, dict) else []
        any_error = any(payload.get('isError') is True for payload in payloads if isinstance(payload, dict))
        combined_text = '\n'.join(str(payload.get('text', '')) for payload in payloads if isinstance(payload, dict)).strip()
        
        if any_error:
            print(f"ERROR: agent returned error payload: {combined_text}", file=sys.stderr)
            sys.exit(1)
            
        if re.search(r'rate_limit_error', combined_text, re.IGNORECASE) or re.match(r'^429\b', combined_text):
            print(f"ERROR: agent rate limited: {combined_text}", file=sys.stderr)
            sys.exit(1)
        
        meta = result.get('meta', {})
        agent_meta = meta.get('agentMeta', {}) if isinstance(meta, dict) else {}
        provider = (
            agent_meta.get('provider', '') if isinstance(agent_meta, dict) else ''
        ) or (
            meta.get('provider', '') if isinstance(meta, dict) else ''
        )
        
        provider = str(provider).strip()
        if expect_provider and provider and provider != expect_provider:
            print(f"ERROR: expected provider={expect_provider}, got provider={provider}", file=sys.stderr)
            sys.exit(1)
    
    def extract_matching_text(path, expected):
        with open(path, 'r') as f:
            p = json.load(f)
        
        result_payloads = p.get('result', {}).get('payloads', []) if isinstance(p.get('result'), dict) else []
        payloads = result_payloads if result_payloads else p.get('payloads', [])
        texts = [str(payload.get('text', '')).strip() for payload in payloads if isinstance(payload, dict)]
        texts = [text for text in texts if text]
        
        match = next((text for text in texts if text == expected), None)
        return match or (texts[0] if texts else "")
    
    def assert_session_used_tools(jsonl_path, *required_tools):
        required = set(required_tools)
        
        with open(jsonl_path, 'r') as f:
            lines = [line.strip() for line in f.readlines() if line.strip()]
        
        seen = set()
        tool_types = {
            "tool_use", "tool_result", "tool", "tool-call", "tool_call",
            "tooluse", "tool-use", "toolresult", "tool-result"
        }
        
        def walk(node, parent=None):
            if not node:
                return
            if isinstance(node, list):
                for item in node:
                    walk(item, node)
                return
            if not isinstance(node, dict):
                return
                
            obj = node
            t = obj.get('type')
            if isinstance(t, str) and (t in tool_types or re.search(r'tool', t, re.IGNORECASE)):
                name = (
                    obj.get('name') or 
                    obj.get('toolName') or 
                    obj.get('tool_name') or
                    (obj.get('tool', {}).get('name') if isinstance(obj.get('tool'), dict) else None)
                )
                if isinstance(name, str):
                    seen.add(name)
                    
            if isinstance(obj.get('name'), str) and isinstance(obj.get('input'), dict):
                seen.add(obj.get('name'))
                
            if isinstance(obj.get('tool_calls'), list):
                for c in obj['tool_calls']:
                    if isinstance(c, dict) and isinstance(c.get('function'), dict):
                        fname = c['function'].get('name')
                        if isinstance(fname, str):
                            seen.add(fname)
                            
            if isinstance(obj.get('function'), dict) and isinstance(obj['function'].get('name'), str):
                seen.add(obj['function']['name'])
                
            for v in obj.values():
                walk(v, obj)
        
        for line in lines:
            try:
                entry = json.loads(line)
                walk(entry)
            except json.JSONDecodeError:
                continue
        
        missing = [t for t in required if t not in seen]
        if missing:
            print(f"Missing tools in transcript: {', '.join(missing)}", file=sys.stderr)
            print(f"Seen tools: {', '.join(sorted(seen))}", file=sys.stderr)
            print("Transcript head:", file=sys.stderr)
            print('\n'.join(lines[:5]), file=sys.stderr)
            sys.exit(1)
    
    def run_profile(profile, port, workspace, agent_model_provider):
        print(f"==> Onboard ({profile})")
        
        workspace_path = Path(workspace)
        workspace_path.mkdir(parents=True, exist_ok=True)
        
        onboard_args = [
            "openclaw", "--profile", profile, "onboard",
            "--non-interactive",
            "--accept-risk",
            "--flow", "quickstart",
            "--gateway-port", str(port),
            "--gateway-bind", "loopback",
            "--gateway-auth", "token",
            "--workspace", str(workspace_path),
            "--skip-health"
        ]
        
        if agent_model_provider == "openai":
            onboard_args.extend([
                "--auth-choice", "openai-api-key",
                "--openai-api-key", openai_api_key
            ])
        elif anthropic_api_key:
            onboard_args.extend([
                "--auth-choice", "apiKey",
                "--anthropic-api-key", anthropic_api_key
            ])
        elif anthropic_api_token:
            onboard_args.extend([
                "--auth-choice", "token",
                "--token-provider", "anthropic",
                "--token", anthropic_api_token
            ])
        else:
            onboard_args.extend([
                "--auth-choice", "apiKey",
                "--anthropic-api-key", anthropic_api_key
            ])
        
        try:
            subprocess.run(onboard_args, check=True)
        except subprocess.CalledProcessError as e:
            print(f"Onboard failed: {e}", file=sys.stderr)
            sys.exit(1)
        
        print(f"==> Verify workspace identity files ({profile})")
        identity_files = ["AGENTS.md", "IDENTITY.md", "USER.md", "SOUL.md", "TOOLS.md"]
        for filename in identity_files:
            if not (workspace_path / filename).exists():
                print(f"Missing identity file: {filename}", file=sys.stderr)
                sys.exit(1)
        
        print(f"==> Configure models ({profile})")
        if agent_model_provider == "openai":
            agent_model = set_agent_model(profile,
                "openai/gpt-5.4",
                "openai/gpt-4o-mini",
                "openai/gpt-4o"
            )
            image_model = set_image_model(profile,
                "openai/gpt-4o-mini",
                "openai/gpt-4o"
            )
        else:
            agent_model = set_agent_model(profile,
                "anthropic/claude-opus-4-6",
                "claude-opus-4-6"
            )
            image_model = set_image_model(profile,
                "anthropic/claude-opus-4-6",
                "claude-opus-4-6"
            )
        
        print(f"model={agent_model}")
        print(f"imageModel={image_model}")
        
        print(f"==> Prepare tool fixtures ({profile})")
        proof_txt = workspace_path / "proof.txt"
        proof_copy = workspace_path / "copy.txt"
        hostname_txt = workspace_path / "hostname.txt"
        image_png = workspace_path / "proof.png"
        image_txt = workspace_path / "image.txt"
        session_id = f"e2e-tools-{profile}"
        
        # Create session directory structure
        session_dir = Path.home() / f".openclaw-{profile}" / "agents" / "main" / "sessions"
        session_dir.mkdir(parents=True, exist_ok=True)
        session_jsonl = session_dir / f"{session_id}.jsonl"
        
        # Generate proof value
        proof_value = hashlib.sha256(os.urandom(32)).hexdigest()
        with open(proof_txt, 'w') as f:
            f.write(proof_value)
        
        # Create PNG image
        write_png_lr_rg(image_png)
        
        expected_hostname = subprocess.run(['hostname'], capture_output=True, text=True).stdout.strip()
        
        print(f"==> Start gateway ({profile})")
        gateway_log = workspace_path / "gateway.log"
        gateway_process = subprocess.Popen([
            "openclaw", "--profile", profile, "gateway",
            "--port", str(port),
            "--bind", "loopback"
        ], stdout=open(gateway_log, 'w'), stderr=subprocess.STDOUT)
        
        gateway_pid = gateway_process.pid
        
        def cleanup_profile():
            if gateway_process.poll() is None:
                gateway_process.terminate()
                try:
                    gateway_process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    gateway_process.kill()
                    gateway_process.wait()
        
        try:
            print(f"==> Wait for health ({profile})")
            for _ in range(240):
                try:
                    subprocess.run([
                        "openclaw", "--profile", profile, "health",
                        "--timeout", "5000", "--json"
                    ], capture_output=True, check=True)
                    break
                except subprocess.CalledProcessError:
                    time.sleep(0.25)
            
            subprocess.run([
                "openclaw", "--profile", profile, "health",
                "--timeout", "60000", "--json"
            ], check=True)
            
            print(f"==> Agent turns ({profile})")
            turn1_json = f"/tmp/agent-{profile}-1.json"
            turn2_json = f"/tmp/agent-{profile}-2.json"
            turn2b_json = f"/tmp/agent-{profile}-2b.json"
            turn3_json = f"/tmp/agent-{profile}-3.json"
            turn3b_json = f"/tmp/agent-{profile}-3b.json"
            turn4_json = f"/tmp/agent-{profile}-4.json"
            
            # Turn 1: Read proof.txt
            run_agent_turn(profile, session_id,
                f"Use the read tool (not exec) to read {proof_txt}. Reply with the exact contents only (no extra whitespace).",
                turn1_json)
            assert_agent_json_has_text(turn1_json)
            assert_agent_json_ok(turn1_json, agent_model_provider)
            reply1 = extract_matching_text(turn1_json, proof_value).strip()
            if reply1 != proof_value:
                print(f"ERROR: agent did not read proof.txt correctly ({profile}): {reply1}", file=sys.stderr)
                sys.exit(1)
            
            # Turn 2: Write to copy.txt
            prompt2 = f'Use the write tool (not exec) to write exactly this string into {proof_copy}:\n{reply1}\nReply with exactly: WROTE'
            run_agent_turn(profile, session_id, prompt2, turn2_json)
            assert_agent_json_has_text(turn2_json)
            assert_agent_json_ok(turn2_json, agent_model_provider)
            
            with open(proof_copy, 'r') as f:
                copy_value = f.read().strip()
            if copy_value != proof_value:
                print(f"ERROR: copy.txt did not match proof.txt ({profile})", file=sys.stderr)
                sys.exit(1)
            
            # Turn 2b: Read copy.txt
            run_agent_turn(profile, session_id,
                f"Use the read tool (not exec) to read {proof_copy}. Reply with the exact contents only (no extra whitespace).",
                turn2b_json)
            assert_agent_json_has_text(turn2b_json)
            assert_agent_json_ok(turn2b_json, agent_model_provider)
            reply2 = extract_matching_text(turn2b_json, proof_value).strip()
            if reply2 != proof_value:
                print(f"ERROR: agent did not read copy.txt correctly ({profile}): {reply2}", file=sys.stderr)
                sys.exit(1)
            
            # Turn 3: Run hostname
            run_agent_turn(profile, session_id,
                "Use the exec tool to run this command: hostname. Reply with the exact stdout only (trim trailing newline).",
                turn3_json)
            assert_agent_json_has_text(turn3_json)
            assert_agent_json_ok(turn3_json, agent_model_provider)
            reply3 = extract_matching_text(turn3_json, expected_hostname).strip()
            if reply3 != expected_hostname:
                print(f"ERROR: agent did not run hostname correctly ({profile}): {reply3}", file=sys.stderr)
                sys.exit(1)
            
            # Turn 3b: Write hostname to file
            prompt3b = f'Use the write tool to write exactly this string into {hostname_txt}:\n{reply3}\nReply with exactly: WROTE'
            run_agent_turn(profile, session_id, prompt3b, turn3b_json)
            assert_agent_json_has_text(turn3b_json)
            assert_agent_json_ok(turn3b_json, agent_model_provider)
            
            with open(hostname_txt, 'r') as f:
                hostname_value = f.read().strip()
            if hostname_value != expected_hostname:
                print(f"ERROR: hostname.txt did not match hostname output ({profile})", file=sys.stderr)
                sys.exit(1)
            
            # Turn 4: Process image
            run_agent_turn(profile, session_id,
                f"Use the image tool on {image_png}. Determine which color is on the left half and which is on the right half. Then use the write tool to write exactly: LEFT=RED RIGHT=GREEN into {image_txt}. Reply with exactly: LEFT=RED RIGHT=GREEN",
                turn4_json)
            assert_agent_json_has_text(turn4_json)
            assert_agent_json_ok(turn4_json, agent_model_provider)
            
            with open(image_txt, 'r') as f:
                image_content = f.read().strip()
            if image_content != "LEFT=RED RIGHT=GREEN":
                print(f"ERROR: image.txt did not contain expected marker ({profile})", file=sys.stderr)
                sys.exit(1)
            
            reply4 = extract_matching_text(turn4_json, "LEFT=RED RIGHT=GREEN")
            if reply4 != "LEFT=RED RIGHT=GREEN":
                print(f"ERROR: agent reply did not contain expected marker ({profile}): {reply4}", file=sys.stderr)
                sys.exit(1)
            
            print(f"==> Verify tool usage via session transcript ({profile})")
            time.sleep(1)  # Give gateway time to flush
            
            if not session_jsonl.exists():
                print(f"ERROR: missing session transcript ({profile}): {session_jsonl}", file=sys.stderr)
                subprocess.run(['ls', '-la', str(session_dir)], stderr=subprocess.STDOUT)
                sys.exit(1)
            
            assert_session_used_tools(str(session_jsonl), "read", "write", "exec", "image")
            
        finally:
            cleanup_profile()
    
    # Run profiles based on mode
    if models_mode in ("openai", "both"):
        run_profile("e2e-openai", 18789, "/tmp/openclaw-e2e-openai", "openai")
    
    if models_mode in ("anthropic", "both"):
        run_profile("e2e-anthropic", 18799, "/tmp/openclaw-e2e-anthropic", "anthropic")
    
    print("OK")


if __name__ == "__main__":
    main()

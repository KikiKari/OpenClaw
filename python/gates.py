#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "7c3a4fb9888ae397fe34834925a5dfe86ce0a31255866e9c97f7ae55e207533a", "source_sha256": "2831a8a242630f9e502bf810a5eba7959a0a033472a3dd6c333bc3178d2227d2", "target_language": "python"}
# gates.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/gates.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import os
import subprocess
import sys
from datetime import datetime


def run_quiet_logged(name, log_file, *cmd):
    """Führt einen Befehl aus und leitet die Ausgabe in eine Logdatei um."""
    with open(log_file, 'w') as log:
        result = subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT)
        if result.returncode != 0:
            print(f"{name} failed. See {log_file} for details.", file=sys.stderr)
            sys.exit(result.returncode)


def bootstrap_deps_if_needed():
    """Bootstrap-Abhängigkeiten installieren, falls nötig."""
    # Placeholder für tatsächliche Implementierung
    pass


def enter_worktree(pr, flag):
    """Wechselt in den Worktree eines PRs."""
    # Placeholder für tatsächliche Implementierung
    pass


def checkout_prep_branch(pr):
    """Checkt den Prep-Branch eines PRs aus."""
    # Placeholder für tatsächliche Implementierung
    pass


def require_artifact(path):
    """Stellt sicher, dass ein Artefakt existiert."""
    if not os.path.exists(path):
        raise FileNotFoundError(f"Required artifact not found: {path}")


def path_is_docsish(path):
    """Prüft, ob ein Pfad Dokumentationsinhalten entspricht."""
    # Placeholder für tatsächliche Implementierung
    return False


def changelog_required_for_changed_files(changed_files):
    """Bestimmt, ob ein Changelog-Eintrag erforderlich ist."""
    # Placeholder für tatsächliche Implementierung
    return False


def normalize_pr_changelog_entries(pr):
    """Normalisiert Changelog-Einträge für einen PR."""
    # Placeholder für tatsächliche Implementierung
    pass


def validate_changelog_merge_hygiene():
    """Validiert die Hygiene beim Zusammenführen von Changelogs."""
    # Placeholder für tatsächliche Implementierung
    pass


def validate_changelog_entry_for_pr(pr, contrib):
    """Validiert den Changelog-Eintrag für einen PR."""
    # Placeholder für tatsächliche Implementierung
    pass


def file_list_is_docsish_only(file_list):
    """Prüft, ob alle Dateien in der Liste Dokumentationsinhalten entsprechen."""
    # Placeholder für tatsächliche Implementierung
    return True


def run_prepare_push_retry_gates(docs_only=False):
    """Führt Gates für Push-Retry durch."""
    bootstrap_deps_if_needed()
    run_quiet_logged("pnpm build (lease-retry)", ".local/lease-retry-build.log", "pnpm", "build")
    run_quiet_logged("pnpm check (lease-retry)", ".local/lease-retry-check.log", "pnpm", "check")
    if not docs_only:
        run_quiet_logged("pnpm test (lease-retry)", ".local/lease-retry-test.log", "pnpm", "test")


def prepare_gates(pr):
    """Bereitet die Gates vor."""
    enter_worktree(pr, False)
    checkout_prep_branch(pr)
    bootstrap_deps_if_needed()
    require_artifact(".local/pr-meta.env")

    # Lade Umgebungsvariablen aus der Datei
    with open(".local/pr-meta.env") as f:
        for line in f:
            if '=' in line:
                key, value = line.strip().split('=', 1)
                os.environ[key] = value.strip('"')

    # Hole geänderte Dateien
    result = subprocess.run(
        ["git", "diff", "--name-only", "origin/main...HEAD"],
        capture_output=True,
        text=True,
        check=True
    )
    changed_files = result.stdout.strip().split('\n')
    changed_files = [f for f in changed_files if f]

    # Filtere nicht-dokumentationsbezogene Dateien
    non_docs = [path for path in changed_files if not path_is_docsish(path)]

    docs_only = bool(changed_files) and not non_docs

    changelog_required = changelog_required_for_changed_files("\n".join(changed_files))

    has_changelog_update = any(f == "CHANGELOG.md" for f in changed_files)

    unsupported_changelog_fragments = [
        f for f in changed_files if f.startswith("changelog/fragments/")
    ]
    if unsupported_changelog_fragments:
        print("Unsupported changelog fragment files detected:")
        for f in unsupported_changelog_fragments:
            print(f)
        print("Move changelog fragment content into CHANGELOG.md and remove changelog/fragments files.")
        sys.exit(1)

    if changelog_required and not has_changelog_update:
        print("Missing changelog update. Add CHANGELOG.md changes.")
        sys.exit(1)

    if has_changelog_update:
        normalize_pr_changelog_entries(pr)

    if changelog_required:
        contrib = os.environ.get("PR_AUTHOR", "")
        validate_changelog_merge_hygiene()
        validate_changelog_entry_for_pr(pr, contrib)
    else:
        print("Changelog not required for this changed-file set.")

    current_head = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        capture_output=True,
        text=True,
        check=True
    ).stdout.strip()

    previous_last_verified_head = ""
    previous_full_gates_head = ""

    if os.path.exists(".local/gates.env") and os.path.getsize(".local/gates.env") > 0:
        with open(".local/gates.env") as f:
            for line in f:
                if '=' in line:
                    key, value = line.strip().split('=', 1)
                    if key == "LAST_VERIFIED_HEAD_SHA":
                        previous_last_verified_head = value.strip('"')
                    elif key == "FULL_GATES_HEAD_SHA":
                        previous_full_gates_head = value.strip('"')

    gates_mode = "full"
    reuse_gates = False

    if docs_only and previous_last_verified_head:
        try:
            subprocess.run(
                ["git", "merge-base", "--is-ancestor", previous_last_verified_head, "HEAD"],
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            result = subprocess.run(
                ["git", "diff", "--name-only", f"{previous_last_verified_head}..HEAD"],
                capture_output=True,
                text=True,
                check=True
            )
            delta_since_verified = result.stdout.strip()
            if not delta_since_verified or file_list_is_docsish_only(delta_since_verified):
                reuse_gates = True
        except subprocess.CalledProcessError:
            pass

    if reuse_gates:
        gates_mode = "reused_docs_only"
        print(f"Docs/changelog-only delta since last verified head {previous_last_verified_head}; reusing prior gates.")
    else:
        run_quiet_logged("pnpm build", ".local/gates-build.log", "pnpm", "build")
        run_quiet_logged("pnpm check", ".local/gates-check.log", "pnpm", "check")

        if docs_only:
            gates_mode = "docs_only"
            print("Docs-only change detected with high confidence; skipping pnpm test.")
        else:
            gates_mode = "full"
            workers = os.environ.get("OPENCLAW_VITEST_MAX_WORKERS", "4")
            print(f"Running pnpm test with OPENCLAW_VITEST_MAX_WORKERS={workers}.")
            run_quiet_logged(
                "pnpm test",
                ".local/gates-test.log",
                "env", f"OPENCLAW_VITEST_MAX_WORKERS={workers}", "pnpm", "test"
            )
            previous_full_gates_head = current_head

    # Schreibe Ergebnisse in .local/gates.env
    with open(".local/gates.env", "w") as f:
        f.write(f'PR_NUMBER="{pr}"\n')
        f.write(f'DOCS_ONLY="{str(docs_only).lower()}"\n')
        f.write(f'CHANGELOG_REQUIRED="{str(changelog_required).lower()}"\n')
        f.write(f'GATES_MODE="{gates_mode}"\n')
        f.write(f'LAST_VERIFIED_HEAD_SHA="{current_head}"\n')
        f.write(f'FULL_GATES_HEAD_SHA="{previous_full_gates_head}"\n')
        f.write(f'GATES_PASSED_AT="{datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")}"\n')

    print(f"docs_only={str(docs_only).lower()}")
    print(f"changelog_required={str(changelog_required).lower()}")
    print(f"gates_mode={gates_mode}")
    print("wrote=.local/gates.env")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 gates.py <pr_number>")
        sys.exit(1)

    command = sys.argv[1]
    if command == "run_prepare_push_retry_gates":
        docs_only = sys.argv[2].lower() == "true" if len(sys.argv) > 2 else False
        run_prepare_push_retry_gates(docs_only)
    elif command == "prepare_gates":
        pr = sys.argv[2]
        prepare_gates(pr)
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)

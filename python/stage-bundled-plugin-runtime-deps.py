#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "d0e7c819e0c9216e47c757c06bfb1c3a931bd0702ae4c45cc0ae538eff7049fb", "source_sha256": "481f90055fd746cf4af45da5765d09d2a9289bac2b7aa0b2fecc8558803339d5", "target_language": "python"}
# stage-bundled-plugin-runtime-deps.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/stage-bundled-plugin-runtime-deps.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def read_json(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        return json.load(f)


def write_json(file_path, value):
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(value, f, indent=2)
        f.write('\n')


def remove_path_if_exists(target_path):
    if os.path.exists(target_path):
        if os.path.isdir(target_path):
            shutil.rmtree(target_path)
        else:
            os.remove(target_path)


def make_temp_dir(parent_dir, prefix):
    temp_dir = tempfile.mkdtemp(prefix=prefix, dir=parent_dir)
    return Path(temp_dir)


def sanitize_temp_prefix_segment(value):
    import re
    normalized = re.sub(r'[^A-Za-z0-9._-]+', '-', value)
    normalized = re.sub(r'-+', '-', normalized)
    return normalized if len(normalized) > 0 else "plugin"


def replace_dir(target_path, source_path):
    remove_path_if_exists(target_path)
    try:
        shutil.move(str(source_path), str(target_path))
        return
    except OSError as e:
        if e.errno != 18:  # EXDEV
            raise

    if os.path.isdir(source_path):
        shutil.copytree(source_path, target_path, dirs_exist_ok=True)
    else:
        shutil.copy2(source_path, target_path)
    
    remove_path_if_exists(source_path)


def dependency_node_modules_path(node_modules_dir, dep_name):
    return node_modules_dir / Path(*dep_name.split('/'))


def read_installed_dependency_version(node_modules_dir, dep_name):
    package_json_path = dependency_node_modules_path(node_modules_dir, dep_name) / 'package.json'
    if not package_json_path.exists():
        return None
    
    try:
        version = read_json(package_json_path)['version']
        return version if isinstance(version, str) else None
    except (KeyError, TypeError):
        return None


def dependency_version_satisfied(spec, installed_version):
    # Simple version comparison - in practice you might want to use a proper semver library
    # This is a placeholder implementation
    return True


staged_runtime_dep_prune_rules = {
    # Type declarations only; runtime resolves through lib/es entrypoints.
    "@larksuiteoapi/node-sdk": ["types"],
}
runtime_deps_staging_version = 2


def collect_installed_runtime_closure(root_node_modules_dir, dependency_specs):
    package_cache = {}
    closure = set()
    queue = list(dependency_specs.items())

    while queue:
        dep_name, spec = queue.pop(0)
        installed_version = read_installed_dependency_version(root_node_modules_dir, dep_name)
        if installed_version is None or not dependency_version_satisfied(spec, installed_version):
            return None
        if dep_name in closure:
            continue

        package_json_path = dependency_node_modules_path(root_node_modules_dir, dep_name) / 'package.json'
        package_json = package_cache.get(dep_name) or read_json(package_json_path)
        package_cache[dep_name] = package_json
        closure.add(dep_name)

        deps = package_json.get('dependencies', {})
        optional_deps = package_json.get('optionalDependencies', {})
        
        for child_name, child_spec in {**deps, **optional_deps}.items():
            queue.append((child_name, child_spec))

    return list(closure)


def prune_staged_installed_dependency_cargo(node_modules_dir, dep_name):
    prune_paths = staged_runtime_dep_prune_rules.get(dep_name)
    if not prune_paths:
        return
    dep_root = dependency_node_modules_path(node_modules_dir, dep_name)
    for relative_path in prune_paths:
        remove_path_if_exists(dep_root / relative_path)


def prune_staged_runtime_dependency_cargo(node_modules_dir):
    for dep_name in staged_runtime_dep_prune_rules.keys():
        prune_staged_installed_dependency_cargo(node_modules_dir, dep_name)


def list_bundled_plugin_runtime_dirs(repo_root):
    extensions_root = repo_root / 'dist' / 'extensions'
    if not extensions_root.exists():
        return []

    result = []
    for item in extensions_root.iterdir():
        if item.is_dir():
            plugin_dir = extensions_root / item.name
            if (plugin_dir / 'package.json').exists():
                result.append(plugin_dir)
    return result


def has_runtime_deps(package_json):
    return (
        len(package_json.get('dependencies', {})) > 0 or
        len(package_json.get('optionalDependencies', {})) > 0
    )


def should_stage_runtime_deps(package_json):
    return package_json.get('openclaw', {}).get('bundle', {}).get('stageRuntimeDependencies') is True


def sanitize_bundled_manifest_for_runtime_install(plugin_dir):
    manifest_path = plugin_dir / 'package.json'
    package_json = read_json(manifest_path)
    changed = False

    if 'peerDependencies' in package_json:
        del package_json['peerDependencies']
        changed = True

    if 'peerDependenciesMeta' in package_json:
        del package_json['peerDependenciesMeta']
        changed = True

    if 'devDependencies' in package_json:
        del package_json['devDependencies']
        changed = True

    if changed:
        write_json(manifest_path, package_json)

    return package_json


def resolve_runtime_deps_stamp_path(plugin_dir):
    return plugin_dir / '.openclaw-runtime-deps-stamp.json'


def create_runtime_deps_fingerprint(package_json):
    data = {
        'packageJson': package_json,
        'pruneRules': list(staged_runtime_dep_prune_rules.items()),
        'version': runtime_deps_staging_version,
    }
    content = json.dumps(data, sort_keys=True)
    return hashlib.sha256(content.encode('utf-8')).hexdigest()


def read_runtime_deps_stamp(stamp_path):
    if not stamp_path.exists():
        return None
    try:
        return read_json(stamp_path)
    except:
        return None


def stage_installed_root_runtime_deps(params):
    fingerprint = params['fingerprint']
    package_json = params['packageJson']
    plugin_dir = params['pluginDir']
    repo_root = params['repoRoot']
    
    dependency_specs = {
        **package_json.get('dependencies', {}),
        **package_json.get('optionalDependencies', {}),
    }
    
    root_node_modules_dir = repo_root / 'node_modules'
    if len(dependency_specs) == 0 or not root_node_modules_dir.exists():
        return False

    dependency_names = collect_installed_runtime_closure(root_node_modules_dir, dependency_specs)
    if dependency_names is None:
        return False

    node_modules_dir = plugin_dir / 'node_modules'
    stamp_path = resolve_runtime_deps_stamp_path(plugin_dir)
    
    temp_prefix = f"openclaw-runtime-deps-{sanitize_temp_prefix_segment(plugin_dir.name)}-"
    staged_node_modules_parent = make_temp_dir(Path(tempfile.gettempdir()), temp_prefix)
    staged_node_modules_dir = staged_node_modules_parent / 'node_modules'

    try:
        for dep_name in dependency_names:
            source_path = dependency_node_modules_path(root_node_modules_dir, dep_name)
            target_path = dependency_node_modules_path(staged_node_modules_dir, dep_name)
            target_path.parent.mkdir(parents=True, exist_ok=True)
            
            if source_path.is_dir():
                shutil.copytree(source_path, target_path, dirs_exist_ok=True)
            else:
                shutil.copy2(source_path, target_path)
        
        prune_staged_runtime_dependency_cargo(staged_node_modules_dir)
        replace_dir(node_modules_dir, staged_node_modules_dir)
        
        write_json(stamp_path, {
            'fingerprint': fingerprint,
            'generatedAt': __import__('datetime').datetime.now().isoformat(),
        })
        return True
    finally:
        remove_path_if_exists(staged_node_modules_parent)


def install_plugin_runtime_deps(params):
    fingerprint = params['fingerprint']
    package_json = params['packageJson']
    plugin_dir = params['pluginDir']
    plugin_id = params['pluginId']
    repo_root = params['repoRoot']
    
    if repo_root and stage_installed_root_runtime_deps({
        'fingerprint': fingerprint,
        'packageJson': package_json,
        'pluginDir': plugin_dir,
        'repoRoot': repo_root
    }):
        return

    node_modules_dir = plugin_dir / 'node_modules'
    stamp_path = resolve_runtime_deps_stamp_path(plugin_dir)
    
    temp_prefix = f"openclaw-runtime-deps-{sanitize_temp_prefix_segment(plugin_id)}-"
    temp_install_dir = make_temp_dir(Path(tempfile.gettempdir()), temp_prefix)
    
    npm_args = [
        'npm',
        'install',
        '--omit=dev',
        '--silent',
        '--ignore-scripts',
        '--legacy-peer-deps',
        '--package-lock=false',
    ]

    try:
        write_json(temp_install_dir / 'package.json', package_json)
        
        result = subprocess.run(
            npm_args,
            cwd=temp_install_dir,
            capture_output=True,
            text=True
        )
        
        if result.returncode != 0:
            output = '\n'.join([result.stderr, result.stdout]).strip()
            raise Exception(f"failed to stage bundled runtime deps for {plugin_id}: {output or 'npm install failed'}")

        staged_node_modules_dir = temp_install_dir / 'node_modules'
        if not staged_node_modules_dir.exists():
            raise Exception(f"failed to stage bundled runtime deps for {plugin_id}: npm install produced no node_modules directory")

        prune_staged_runtime_dependency_cargo(staged_node_modules_dir)
        replace_dir(node_modules_dir, staged_node_modules_dir)
        
        write_json(stamp_path, {
            'fingerprint': fingerprint,
            'generatedAt': __import__('datetime').datetime.now().isoformat(),
        })
    finally:
        remove_path_if_exists(temp_install_dir)


def install_plugin_runtime_deps_with_retries(params):
    attempts = params.get('attempts', 3)
    last_error = None
    
    for attempt in range(1, attempts + 1):
        try:
            install_params = params['installParams'].copy()
            install_params['attempt'] = attempt
            params['install'](**install_params)
            return
        except Exception as error:
            last_error = error
            if attempt == attempts:
                break
    
    raise last_error


def stage_bundled_plugin_runtime_deps(params=None):
    if params is None:
        params = {}
    
    repo_root = Path(params.get('cwd') or params.get('repoRoot') or os.getcwd())
    install_plugin_runtime_deps_impl = params.get('installPluginRuntimeDepsImpl', install_plugin_runtime_deps)
    install_attempts = params.get('installAttempts', 3)
    
    for plugin_dir in list_bundled_plugin_runtime_dirs(repo_root):
        plugin_id = plugin_dir.name
        package_json = sanitize_bundled_manifest_for_runtime_install(plugin_dir)
        node_modules_dir = plugin_dir / 'node_modules'
        stamp_path = resolve_runtime_deps_stamp_path(plugin_dir)
        
        if not has_runtime_deps(package_json) or not should_stage_runtime_deps(package_json):
            remove_path_if_exists(node_modules_dir)
            remove_path_if_exists(stamp_path)
            continue
            
        fingerprint = create_runtime_deps_fingerprint(package_json)
        stamp = read_runtime_deps_stamp(stamp_path)
        
        if node_modules_dir.exists() and stamp and stamp.get('fingerprint') == fingerprint:
            continue
            
        install_plugin_runtime_deps_with_retries({
            'attempts': install_attempts,
            'install': install_plugin_runtime_deps_impl,
            'installParams': {
                'fingerprint': fingerprint,
                'packageJson': package_json,
                'pluginDir': plugin_dir,
                'pluginId': plugin_id,
                'repoRoot': repo_root,
            },
        })


if __name__ == '__main__':
    stage_bundled_plugin_runtime_deps()

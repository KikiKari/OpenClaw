#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "b8a9e8ea78b0c7707504aeafcd0780b598636490697db9be4fd18cff22a082a7", "source_sha256": "d97d27f12d9366bc18a828ca10d87d4ac159681dec9d4b6606e4827761c6ea72", "target_language": "ruby"}
# changed-extensions.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/changed-extensions.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

require "json"
require "open3"
require_relative "bundled-plugin-paths"

REPO_ROOT = File.expand_path("../../..", __dir__)

def run_git(args, options = {})
  Open3.popen3("git", *args, chdir: REPO_ROOT) do |stdin, stdout, stderr, wait_thr|
    stdin.close
    out = stdout.read
    err = stderr.read
    status = wait_thr.value

    unless status.success?
      raise "git command failed: #{err}"
    end

    out
  end
end

def normalize_relative(input_path)
  input_path.tr("\\", "/")
end

def has_git_commit(ref)
  return false if ref.nil? || ref.match?(/^0+$/)

  begin
    run_git(["rev-parse", "--verify", "#{ref}^{commit}"])
    true
  rescue
    false
  end
end

def resolve_changed_paths_base(params = {})
  base = params[:base]
  head = params[:head] || "HEAD"
  fallback_base_ref = params[:fallbackBaseRef]

  return base if has_git_commit(base)

  if fallback_base_ref
    remote_base_ref = fallback_base_ref.start_with?("origin/") ? fallback_base_ref : "origin/#{fallback_base_ref}"
    if has_git_commit(remote_base_ref)
      merge_base = run_git(["merge-base", remote_base_ref, head]).strip
      return merge_base if has_git_commit(merge_base)
    end
  end

  raise "A git base revision is required to list changed extensions." unless base
  raise "Git base revision is unavailable locally: #{base}"
end

def list_changed_paths(base, head = "HEAD")
  raise "A git base revision is required to list changed extensions." unless base

  output = run_git(["diff", "--name-only", base, head])
  output.split("\n").map(&:strip).reject(&:empty?)
end

def has_extension_package(extension_id)
  File.exist?(File.join(REPO_ROOT, BUNDLED_PLUGIN_ROOT_DIR, extension_id, "package.json"))
end

def list_available_extension_ids
  extensions_dir = File.join(REPO_ROOT, BUNDLED_PLUGIN_ROOT_DIR)
  return [] unless Dir.exist?(extensions_dir)

  Dir.children(extensions_dir)
     .select { |entry| File.directory?(File.join(extensions_dir, entry)) }
     .select { |extension_id| has_extension_package(extension_id) }
     .sort
end

def detect_changed_extension_ids(changed_paths)
  extension_ids = Set.new

  changed_paths.each do |raw_path|
    relative_path = normalize_relative(raw_path.to_s.strip)
    next if relative_path.empty?

    extension_match = relative_path.match(/^#{Regexp.escape(BUNDLED_PLUGIN_PATH_PREFIX)}([^\/]+)(?:\/|$)/)
    if extension_match
      extension_id = extension_match[1]
      if has_extension_package(extension_id)
        extension_ids.add(extension_id)
      end
      next
    end

    paired_core_match = relative_path.match(/^src\/([^\/]+)(?:\/|$)/)
    if paired_core_match && has_extension_package(paired_core_match[1])
      extension_ids.add(paired_core_match[1])
    end
  end

  extension_ids.sort
end

def list_changed_extension_ids(params = {})
  head = params[:head] || "HEAD"
  unavailable_base_behavior = params[:unavailableBaseBehavior] || "error"

  begin
    base = resolve_changed_paths_base(params)
    changed_paths = list_changed_paths(base, head)
    detect_changed_extension_ids(changed_paths)
  rescue => e
    case unavailable_base_behavior
    when "all"
      list_available_extension_ids
    when "empty"
      []
    else
      raise e
    end
  end
end

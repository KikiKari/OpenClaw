#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "ea4e44d937a410978ff8a10042dbff867fbcb4b80cc8eaf10449761a68e7519f", "source_sha256": "b6d33ba222e838d8ea4e8f134b161c60019978c5abaa86299906dfe095635a2b", "target_language": "ruby"}
# callsite-guard.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/callsite-guard.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

require 'fileutils'
require_relative 'ts_guard_utils'

def run_callsite_guard(params)
  repo_root = resolve_repo_root(params[:import_meta_url])
  source_roots = resolve_source_roots(repo_root, params[:source_roots])
  files = collect_typescript_files_from_roots(source_roots, {
    extra_test_suffixes: params[:extra_test_suffixes]
  })
  violations = []

  files.each do |file_path|
    rel_path = Pathname.new(file_path).relative_path_from(Pathname.new(repo_root)).to_s.gsub(File::SEPARATOR, '/')
    if params[:skip_relative_path]&.call(rel_path)
      next
    end
    content = File.read(file_path, encoding: 'UTF-8')
    params[:find_call_lines].call(content, file_path).each do |line|
      callsite = "#{rel_path}:#{line}"
      if params[:allow_callsite]&.call(callsite)
        next
      end
      violations.push(callsite)
    end
  end

  if violations.length == 0
    return
  end

  STDERR.puts params[:header]
  output = params[:sort_violations] == false ? violations : violations.sort
  output.each do |violation|
    STDERR.puts "- #{violation}"
  end
  if params[:footer]
    STDERR.puts params[:footer]
  end
  exit 1
end

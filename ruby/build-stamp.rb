#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "62136e33e6e396b9d122697e02deede8948022de09d65f8d240094cf7f4a5c2f", "source_sha256": "8537e4253cc6ca148bc7b8cee5f458bfd0843576263cad8e98ca2c46fa47f2f1", "target_language": "ruby"}
# build-stamp.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/build-stamp.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'fileutils'
require 'pathname'
require 'open3'

def resolve_git_head(params = {})
  cwd = params[:cwd] || Dir.pwd
  spawn_sync_impl = params[:spawn_sync] || method(:default_spawn_sync)

  begin
    stdout, stderr, status = spawn_sync_impl.call('git', ['rev-parse', 'HEAD'], chdir: cwd)
    return nil unless status.success?

    head = stdout.strip
    return head.empty? ? nil : head
  rescue StandardError
    return nil
  end
end

def default_spawn_sync(*args)
  Open3.capture3(*args)
end

def write_build_stamp(params = {})
  cwd = params[:cwd] || Dir.pwd
  fs_impl = params[:fs] || FileUtils
  now_method = params[:now] || -> { Time.now.to_i * 1000 + Time.now.usec / 1000 }

  dist_root = File.join(cwd, 'dist')
  build_stamp_path = File.join(dist_root, '.buildstamp')
  
  head = resolve_git_head(
    cwd: cwd,
    spawn_sync: params[:spawn_sync]
  )

  fs_impl.mkpath(dist_root) unless fs_impl.respond_to?(:write)
  
  # For compatibility with the original implementation
  unless fs_impl == FileUtils
    fs_impl.mkdir_p(dist_root)
  else
    FileUtils.mkdir_p(dist_root)
  end

  timestamp = now_method.call
  content = { builtAt: timestamp, head: head }.to_json + "\n"
  
  if fs_impl == FileUtils
    File.write(build_stamp_path, content, mode: 'w:utf-8')
  else
    fs_impl.write_file(build_stamp_path, content, 'utf-8')
  end
  
  build_stamp_path
end

if __FILE__ == $0
  begin
    write_build_stamp
  rescue => error
    STDERR.puts error
    exit 1
  end
end

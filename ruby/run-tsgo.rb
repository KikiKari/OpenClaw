#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "bec38cafbf62f598915635ed618dcacffb3060327351960ed950ce5649f0c64c", "source_sha256": "5425378c778f4ef6ac0e8404ecffe774c2d3aea6bad539b4fd772554e566f469", "target_language": "ruby"}
# run-tsgo.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/run-tsgo.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

require 'open3'
require 'fileutils'
require_relative 'lib/local-heavy-check-runtime'

def read_flag_value(args, name)
  args.each_with_index do |arg, index|
    if arg == name
      return args[index + 1]
    end
    if arg.start_with?("#{name}=")
      return arg[name.length + 1..-1]
    end
  end
  nil
end

final_args = ARGV.dup
env = ENV.to_h

# applyLocalTsgoPolicy equivalent - assuming it modifies args and env
# Since we don't have the exact implementation, we'll proceed with what we have

tsgo_path = File.expand_path('node_modules/.bin/tsgo')
ts_build_info_file = read_flag_value(final_args, '--tsBuildInfoFile')

if ts_build_info_file
  FileUtils.mkdir_p(File.dirname(File.expand_path(ts_build_info_file)))
end

release_lock = acquire_local_heavy_check_lock_sync({
  cwd: Dir.pwd,
  env: env,
  tool_name: 'tsgo'
})

begin
  stdin, stdout, stderr, wait_thr = Open3.popen3(tsgo_path, *final_args, chdir: Dir.pwd)

  # Inherit stdio by connecting pipes
  stdin.close_write
  
  # Read and forward output streams
  stdout_thread = Thread.new do
    while line = stdout.gets
      puts line
    end
  end
  
  stderr_thread = Thread.new do
    while line = stderr.gets
      $stderr.puts line
    end
  end
  
  stdout_thread.join
  stderr_thread.join
  
  status = wait_thr.value
  exit status.exitstatus || 1
rescue => e
  raise e
ensure
  release_lock.call if release_lock
end

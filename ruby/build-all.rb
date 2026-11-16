#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "a2eabeff58163278f1f9218acaf048fbfee36d46f0ddb05cdc59511ab760dbb4", "source_sha256": "c07aee6a3f0a90788cfe647dfcc79cf95df841ce0459eb8ffd9bf6aaa426ea38", "target_language": "ruby"}
# build-all.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/build-all.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

require 'open3'
require 'pathname'
require_relative 'pnpm-runner'

NODE_BIN = RbConfig.ruby
WINDOWS_BUILD_MAX_OLD_SPACE_MB = 4096

BUILD_ALL_STEPS = [
  { label: "canvas:a2ui:bundle", kind: "pnpm", pnpm_args: ["canvas:a2ui:bundle"] },
  { label: "tsdown", kind: "node", args: ["scripts/tsdown-build.mjs"] },
  { label: "runtime-postbuild", kind: "node", args: ["scripts/runtime-postbuild.mjs"] },
  {
    label: "write-npm-update-compat-sidecars",
    kind: "node",
    args: ["scripts/write-npm-update-compat-sidecars.mjs"],
  },
  { label: "build-stamp", kind: "node", args: ["scripts/build-stamp.mjs"] },
  {
    label: "build:plugin-sdk:dts",
    kind: "pnpm",
    pnpm_args: ["build:plugin-sdk:dts"],
    windows_node_options: "--max-old-space-size=#{WINDOWS_BUILD_MAX_OLD_SPACE_MB}",
  },
  {
    label: "write-plugin-sdk-entry-dts",
    kind: "node",
    args: ["--import", "tsx", "scripts/write-plugin-sdk-entry-dts.ts"],
  },
  {
    label: "check-plugin-sdk-exports",
    kind: "node",
    args: ["scripts/check-plugin-sdk-exports.mjs"],
  },
  {
    label: "canvas-a2ui-copy",
    kind: "node",
    args: ["--import", "tsx", "scripts/canvas-a2ui-copy.ts"],
  },
  {
    label: "copy-hook-metadata",
    kind: "node",
    args: ["--import", "tsx", "scripts/copy-hook-metadata.ts"],
  },
  {
    label: "copy-export-html-templates",
    kind: "node",
    args: ["--import", "tsx", "scripts/copy-export-html-templates.ts"],
  },
  {
    label: "write-build-info",
    kind: "node",
    args: ["--import", "tsx", "scripts/write-build-info.ts"],
  },
  {
    label: "write-cli-startup-metadata",
    kind: "node",
    args: ["--experimental-strip-types", "scripts/write-cli-startup-metadata.ts"],
  },
  {
    label: "write-cli-compat",
    kind: "node",
    args: ["--import", "tsx", "scripts/write-cli-compat.ts"],
  },
].freeze

def resolve_step_env(step, env, platform)
  return env if platform != "windows" || !step[:windows_node_options]
  
  current_node_options = env["NODE_OPTIONS"]&.strip || ""
  return env if current_node_options.include?(step[:windows_node_options])
  
  new_node_options = current_node_options.empty? ? 
    step[:windows_node_options] : 
    "#{current_node_options} #{step[:windows_node_options]}"
    
  env.merge("NODE_OPTIONS" => new_node_options)
end

def resolve_build_all_step(step, params = {})
  platform = params[:platform] || (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM ? "windows" : "unix")
  env = resolve_step_env(step, params[:env] || ENV.to_h, platform)
  
  if step[:kind] == "pnpm"
    runner = resolve_pnpm_runner(
      pnpm_args: step[:pnpm_args],
      node_exec_path: params[:node_exec_path] || NODE_BIN,
      npm_exec_path: params[:npm_exec_path] || env["npm_execpath"],
      com_spec: params[:com_spec] || env["ComSpec"],
      platform: platform
    )
    
    return {
      command: runner[:command],
      args: runner[:args],
      options: {
        env: env,
        shell: runner[:shell],
        windows_verbatim_arguments: runner[:windows_verbatim_arguments]
      }
    }
  end
  
  {
    command: params[:node_exec_path] || NODE_BIN,
    args: step[:args],
    options: {
      env: env
    }
  }
end

def main
  BUILD_ALL_STEPS.each do |step|
    $stderr.puts "[build-all] #{step[:label]}"
    invocation = resolve_build_all_step(step)
    
    # Convert hash keys to symbols for Open3
    opts = invocation[:options].transform_keys(&:to_sym)
    
    status = Open3.spawn(
      invocation[:command], 
      *invocation[:args],
      opts
    )
    
    if status.nil?
      exit(1)
    elsif status != 0
      exit(status)
    end
  end
end

# Check if this file is being run directly
if __FILE__ == $0
  main
end

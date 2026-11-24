#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "a889dedabbb7eca5fd20a5ecffc379ee5d3150cd71760b019d75c5310071381c", "source_sha256": "0f2bb155d699e769ad3eb99a6500cc6dbb27948a57f7493a3b98c731200853d4", "target_language": "ruby"}
# test-extension.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-extension.mjs
# Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

require_relative './lib/error_format'
require_relative './lib/extension_test_plan'
require_relative './lib/vitest_batch_runner'

def print_usage
  $stderr.puts "Usage: pnpm test:extension <extension-name|path> [vitest args...]"
  $stderr.puts "       node scripts/test-extension.mjs [extension-name|path] [vitest args...]"
end

def print_no_tests_message(plan)
  puts "[test-extension] No tests found for #{plan.extension_dir}. Skipping."
end

def run
  raw_args = ARGV.dup
  if raw_args.include?("--help") || raw_args.include?("-h")
    print_usage
    return
  end

  passthrough_args = raw_args.reject { |arg| arg == "--" }

  target_arg = nil
  if passthrough_args[0] && !passthrough_args[0].start_with?("-")
    target_arg = passthrough_args.shift
  end

  plan = nil
  begin
    plan = resolve_extension_test_plan({ cwd: Dir.pwd, target_arg: target_arg })
  rescue => error
    print_usage
    $stderr.puts format_error_message(error)
    exit 1
  end

  unless plan.has_tests
    print_no_tests_message(plan)
    return
  end

  puts "[test-extension] Running #{plan.test_file_count} test files for #{plan.extension_id}"
  exit_code = run_vitest_batch({
    args: passthrough_ags,
    config: plan.config,
    env: ENV.to_h,
    targets: plan.roots
  })
  exit exit_code
end

if __FILE__ == $0
  run
end

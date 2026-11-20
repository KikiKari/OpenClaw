#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "ac732090e77f164af7e4aff22a90c5ca41cd4a58485a598e0442e783c54200c8", "source_sha256": "f198925e5c21dc828628def1707ba79512014dafa5a425580bbf80881a4b0ed7", "target_language": "ruby"}
# ghsa-patch.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/ghsa-patch.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'fileutils'
require 'securerandom'
require 'open3'

def usage
  $stderr.puts <<~USAGE
    Usage:
      ruby scripts/ghsa-patch.rb --ghsa <GHSA-id-or-url> [--repo owner/name]
        --summary <text> --severity <low|medium|high|critical>
        --description-file <path>
        --vulnerable-version-range <range>
        --patched-versions <range-or-null>
        [--package openclaw] [--ecosystem npm] [--cvss <vector>]
  USAGE
end

def fail(message)
  $stderr.puts message
  exit 1
end

def parse_args(argv)
  out = {}
  i = 0
  while i < argv.length
    arg = argv[i]
    unless arg.start_with?('--')
      fail("Unexpected argument: #{arg}")
    end
    key = arg[2..-1]
    value = argv[i + 1]
    if !value || value.start_with?('--')
      fail("Missing value for --#{key}")
    end
    out[key] = value
    i += 2
  end
  out
end

def run_gh(args)
  stdin, stdout, stderr, wait_thr = Open3.popen3('gh', *args)
  stdin.close
  output = stdout.read
  error_output = stderr.read
  stdout.close
  stderr.close
  status = wait_thr.value

  if status != 0
    error_msg = (error_output.strip.empty? ? output.strip : error_output.strip) || "gh #{args.join(' ')} failed"
    fail(error_msg)
  end
  output
end

def derive_repo_from_origin
  output, _status = Open3.capture2('git', 'remote', 'get-url', 'origin')
  remote = output.strip
  https_match = remote.match(/github\.com[\/:]([^\/]+)\/([^\/.]+)(?:\.git)?$/)
  unless https_match
    fail("Could not parse origin remote: #{remote}")
  end
  "#{https_match[1]}/#{https_match[2]}"
end

def parse_ghsa_id(value)
  match = value.match(/GHSA-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}/i)
  unless match
    fail("Could not parse GHSA id from: #{value}")
  end
  match[0]
end

def write_temp_json(data)
  file = File.join(Dir.tmpdir, "ghsa-patch-#{SecureRandom.uuid}.json")
  File.write(file, "#{JSON.pretty_generate(data)}\n")
  file
end

args = parse_args(ARGV)

if !args['ghsa'] || !args['summary'] || !args['severity'] || !args['description-file']
  usage
  exit 1
end

repo = args['repo'] || derive_repo_from_origin
ghsa_id = parse_ghsa_id(args['ghsa'])
advisory_path = "/repos/#{repo}/security-advisories/#{ghsa_id}"
description_path = File.expand_path(args['description-file'])

unless File.exist?(description_path)
  fail("Description file does not exist: #{description_path}")
end

current = JSON.parse(run_gh(['api', '-H', 'X-GitHub-Api-Version: 2022-11-28', advisory_path]))
restored_cvss = args['cvss'] || current&.dig('cvss', 'vector_string') || nil

ecosystem = args['ecosystem'] || 'npm'
package_name = args['package'] || 'openclaw'
vulnerable_range = args['vulnerable-version-range']
patched_versions_raw = args['patched-versions']

if !vulnerable_range
  fail('Missing --vulnerable-version-range')
end

if patched_versions_raw.nil?
  fail('Missing --patched-versions')
end

patched_versions = patched_versions_raw == 'null' ? nil : patched_versions_raw
description = File.read(description_path)

payload = {
  summary: args['summary'],
  severity: args['severity'],
  description: description,
  vulnerabilities: [
    {
      package: {
        ecosystem: ecosystem,
        name: package_name
      },
      vulnerable_version_range: vulnerable_range,
      patched_versions: patched_versions,
      vulnerable_functions: []
    }
  ]
}

patch_file = write_temp_json(payload)
run_gh([
  'api',
  '-H',
  'X-GitHub-Api-Version: 2022-11-28',
  '-X',
  'PATCH',
  advisory_path,
  '--input',
  patch_file
])

if restored_cvss
  run_gh([
    'api',
    '-H',
    'X-GitHub-Api-Version: 2022-11-28',
    '-X',
    'PATCH',
    advisory_path,
    '-f',
    "cvss_vector_string=#{restored_cvss}"
  ])
end

refreshed = JSON.parse(run_gh(['api', '-H', 'X-GitHub-Api-Version: 2022-11-28', advisory_path]))
puts JSON.pretty_generate({
  html_url: refreshed['html_url'],
  state: refreshed['state'],
  severity: refreshed['severity'],
  summary: refreshed['summary'],
  vulnerabilities: refreshed['vulnerabilities'],
  cvss: refreshed['cvss'],
  updated_at: refreshed['updated_at']
})

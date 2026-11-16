#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "4c015840926c1bbd3aa5de65bfc7d09c9e56582f63485a374f16d066cec4ed90", "source_sha256": "d0e229aab6f22cce6a57639e2ffb6182fc50c823ca2adff745764d168dc70826", "target_language": "ruby"}
# audit-seams.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/audit-seams.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'pathname'
require 'set'

# Constants
REPO_ROOT = Pathname.new(__FILE__).dirname.parent.to_s
SRC_ROOT = File.join(REPO_ROOT, "src")
EXTENSIONS_ROOT = File.join(REPO_ROOT, "extensions")
TEST_ROOT = File.join(REPO_ROOT, "test")
WORKSPACE_PACKAGE_PATHS = ["ui/package.json"]
MAX_SCAN_BYTES = 2 * 1024 * 1024

BUNDLED_PLUGIN_PATH_PREFIX = "extensions/"
BUNDLED_PLUGIN_ROOT_DIR = "extensions"

OPTIONAL_BUNDLED_CLUSTER_SET = Set.new([
  "ui",
  "sms-twilio",
  "email-sendgrid",
  "voice-twilio",
  "calendar-google",
  "calendar-outlook",
  "notion",
  "slack",
  "discord",
  "whatsapp-twilio",
  "instagram",
  "linkedin",
  "twitter",
  "youtube",
  "zoom",
  "webflow",
  "shopify",
  "stripe",
  "paypal",
  "airtable",
  "hubspot",
  "salesforce",
  "zendesk",
  "intercom",
  "mailchimp",
  "typeform",
  "google-drive",
  "dropbox",
  "onedrive",
  "aws-s3",
  "firebase",
  "mongodb",
  "postgresql",
  "mysql",
  "redis",
  "elasticsearch",
  "openai",
  "anthropic",
  "replicate",
  "elevenlabs",
  "assemblyai",
  "huggingface",
  "pinecone",
  "weaviate",
  "qdrant",
  "chroma",
  "supabase",
  "deta",
  "railway",
  "vercel",
  "netlify",
  "cloudflare",
  "aws-lambda",
  "gcp-functions",
  "azure-functions"
])

HELP_TEXT = <<~USAGE
Usage: ruby audit-seams.rb [--help]

Audit repo seam inventory and emit JSON to stdout.

Sections:
  duplicatedSeamFamilies       Plugin SDK seam families imported from multiple production files
  overlapFiles                 Production files that touch multiple seam families
  optionalClusterStaticLeaks   Optional extension/plugin clusters referenced from the static graph
  missingPackages              Workspace packages whose deps are not mirrored at the root
  seamTestInventory            High-signal seam candidates with nearby-test gap signals,
                               including cron orchestration seams for agent handoff,
                               outbound/media delivery, heartbeat/followup handoff,
                               and scheduler state crossings, plus subagent seams
                               for spawn/session handoff, announce delivery,
                               lifecycle registry, cleanup, and parent streaming

Notes:
  - Output is JSON only.
  - For clean redirected JSON through package scripts, prefer:
      pnpm --silent audit:seams > seam-inventory.json
USAGE

def collect_workspace_package_paths
  Dir.children(EXTENSIONS_ROOT).each do |entry|
    if File.directory?(File.join(EXTENSIONS_ROOT, entry))
      WORKSPACE_PACKAGE_PATHS.push(File.join("extensions", entry, "package.json"))
    end
  end
end

def normalize_path(file_path)
  Pathname.new(file_path).relative_path_from(Pathname.new(REPO_ROOT)).to_s.gsub(File::SEPARATOR, "/")
end

def read_scannable_text(file_path, max_bytes = MAX_SCAN_BYTES)
  stat = File.stat(file_path)
  if stat.size <= max_bytes
    return File.read(file_path, encoding: "UTF-8")
  end
  
  File.open(file_path, "r") do |handle|
    handle.read(max_bytes, encoding: "UTF-8")
  end
end

def redact_npm_spec(npm_spec)
  return npm_spec unless npm_spec.is_a?(String)
  
  npm_spec
    .gsub(%r{(https?://)([^/\s:@]+):([^/\s@]+)@}i, '\1***:***@')
    .gsub(%r{(https?://)([^/\s:@]+)@}i, '\1***@')
end

def is_code_file(file_name)
  /\.(ts|tsx|mts|cts|js|jsx|mjs|cjs)$/ =~ file_name
end

def is_test_like_path(relative_path)
  /(^|\/)(__tests__|fixtures|test-utils|test-fixtures)\// =~ relative_path ||
    /(?:^|\/)[^\/]*(?:[.-](?:test|spec))(?:[.-][^\/]+)?\.(ts|tsx|mts|cts|js|jsx|mjs|cjs)$/ =~ relative_path
end

def is_production_like_file(relative_path)
  !is_test_like_path(relative_path)
end

def walk_code_files(root_dir)
  out = []
  
  def walk(dir, out, &block)
    Dir.children(dir).each do |entry|
      next if entry == "dist" || entry == "node_modules"
      
      full_path = File.join(dir, entry)
      if File.directory?(full_path)
        walk(full_path, out, &block)
        next
      end
      
      next unless File.file?(full_path) && is_code_file(entry)
      
      relative_path = normalize_path(full_path)
      next unless is_production_like_file(relative_path)
      
      out.push(full_path)
    end
  end
  
  walk(root_dir, out)
  out.sort_by { |path| normalize_path(path) }
end

def walk_all_code_files(root_dir, options = {})
  out = []
  include_tests = options[:include_tests] == true
  
  def walk(dir, out, include_tests, &block)
    entries = Dir.children(dir)
  rescue
    return
  else
    entries.each do |entry|
      next if entry == "dist" || entry == "node_modules"
      
      full_path = File.join(dir, entry)
      if File.directory?(full_path)
        walk(full_path, out, include_tests, &block)
        next
      end
      
      next unless File.file?(full_path) && is_code_file(entry)
      
      relative_path = normalize_path(full_path)
      next unless include_tests || is_production_like_file(relative_path)
      
      out.push(full_path)
    end
  end
  
  walk(root_dir, out, include_tests)
  out.sort_by { |path| normalize_path(path) }
end

def to_line(source_file, node_start)
  # Simplified implementation since we don't have TypeScript AST in Ruby
  lines = source_file.split("\n")
  current_pos = 0
  
  lines.each_with_index do |line, index|
    if current_pos <= node_start && node_start < current_pos + line.length + 1
      return index + 1
    end
    current_pos += line.length + 1
  end
  
  1
end

def resolve_relative_specifier(specifier, importer_file)
  return nil unless specifier.start_with?(".")
  
  normalize_path(File.expand_path(specifier, File.dirname(importer_file)))
end

def normalize_plugin_sdk_family(resolved_path)
  relative = resolved_path.sub(/^src\/plugin-sdk\//, "")
  relative.sub(/\.(m|c)?[jt]sx?$/, "")
end

def resolve_optional_cluster_from_path(resolved_path)
  if resolved_path.start_with?(BUNDLED_PLUGIN_PATH_PREFIX)
    cluster = resolved_path.split("/")[1]
    return OPTIONAL_BUNDLED_CLUSTER_SET.include?(cluster) ? cluster : nil
  end
  
  if resolved_path.start_with?("src/plugin-sdk/")
    cluster = normalize_plugin_sdk_family(resolved_path).split("/")[0]
    return OPTIONAL_BUNDLED_CLUSTER_SET.include?(cluster) ? cluster : nil
  end
  
  nil
end

def compare_imports(left, right)
  [
    left[:family] <=> right[:family],
    left[:file] <=> right[:file],
    left[:line] <=> right[:line],
    left[:kind] <=> right[:kind],
    left[:specifier] <=> right[:specifier]
  ].find { |result| result != 0 } || 0
end

def collect_plugin_sdk_imports(file_path, source)
  entries = []
  
  # Simple regex-based parsing instead of TypeScript AST
  source.scan(/import\s+(?:.*?\s+from\s+)?["'](.*?\.\.?\/.*?)["']/) do |match|
    specifier = match[0]
    resolved_path = resolve_relative_specifier(specifier, file_path)
    
    if resolved_path&.start_with?("src/plugin-sdk/")
      entries.push({
        family: normalize_plugin_sdk_family(resolved_path),
        file: normalize_path(file_path),
        kind: "import",
        line: source.lines.count { |line| source.index(line) < source.index(specifier) } + 1,
        resolved_path: resolved_path,
        specifier: specifier
      })
    end
  end
  
  source.scan(/export\s+.*?\s+from\s+["'](.*?\.\.?\/.*?)["']/) do |match|
    specifier = match[0]
    resolved_path = resolve_relative_specifier(specifier, file_path)
    
    if resolved_path&.start_with?("src/plugin-sdk/")
      entries.push({
        family: normalize_plugin_sdk_family(resolved_path),
        file: normalize_path(file_path),
        kind: "export",
        line: source.lines.count { |line| source.index(line) < source.index(specifier) } + 1,
        resolved_path: resolved_path,
        specifier: specifier
      })
    end
  end
  
  entries
end

def collect_core_plugin_sdk_imports
  files = walk_code_files(SRC_ROOT)
  inventory = []
  
  files.each do |file_path|
    next if normalize_path(file_path).start_with?("src/plugin-sdk/")
    
    source = File.read(file_path, encoding: "UTF-8")
    inventory.concat(collect_plugin_sdk_imports(file_path, source))
  end
  
  inventory.sort { |left, right| compare_imports(left, right) }
end

def collect_optional_cluster_static_imports(file_path, source)
  entries = []
  
  source.scan(/(import|export)\s+.*?\s+from\s+["'](.*?\.\.?\/.*?)["']/) do |kind, specifier|
    next unless specifier.start_with?(".")
    
    resolved_path = resolve_relative_specifier(specifier, file_path)
    next unless resolved_path
    
    cluster = resolve_optional_cluster_from_path(resolved_path)
    next unless cluster
    
    entries.push({
      cluster: cluster,
      file: normalize_path(file_path),
      kind: kind,
      line: source.lines.count { |line| source.index(line) < source.index(specifier) } + 1,
      resolved_path: resolved_path,
      specifier: specifier
    })
  end
  
  entries
end

def collect_optional_cluster_static_leaks
  files = walk_code_files(SRC_ROOT)
  inventory = []
  
  files.each do |file_path|
    relative_path = normalize_path(file_path)
    next if relative_path.start_with?("src/plugin-sdk/")
    
    source = File.read(file_path, encoding: "UTF-8")
    inventory.concat(collect_optional_cluster_static_imports(file_path, source))
  end
  
  inventory.sort do |left, right|
    [
      left[:cluster] <=> right[:cluster],
      left[:file] <=> right[:file],
      left[:line] <=> right[:line],
      left[:kind] <=> right[:kind],
      left[:specifier] <=> right[:specifier]
    ].find { |result| result != 0 } || 0
  end
end

def build_duplicated_seam_families(inventory)
  grouped = Hash.new { |h, k| h[k] = [] }
  
  inventory.each do |entry|
    grouped[entry[:family]] << entry
  end
  
  duplicated = {}
  grouped.each do |family, entries|
    files = entries.map { |entry| entry[:file] }.uniq.sort
    next unless files.length > 1
    
    duplicated[family] = {
      count: files.length,
      import_count: entries.length,
      files: files,
      imports: entries
    }
  end
  
  duplicated.sort.to_h
end

def build_overlap_files(inventory)
  by_file = Hash.new { |h, k| h[k] = [] }
  
  inventory.each do |entry|
    by_file[entry[:file]] << entry
  end
  
  result = []
  by_file.each do |file, entries|
    families = entries.map { |entry| entry[:family] }.uniq.sort
    next unless families.length > 1
    
    result.push({
      file: file,
      families: families,
      imports: entries
    })
  end
  
  result.sort do |left, right|
    [
      right[:families].length <=> left[:families].length,
      right[:imports].length <=> left[:imports].length,
      left[:file] <=> right[:file]
    ].find { |result| result != 0 } || 0
  end
end

def build_optional_cluster_static_leaks(inventory)
  grouped = Hash.new { |h, k| h[k] = [] }
  
  inventory.each do |entry|
    grouped[entry[:cluster]] << entry
  end
  
  result = {}
  grouped.each do |cluster, entries|
    result[cluster] = {
      count: entries.length,
      files: entries.map { |entry| entry[:file] }.uniq.sort,
      imports: entries
    }
  end
  
  result.sort.to_h
end

def package_cluster_meta(relative_package_path)
  if relative_package_path == "ui/package.json"
    return {
      cluster: "ui",
      package_name: "openclaw-control-ui",
      package_path: relative_package_path,
      reachability: "workspace-ui"
    }
  end
  
  cluster = relative_package_path.split("/")[1]
  {
    cluster: cluster,
    package_name: nil,
    package_path: relative_package_path,
    reachability: relative_package_path.start_with?(BUNDLED_PLUGIN_PATH_PREFIX) ? 
                  "extension-workspace" : "workspace"
  }
end

def classify_missing_package_cluster(params)
  if params[:has_static_leak]
    return {
      decision: "required",
      reason: "Cluster already appears in the static graph in this audit run, so treating it as optional would be misleading."
    }
  end
  
  if OPTIONAL_BUNDLED_CLUSTER_SET.include?(params[:cluster])
    if params[:cluster] == "ui"
      return {
        decision: "optional",
        reason: "Private UI workspace. Repo-wide CLI/plugin CI should not require UI-only packages."
      }
    end
    
    if params[:plugin_sdk_entries].length > 0
      return {
        decision: "optional",
        reason: "Public plugin-sdk entry exists, but repo-wide default check/build should isolate this optional cluster from the static graph."
      }
    end
    
    return {
      decision: "optional",
      reason: "Workspace package is intentionally not mirrored into the root dependency set by default CI policy."
    }
  end
  
  {
    decision: "required",
    reason: "Cluster is statically visible to repo-wide check/build and has not been classified optional."
  }
end

def build_missing_packages(params = {})
  root_package = JSON.parse(File.read(File.join(REPO_ROOT, "package.json"), encoding: "UTF-8"))
  root_deps = Set.new(
    (root_package["dependencies"]&.keys || []) +
    (root_package["optionalDependencies"]&.keys || []) +
    (root_package["devDependencies"]&.keys || [])
  )
  
  plugin_sdk_entry_sources = walk_code_files(File.join(REPO_ROOT, "src", "plugin-sdk"))
  plugin_sdk_reachability = Hash.new { |h, k| h[k] = Set.new }
  
  plugin_sdk_entry_sources.each do |file_path|
    source = File.read(file_path, encoding: "UTF-8")
    source.scan(/from\s+"(\.\.\/\.\.\/extensions\/([^\/]+)\/[^"]+)"/) do |match|
      cluster = match[1]
      plugin_sdk_reachability[cluster].add(normalize_path(file_path))
    end
  end
  
  output = []
  WORKSPACE_PACKAGE_PATHS.sort.each do |relative_package_path|
    package_path = File.join(REPO_ROOT, relative_package_path)
    begin
      pkg = JSON.parse(File.read(package_path, encoding: "UTF-8"))
    rescue
      next
    end
    
    missing = (pkg["dependencies"]&.keys || [])
                .select { |dep| dep != "openclaw" && !root_deps.include?(dep) }
                .sort
    
    next if missing.empty?
    
    meta = package_cluster_meta(relative_package_path)
    plugin_sdk_entries = plugin_sdk_reachability[meta[:cluster]].to_a.sort
    classification = classify_missing_package_cluster({
      cluster: meta[:cluster],
      plugin_sdk_entries: plugin_sdk_entries,
      has_static_leak: params[:static_leak_clusters]&.include?(meta[:cluster]) == true
    })
    
    entry = {
      cluster: meta[:cluster],
      decision: classification[:decision],
      decision_reason: classification[:reason],
      package_name: pkg["name"] || meta[:package_name],
      package_path: relative_package_path,
      npm_spec: redact_npm_spec(pkg.dig("openclaw", "install", "npmSpec")),
      private: pkg["private"] == true,
      missing: missing
    }
    
    unless plugin_sdk_entries.empty?
      entry[:plugin_sdk_reachability] = { static_entry_points: plugin_sdk_entries }
    end
    
    output.push(entry)
  end
  
  output.sort do |left, right|
    [right[:missing].length <=> left[:missing].length, left[:cluster] <=> right[:cluster]].find { |result| result != 0 } || 0
  end
end

def stem_from_relative_path(relative_path)
  relative_path.sub(/\.(m|c)?[jt]sx?$/, "")
end

def split_name_tokens(name)
  name.split(/[^a-zA-Z0-9]+/)
      .map(&:strip)
      .map(&:downcase)
      .reject(&:empty?)
end

def escape_for_regexp(value)
  Regexp.escape(value)
end

def has_import_source(source, specifier)
  escaped = escape_for_regexp(specifier)
  /from\s+["']#{escaped}["']|import\s*\(\s*["']#{escaped}["']\s*\)/.match?(source)
end

def has_any_import_source(source, specifiers)
  specifiers.any? { |specifier| has_import_source(source, specifier) }
end

def is_cron_production_path(relative_path)
  relative_path.start_with?("src/cron/") && is_production_like_file(relative_path)
end

def is_subagent_production_path(relative_path)
  (relative_path.start_with?("src/agents/") || relative_path.start_with?("src/cron/")) &&
    is_production_like_file(relative_path) &&
    (/subagent|sessions-spawn|acp-spawn/.match?(relative_path) ||
     relative_path == "src/agents/tools/sessions-spawn-tool.ts" ||
     relative_path == "src/agents/tools/subagents-tool.ts")
end

def describe_cron_seam_kinds(relative_path, source)
  return [] unless is_cron_production_path(relative_path)
  
  seam_kinds = []
  
  imports_agent_runner = has_any_import_source(source, [
    "../../agents/cli-runner.js",
    "../../agents/pi-embedded.js",
    "../../agents/model-fallback.js",
    "../../agents/subagent-registry.js",
    "../../infra/agent-events.js"
  ])
  
  imports_outbound_delivery = has_any_import_source(source, [
    "../infra/outbound/deliver.js",
    "../../infra/outbound/deliver.js",
    "../infra/outbound/session-context.js",
    "../../infra/outbound/session-context.js",
    "../infra/outbound/identity.js",
    "../../infra/outbound/identity.js",
    "../cli/outbound-send-deps.js",
    "../../cli/outbound-send-deps.js"
  ])
  
  imports_heartbeat = has_any_import_source(source, [
    "../auto-reply/heartbeat.js",
    "../../auto-reply/heartbeat.js",
    "../infra/heartbeat-wake.js",
    "../../infra/heartbeat-wake.js"
  ])
  
  imports_followup = has_any_import_source(source, [
    "./subagent-followup.js",
    "../../agents/subagent-registry.js",
    "../../agents/tools/agent-step.js",
    "../../gateway/call.js"
  ])
  
  imports_scheduler_modules = relative_path.start_with?("src/cron/service/") &&
    has_any_import_source(source, [
      "./jobs.js",
      "./store.js",
      "./timer.js",
      "./state.js",
      "../schedule.js",
      "../store.js",
      "../run-log.js"
    ])
  
  if imports_agent_runner &&
     /\brunCliAgent\b|\brunEmbeddedPiAgent\b|\brunWithModelFallback\b|\bregisterAgentRunContext\b/.match?(source)
    seam_kinds.push("cron-agent-handoff")
  end
  
  if imports_outbound_delivery &&
     /\bdeliverOutboundPayloads\b|\bbuildOutboundSessionContext\b|\bresolveAgentOutboundIdentity\b/.match?(source)
    seam_kinds.push("cron-outbound-delivery")
  end
  
  if imports_heartbeat &&
     /\bstripHeartbeatToken\b|\bHeartbeat\b|\bheartbeat\b|\bnext-heartbeat\b/.match?(source)
    seam_kinds.push("cron-heartbeat-handoff")
  end
  
  if imports_scheduler_modules &&
     /\bensureLoaded\b|\bpersist\b|\barmTimer\b|\brunMissedJobs\b|\bcomputeJobNextRunAtMs\b|\brecomputeNextRuns\b|\bnextWakeAtMs\b/.match?(source)
    seam_kinds.push("cron-scheduler-state")
  end
  
  if imports_outbound_delivery &&
     /\bmediaUrl\b|\bmediaUrls\b|\bfilename\b|\baudioAsVoice\b|\bdeliveryPayloads\b|\bdeliveryPayloadHasStructuredContent\b/.match?(source)
    seam_kinds.push("cron-media-delivery")
  end
  
  if imports_followup &&
     /\bwaitForDescendantSubagentSummary\b|\breadDescendantSubagentFallbackReply\b|\bexpectsSubagentFollowup\b|\bcallGateway\b|\blistDescendantRunsForRequester\b/.match?(source)
    seam_kinds.push("cron-followup-handoff")
  end
  
  seam_kinds
end

def describe_subagent_seam_kinds(relative_path, source)
  return [] unless is_subagent_production_path(relative_path)
  
  seam_kinds = []
  
  is_announce_dispatch_path = relative_path == "src/agents/subagent-announce.ts" ||
                              relative_path == "src/agents/subagent-announce-dispatch.ts"
  
  imports_spawn_runtime = has_any_import_source(source, [
    "./subagent-spawn.js",
    "../subagent-spawn.js",
    "./acp-spawn.js",
    "../acp-spawn.js",
    "./subagent-registry.js",
    "../subagent-registry.js",
    "../acp/control-plane/manager.js"
  ])
  
  imports_lifecycle_registry = has_any_import_source(source, [
    "./subagent-registry-completion.js",
    "./subagent-registry-cleanup.js",
    "./subagent-registry-state.js",
    "./subagent-registry.js",
    "./subagent-lifecycle-events.js",
    "../context-engine/init.js",
    "../context-engine/registry.js",
    "../sessions/session-lifecycle-events.js"
  ])
  
  imports_announce_delivery = has_any_import_source(source, [
    "./subagent-announce.js",
    "./subagent-announce-dispatch.js",
    "./subagent-announce-queue.js",
    "../infra/outbound/bound-delivery-router.js",
    "../utils/delivery-context.js",
    "../gateway/call.js"
  ])
  
  imports_cleanup = has_any_import_source(source, [
    "../gateway/call.js",
    "./subagent-registry-cleanup.js",
    "../acp/control-plane/spawn.js"
  ])
  
  imports_parent_stream = has_any_import_source(source, [
    "./acp-spawn-parent-stream.js",
    "../infra/heartbeat-wake.js",
    "../infra/system-events.js",
    "../infra/agent-events.js"
  ])
  
  if imports_spawn_runtime &&
     /\bspawnSubagentDirect\b|\bspawnAcpDirect\b|\bregisterSubagentRun\b|\bgetAcpSessionManager\b|\bspawnSubagent\b|\bspawnAcp\b/.match?(source)
    seam_kinds.push("subagent-session-spawn")
  end
  
  if imports_lifecycle_registry &&
     /\bemitSubagentEndedHookOnce\b|\bresolveDeferredCleanupDecision\b|\bpersistSubagentRunsToDisk\b|\brestoreSubagentRunsFromDisk\b|\bresolveContextEngine\b|\bemitSessionLifecycleEvent\b|\bcaptureSubagentCompletionReply\b/.match?(source)
    seam_kinds.push("subagent-lifecycle-registry")
  end
  
  if (imports_announce_delivery || is_announce_dispatch_path) &&
     /\brunSubagentAnnounceFlow\b|\brunSubagentAnnounceDispatch\b|\benqueueAnnounce\b|\bcreateBoundDeliveryRouter\b|\bqueueEmbeddedPiMessage\b|\bwaitForEmbeddedPiRunEnd\b|\bqueue-fallback\b|\bdirect-primary\b/.match?(source)
    seam_kinds.push("subagent-announce-delivery")
  end
  
  if imports_cleanup &&
     /\bsessions\.delete\b|\bdeleteTranscript\b|\bcleanupFailedAcpSpawn\b|\bcleanupProvisionalSession\b|\bcleanupFailedSpawnBeforeAgentStart\b|\bresolveDeferredCleanupDecision\b/.match?(source)
    seam_kinds.push("subagent-session-cleanup")
  end
  
  if imports_parent_stream &&
     /\bstartAcpSpawnParentStreamRelay\b|\brequestHeartbeatNow\b|\benqueueSystemEvent\b|\bonAgentEvent\b|\bstreamTo\b/.match?(source)
    seam_kinds.push("subagent-parent-stream")
  end
  
  seam_kinds
end

def describe_seam_kinds(relative_path, source)
  seam_kinds = []
  
  is_reply_delivery_path = /reply-delivery|reply-dispatcher|deliver-reply|reply\/.*delivery|monitor\/(?:replies|deliver|native-command)|outbound\/deliver|outbound\/message/.match?(relative_path)
  
  is_channel_media_adapter_path = (relative_path.start_with?(BUNDLED_PLUGIN_PATH_PREFIX) &&
                                   /(outbound|outbound-adapter|reply-delivery|send|delivery|messenger|channel(?:\.runtime)?)\.ts$/.match?(relative_path)) ||
                                  /^src\/channels\/plugins\/outbound\/[^\/]+\.ts$/.match?(relative_path)
  
  if relative_path.start_with?("src/agents/tools/") &&
     source.include?("details") &&
     source.include?("media") &&
     /details\s*:\s*{[\s\S]*\bmedia\b\s*:/.match?(source)
    seam_kinds.push("tool-result-media")
  end
  
  if is_reply_delivery_path &&
     /\bmediaUrl\b|\bmediaUrls\b|resolveSendableOutboundReplyParts/.match?(source)
    seam_kinds.push("reply-delivery-media")
  end
  
  if is_channel_media_adapter_path &&
     (/sendMedia\b/.match?(source) || /\bmediaUrl\b|\bmediaUrls\b|filename|audioAsVoice/.match?(source))
    seam_kinds.push("channel-media-adapter")
  end
  
  if is_reply_delivery_path &&
     /blockStreamingEnabled|directlySentBlockKeys|resolveSendableOutboundReplyParts/.match?(source) &&
     /\bmediaUrl\b|\bmediaUrls\b/.match?(source)
    seam_kinds.push("streaming-media-handoff")
  end
  
  seam_kinds.concat(describe_cron_seam_kinds(relative_path, source))
  seam_kinds.concat(describe_subagent_seam_kinds(relative_path, source))
  
  seam_kinds.uniq.sort
end

def build_test_index(test_files)
  test_files.map do |file_path|
    relative_path = normalize_path(file_path)
    stem = stem_from_relative_path(relative_path)
               .sub(/\.test$/, "")
               .sub(/\.spec$/, "")
    base_name = File.basename(stem)
    source = read_scannable_text(file_path)
    
    {
      file_path: file_path,
      relative_path: relative_path,
      stem: stem,
      base_name: base_name,
      source: source
    }
  end
end

def has_executable_import_reference(source, import_path)
  escaped_import_path = escape_for_regexp(import_path)
  suffix = "(?:\\.[^\"'\\\\`]+)?"
  
  patterns = [
    /from\s*["'`]#{escaped_import_path}#{suffix}["'`]/,
    /import\s*["'`]#{escaped_import_path}#{suffix}["'`]/,
    /require\s*\(\s*["'`]#{escaped_import_path}#{suffix}["'`]\s*\)/,
    /import\s*\(\s*["'`]#{escaped_import_path}#{suffix}["'`]\s*\)/
  ]
  
  patterns.any? { |pattern| pattern.match?(source) }
end

def has_module_mock_reference(source, import_path)
  escaped_import_path = escape_for_regexp(import_path)
  suffix = "(?:\\.[^\"'\\\\`]+)?"
  
  patterns = [
    /vi\.mock\s*\(\s*["'`]#{escaped_import_path}#{suffix}["'`]/,
    /jest\.mock\s*\(\s*["'`]#{escaped_import_path}#{suffix}["'`]/
  ]
  
  patterns.any? { |pattern| pattern.match?(source) }
end

def match_quality_rank(quality)
  case quality
  when "exact-stem"
    0
  when "path-nearby"
    1
  when "direct-import"
    2
  when "dir-token"
    3
  else
    4
  end
end

def find_related_tests(relative_path, test_index)
  stem = stem_from_relative_path(relative_path)
  base_name = File.basename(stem)
  dir_name = File.dirname(relative_path)
  normalized_dir = dir_name.gsub(File::SEPARATOR, "/")
  base_tokens = split_name_tokens(base_name).select { |token| token.length >= 7 }.to_set
  
  matches = test_index.flat_map do |entry|
    if entry[:stem] == stem
      [{ file: entry[:relative_path], match_quality: "exact-stem" }]
    elsif entry[:stem].start_with?("#{stem}.")
      [{ file: entry[:relative_path], match_quality: "path-nearby" }]
    else
      entry_dir = File.dirname(entry[:relative_path]).gsub(File::SEPARATOR, "/")
      import_path = if Pathname.new(entry_dir).relative_path_from(Pathname.new(stem)).to_s == File.basename(stem)
                      "./#{File.basename(stem)}"
                    elsif Pathname.new(entry_dir).relative_path_from(Pathname.new(stem)).to_s.start_with?(".")
                      Pathname.new(entry_dir).relative_path_from(Pathname.new(stem)).to_s
                    else
                      "./#{Pathname.new(entry_dir).relative_path_from(Pathname.new(stem))}"
                    end
      
      if has_executable_import_reference(entry[:source], import_path) &&
         !has_module_mock_reference(entry[:source], import_path)
        [{ file: entry[:relative_path], match_quality: "direct-import" }]
      elsif entry_dir == normalized_dir && !base_tokens.empty?
        entry_tokens = split_name_tokens(entry[:base_name])
        shared_token = entry_tokens.find { |token| base_tokens.include?(token) }
        if shared_token
          [{ file: entry[:relative_path], match_quality: "dir-token" }]
        else
          []
        end
      else
        []
      end
    end
  end
  
  by_file = {}
  matches.each do |match|
    existing = by_file[match[:file]]
    if !existing || match_quality_rank(match[:match_quality]) < match_quality_rank(existing[:match_quality])
      by_file[match[:file]] = match
    end
  end
  
  by_file.values.sort do |left, right|
    [
      match_quality_rank(left[:match_quality]) <=> match_quality_rank(right[:match_quality]),
      left[:file] <=> right[:file]
    ].find { |result| result != 0 } || 0
  end
end

def determine_seam_test_status(seam_kinds, related_test_matches)
  if related_test_matches.empty?
    return {
      status: "gap",
      reason: "No nearby test file references this seam candidate."
    }
  end
  
  best_match = related_test_matches.first[:match_quality] || "unknown"
  
  high_signal_seams = [
    "reply-delivery-media",
    "streaming-media-handoff",
    "tool-result-media",
    "cron-agent-handoff",
    "cron-outbound-delivery",
    "cron-heartbeat-handoff",
    "cron-scheduler-state",
    "cron-media-delivery",
    "cron-followup-handoff",
    "subagent-session-spawn",
    "subagent-lifecycle-registry",
    "subagent-announce-delivery",
    "subagent-session-cleanup",
    "subagent-parent-stream"
  ]
  
  if seam_kinds.any? { |kind| high_signal_seams.include?(kind) }
    {
      status: "partial",
      reason: "Nearby tests exist (best match: #{best_match}), but this inventory does not prove cross-layer seam coverage end to end."
    }
  else
    {
      status: "heuristic-nearby",
      reason: "Nearby tests exist (best match: #{best_match}), but this remains a filename/path heuristic rather than proof of seam assertions."
    }
  end
end

def build_seam_test_inventory
  production_files = (walk_code_files(SRC_ROOT) + walk_code_files(EXTENSIONS_ROOT))
                     .sort_by { |path| normalize_path(path) }
  
  test_files = (walk_all_code_files(SRC_ROOT, include_tests: true) +
                walk_all_code_files(EXTENSIONS_ROOT, include_tests: true) +
                walk_all_code_files(TEST_ROOT, include_tests: true))
               .select { |file_path| /\.(test|spec)\.(ts|tsx|mts|cts|js|jsx|mjs|cjs)$/ =~ file_path }
               .sort_by { |path| normalize_path(path) }
  
  test_index = build_test_index(test_files)
  inventory = []
  
  production_files.each do |file_path|
    relative_path = normalize_path(file_path)
    source = read_scannable_text(file_path)
    seam_kinds = describe_seam_kinds(relative_path, source)
    next if seam_kinds.empty?
    
    related_test_matches = find_related_tests(relative_path, test_index)
    status = determine_seam_test_status(seam_kinds, related_test_matches)
    
    inventory.push({
      file: relative_path,
      seam_kinds: seam_kinds,
      related_tests: related_test_matches.map { |entry| entry[:file] },
      related_test_matches: related_test_matches,
      status: status[:status],
      reason: status[:reason]
    })
  end
  
  inventory.sort do |left, right|
    [
      left[:status] <=> right[:status],
      left[:file] <=> right[:file],
      left[:seam_kinds].join(",") <=> right[:seam_kinds].join(",")
    ].find { |result| result != 0 } || 0
  end
end

def main(argv = ARGV)
  args = argv.to_set
  
  if args.include?("--help") || args.include?("-h")
    puts HELP_TEXT
    return
  end
  
  collect_workspace_package_paths()
  inventory = collect_core_plugin_sdk_imports()
  optional_cluster_static_leaks = collect_optional_cluster_static_leaks()
  static_leak_clusters = optional_cluster_static_leaks.map { |entry| entry[:cluster] }.to_set
  
  result = {
    duplicated_seam_families: build_duplicated_seam_families(inventory),
    overlap_files: build_overlap_files(inventory),
    optional_cluster_static_leaks: build_optional_cluster_static_leaks(optional_cluster_static_leaks),
    missing_packages: build_missing_packages(static_leak_clusters: static_leak_clusters),
    seam_test_inventory: build_seam_test_inventory()
  }
  
  puts JSON.pretty_generate(result)
end

if __FILE__ == $0
  main()
end

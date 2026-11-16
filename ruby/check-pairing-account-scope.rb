#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "0c1920f538e90f4a9a0c475390765bc72f8496379069a0184ed415adfc024242", "source_sha256": "03602fb41765aad7878e52af85d1c4c5a8d1d8a752b53a46602deb38e8783f73", "target_language": "ruby"}
# check-pairing-account-scope.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-pairing-account-scope.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

require 'pathname'
require_relative 'lib/pairing_guard_context'
require_relative 'lib/ts_guard_utils'

# Create pairing guard context
context = create_pairing_guard_context(__FILE__)
repo_root = context[:repo_root]
source_roots = context[:source_roots]

def is_undefined_like_expression(node)
  if node.type == 'Identifier' && node.text == 'undefined'
    return true
  end
  return node.kind == 'NullKeyword'
end

def has_required_account_id_property(node)
  unless node.type == 'ObjectLiteralExpression'
    return false
  end
  
  node.properties.each do |property|
    if property.type == 'ShorthandPropertyAssignment' && property.name.text == 'accountId'
      return true
    end
    
    next unless property.type == 'PropertyAssignment'
    
    property_name = nil
    if property.name.type == 'Identifier'
      property_name = property.name.text
    elsif property.name.type == 'StringLiteral'
      property_name = property.name.text
    end
    
    next if property_name != 'accountId'
    
    if is_undefined_like_expression(property.initializer)
      return false
    end
    
    return true
  end
  
  return false
end

def find_violations(content, file_path)
  # This would require a TypeScript parser for Ruby, which doesn't exist natively
  # We'll simulate the behavior with basic string parsing since we can't fully replicate
  # the TypeScript AST traversal without a proper parser library
  
  violations = []
  lines = content.split("\n")
  
  lines.each_with_index do |line, index|
    line_num = index + 1
    
    # Check for readChannelAllowFromStore calls with missing accountId
    if line.match(/readChannelAllowFromStore\([^,]*,[^,]*,\s*(undefined|null)/) ||
       line.match(/readChannelAllowFromStore\([^,]*,[^,]*\s*\)/) && !line.match(/readChannelAllowFromStore\([^,]*,[^,]*,[^\)]+\)/)
      
      violations.push({
        line: line_num,
        reason: "readChannelAllowFromStore call must pass explicit accountId as 3rd arg"
      })
    end
    
    # Check for legacy calls
    if line.match(/readLegacyChannelAllowFromStore(Sync)?\(/)
      call_name = line.match(/(readLegacyChannelAllowFromStore(?:Sync)?)/)[1]
      violations.push({
        line: line_num,
        reason: "#{call_name} is legacy-only; use account-scoped readChannelAllowFromStore* APIs"
      })
    end
    
    # Check for upsertChannelPairingRequest calls without accountId
    if line.match(/upsertChannelPairingRequest\(/)
      # This is a simplified check - in reality we'd need to parse the object literal
      # For now, we'll flag any call that doesn't obviously contain accountId
      unless line.match(/upsertChannelPairingRequest\([^}]*accountId[^}]*\)/)
        violations.push({
          line: line_num,
          reason: "upsertChannelPairingRequest call must include accountId in params"
        })
      end
    end
  end
  
  violations
end

def main
  violations = collect_file_violations({
    source_roots: $source_roots,
    repo_root: $repo_root,
    find_violations: method(:find_violations)
  })
  
  if violations.length == 0
    return
  end
  
  puts "Found unscoped pairing-store calls:"
  violations.each do |violation|
    puts "- #{violation[:path]}:#{violation[:line]} (#{violation[:reason]})"
  end
  exit(1)
end

# Set globals for access within methods
$repo_root = repo_root
$source_roots = source_roots

run_as_script(__FILE__, method(:main))

#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "6ff4267f408e2e71cdc5008eac1df5bc2d33c54bb2cc49a4fb3fdecf0f2a2b0f", "source_sha256": "646ce6bf1521c1200f2204aa19a05521f8f53d734ec8c000b61f4290f2a05074", "target_language": "ruby"}
# changelog.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/changelog.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

def normalize_pr_changelog_entries(pr)
  changelog_path = "CHANGELOG.md"
  return unless File.exist?(changelog_path)

  content = File.read(changelog_path)
  lines = content.split("\n")
  pr_pattern = /(?:\(##{pr}\)|openclaw##{pr})/i

  def find_active_section_index(arr)
    arr.index { |line| line.strip == "## Unreleased" }
  end

  def find_section_end(arr, start)
    (start + 1...arr.length).each do |i|
      return i if arr[i] =~ /^## /
    end
    arr.length
  end

  def ensure_active_section(arr)
    active_index = find_active_section_index(arr)
    return active_index if active_index

    insert_at = arr.each_with_index.find { |line, idx| idx > 0 && line =~ /^## / }&.last || arr.length
    block = ["## Unreleased", "", "### Changes", ""]
    block.unshift("") if insert_at > 0 && arr[insert_at - 1] != ""
    arr.insert(insert_at, *block)
    find_active_section_index(arr)
  end

  def context_for(arr, index)
    major = ""
    minor = ""
    index.downto(0) do |i|
      line = arr[i]
      if minor.empty? && line =~ /^### /
        minor = line.strip
      elsif line =~ /^## /
        major = line.strip
        break
      end
    end
    { major: major, minor: minor }
  end

  def ensure_subsection(arr, subsection)
    active_index = ensure_active_section(arr)
    active_end = find_section_end(arr, active_index)
    desired = subsection && subsection =~ /^### / ? subsection : "### Changes"
    
    (active_index + 1...active_end).each do |i|
      return i if arr[i].strip == desired
    end

    insert_at = active_end
    while insert_at > active_index + 1 && arr[insert_at - 1].empty?
      insert_at -= 1
    end
    
    block = ["", desired, ""]
    arr.insert(insert_at, *block)
    insert_at + 1
  end

  def section_tail_insert_index(arr, subsection_index)
    next_heading = arr.length
    (subsection_index + 1...arr.length).each do |i|
      if arr[i] =~ /^### / || arr[i] =~ /^## /
        next_heading = i
        break
      end
    end

    insert_at = next_heading
    while insert_at > subsection_index + 1 && arr[insert_at - 1].empty?
      insert_at -= 1
    end
    insert_at
  end

  ensure_active_section(lines)

  moved = []
  lines.each_with_index do |line, i|
    next unless pr_pattern.match?(line)
    ctx = context_for(lines, i)
    next if ctx[:major] == "## Unreleased"
    moved.push({
      line: line,
      subsection: ctx[:minor].empty? ? "### Changes" : ctx[:minor],
      index: i
    })
  end

  return if moved.empty?

  remove_indexes = moved.map { |entry| entry[:index] }.to_set
  next_lines = lines.reject.with_index { |_, idx| remove_indexes.include?(idx) }

  moved.each do |entry|
    subsection_index = ensure_subsection(next_lines, entry[:subsection])
    insert_at = section_tail_insert_index(next_lines, subsection_index)

    next_heading = next_lines.length
    (subsection_index + 1...next_lines.length).each do |i|
      if next_lines[i] =~ /^### / || next_lines[i] =~ /^## /
        next_heading = i
        break
      end
    end

    already_present = next_lines[subsection_index + 1...next_heading].any? { |line| line == entry[:line] }
    next if already_present

    next_lines.insert(insert_at, entry[:line])
  end

  updated = next_lines.join("\n")
  File.write(changelog_path, updated) if updated != content
end

def validate_changelog_entry_for_pr(pr, contrib)
  diff_output = `git diff --unified=0 origin/main...HEAD -- CHANGELOG.md`
  added_lines = diff_output.lines.grep(/^\+/).map { |line| line[1..-1] }.join("\n")

  if added_lines.empty?
    puts "CHANGELOG.md is in diff but no added lines were detected."
    exit 1
  end

  pr_pattern = "(##{pr}|openclaw##{pr})"
  
  unless added_lines.match?(/#{pr_pattern}/i)
    puts "CHANGELOG.md update must reference PR ##{pr} (for example, (##{pr}))."
    exit 1
  end

  diff_file = "/tmp/changelog_diff_#{Time.now.to_i}_#{$$}"
  File.write(diff_file, diff_output)

  begin
    issue_count = 0
    added = {}
    pr_added_lines = []
    pr_added_text = {}

    # First pass: parse diff to get added lines
    current_line_no = 0
    File.readlines(diff_file).each do |line|
      if line =~ /^@@ /
        if line.match?(/\+[0-9]+/)
          match = line.match(/\+([0-9]+)/)
          current_line_no = match[1].to_i if match
        else
          current_line_no = 0
        end
        next
      end
      
      next if line =~ /^\+\+\+/
      
      if line =~ /^\+/
        if current_line_no > 0
          added[current_line_no] = true
          added_text = line[1..-1]
          if added_text.match?(/#{pr_pattern}/i)
            pr_added_lines << current_line_no
            pr_added_text[current_line_no] = added_text
          end
          current_line_no += 1
        end
        next
      end
      
      next if line =~ /^-/
      
      current_line_no += 1 if current_line_no > 0
    end

    # Second pass: validate positions
    changelog_lines = File.readlines("CHANGELOG.md").map(&:chomp)
    file_line_count = changelog_lines.length

    pr_added_lines.each do |entry_line|
      release_line = 0
      section_line = 0
      
      entry_line.downto(1) do |i|
        line_content = changelog_lines[i-1]
        if section_line == 0 && line_content =~ /^### /
          section_line = i
          next
        end
        if line_content =~ /^## /
          release_line = i
          break
        end
      end

      if release_line == 0 || changelog_lines[release_line-1] != "## Unreleased"
        puts "CHANGELOG.md PR-linked entry must be in ## Unreleased: line #{entry_line}: #{pr_added_text[entry_line]}"
        issue_count += 1
        next
      end
      
      if section_line == 0
        puts "CHANGELOG.md entry must be inside a subsection (### ...): line #{entry_line}: #{pr_added_text[entry_line]}"
        issue_count += 1
        next
      end

      section_name = changelog_lines[section_line-1]
      next_heading = file_line_count + 1
      
      (entry_line+1..file_line_count).each do |i|
        if changelog_lines[i-1] =~ /^### / || changelog_lines[i-1] =~ /^## /
          next_heading = i
          break
        end
      end

      (entry_line+1...next_heading).each do |i|
        line_text = changelog_lines[i-1]
        next if line_text =~ /^[[:space:]]*$/
        next if added.key?(i)
        
        puts "CHANGELOG.md PR-linked entry must be appended at the end of section #{section_name}: line #{entry_line}: #{pr_added_text[entry_line]}"
        puts "Found existing non-added line below it at line #{i}: #{line_text}"
        issue_count += 1
        break
      end
    end

    if issue_count > 0
      puts "Move this PR changelog entry to the end of its section (just before the next heading)."
      exit 1
    end
  ensure
    File.delete(diff_file) if File.exist?(diff_file)
  end

  puts "changelog placement validated: PR-linked entries are appended at section tail"

  if contrib && contrib != "null"
    unless added_lines.match?(/#{pr_pattern}/i) && added_lines.match?(/thanks @#{contrib}/i)
      puts "CHANGELOG.md update must include both PR ##{pr} and thanks @#{contrib} on the changelog entry line."
      exit 1
    end
    puts "changelog validated: found PR ##{pr} + thanks @#{contrib}"
    return
  end

  puts "changelog validated: found PR ##{pr} (contributor handle unavailable, skipping thanks check)"
end

def validate_changelog_merge_hygiene
  diff_output = `git diff --unified=0 origin/main...HEAD -- CHANGELOG.md`
  return if diff_output.empty?

  removed_lines = diff_output.lines.grep(/^-/).map { |line| line[1..-1] }.join("\n")
  return if removed_lines.empty?

  removed_refs = removed_lines.scan(/#[0-9]+/).uniq
  return if removed_refs.empty?

  added_lines = diff_output.lines.grep(/^\+/).map { |line| line[1..-1] }.join("\n")

  removed_refs.each do |ref|
    next if ref.empty?
    unless added_lines.include?(ref)
      puts "CHANGELOG.md drops existing entry reference #{ref} without re-adding it."
      puts "Likely merge conflict loss; restore the dropped entry (or keep the same PR ref in rewritten text)."
      exit 1
    end
  end

  puts "changelog merge hygiene validated: no dropped PR references"
end

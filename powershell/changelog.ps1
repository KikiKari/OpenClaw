#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "a0bee9f02959720ef63fe09351481eafe063a9855b99ad9b0cc9465414c35b8c", "source_sha256": "646ce6bf1521c1200f2204aa19a05521f8f53d734ec8c000b61f4290f2a05074", "target_language": "powershell"}
# changelog.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/changelog.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

function normalize_pr_changelog_entries {
    param(
        [string]$pr
    )
    
    $changelog_path = "CHANGELOG.md"
    
    if (-not (Test-Path $changelog_path)) {
        return
    }
    
    $original = Get-Content -Path $changelog_path -Raw
    $lines = $original -split "`n"
    $prPattern = "(?:\(#$pr\)|openclaw#$pr)"
    
    function findActiveSectionIndex {
        param([array]$arr)
        for ($i = 0; $i -lt $arr.Length; $i++) {
            if ($arr[$i].Trim() -eq "## Unreleased") {
                return $i
            }
        }
        return -1
    }
    
    function findSectionEnd {
        param([array]$arr, [int]$start)
        for ($i = $start + 1; $i -lt $arr.Length; $i++) {
            if ($arr[$i] -match "^## ") {
                return $i
            }
        }
        return $arr.Length
    }
    
    function ensureActiveSection {
        param([array]$arr)
        $activeIndex = findActiveSectionIndex $arr
        if ($activeIndex -ne -1) {
            return $activeIndex
        }
        
        $insertAt = -1
        for ($i = 1; $i -lt $arr.Length; $i++) {
            if ($arr[$i] -match "^## ") {
                $insertAt = $i
                break
            }
        }
        if ($insertAt -eq -1) {
            $insertAt = $arr.Length
        }
        
        $block = @("## Unreleased", "", "### Changes", "")
        if ($insertAt -gt 0 -and $arr[$insertAt - 1] -ne "") {
            $block = @("") + $block
        }
        
        $newArr = @()
        for ($i = 0; $i -lt $insertAt; $i++) {
            $newArr += $arr[$i]
        }
        $newArr += $block
        for ($i = $insertAt; $i -lt $arr.Length; $i++) {
            $newArr += $arr[$i]
        }
        
        # Update global array reference
        for ($i = 0; $i -lt $newArr.Length; $i++) {
            if ($i -lt $arr.Length) {
                $arr[$i] = $newArr[$i]
            } else {
                $arr += $newArr[$i]
            }
        }
        
        return findActiveSectionIndex $arr
    }
    
    function contextFor {
        param([array]$arr, [int]$index)
        $major = ""
        $minor = ""
        for ($i = $index; $i -ge 0; $i--) {
            $line = $arr[$i]
            if (-not $minor -and $line -match "^### ") {
                $minor = $line.Trim()
            }
            if ($line -match "^## ") {
                $major = $line.Trim()
                break
            }
        }
        return @{ major = $major; minor = $minor }
    }
    
    function ensureSubsection {
        param([array]$arr, [string]$subsection)
        $activeIndex = ensureActiveSection $arr
        $activeEnd = findSectionEnd $arr $activeIndex
        $desired = if ($subsection -and $subsection -match "^### ") { $subsection } else { "### Changes" }
        
        for ($i = $activeIndex + 1; $i -lt $activeEnd; $i++) {
            if ($arr[$i].Trim() -eq $desired) {
                return $i
            }
        }
        
        $insertAt = $activeEnd
        while ($insertAt -gt $activeIndex + 1 -and $arr[$insertAt - 1] -eq "") {
            $insertAt--
        }
        
        $block = @("", $desired, "")
        $newArr = @()
        for ($i = 0; $i -lt $insertAt; $i++) {
            $newArr += $arr[$i]
        }
        $newArr += $block
        for ($i = $insertAt; $i -lt $arr.Length; $i++) {
            $newArr += $arr[$i]
        }
        
        # Update global array reference
        $arr.Clear()
        $arr += $newArr
        
        return $insertAt + 1
    }
    
    function sectionTailInsertIndex {
        param([array]$arr, [int]$subsectionIndex)
        $nextHeading = $arr.Length
        for ($i = $subsectionIndex + 1; $i -lt $arr.Length; $i++) {
            if ($arr[$i] -match "^### " -or $arr[$i] -match "^## ") {
                $nextHeading = $i
                break
            }
        }
        
        $insertAt = $nextHeading
        while ($insertAt -gt $subsectionIndex + 1 -and $arr[$insertAt - 1] -eq "") {
            $insertAt--
        }
        return $insertAt
    }
    
    ensureActiveSection $lines
    
    $moved = @()
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -notmatch $prPattern) {
            continue
        }
        $ctx = contextFor $lines $i
        if ($ctx.major -eq "## Unreleased") {
            continue
        }
        $moved += @{
            line = $lines[$i]
            subsection = if ($ctx.minor) { $ctx.minor } else { "### Changes" }
            index = $i
        }
    }
    
    if ($moved.Length -eq 0) {
        return
    }
    
    $removeIndexes = @{}
    foreach ($entry in $moved) {
        $removeIndexes[$entry.index] = $true
    }
    
    $nextLines = @()
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if (-not $removeIndexes.ContainsKey($i)) {
            $nextLines += $lines[$i]
        }
    }
    
    foreach ($entry in $moved) {
        $subsectionIndex = ensureSubsection $nextLines $entry.subsection
        $insertAt = sectionTailInsertIndex $nextLines $subsectionIndex
        
        $nextHeading = $nextLines.Length
        for ($i = $subsectionIndex + 1; $i -lt $nextLines.Length; $i++) {
            if ($nextLines[$i] -match "^### " -or $nextLines[$i] -match "^## ") {
                $nextHeading = $i
                break
            }
        }
        
        $alreadyPresent = $false
        for ($i = $subsectionIndex + 1; $i -lt $nextHeading; $i++) {
            if ($nextLines[$i] -eq $entry.line) {
                $alreadyPresent = $true
                break
            }
        }
        
        if (-not $alreadyPresent) {
            $newLines = @()
            for ($i = 0; $i -lt $insertAt; $i++) {
                $newLines += $nextLines[$i]
            }
            $newLines += $entry.line
            for ($i = $insertAt; $i -lt $nextLines.Length; $i++) {
                $newLines += $nextLines[$i]
            }
            $nextLines = $newLines
        }
    }
    
    $updated = ($nextLines -join "`n") + "`n"
    if ($updated -ne $original) {
        Set-Content -Path $changelog_path -Value $updated
    }
}

function validate_changelog_entry_for_pr {
    param(
        [string]$pr,
        [string]$contrib
    )
    
    $diffOutput = git diff --unified=0 origin/main...HEAD -- CHANGELOG.md
    $added_lines = ($diffOutput | Select-String -Pattern "^(\+\+\+)" -NotMatch) | 
                   Where-Object { $_.Line -match "^\+" } | 
                   ForEach-Object { $_.Line.Substring(1) }
    
    if (-not $added_lines) {
        Write-Error "CHANGELOG.md is in diff but no added lines were detected."
        exit 1
    }
    
    $pr_pattern = "(#$pr|openclaw#$pr)"
    
    $with_pr = $added_lines | Where-Object { $_ -match $pr_pattern }
    if (-not $with_pr) {
        Write-Error "CHANGELOG.md update must reference PR #$pr (for example, (#$pr))."
        exit 1
    }
    
    $diff_file = [System.IO.Path]::GetTempFileName()
    $diffOutput | Out-File -FilePath $diff_file -Encoding UTF8
    
    $awkScript = @"
BEGIN {
  line_no = 0
  file_line_count = 0
  issue_count = 0
}
FNR == NR {
  if (`$0 ~ /^@@ /) {
    if (match(`$0, /\\+[0-9]+/)) {
      line_no = substr(`$0, RSTART + 1, RLENGTH - 1) + 0
    } else {
      line_no = 0
    }
    next
  }
  if (`$0 ~ /^\\+\\+\\+/) {
    next
  }
  if (`$0 ~ /^\\+/) {
    if (line_no > 0) {
      added[line_no] = 1
      added_text = substr(`$0, 2)
      if (added_text ~ /$pr_pattern/) {
        pr_added_lines[++pr_added_count] = line_no
        pr_added_text[line_no] = added_text
      }
      line_no++
    }
    next
  }
  if (`$0 ~ /^-/) {
    next
  }
  if (line_no > 0) {
    line_no++
  }
  next
}
{
  changelog[FNR] = `$0
  file_line_count = FNR
}
END {
  for (idx = 1; idx <= pr_added_count; idx++) {
    entry_line = pr_added_lines[idx]
    release_line = 0
    section_line = 0
    for (i = entry_line; i >= 1; i--) {
      if (section_line == 0 && changelog[i] ~ /^### /) {
        section_line = i
        continue
      }
      if (changelog[i] ~ /^## /) {
        release_line = i
        break
      }
    }
    if (release_line == 0 || changelog[release_line] != "## Unreleased") {
      printf "CHANGELOG.md PR-linked entry must be in ## Unreleased: line %d: %s\\n", entry_line, pr_added_text[entry_line]
      issue_count++
      continue
    }
    if (section_line == 0) {
      printf "CHANGELOG.md entry must be inside a subsection (### ...): line %d: %s\\n", entry_line, pr_added_text[entry_line]
      issue_count++
      continue
    }

    section_name = changelog[section_line]
    next_heading = file_line_count + 1
    for (i = entry_line + 1; i <= file_line_count; i++) {
      if (changelog[i] ~ /^### / || changelog[i] ~ /^## /) {
        next_heading = i
        break
      }
    }

    for (i = entry_line + 1; i < next_heading; i++) {
      line_text = changelog[i]
      if (line_text ~ /^[[:space:]]*\$/) {
        continue
      }
      if (i in added) {
        continue
      }
      printf "CHANGELOG.md PR-linked entry must be appended at the end of section %s: line %d: %s\\n", section_name, entry_line, pr_added_text[entry_line]
      printf "Found existing non-added line below it at line %d: %s\\n", i, line_text
      issue_count++
      break
    }
  }

  if (issue_count > 0) {
    print "Move this PR changelog entry to the end of its section (just before the next heading)."
    exit 1
  }
}
"@
    
    $changelogContent = Get-Content -Path "CHANGELOG.md"
    $result = $awkScript | Out-String | awk -v pr_pattern="$pr_pattern" - "$diff_file" $changelogContent
    
    if ($LASTEXITCODE -ne 0) {
        Remove-Item -Force $diff_file
        exit 1
    }
    
    Remove-Item -Force $diff_file
    Write-Host "changelog placement validated: PR-linked entries are appended at section tail"
    
    if ($contrib -and $contrib -ne "null") {
        $with_pr_and_thanks = $added_lines | Where-Object { $_ -match $pr_pattern -and $_ -match "thanks @$contrib" }
        if (-not $with_pr_and_thanks) {
            Write-Error "CHANGELOG.md update must include both PR #$pr and thanks @$contrib on the changelog entry line."
            exit 1
        }
        Write-Host "changelog validated: found PR #$pr + thanks @$contrib"
        return
    }
    
    Write-Host "changelog validated: found PR #$pr (contributor handle unavailable, skipping thanks check)"
}

function validate_changelog_merge_hygiene {
    $diff = git diff --unified=0 origin/main...HEAD -- CHANGELOG.md
    
    $removed_lines = $diff | Where-Object { $_ -match "^-" -and $_ -notmatch "^---" } | ForEach-Object { $_.Substring(1) }
    if (-not $removed_lines) {
        return
    }
    
    $removed_refs = $removed_lines | Select-String -Pattern '#[0-9]+' -AllMatches | ForEach-Object { $_.Matches.Value } | Sort-Object -Unique
    if (-not $removed_refs) {
        return
    }
    
    $added_lines = $diff | Where-Object { $_ -match "^\+" -and $_ -notmatch "^\+\+\+" } | ForEach-Object { $_.Substring(1) }
    
    foreach ($ref in $removed_refs) {
        if (-not ($added_lines | Where-Object { $_ -match [regex]::Escape($ref) })) {
            Write-Error "CHANGELOG.md drops existing entry reference $ref without re-adding it."
            Write-Error "Likely merge conflict loss; restore the dropped entry (or keep the same PR ref in rewritten text)."
            exit 1
        }
    }
    
    Write-Host "changelog merge hygiene validated: no dropped PR references"
}

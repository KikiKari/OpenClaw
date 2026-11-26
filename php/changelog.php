<?php
// abstraction-provenance: {"artifact_sha256": "6a16dccee4d51356d3d557acc2f00bad1ec70f98cbb9b96bf50620979247d885", "source_sha256": "646ce6bf1521c1200f2204aa19a05521f8f53d734ec8c000b61f4290f2a05074", "target_language": "php"}
// changelog.sh — portiert nach php
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/changelog.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
function normalize_pr_changelog_entries($pr) {
    $changelog_path = "CHANGELOG.md";

    if (!file_exists($changelog_path)) {
        return;
    }

    $original = file_get_contents($changelog_path);
    $lines = explode("\n", $original);
    $prPattern = '/(?:\(#' . preg_quote($pr, '/') . '\)|openclaw#' . preg_quote($pr, '/') . ')/i';

    function findActiveSectionIndex($arr) {
        foreach ($arr as $index => $line) {
            if (trim($line) === "## Unreleased") {
                return $index;
            }
        }
        return -1;
    }

    function findSectionEnd($arr, $start) {
        for ($i = $start + 1; $i < count($arr); $i++) {
            if (preg_match('/^## /', $arr[$i])) {
                return $i;
            }
        }
        return count($arr);
    }

    function ensureActiveSection(&$arr) {
        $activeIndex = findActiveSectionIndex($arr);
        if ($activeIndex !== -1) {
            return $activeIndex;
        }

        $insertAt = -1;
        foreach ($arr as $idx => $line) {
            if ($idx > 0 && preg_match('/^## /', $line)) {
                $insertAt = $idx;
                break;
            }
        }
        if ($insertAt === -1) {
            $insertAt = count($arr);
        }

        $block = ["## Unreleased", "", "### Changes", ""];
        if ($insertAt > 0 && $arr[$insertAt - 1] !== "") {
            array_unshift($block, "");
        }
        array_splice($arr, $insertAt, 0, $block);
        return findActiveSectionIndex($arr);
    }

    function contextFor($arr, $index) {
        $major = "";
        $minor = "";
        for ($i = $index; $i >= 0; $i--) {
            $line = $arr[$i];
            if (!$minor && preg_match('/^### /', $line)) {
                $minor = trim($line);
            }
            if (preg_match('/^## /', $line)) {
                $major = trim($line);
                break;
            }
        }
        return ['major' => $major, 'minor' => $minor];
    }

    function ensureSubsection(&$arr, $subsection) {
        $activeIndex = ensureActiveSection($arr);
        $activeEnd = findSectionEnd($arr, $activeIndex);
        $desired = $subsection && preg_match('/^### /', $subsection) ? $subsection : "### Changes";
        for ($i = $activeIndex + 1; $i < $activeEnd; $i++) {
            if (trim($arr[$i]) === $desired) {
                return $i;
            }
        }

        $insertAt = $activeEnd;
        while ($insertAt > $activeIndex + 1 && $arr[$insertAt - 1] === "") {
            $insertAt--;
        }
        $block = ["", $desired, ""];
        array_splice($arr, $insertAt, 0, $block);
        return $insertAt + 1;
    }

    function sectionTailInsertIndex($arr, $subsectionIndex) {
        $nextHeading = count($arr);
        for ($i = $subsectionIndex + 1; $i < count($arr); $i++) {
            if (preg_match('/^### /', $arr[$i]) || preg_match('/^## /', $arr[$i])) {
                $nextHeading = $i;
                break;
            }
        }

        $insertAt = $nextHeading;
        while ($insertAt > $subsectionIndex + 1 && $arr[$insertAt - 1] === "") {
            $insertAt--;
        }
        return $insertAt;
    }

    ensureActiveSection($lines);

    $moved = [];
    for ($i = 0; $i < count($lines); $i++) {
        if (!preg_match($prPattern, $lines[$i])) {
            continue;
        }
        $ctx = contextFor($lines, $i);
        if ($ctx['major'] === "## Unreleased") {
            continue;
        }
        $moved[] = [
            'line' => $lines[$i],
            'subsection' => $ctx['minor'] ?: "### Changes",
            'index' => $i,
        ];
    }

    if (count($moved) === 0) {
        return;
    }

    $removeIndexes = [];
    foreach ($moved as $entry) {
        $removeIndexes[$entry['index']] = true;
    }
    $nextLines = [];
    foreach ($lines as $idx => $line) {
        if (!isset($removeIndexes[$idx])) {
            $nextLines[] = $line;
        }
    }

    foreach ($moved as $entry) {
        $subsectionIndex = ensureSubsection($nextLines, $entry['subsection']);
        $insertAt = sectionTailInsertIndex($nextLines, $subsectionIndex);

        $nextHeading = count($nextLines);
        for ($i = $subsectionIndex + 1; $i < count($nextLines); $i++) {
            if (preg_match('/^### /', $nextLines[$i]) || preg_match('/^## /', $nextLines[$i])) {
                $nextHeading = $i;
                break;
            }
        }

        $alreadyPresent = false;
        for ($j = $subsectionIndex + 1; $j < $nextHeading; $j++) {
            if (isset($nextLines[$j]) && $nextLines[$j] === $entry['line']) {
                $alreadyPresent = true;
                break;
            }
        }
        if ($alreadyPresent) {
            continue;
        }
        array_splice($nextLines, $insertAt, 0, [$entry['line']]);
    }

    $updated = implode("\n", $nextLines);
    if ($updated !== $original) {
        file_put_contents($changelog_path, $updated);
    }
}

function validate_changelog_entry_for_pr($pr, $contrib) {
    $output = [];
    exec('git diff --unified=0 origin/main...HEAD -- CHANGELOG.md', $output);
    $added_lines = '';
    foreach ($output as $line) {
        if (strpos($line, '+++') === 0) {
            continue;
        }
        if (strpos($line, '+') === 0) {
            $added_lines .= substr($line, 1) . "\n";
        }
    }

    if (empty(trim($added_lines))) {
        fwrite(STDERR, "CHANGELOG.md is in diff but no added lines were detected.\n");
        exit(1);
    }

    $pr_pattern = '(#' . $pr . '|openclaw#' . $pr . ')';
    $pattern_found = false;
    $lines = explode("\n", $added_lines);
    foreach ($lines as $line) {
        if (preg_match('/' . $pr_pattern . '/i', $line)) {
            $pattern_found = true;
            break;
        }
    }

    if (!$pattern_found) {
        fwrite(STDERR, "CHANGELOG.md update must reference PR #$pr (for example, (#$pr)).\n");
        exit(1);
    }

    $tmpfname = tempnam(sys_get_temp_dir(), 'changelog_diff');
    file_put_contents($tmpfname, implode("\n", $output));

    $awk_script = '
BEGIN {
  line_no = 0
  file_line_count = 0
  issue_count = 0
}
FNR == NR {
  if ($0 ~ /^@@ /) {
    if (match($0, /\+[0-9]+/)) {
      line_no = substr($0, RSTART + 1, RLENGTH - 1) + 0
    } else {
      line_no = 0
    }
    next
  }
  if ($0 ~ /^\+\+\+/) {
    next
  }
  if ($0 ~ /^\+/) {
    if (line_no > 0) {
      added[line_no] = 1
      added_text = substr($0, 2)
      if (added_text ~ pr_pattern) {
        pr_added_lines[++pr_added_count] = line_no
        pr_added_text[line_no] = added_text
      }
      line_no++
    }
    next
  }
  if ($0 ~ /^-/) {
    next
  }
  if (line_no > 0) {
    line_no++
  }
  next
}
{
  changelog[FNR] = $0
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
      printf "CHANGELOG.md PR-linked entry must be in ## Unreleased: line %d: %s\n", entry_line, pr_added_text[entry_line]
      issue_count++
      continue
    }
    if (section_line == 0) {
      printf "CHANGELOG.md entry must be inside a subsection (### ...): line %d: %s\n", entry_line, pr_added_text[entry_line]
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
      if (line_text ~ /^[[:space:]]*$/) {
        continue
      }
      if (i in added) {
        continue
      }
      printf "CHANGELOG.md PR-linked entry must be appended at the end of section %s: line %d: %s\n", section_name, entry_line, pr_added_text[entry_line]
      printf "Found existing non-added line below it at line %d: %s\n", i, line_text
      issue_count++
      break
    }
  }

  if (issue_count > 0) {
    print "Move this PR changelog entry to the end of its section (just before the next heading)."
    exit 1
  }
}
';
    $result = 0;
    exec("awk -v pr_pattern='$pr_pattern' '$awk_script' " . escapeshellarg($tmpfname) . " CHANGELOG.md", $output, $result);
    unlink($tmpfname);

    if ($result !== 0) {
        exit(1);
    }

    echo "changelog placement validated: PR-linked entries are appended at section tail\n";

    if (!empty($contrib) && $contrib !== "null") {
        $pattern_and_thanks_found = false;
        $lines = explode("\n", $added_lines);
        foreach ($lines as $line) {
            if (preg_match('/' . $pr_pattern . '/i', $line) && stripos($line, "thanks @$contrib") !== false) {
                $pattern_and_thanks_found = true;
                break;
            }
        }

        if (!$pattern_and_thanks_found) {
            fwrite(STDERR, "CHANGELOG.md update must include both PR #$pr and thanks @$contrib on the changelog entry line.\n");
            exit(1);
        }
        echo "changelog validated: found PR #$pr + thanks @$contrib\n";
        return;
    }

    echo "changelog validated: found PR #$pr (contributor handle unavailable, skipping thanks check)\n";
}

function validate_changelog_merge_hygiene() {
    $output = [];
    exec('git diff --unified=0 origin/main...HEAD -- CHANGELOG.md', $output);
    $diff = implode("\n", $output);

    $removed_lines = '';
    $diff_lines = explode("\n", $diff);
    foreach ($diff_lines as $line) {
        if (strpos($line, '---') === 0) {
            continue;
        }
        if (strpos($line, '-') === 0) {
            $removed_lines .= substr($line, 1) . "\n";
        }
    }

    if (empty(trim($removed_lines))) {
        return;
    }

    preg_match_all('/#[0-9]+/', $removed_lines, $matches);
    $removed_refs = array_unique($matches[0]);
    if (empty($removed_refs)) {
        return;
    }

    $added_lines = '';
    foreach ($diff_lines as $line) {
        if (strpos($line, '+++') === 0) {
            continue;
        }
        if (strpos($line, '+') === 0) {
            $added_lines .= substr($line, 1) . "\n";
        }
    }

    foreach ($removed_refs as $ref) {
        if (empty($ref)) {
            continue;
        }
        if (strpos($added_lines, $ref) === false) {
            fwrite(STDERR, "CHANGELOG.md drops existing entry reference $ref without re-adding it.\n");
            fwrite(STDERR, "Likely merge conflict loss; restore the dropped entry (or keep the same PR ref in rewritten text).\n");
            exit(1);
        }
    }

    echo "changelog merge hygiene validated: no dropped PR references\n";
}

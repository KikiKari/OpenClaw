// abstraction-provenance: {"artifact_sha256": "30c8d95c9b063b96cb72f04aaa03393077f03353368223d89db91f7629c01e6b", "source_sha256": "646ce6bf1521c1200f2204aa19a05521f8f53d734ec8c000b61f4290f2a05074", "target_language": "fsharp"}
// changelog.sh — portiert nach fsharp
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/changelog.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

open System
open System.IO
open System.Text.RegularExpressions
open System.Diagnostics

let normalizePrChangelogEntries (pr: string) =
    let changelogPath = "CHANGELOG.md"
    
    if not (File.Exists(changelogPath)) then
        0
    else
        let original = File.ReadAllText(changelogPath)
        let lines = original.Split('\n') |> Array.toList
        
        // Create temporary JavaScript file
        let jsCode = $"""
const fs = require("node:fs");

const pr = "{pr}";
const path = "CHANGELOG.md";
const original = fs.readFileSync(path, "utf8");
const lines = original.split("\\n");
const prPattern = new RegExp(`(?:\\\\(#${{pr}}\\\\)|openclaw#${{pr}})`, "i");

function findActiveSectionIndex(arr) {{
  return arr.findIndex((line) => line.trim() === "## Unreleased");
}}

function findSectionEnd(arr, start) {{
  for (let i = start + 1; i < arr.length; i += 1) {{
    if (/^## /.test(arr[i])) {{
      return i;
    }}
  }}
  return arr.length;
}}

function ensureActiveSection(arr) {{
  let activeIndex = findActiveSectionIndex(arr);
  if (activeIndex !== -1) {{
    return activeIndex;
  }}

  let insertAt = arr.findIndex((line, idx) => idx > 0 && /^## /.test(line));
  if (insertAt === -1) {{
    insertAt = arr.length;
  }}

  const block = ["## Unreleased", "", "### Changes", ""];
  if (insertAt > 0 && arr[insertAt - 1] !== "") {{
    block.unshift("");
  }}
  arr.splice(insertAt, 0, ...block);
  return findActiveSectionIndex(arr);
}}

function contextFor(arr, index) {{
  let major = "";
  let minor = "";
  for (let i = index; i >= 0; i -= 1) {{
    const line = arr[i];
    if (!minor && /^### /.test(line)) {{
      minor = line.trim();
    }}
    if (/^## /.test(line)) {{
      major = line.trim();
      break;
    }}
  }}
  return {{ major, minor }};
}}

function ensureSubsection(arr, subsection) {{
  const activeIndex = ensureActiveSection(arr);
  const activeEnd = findSectionEnd(arr, activeIndex);
  const desired = subsection && /^### /.test(subsection) ? subsection : "### Changes";
  for (let i = activeIndex + 1; i < activeEnd; i += 1) {{
    if (arr[i].trim() === desired) {{
      return i;
    }}
  }}

  let insertAt = activeEnd;
  while (insertAt > activeIndex + 1 && arr[insertAt - 1] === "") {{
    insertAt -= 1;
  }}
  const block = ["", desired, ""];
  arr.splice(insertAt, 0, ...block);
  return insertAt + 1;
}}

function sectionTailInsertIndex(arr, subsectionIndex) {{
  let nextHeading = arr.length;
  for (let i = subsectionIndex + 1; i < arr.length; i += 1) {{
    if (/^### /.test(arr[i]) || /^## /.test(arr[i])) {{
      nextHeading = i;
      break;
    }}
  }}

  let insertAt = nextHeading;
  while (insertAt > subsectionIndex + 1 && arr[insertAt - 1] === "") {{
    insertAt -= 1;
  }}
  return insertAt;
}}

ensureActiveSection(lines);

const moved = [];
for (let i = 0; i < lines.length; i += 1) {{
  if (!prPattern.test(lines[i])) {{
    continue;
  }}
  const ctx = contextFor(lines, i);
  if (ctx.major === "## Unreleased") {{
    continue;
  }}
  moved.push({{
    line: lines[i],
    subsection: ctx.minor || "### Changes",
    index: i,
  }});
}}

if (moved.length === 0) {{
  process.exit(0);
}}

const removeIndexes = new Set(moved.map((entry) => entry.index));
const nextLines = lines.filter((_, idx) => !removeIndexes.has(idx));

for (const entry of moved) {{
  const subsectionIndex = ensureSubsection(nextLines, entry.subsection);
  const insertAt = sectionTailInsertIndex(nextLines, subsectionIndex);

  let nextHeading = nextLines.length;
  for (let i = subsectionIndex + 1; i < nextLines.length; i += 1) {{
    if (/^### /.test(nextLines[i]) || /^## /.test(nextLines[i])) {{
      nextHeading = i;
      break;
    }}
  }}

  const alreadyPresent = nextLines
    .slice(subsectionIndex + 1, nextHeading)
    .some((line) => line === entry.line);
  if (alreadyPresent) {{
    continue;
  }}
  nextLines.splice(insertAt, 0, entry.line);
}}

const updated = nextLines.join("\\n");
if (updated !== original) {{
  fs.writeFileSync(path, updated);
}}
"""
        
        let tempJsFile = Path.GetTempFileName() + ".js"
        File.WriteAllText(tempJsFile, jsCode)
        
        try
            let startInfo = ProcessStartInfo(
                FileName = "node",
                Arguments = $"\"{tempJsFile}\"",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            )
            
            use proc = Process.Start(startInfo)
            proc.WaitForExit()
            proc.ExitCode
        finally
            if File.Exists(tempJsFile) then
                File.Delete(tempJsFile)

let validateChangelogEntryForPr (pr: string) (contrib: string) =
    let psi = ProcessStartInfo(
        FileName = "git",
        Arguments = "diff --unified=0 origin/main...HEAD -- CHANGELOG.md",
        UseShellExecute = false,
        RedirectStandardOutput = true
    )
    
    use proc = Process.Start(psi)
    let diffOutput = proc.StandardOutput.ReadToEnd()
    proc.WaitForExit()
    
    let addedLines = 
        diffOutput.Split('\n')
        |> Array.filter (fun line -> line.StartsWith("+++"))
        |> Array.skip 1
        |> Array.filter (fun line -> line.StartsWith("+"))
        |> Array.map (fun line -> line.Substring(1))
        |> String.concat "\n"
    
    if String.IsNullOrWhiteSpace(addedLines) then
        Console.WriteLine("CHANGELOG.md is in diff but no added lines were detected.")
        Environment.Exit(1)
    
    let prPattern = $"(#{pr}|openclaw#{pr})"
    
    let withPr = 
        try
            let psiRg = ProcessStartInfo(
                FileName = "rg",
                Arguments = $"-in \"{prPattern}\"",
                UseShellExecute = false,
                RedirectStandardInput = true,
                RedirectStandardOutput = true
            )
            
            use procRg = Process.Start(psiRg)
            procRg.StandardInput.Write(addedLines)
            procRg.StandardInput.Close()
            let output = procRg.StandardOutput.ReadToEnd()
            procRg.WaitForExit()
            output.Trim()
        with _ -> ""
    
    if String.IsNullOrWhiteSpace(withPr) then
        Console.WriteLine($"CHANGELOG.md update must reference PR #{pr} (for example, (#{pr})).")
        Environment.Exit(1)
    
    let tempDiffFile = Path.GetTempFileName()
    File.WriteAllText(tempDiffFile, diffOutput)
    
    let awkScript = $@"
BEGIN {{
  line_no = 0
  file_line_count = 0
  issue_count = 0
}}
FNR == NR {{
  if ($0 ~ /^@@ /) {{
    if (match($0, /\\+[0-9]+/)) {{
      line_no = substr($0, RSTART + 1, RLENGTH - 1) + 0
    }} else {{
      line_no = 0
    }}
    next
  }}
  if ($0 ~ /^\\+\\+\\+/) {{
    next
  }}
  if ($0 ~ /^\\+/) {{
    if (line_no > 0) {{
      added[line_no] = 1
      added_text = substr($0, 2)
      if (added_text ~ pr_pattern) {{
        pr_added_lines[++pr_added_count] = line_no
        pr_added_text[line_no] = added_text
      }}
      line_no++
    }}
    next
  }}
  if ($0 ~ /^-/) {{
    next
  }}
  if (line_no > 0) {{
    line_no++
  }}
  next
}}
{{
  changelog[FNR] = $0
  file_line_count = FNR
}}
END {{
  for (idx = 1; idx <= pr_added_count; idx++) {{
    entry_line = pr_added_lines[idx]
    release_line = 0
    section_line = 0
    for (i = entry_line; i >= 1; i--) {{
      if (section_line == 0 && changelog[i] ~ /^### /) {{
        section_line = i
        continue
      }}
      if (changelog[i] ~ /^## /) {{
        release_line = i
        break
      }}
    }}
    if (release_line == 0 || changelog[release_line] != ""## Unreleased"") {{
      printf ""CHANGELOG.md PR-linked entry must be in ## Unreleased: line %d: %s\\n"", entry_line, pr_added_text[entry_line]
      issue_count++
      continue
    }}
    if (section_line == 0) {{
      printf ""CHANGELOG.md entry must be inside a subsection (### ...): line %d: %s\\n"", entry_line, pr_added_text[entry_line]
      issue_count++
      continue
    }}

    section_name = changelog[section_line]
    next_heading = file_line_count + 1
    for (i = entry_line + 1; i <= file_line_count; i++) {{
      if (changelog[i] ~ /^### / || changelog[i] ~ /^## /) {{
        next_heading = i
        break
      }}
    }}

    for (i = entry_line + 1; i < next_heading; i++) {{
      line_text = changelog[i]
      if (line_text ~ /^[[:space:]]*$/) {{
        continue
      }}
      if (i in added) {{
        continue
      }}
      printf ""CHANGELOG.md PR-linked entry must be appended at the end of section %s: line %d: %s\\n"", section_name, entry_line, pr_added_text[entry_line]
      printf ""Found existing non-added line below it at line %d: %s\\n"", i, line_text
      issue_count++
      break
    }}
  }}

  if (issue_count > 0) {{
    print ""Move this PR changelog entry to the end of its section (just before the next heading).""
    exit 1
  }}
}}
"
    
    let psiAwk = ProcessStartInfo(
        FileName = "awk",
        Arguments = $"-v pr_pattern=\"{prPattern}\" -f - CHANGELOG.md",
        UseShellExecute = false,
        RedirectStandardInput = true
    )
    
    use procAwk = Process.Start(psiAwk)
    procAwk.StandardInput.Write(awkScript)
    procAwk.StandardInput.Close()
    let exitCode = procAwk.WaitForExit()
    
    File.Delete(tempDiffFile)
    
    if not exitCode then
        Environment.Exit(1)
    
    Console.WriteLine("changelog placement validated: PR-linked entries are appended at section tail")
    
    if not (String.IsNullOrEmpty(contrib)) && contrib <> "null" then
        let withPrAndThanks = 
            try
                let psiRg1 = ProcessStartInfo(
                    FileName = "rg",
                    Arguments = $"-in \"{prPattern}\"",
                    UseShellExecute = false,
                    RedirectStandardInput = true,
                    RedirectStandardOutput = true
                )
                
                use procRg1 = Process.Start(psiRg1)
                procRg1.StandardInput.Write(addedLines)
                procRg1.StandardInput.Close()
                let output1 = procRg1.StandardOutput.ReadToEnd()
                procRg1.WaitForExit()
                
                let psiRg2 = ProcessStartInfo(
                    FileName = "rg",
                    Arguments = "-i \"thanks @" + contrib + "\"",
                    UseShellExecute = false,
                    RedirectStandardInput = true,
                    RedirectStandardOutput = true
                )
                
                use procRg2 = Process.Start(psiRg2)
                procRg2.StandardInput.Write(output1)
                procRg2.StandardInput.Close()
                let output2 = procRg2.StandardOutput.ReadToEnd()
                procRg2.WaitForExit()
                output2.Trim()
            with _ -> ""
        
        if String.IsNullOrWhiteSpace(withPrAndThanks) then
            Console.WriteLine($"CHANGELOG.md update must include both PR #{pr} and thanks @{contrib} on the changelog entry line.")
            Environment.Exit(1)
        
        Console.WriteLine($"changelog validated: found PR #{pr} + thanks @{contrib}")
        0
    else
        Console.WriteLine($"changelog validated: found PR #{pr} (contributor handle unavailable, skipping thanks check)")
        0

let validateChangelogMergeHygiene () =
    let psi = ProcessStartInfo(
        FileName = "git",
        Arguments = "diff --unified=0 origin/main...HEAD -- CHANGELOG.md",
        UseShellExecute = false,
        RedirectStandardOutput = true
    )
    
    use proc = Process.Start(psi)
    let diffOutput = proc.StandardOutput.ReadToEnd()
    proc.WaitForExit()
    
    let removedLines = 
        diffOutput.Split('\n')
        |> Array.filter (fun line -> not (line.StartsWith("---")))
        |> Array.filter (fun line -> line.StartsWith("-"))
        |> Array.map (fun line -> line.Substring(1))
        |> String.concat "\n"
    
    if String.IsNullOrWhiteSpace(removedLines) then
        0
    else
        let removedRefs = 
            try
                let psiRg = ProcessStartInfo(
                    FileName = "rg",
                    Arguments = "-o \"#[0-9]+\"",
                    UseShellExecute = false,
                    RedirectStandardInput = true,
                    RedirectStandardOutput = true
                )
                
                use procRg = Process.Start(psiRg)
                procRg.StandardInput.Write(removedLines)
                procRg.StandardInput.Close()
                let output = procRg.StandardOutput.ReadToEnd()
                procRg.WaitForExit()
                
                output.Split('\n', StringSplitOptions.RemoveEmptyEntries)
                |> Array.distinct
                |> Array.sort
            with _ -> [||]
        
        if removedRefs.Length = 0 then
            0
        else
            let addedLines = 
                diffOutput.Split('\n')
                |> Array.filter (fun line -> not (line.StartsWith("+++")))
                |> Array.filter (fun line -> line.StartsWith("+"))
                |> Array.map (fun line -> line.Substring(1))
                |> String.concat "\n"
            
            for ref in removedRefs do
                if not (addedLines.Contains(ref)) then
                    Console.WriteLine($"CHANGELOG.md drops existing entry reference {ref} without re-adding it.")
                    Console.WriteLine("Likely merge conflict loss; restore the dropped entry (or keep the same PR ref in rewritten text).")
                    Environment.Exit(1)
            
            Console.WriteLine("changelog merge hygiene validated: no dropped PR references")
            0

#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "ba84aa1ccac6f70ce04f1fa44efad714221463cf8d070d4037838fbdf5130200", "source_sha256": "24e3cb1dc8d717f90272134987f4b84a5137f1d8cacace1c6ccd6621b24e9566", "target_language": "powershell"}
# review.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/review.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

function Set-ReviewMode {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Mode
    )
    
    # Security: shell-escape values to prevent command injection when sourced.
    $content = @"
REVIEW_MODE=$Mode
REVIEW_MODE_SET_AT=$([System.DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ"))
"@
    $content | Out-File -FilePath ".local/review-mode.env" -Encoding utf8
}

function Review-Claim {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Pr
    )
    
    $root = RepoRoot
    Set-Location $root
    if (!(Test-Path ".local")) {
        New-Item -ItemType Directory -Path ".local" | Out-Null
    }
    
    $reviewer = ""
    $maxAttempts = 3
    
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        $userLog = ".local/review-claim-user-attempt-$attempt.log"
        
        try {
            $reviewer = gh api user --jq .login 2>$userLog
            if ($LASTEXITCODE -eq 0) {
                $reviewer | Out-File -FilePath $userLog -Encoding utf8
                break
            }
        } catch {}
        
        Write-Host "Claim reviewer lookup failed (attempt $attempt/$maxAttempts)."
        Print-RelevantLogExcerpt $userLog
        
        if ($attempt -lt $maxAttempts) {
            Start-Sleep -Seconds 2
        }
    }
    
    if ([string]::IsNullOrEmpty($reviewer)) {
        Write-Host "Failed to resolve reviewer login after $maxAttempts attempts."
        return 1
    }
    
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        $claimLog = ".local/review-claim-assignee-attempt-$attempt.log"
        
        try {
            $output = gh pr edit $Pr --add-assignee $reviewer 2>&1 >$claimLog
            if ($LASTEXITCODE -eq 0) {
                Write-Host "review claim succeeded: @$reviewer assigned to PR #$Pr"
                return 0
            }
        } catch {}
        
        Write-Host "Claim assignee update failed (attempt $attempt/$maxAttempts)."
        Print-RelevantLogExcerpt $claimLog
        
        if ($attempt -lt $maxAttempts) {
            Start-Sleep -Seconds 2
        }
    }
    
    Write-Host "Failed to assign @$reviewer to PR #$Pr after $maxAttempts attempts."
    return 1
}

function Review-CheckoutMain {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Pr
    )
    
    EnterWorktree $Pr $false
    git fetch origin main
    git checkout --detach origin/main
    Set-ReviewMode "main"
    
    Write-Host "review mode set to main baseline"
    Write-Host "branch=$(git branch --show-current)"
    Write-Host "head=$(git rev-parse --short HEAD)"
}

function Review-CheckoutPr {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Pr
    )
    
    EnterWorktree $Pr $false
    git fetch origin "pull/$Pr/head:pr-$Pr" --force
    git checkout --detach "pr-$Pr"
    Set-ReviewMode "pr"
    
    Write-Host "review mode set to PR head"
    Write-Host "branch=$(git branch --show-current)"
    Write-Host "head=$(git rev-parse --short HEAD)"
}

function Review-Guard {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Pr
    )
    
    EnterWorktree $Pr $false
    RequireArtifact ".local/review-mode.env"
    RequireArtifact ".local/pr-meta.env"
    
    . .local/review-mode.env
    . .local/pr-meta.env
    
    $branch = git branch --show-current
    $headSha = git rev-parse HEAD
    
    switch ($REVIEW_MODE) {
        "main" {
            $expectedMainSha = git rev-parse origin/main
            if ($headSha -ne $expectedMainSha) {
                Write-Host "Review guard failed: expected HEAD at origin/main ($expectedMainSha) for main baseline mode, got $headSha"
                exit 1
            }
        }
        "pr" {
            if ([string]::IsNullOrEmpty($PR_HEAD_SHA)) {
                Write-Host "Review guard failed: missing PR_HEAD_SHA in .local/pr-meta.env"
                exit 1
            }
            if ($headSha -ne $PR_HEAD_SHA) {
                Write-Host "Review guard failed: expected HEAD at PR_HEAD_SHA ($PR_HEAD_SHA), got $headSha"
                exit 1
            }
        }
        default {
            Write-Host "Review guard failed: unknown review mode '$REVIEW_MODE'"
            exit 1
        }
    }
    
    Write-Host "review guard passed"
    Write-Host "mode=$REVIEW_MODE"
    Write-Host "branch=$branch"
    Write-Host "head=$headSha"
}

function Review-ArtifactsInit {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Pr
    )
    
    EnterWorktree $Pr $false
    RequireArtifact ".local/pr-meta.env"
    
    if (!(Test-Path ".local/review.md")) {
        $mdContent = @"
A) TL;DR recommendation

B) What changed and what is good?

C) Security findings

D) What is the PR intent? Is this the most optimal implementation?

E) Concerns or questions (actionable)

F) Tests

G) Docs status

H) Changelog

I) Follow ups (optional)

J) Suggested PR comment (optional)
"@
        $mdContent | Out-File -FilePath ".local/review.md" -Encoding utf8
    }
    
    if (!(Test-Path ".local/review.json")) {
        $jsonContent = @"
{
  "recommendation": "NEEDS WORK",
  "findings": [],
  "nitSweep": {
    "performed": true,
    "status": "none",
    "summary": "No optional nits identified."
  },
  "behavioralSweep": {
    "performed": true,
    "status": "not_applicable",
    "summary": "No runtime branch-level behavior changes require sweep evidence.",
    "silentDropRisk": "none",
    "branches": []
  },
  "issueValidation": {
    "performed": true,
    "source": "pr_body",
    "status": "unclear",
    "summary": "Review not completed yet."
  },
  "tests": {
    "ran": [],
    "gaps": [],
    "result": "pass"
  },
  "docs": "not_applicable",
  "changelog": "not_required"
}
"@
        $jsonContent | Out-File -FilePath ".local/review.json" -Encoding utf8
    }
    
    Write-Host "review artifact templates are ready"
    Write-Host "files=.local/review.md .local/review.json"
}

function Review-ValidateArtifacts {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Pr
    )
    
    EnterWorktree $Pr $false
    RequireArtifact ".local/review.md"
    RequireArtifact ".local/review.json"
    RequireArtifact ".local/pr-meta.env"
    RequireArtifact ".local/pr-meta.json"
    
    Review-Guard $Pr
    
    jq . .local/review.json > $null
    if ($LASTEXITCODE -ne 0) {
        exit 1
    }
    
    $sections = @("A)", "B)", "C)", "D)", "E)", "F)", "G)", "H)", "I)", "J)")
    foreach ($section in $sections) {
        $found = Select-String -Path ".local/review.md" -Pattern "^$section" -Quiet
        if (-not $found) {
            Write-Host "Missing section header in .local/review.md: $section"
            exit 1
        }
    }
    
    $recommendation = jq -r '.recommendation // ""' .local/review.json
    switch ($recommendation) {
        "READY FOR /prepare-pr" {}
        "NEEDS WORK" {}
        "NEEDS DISCUSSION" {}
        "NOT USEFUL (CLOSE)" {}
        default {
            Write-Host "Invalid recommendation in .local/review.json: $recommendation"
            exit 1
        }
    }
    
    $invalidSeverityCount = jq '[.findings[]? | select((.severity // "") != "BLOCKER" and (.severity // "") != "IMPORTANT" and (.severity // "") != "NIT")] | length' .local/review.json
    if ([int]$invalidSeverityCount -gt 0) {
        Write-Host "Invalid finding severity in .local/review.json"
        exit 1
    }
    
    $invalidFindingsCount = jq '[.findings[]? | select((.id|type)!="string" or (.title|type)!="string" or (.area|type)!="string" or (.fix|type)!="string")] | length' .local/review.json
    if ([int]$invalidFindingsCount -gt 0) {
        Write-Host "Invalid finding shape in .local/review.json (id/title/area/fix must be strings)"
        exit 1
    }
    
    $nitFindingsCount = jq '[.findings[]? | select((.severity // "") == "NIT")] | length' .local/review.json
    
    $nitSweepPerformed = jq -r '.nitSweep.performed // empty' .local/review.json
    if ($nitSweepPerformed -ne "true") {
        Write-Host "Invalid nit sweep in .local/review.json: nitSweep.performed must be true"
        exit 1
    }
    
    $nitSweepStatus = jq -r '.nitSweep.status // ""' .local/review.json
    switch ($nitSweepStatus) {
        "none" {
            if ([int]$nitFindingsCount -gt 0) {
                Write-Host "Invalid nit sweep in .local/review.json: nitSweep.status is none but NIT findings exist"
                exit 1
            }
        }
        "has_nits" {
            if ([int]$nitFindingsCount -lt 1) {
                Write-Host "Invalid nit sweep in .local/review.json: nitSweep.status is has_nits but no NIT findings exist"
                exit 1
            }
        }
        default {
            Write-Host "Invalid nit sweep status in .local/review.json: $nitSweepStatus"
            exit 1
        }
    }
    
    $invalidNitSummaryCount = jq '[.nitSweep.summary | select((type != "string") or (gsub("^\\s+|\\s+$";"") | length == 0))] | length' .local/review.json
    if ([int]$invalidNitSummaryCount -gt 0) {
        Write-Host "Invalid nit sweep summary in .local/review.json: nitSweep.summary must be a non-empty string"
        exit 1
    }
    
    $issueValidationPerformed = jq -r '.issueValidation.performed // empty' .local/review.json
    if ($issueValidationPerformed -ne "true") {
        Write-Host "Invalid issue validation in .local/review.json: issueValidation.performed must be true"
        exit 1
    }
    
    $issueValidationSource = jq -r '.issueValidation.source // ""' .local/review.json
    switch ($issueValidationSource) {
        "linked_issue" {}
        "pr_body" {}
        "both" {}
        default {
            Write-Host "Invalid issue validation source in .local/review.json: $issueValidationSource"
            exit 1
        }
    }
    
    $issueValidationStatus = jq -r '.issueValidation.status // ""' .local/review.json
    switch ($issueValidationStatus) {
        "valid" {}
        "unclear" {}
        "invalid" {}
        "already_fixed_on_main" {}
        default {
            Write-Host "Invalid issue validation status in .local/review.json: $issueValidationStatus"
            exit 1
        }
    }
    
    $invalidIssueSummaryCount = jq '[.issueValidation.summary | select((type != "string") or (gsub("^\\s+|\\s+$";"") | length == 0))] | length' .local/review.json
    if ([int]$invalidIssueSummaryCount -gt 0) {
        Write-Host "Invalid issue validation summary in .local/review.json: issueValidation.summary must be a non-empty string"
        exit 1
    }
    
    $runtimeFileCount = jq '[.files[]? | (.path // "") | select(test("^(src|extensions|apps)/")) | select(test("(^|/)__tests__/|\\.test\\.|\\.spec\\.") | not) | select(test("\\.(md|mdx)$") | not)] | length' .local/pr-meta.json
    
    $runtimeReviewRequired = "false"
    if ([int]$runtimeFileCount -gt 0) {
        $runtimeReviewRequired = "true"
    }
    
    $behavioralSweepPerformed = jq -r '.behavioralSweep.performed // empty' .local/review.json
    if ($behavioralSweepPerformed -ne "true") {
        Write-Host "Invalid behavioral sweep in .local/review.json: behavioralSweep.performed must be true"
        exit 1
    }
    
    $behavioralSweepStatus = jq -r '.behavioralSweep.status // ""' .local/review.json
    switch ($behavioralSweepStatus) {
        "pass" {}
        "needs_work" {}
        "not_applicable" {}
        default {
            Write-Host "Invalid behavioral sweep status in .local/review.json: $behavioralSweepStatus"
            exit 1
        }
    }
    
    $behavioralSweepRisk = jq -r '.behavioralSweep.silentDropRisk // ""' .local/review.json
    switch ($behavioralSweepRisk) {
        "none" {}
        "present" {}
        "unknown" {}
        default {
            Write-Host "Invalid behavioral sweep risk in .local/review.json: $behavioralSweepRisk"
            exit 1
        }
    }
    
    $invalidBehavioralSummaryCount = jq '[.behavioralSweep.summary | select((type != "string") or (gsub("^\\s+|\\s+$";"") | length == 0))] | length' .local/review.json
    if ([int]$invalidBehavioralSummaryCount -gt 0) {
        Write-Host "Invalid behavioral sweep summary in .local/review.json: behavioralSweep.summary must be a non-empty string"
        exit 1
    }
    
    $behavioralBranchesIsArray = jq -r 'if (.behavioralSweep.branches | type) == "array" then "true" else "false" end' .local/review.json
    if ($behavioralBranchesIsArray -ne "true") {
        Write-Host "Invalid behavioral sweep in .local/review.json: behavioralSweep.branches must be an array"
        exit 1
    }
    
    $invalidBehavioralBranchCount = jq '[.behavioralSweep.branches[]? | select((.path|type)!="string" or (.decision|type)!="string" or (.outcome|type)!="string")] | length' .local/review.json
    if ([int]$invalidBehavioralBranchCount -gt 0) {
        Write-Host "Invalid behavioral sweep branch entry in .local/review.json: each branch needs string path/decision/outcome"
        exit 1
    }
    
    $behavioralBranchCount = jq '[.behavioralSweep.branches[]?] | length' .local/review.json
    
    if ($runtimeReviewRequired -eq "true" -and $behavioralSweepStatus -eq "not_applicable") {
        Write-Host "Invalid behavioral sweep in .local/review.json: runtime file changes require behavioralSweep.status=pass|needs_work"
        exit 1
    }
    
    if ($runtimeReviewRequired -eq "true" -and [int]$behavioralBranchCount -lt 1) {
        Write-Host "Invalid behavioral sweep in .local/review.json: runtime file changes require at least one branch entry"
        exit 1
    }
    
    if ($behavioralSweepStatus -eq "not_applicable" -and [int]$behavioralBranchCount -gt 0) {
        Write-Host "Invalid behavioral sweep in .local/review.json: not_applicable cannot include branch entries"
        exit 1
    }
    
    if ($behavioralSweepStatus -eq "pass" -and $behavioralSweepRisk -ne "none") {
        Write-Host "Invalid behavioral sweep in .local/review.json: status=pass requires silentDropRisk=none"
        exit 1
    }
    
    if ($recommendation -eq "READY FOR /prepare-pr" -and $issueValidationStatus -ne "valid") {
        Write-Host "Invalid recommendation in .local/review.json: READY FOR /prepare-pr requires issueValidation.status=valid"
        exit 1
    }
    
    if ($recommendation -eq "READY FOR /prepare-pr" -and $behavioralSweepStatus -eq "needs_work") {
        Write-Host "Invalid recommendation in .local/review.json: READY FOR /prepare-pr requires behavioralSweep.status!=needs_work"
        exit 1
    }
    
    if ($recommendation -eq "READY FOR /prepare-pr" -and $runtimeReviewRequired -eq "true" -and $behavioralSweepStatus -ne "pass") {
        Write-Host "Invalid recommendation in .local/review.json: READY FOR /prepare-pr on runtime changes requires behavioralSweep.status=pass"
        exit 1
    }
    
    if ($recommendation -eq "READY FOR /prepare-pr" -and $behavioralSweepRisk -eq "present") {
        Write-Host "Invalid recommendation in .local/review.json: READY FOR /prepare-pr is not allowed when behavioralSweep.silentDropRisk=present"
        exit 1
    }
    
    $docsStatus = jq -r '.docs // ""' .local/review.json
    switch ($docsStatus) {
        "up_to_date" {}
        "missing" {}
        "not_applicable" {}
        default {
            Write-Host "Invalid docs status in .local/review.json: $docsStatus"
            exit 1
        }
    }
    
    $changelogStatus = jq -r '.changelog // ""' .local/review.json
    switch ($changelogStatus) {
        "required" {}
        "not_required" {}
        default {
            Write-Host "Invalid changelog status in .local/review.json: $changelogStatus (must be `"required`" or `"not_required`")"
            exit 1
        }
    }
    
    Write-Host "review artifacts validated"
    Print-ReviewStdoutSummary
}

function Review-Tests {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Pr,
        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$Targets
    )
    
    if ($Targets.Count -lt 1) {
        Write-Host "Usage: scripts/pr review-tests <PR> <test-file> [<test-file> ...]"
        exit 2
    }
    
    EnterWorktree $Pr $false
    Review-Guard $Pr
    
    foreach ($target in $Targets) {
        if (!(Test-Path $target)) {
            Write-Host "Missing test target file: $target"
            exit 1
        }
    }
    
    BootstrapDepsIfNeeded
    
    $runLog = ".local/review-tests-run.log"
    Run-QuietLogged "pnpm test" $runLog "pnpm" "test", "--", $Targets
    
    $missingRun = @()
    foreach ($target in $Targets) {
        $base = Split-Path -Leaf $target
        $foundInLog = $false
        if (Select-String -Path $runLog -Pattern $target -Quiet) {
            $foundInLog = $true
        }
        if (Select-String -Path $runLog -Pattern $base -Quiet) {
            $foundInLog = $true
        }
        if (-not $foundInLog) {
            $missingRun += $target
        }
    }
    
    if ($missingRun.Count -gt 0) {
        Write-Host "These requested targets were not observed in vitest run output:"
        foreach ($item in $missingRun) {
            Write-Host " - $item"
        }
        exit 1
    }
    
    # Security: shell-escape values to prevent command injection when sourced.
    $content = @"
REVIEW_TESTS_AT=$([System.DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ"))
REVIEW_TEST_TARGET_COUNT=$($Targets.Count)
"@
    $content | Out-File -FilePath ".local/review-tests.env" -Encoding utf8
    
    Write-Host "review tests passed and were observed in output"
}

function Review-Init {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Pr
    )
    
    EnterWorktree $Pr $true
    
    $json = PrMetaJson $Pr
    Write-PrMetaFiles $json
    
    git fetch origin "pull/$Pr/head:pr-$Pr" --force
    $mb = git merge-base origin/main "pr-$Pr"
    
    # Security: shell-escape values to prevent command injection when sourced.
    $content = @"
PR_NUMBER=$Pr
MERGE_BASE=$mb
REVIEW_STARTED_AT=$([System.DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ"))
"@
    $content | Out-File -FilePath ".local/review-context.env" -Encoding utf8
    Set-ReviewMode "main"
    
    $json | jq '{number,title,url,state,isDraft,author:.author.login,base:.baseRefName,head:.headRefName,headSha:.headRefOid,headRepo:.headRepository.nameWithOwner,additions,deletions,files:(.files|length)}'
    Write-Host "worktree=$PWD"
    Write-Host "pr_url=${env:PR_URL}"
    Write-Host "merge_base=$mb"
    Write-Host "branch=$(git branch --show-current)"
    Write-Host "wrote=.local/pr-meta.json .local/pr-meta.env .local/review-context.env .local/review-mode.env"
    
    $guide = @"
Review guidance:
- Inspect main baseline: scripts/pr review-checkout-main $Pr
- Inspect PR head:      scripts/pr review-checkout-pr $Pr
- Guard before writeout: scripts/pr review-guard $Pr
"@
    Write-Host $guide
}

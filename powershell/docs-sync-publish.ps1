#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "cc3532b744443d094e419518b590f6ad1207410dd4f9e0f70ecb2543ab050eef", "source_sha256": "51ab4d0a9d189c9eda9b410805bf753ea3df4406b70d58c8757e52b4551325b6", "target_language": "powershell"}
# docs-sync-publish.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/docs-sync-publish.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

$HERE = Split-Path $MyInvocation.MyCommand.Path -Parent
$ROOT = Resolve-Path (Join-Path $HERE "..")
$SOURCE_DOCS_DIR = Join-Path $ROOT "docs"
$SOURCE_CONFIG_PATH = Join-Path $SOURCE_DOCS_DIR "docs.json"

$GENERATED_LOCALES = @(
  @{
    language = "zh-Hans"
    dir = "zh-CN"
    navFile = "zh-Hans-navigation.json"
    tmFile = "zh-CN.tm.jsonl"
    navMode = "overlay"
  }
  @{
    language = "ja"
    dir = "ja-JP"
    navFile = "ja-navigation.json"
    tmFile = "ja-JP.tm.jsonl"
    navMode = "clone-en"
  }
  @{
    language = "es"
    dir = "es"
    navFile = "es-navigation.json"
    tmFile = "es.tm.jsonl"
    navMode = "clone-en"
  }
  @{
    language = "pt-BR"
    dir = "pt-BR"
    navFile = "pt-BR-navigation.json"
    tmFile = "pt-BR.tm.jsonl"
    navMode = "clone-en"
  }
  @{
    language = "ko"
    dir = "ko"
    navFile = "ko-navigation.json"
    tmFile = "ko.tm.jsonl"
    navMode = "clone-en"
  }
  @{
    language = "de"
    dir = "de"
    navFile = "de-navigation.json"
    tmFile = "de.tm.jsonl"
    navMode = "clone-en"
  }
  @{
    language = "fr"
    dir = "fr"
    navFile = "fr-navigation.json"
    tmFile = "fr.tm.jsonl"
    navMode = "clone-en"
  }
  @{
    language = "ar"
    dir = "ar"
    navFile = "ar-navigation.json"
    tmFile = "ar.tm.jsonl"
    navMode = "clone-en"
  }
  @{
    language = "it"
    dir = "it"
    navFile = "it-navigation.json"
    tmFile = "it.tm.jsonl"
    navMode = "clone-en"
  }
  @{
    language = "tr"
    dir = "tr"
    navFile = "tr-navigation.json"
    tmFile = "tr.tm.jsonl"
    navMode = "clone-en"
  }
  @{
    language = "uk"
    dir = "uk"
    navFile = "uk-navigation.json"
    tmFile = "uk.tm.jsonl"
    navMode = "clone-en"
  }
  @{
    language = "id"
    dir = "id"
    navFile = "id-navigation.json"
    tmFile = "id.tm.jsonl"
    navMode = "clone-en"
  }
  @{
    language = "pl"
    dir = "pl"
    navFile = "pl-navigation.json"
    tmFile = "pl.tm.jsonl"
    navMode = "clone-en"
  }
)

function Parse-Args {
  param(
    [string[]]$argv
  )

  $args = @{
    target = ""
    sourceRepo = ""
    sourceSha = ""
  }

  $index = 0
  while ($index -lt $argv.Length) {
    $part = $argv[$index]
    switch ($part) {
      "--target" {
        $args.target = if ($index + 1 -lt $argv.Length) { $argv[$index + 1] } else { "" }
        $index += 1
      }
      "--source-repo" {
        $args.sourceRepo = if ($index + 1 -lt $argv.Length) { $argv[$index + 1] } else { "" }
        $index += 1
      }
      "--source-sha" {
        $args.sourceSha = if ($index + 1 -lt $argv.Length) { $argv[$index + 1] } else { "" }
        $index += 1
      }
      default {
        throw "unknown arg: $part"
      }
    }
    $index += 1
  }

  if (-not $args.target) {
    throw "missing --target"
  }

  return $args
}

function Invoke-Command {
  param(
    [string]$command,
    [string[]]$arguments,
    [hashtable]$options = @{}
  )

  $processInfo = New-Object System.Diagnostics.ProcessStartInfo
  $processInfo.FileName = $command
  $processInfo.Arguments = ($arguments | ForEach-Object { "`"$_`"" }) -join " "
  $processInfo.WorkingDirectory = $ROOT
  $processInfo.UseShellExecute = $false
  $processInfo.RedirectStandardOutput = $false
  $processInfo.RedirectStandardError = $false

  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = $processInfo
  $process.Start() | Out-Null
  $process.WaitForExit()

  if ($process.ExitCode -ne 0) {
    throw "$command exited with code $($process.ExitCode)"
  }
}

function Ensure-Dir {
  param([string]$dirPath)
  if (-not (Test-Path $dirPath)) {
    New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
  }
}

function Read-Json {
  param([string]$filePath)
  $content = Get-Content $filePath -Raw
  return $content | ConvertFrom-Json
}

function Write-Json {
  param(
    [string]$filePath,
    $value
  )
  Ensure-Dir (Split-Path $filePath -Parent)
  $json = $value | ConvertTo-Json -Depth 100
  Set-Content $filePath "$json`n"
}

function Prefix-LocalePage {
  param(
    $entry,
    [string]$localeDir
  )

  if ($entry -is [string]) {
    return "${localeDir}/$entry"
  }
  if ($entry -is [array]) {
    $result = @()
    foreach ($item in $entry) {
      $result += Prefix-LocalePage $item $localeDir
    }
    return $result
  }
  if ($null -eq $entry -or $entry.GetType().Name -ne "PSCustomObject") {
    return $entry
  }

  $clone = $entry.PSObject.Copy()
  if ($clone.psobject.Properties["page"]) {
    $clone.page = "${localeDir}/$($clone.page)"
  }
  if ($clone.psobject.Properties["pages"] -and $clone.pages -is [array]) {
    $newPages = @()
    foreach ($item in $clone.pages) {
      $newPages += Prefix-LocalePage $item $localeDir
    }
    $clone.pages = $newPages
  }
  return $clone
}

function Clone-EnglishLanguageNav {
  param(
    $englishNav,
    $locale
  )

  if ($null -eq $englishNav) {
    throw "docs/docs.json is missing navigation.languages.en"
  }

  $tabs = @()
  if ($englishNav.tabs -is [array]) {
    foreach ($tab in $englishNav.tabs) {
      $newTab = $tab.PSObject.Copy()
      
      if ($newTab.psobject.Properties["pages"] -and $newTab.pages -is [array]) {
        $newPages = @()
        foreach ($entry in $newTab.pages) {
          $newPages += Prefix-LocalePage $entry $locale.dir
        }
        $newTab.pages = $newPages
      }
      
      if ($newTab.psobject.Properties["groups"] -and $newTab.groups -is [array]) {
        $newGroups = @()
        foreach ($group in $newTab.groups) {
          $newGroup = $group.PSObject.Copy()
          if ($newGroup.psobject.Properties["pages"] -and $newGroup.pages -is [array]) {
            $groupPages = @()
            foreach ($entry in $newGroup.pages) {
              $groupPages += Prefix-LocalePage $entry $locale.dir
            }
            $newGroup.pages = $groupPages
          }
          $newGroups += $newGroup
        }
        $newTab.groups = $newGroups
      }
      
      $tabs += $newTab
    }
  }

  $result = $englishNav.PSObject.Copy()
  $result.language = $locale.language
  $result.tabs = $tabs
  return $result
}

function Compose-LocaleNav {
  param(
    $locale,
    $englishNav
  )

  if ($locale.navMode -eq "clone-en") {
    return Clone-EnglishLanguageNav $englishNav $locale
  }
  return Read-Json (Join-Path $SOURCE_DOCS_DIR ".i18n" $locale.navFile)
}

function Compose-DocsConfig {
  $sourceConfig = Read-Json $SOURCE_CONFIG_PATH
  $languages = $sourceConfig.navigation.languages

  if ($null -eq $languages -or $languages.GetType().Name -ne "Object[]") {
    throw "docs/docs.json is missing navigation.languages"
  }

  $englishNav = $languages | Where-Object { $_.language -eq "en" } | Select-Object -First 1
  $generatedLanguageSet = @{}
  foreach ($entry in $GENERATED_LOCALES) {
    $generatedLanguageSet[$entry.language] = $true
  }

  $withoutGenerated = @()
  foreach ($entry in $languages) {
    if (-not $generatedLanguageSet.ContainsKey($entry.language)) {
      $withoutGenerated += $entry
    }
  }

  $enIndex = -1
  for ($i = 0; $i -lt $withoutGenerated.Count; $i++) {
    if ($withoutGenerated[$i].language -eq "en") {
      $enIndex = $i
      break
    }
  }

  $generated = @()
  foreach ($entry in $GENERATED_LOCALES) {
    $generated += Compose-LocaleNav $entry $englishNav
  }

  if ($enIndex -eq -1) {
    $withoutGenerated += $generated
  } else {
    $beforeEn = $withoutGenerated[0..$enIndex]
    $afterEn = $withoutGenerated[($enIndex + 1)..($withoutGenerated.Length - 1)]
    $withoutGenerated = $beforeEn + $generated + $afterEn
  }

  $result = $sourceConfig.PSObject.Copy()
  $navCopy = $sourceConfig.navigation.PSObject.Copy()
  $navCopy.languages = $withoutGenerated
  $result.navigation = $navCopy
  
  return $result
}

function Sync-DocsTree {
  param([string]$targetRoot)

  $targetDocsDir = Join-Path $targetRoot "docs"
  Ensure-Dir $targetDocsDir

  $localeFilters = @()
  foreach ($entry in $GENERATED_LOCALES) {
    $localeFilters += "--filter"
    $localeFilters += "P $($entry.dir)/"
    $localeFilters += "--filter"
    $localeFilters += "P .i18n/$($entry.tmFile)"
    $localeFilters += "--exclude"
    $localeFilters += "$($entry.dir)/"
    $localeFilters += "--exclude"
    $localeFilters += ".i18n/$($entry.tmFile)"
  }

  $rsyncArgs = @(
    "-a"
    "--delete"
    "--filter"
    "P .i18n/README.md"
    "--exclude"
    ".i18n/README.md"
  ) + $localeFilters + @(
    "$SOURCE_DOCS_DIR/"
    "$targetDocsDir/"
  )

  Invoke-Command "rsync" $rsyncArgs

  foreach ($locale in $GENERATED_LOCALES) {
    $sourceTmPath = Join-Path $SOURCE_DOCS_DIR ".i18n" $locale.tmFile
    $targetTmPath = Join-Path $targetDocsDir ".i18n" $locale.tmFile
    if (-not (Test-Path $targetTmPath) -and (Test-Path $sourceTmPath)) {
      Ensure-Dir (Split-Path $targetTmPath -Parent)
      Copy-Item $sourceTmPath $targetTmPath
    }
  }

  Write-Json (Join-Path $targetDocsDir "docs.json") (Compose-DocsConfig)
}

function Write-SyncMetadata {
  param(
    [string]$targetRoot,
    $args
  )

  $metadata = @{
    repository = if ($args.sourceRepo) { $args.sourceRepo } else { "" }
    sha = if ($args.sourceSha) { $args.sourceSha } else { "" }
    syncedAt = (Get-Date).ToUniversalTime().ToString("o")
  }
  
  Write-Json (Join-Path $targetRoot ".openclaw-sync" "source.json") $metadata
}

function Main {
  $args = Parse-Args $args
  $targetRoot = Resolve-Path $args.target

  if (-not (Test-Path $targetRoot)) {
    throw "target does not exist: $targetRoot"
  }

  Sync-DocsTree $targetRoot
  Write-SyncMetadata $targetRoot $args
}

Main

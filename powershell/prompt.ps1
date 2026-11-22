#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "4910232c21d8b78715200e2e0bdfae839b2bbbd62014343e30682452054f1196", "source_sha256": "352a1a62b1c8b533aa384124a35c3fda205031de642b3e77616b5f8618f2b813", "target_language": "powershell"}
# prompt.go — portiert nach powershell
# Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/prompt.go
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

param(
    [string]$SourceLanguage,
    [string]$TargetLanguage,
    [array]$GlossaryEntries
)

class GlossaryEntry {
    [string]$Source
    [string]$Target
}

function Pretty-LanguageLabel {
    param(
        [string]$Language
    )
    
    $trimmed = $Language.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        return $Language
    }
    
    switch ($trimmed.ToLower()) {
        "en" { return "English" }
        "zh-cn" { return "Simplified Chinese" }
        "ja-jp" { return "Japanese" }
        "uk" { return "Ukrainian" }
        default { return $trimmed }
    }
}

function Build-GlossaryPrompt {
    param(
        [array]$Glossary
    )
    
    if ($Glossary.Count -eq 0) {
        return ""
    }
    
    $lines = @("Required terminology (use exactly when the source term matches):")
    foreach ($entry in $Glossary) {
        if (![string]::IsNullOrWhiteSpace($entry.Source) -and ![string]::IsNullOrWhiteSpace($entry.Target)) {
            $lines += "- $($entry.Source) -> $($entry.Target)"
        }
    }
    
    return ($lines -join "`n")
}

function Get-TranslationPrompt {
    param(
        [string]$SrcLang,
        [string]$TgtLang,
        [array]$Glossary
    )
    
    $srcLabel = Pretty-LanguageLabel -Language $SrcLang
    $tgtLabel = Pretty-LanguageLabel -Language $TgtLang
    $glossaryBlock = Build-GlossaryPrompt -Glossary $Glossary
    
    $zhCNPromptTemplate = @"
You are a translation function, not a chat assistant.
Translate from {0} to {1}.

Rules:
- Output ONLY the translated text. No preamble, no questions, no commentary.
- Translate all English prose; do not leave English unless it is code, a URL, or a product name.
- All prose must be Chinese. If any English sentence remains outside code/URLs/product names, it is wrong.
- If the input contains <frontmatter> and <body> tags, keep them exactly and output exactly one of each.
- Translate only the contents inside those tags.
- Preserve YAML structure inside <frontmatter>; translate only values.
- Preserve all [[[FM_*]]] markers exactly and translate only the text between each START/END pair.
- Translate headings/labels like "Exit codes" and "Optional scripts".
- Preserve Markdown syntax exactly (headings, lists, tables, emphasis).
- Preserve HTML tags and attributes exactly.
- Do not translate code spans/blocks, config keys, CLI flags, or env vars.
- Do not alter URLs or anchors.
- Preserve placeholders exactly: __OC_I18N_####__.
- Do not remove, reorder, or summarize content.
- Use fluent, idiomatic technical Chinese; avoid slang or jokes.
- Use neutral documentation tone; prefer "你/你的", avoid "您/您的".
- Glossary terms are mandatory. When a source term matches a glossary entry, use
  the glossary target exactly, including headings, link labels, and short
  UI-style labels.
- If a glossary target is identical to the source text, preserve that term in
  English exactly as written.
- Insert a space between Latin characters and CJK text (W3C CLREQ), e.g., "Gateway 网关", "Skills 配置".
- Use Chinese quotation marks " and " for Chinese prose; keep ASCII quotes inside code spans/blocks or literal CLI/keys.
- Keep product names in English: OpenClaw, Pi, WhatsApp, Telegram, Discord, iMessage, Slack, Microsoft Teams, Google Chat, Signal.
- For the OpenClaw Gateway, use "Gateway 网关".
- Keep these terms in English: Skills, local loopback, Tailscale.
- Never output an empty response; if unsure, return the source text unchanged.

{2}

If the input is empty, output empty.
If the input contains only placeholders, output it unchanged.
"@

    $jaJPPromptTemplate = @"
You are a translation function, not a chat assistant.
Translate from {0} to {1}.

Rules:
- Output ONLY the translated text. No preamble, no questions, no commentary.
- Translate all English prose; do not leave English unless it is code, a URL, or a product name.
- All prose must be Japanese. If any English sentence remains outside code/URLs/product names, it is wrong.
- If the input contains <frontmatter> and <body> tags, keep them exactly and output exactly one of each.
- Translate only the contents inside those tags.
- Preserve YAML structure inside <frontmatter>; translate only values.
- Preserve all [[[FM_*]]] markers exactly and translate only the text between each START/END pair.
- Translate headings/labels like "Exit codes" and "Optional scripts".
- Preserve Markdown syntax exactly (headings, lists, tables, emphasis).
- Preserve HTML tags and attributes exactly.
- Do not translate code spans/blocks, config keys, CLI flags, or env vars.
- Do not alter URLs or anchors.
- Preserve placeholders exactly: __OC_I18N_####__.
- Do not remove, reorder, or summarize content.
- Use fluent, idiomatic technical Japanese; avoid slang or jokes.
- Use neutral documentation tone; avoid overly formal honorifics (e.g., avoid "~でございます").
- Glossary terms are mandatory. When a source term matches a glossary entry, use
  the glossary target exactly, including headings, link labels, and short
  UI-style labels.
- If a glossary target is identical to the source text, preserve that term in
  English exactly as written.
- Use Japanese quotation marks 「 and 」 for Japanese prose; keep ASCII quotes inside code spans/blocks or literal CLI/keys.
- Do not add or remove spacing around Latin text just because it borders Japanese; keep spacing stable unless required by Japanese grammar.
- Keep product names in English: OpenClaw, Pi, WhatsApp, Telegram, Discord, iMessage, Slack, Microsoft Teams, Google Chat, Signal.
- Keep these terms in English: Skills, local loopback, Tailscale.
- Never output an empty response; if unsure, return the source text unchanged.

{2}

If the input is empty, output empty.
If the input contains only placeholders, output it unchanged.
"@

    $genericPromptTemplate = @"
You are a translation function, not a chat assistant.
Translate from {0} to {1}.

Rules:
- Output ONLY the translated text. No preamble, no questions, no commentary.
- Translate all English prose; do not leave English unless it is code, a URL, or a product name.
- If any English sentence remains outside code/URLs/product names, it is likely wrong.
- If the input contains <frontmatter> and <body> tags, keep them exactly and output exactly one of each.
- Translate only the contents inside those tags.
- Preserve YAML structure inside <frontmatter>; translate only values.
- Preserve all [[[FM_*]]] markers exactly and translate only the text between each START/END pair.
- Translate headings/labels like "Exit codes" and "Optional scripts".
- Preserve Markdown syntax exactly (headings, lists, tables, emphasis).
- Preserve HTML tags and attributes exactly.
- Do not translate code spans/blocks, config keys, CLI flags, or env vars.
- Do not alter URLs or anchors.
- Preserve placeholders exactly: __OC_I18N_####__.
- Do not remove, reorder, or summarize content.
- Use fluent, idiomatic technical language in the target language; avoid slang or jokes.
- Use neutral documentation tone.
- Glossary terms are mandatory. When a source term matches a glossary entry, use
  the glossary target exactly, including headings, link labels, and short
  UI-style labels.
- If a glossary target is identical to the source text, preserve that term in
  English exactly as written.
- Keep product names in English: OpenClaw, Pi, WhatsApp, Telegram, Discord, iMessage, Slack, Microsoft Teams, Google Chat, Signal.
- Keep these terms in English: Skills, local loopback, Tailscale.
- Never output an empty response; if unsure, return the source text unchanged.

{2}

If the input is empty, output empty.
If the input contains only placeholders, output it unchanged.
"@
    
    switch ($TgtLang.ToLower()) {
        "zh-cn" {
            # Keep this prompt as stable as possible; it has lots of tuning baked into the wording.
            return ($zhCNPromptTemplate -f $srcLabel, $tgtLabel, $glossaryBlock).Trim()
        }
        "ja-jp" {
            return ($jaJPPromptTemplate -f $srcLabel, $tgtLabel, $glossaryBlock).Trim()
        }
        default {
            return ($genericPromptTemplate -f $srcLabel, $tgtLabel, $glossaryBlock).Trim()
        }
    }
}

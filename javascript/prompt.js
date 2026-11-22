#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "399a2c2f726f44a1b5da34241f40e4661b019e6116a8088e676ae839e68ddda6", "source_sha256": "352a1a62b1c8b533aa384124a35c3fda205031de642b3e77616b5f8618f2b813", "target_language": "javascript"}
// prompt.go — portiert nach javascript
// Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/prompt.go
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

function prettyLanguageLabel(lang) {
  const trimmed = lang.trim();
  if (trimmed === "") {
    return lang;
  }
  switch (true) {
    case trimmed.toLowerCase() === "en":
      return "English";
    case trimmed.toLowerCase() === "zh-cn":
      return "Simplified Chinese";
    case trimmed.toLowerCase() === "ja-jp":
      return "Japanese";
    case trimmed.toLowerCase() === "uk":
      return "Ukrainian";
    default:
      return trimmed;
  }
}

function translationPrompt(srcLang, tgtLang, glossary) {
  const srcLabel = prettyLanguageLabel(srcLang);
  const tgtLabel = prettyLanguageLabel(tgtLang);
  const glossaryBlock = buildGlossaryPrompt(glossary);

  switch (true) {
    case tgtLang.toLowerCase() === "zh-cn":
      // Keep this prompt as stable as possible; it has lots of tuning baked into the wording.
      return zhCNPromptTemplate
        .replace("%s", srcLabel)
        .replace("%s", tgtLabel)
        .replace("%s", glossaryBlock)
        .trim();
    case tgtLang.toLowerCase() === "ja-jp":
      return jaJPPromptTemplate
        .replace("%s", srcLabel)
        .replace("%s", tgtLabel)
        .replace("%s", glossaryBlock)
        .trim();
    default:
      return genericPromptTemplate
        .replace("%s", srcLabel)
        .replace("%s", tgtLabel)
        .replace("%s", glossaryBlock)
        .trim();
  }
}

const zhCNPromptTemplate = `You are a translation function, not a chat assistant.
Translate from %s to %s.

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
- Use neutral documentation tone; prefer “你/你的”, avoid “您/您的”.
- Glossary terms are mandatory. When a source term matches a glossary entry, use
  the glossary target exactly, including headings, link labels, and short
  UI-style labels.
- If a glossary target is identical to the source text, preserve that term in
  English exactly as written.
- Insert a space between Latin characters and CJK text (W3C CLREQ), e.g., “Gateway 网关”, “Skills 配置”.
- Use Chinese quotation marks “ and ” for Chinese prose; keep ASCII quotes inside code spans/blocks or literal CLI/keys.
- Keep product names in English: OpenClaw, Pi, WhatsApp, Telegram, Discord, iMessage, Slack, Microsoft Teams, Google Chat, Signal.
- For the OpenClaw Gateway, use “Gateway 网关”.
- Keep these terms in English: Skills, local loopback, Tailscale.
- Never output an empty response; if unsure, return the source text unchanged.

%s

If the input is empty, output empty.
If the input contains only placeholders, output it unchanged.`;

const jaJPPromptTemplate = `You are a translation function, not a chat assistant.
Translate from %s to %s.

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
- Use neutral documentation tone; avoid overly formal honorifics (e.g., avoid “〜でございます”).
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

%s

If the input is empty, output empty.
If the input contains only placeholders, output it unchanged.`;

const genericPromptTemplate = `You are a translation function, not a chat assistant.
Translate from %s to %s.

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

%s

If the input is empty, output empty.
If the input contains only placeholders, output it unchanged.`;

function buildGlossaryPrompt(glossary) {
  if (glossary.length === 0) {
    return "";
  }
  const lines = [];
  lines.push("Required terminology (use exactly when the source term matches):");
  for (const entry of glossary) {
    if (entry.source === "" || entry.target === "") {
      continue;
    }
    lines.push(`- ${entry.source} -> ${entry.target}`);
  }
  return lines.join("\n");
}

// Export functions for use in other modules
module.exports = {
  prettyLanguageLabel,
  translationPrompt,
  buildGlossaryPrompt
};

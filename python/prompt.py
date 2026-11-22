#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "1eb96ff068a3992367cdd2dca0c74d49c35fd68fa2094779d9eaed055453c385", "source_sha256": "352a1a62b1c8b533aa384124a35c3fda205031de642b3e77616b5f8618f2b813", "target_language": "python"}
# prompt.go — portiert nach python
# Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/prompt.go
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

def pretty_language_label(lang):
    """Convert language codes to human-readable labels."""
    trimmed = lang.strip()
    if not trimmed:
        return lang
    
    # Case-insensitive comparisons
    lower_trimmed = trimmed.lower()
    
    if lower_trimmed == "en":
        return "English"
    elif lower_trimmed == "zh-cn":
        return "Simplified Chinese"
    elif lower_trimmed == "ja-jp":
        return "Japanese"
    elif lower_trimmed == "uk":
        return "Ukrainian"
    else:
        return trimmed


def translation_prompt(src_lang, tgt_lang, glossary):
    """Generate a translation prompt based on source/target languages and glossary."""
    src_label = pretty_language_label(src_lang)
    tgt_label = pretty_language_label(tgt_lang)
    glossary_block = build_glossary_prompt(glossary)

    # Case-insensitive comparison for target language
    lower_tgt_lang = tgt_lang.lower().strip()

    if lower_tgt_lang == "zh-cn":
        # Keep this prompt as stable as possible; it has lots of tuning baked into the wording.
        template = zh_cn_prompt_template
    elif lower_tgt_lang == "ja-jp":
        template = ja_jp_prompt_template
    else:
        template = generic_prompt_template

    # Format and clean up whitespace
    prompt = template % (src_label, tgt_label, glossary_block)
    return prompt.strip()


# Template strings for different language prompts
zh_cn_prompt_template = '''You are a translation function, not a chat assistant.
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
If the input contains only placeholders, output it unchanged.'''

ja_jp_prompt_template = '''You are a translation function, not a chat assistant.
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
If the input contains only placeholders, output it unchanged.'''

generic_prompt_template = '''You are a translation function, not a chat assistant.
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
If the input contains only placeholders, output it unchanged.'''


def build_glossary_prompt(glossary):
    """Build a formatted glossary block from a list of entries."""
    if not glossary:
        return ""

    lines = ["Required terminology (use exactly when the source term matches):"]
    for entry in glossary:
        # Skip invalid entries
        if not entry.get("source") or not entry.get("target"):
            continue
        lines.append(f"- {entry['source']} -> {entry['target']}")
    
    return "\n".join(lines)

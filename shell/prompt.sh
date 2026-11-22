#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "179e3d09813b4ec2b6863448a3dbd7e80014640fc2dd5bc9f7adad4ff8b3a6e9", "source_sha256": "352a1a62b1c8b533aa384124a35c3fda205031de642b3e77616b5f8618f2b813", "target_language": "shell"}
# prompt.go — portiert nach shell
# Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/prompt.go
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Function to pretty print language label
pretty_language_label() {
    local lang="$1"
    lang="$(echo "$lang" | xargs)" # trim whitespace
    if [[ -z "$lang" ]]; then
        echo "$lang"
        return
    fi

    case "${lang,,}" in
        en)
            echo "English"
            ;;
        zh-cn)
            echo "Simplified Chinese"
            ;;
        ja-jp)
            echo "Japanese"
            ;;
        uk)
            echo "Ukrainian"
            ;;
        *)
            echo "$lang"
            ;;
    esac
}

# Function to build glossary prompt
build_glossary_prompt() {
    local -a glossary=("${@}")
    if (( ${#glossary[@]} == 0 )); then
        echo ""
        return
    fi

    local lines=("Required terminology (use exactly when the source term matches):")
    local i
    for ((i=0; i<${#glossary[@]}; i+=2)); do
        local src="${glossary[$i]}"
        local tgt="${glossary[$((i+1))]}"
        if [[ -n "$src" && -n "$tgt" ]]; then
            lines+=("- $src -> $tgt")
        fi
    done
    printf '%s\n' "${lines[@]}"
}

# Main function to generate translation prompt
translation_prompt() {
    local src_lang="$1"
    local tgt_lang="$2"
    shift 2
    local -a glossary=("$@")

    local src_label
    src_label=$(pretty_language_label "$src_lang")
    local tgt_label
    tgt_label=$(pretty_language_label "$tgt_lang")
    local glossary_block
    glossary_block=$(build_glossary_prompt "${glossary[@]}")

    case "${tgt_lang,,}" in
        zh-cn)
            # Keep this prompt as stable as possible; it has lots of tuning baked into the wording.
            read -r -d '' template <<'EOF'
You are a translation function, not a chat assistant.
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
If the input contains only placeholders, output it unchanged.
EOF
            ;;
        ja-jp)
            read -r -d '' template <<'EOF'
You are a translation function, not a chat assistant.
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
If the input contains only placeholders, output it unchanged.
EOF
            ;;
        *)
            read -r -d '' template <<'EOF'
You are a translation function, not a chat assistant.
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
If the input contains only placeholders, output it unchanged.
EOF
            ;;
    esac

    # Format the template with variables
    printf "%s\n" "$(printf "$template" "$src_label" "$tgt_label" "$glossary_block")" | sed 's/^[[:space:]]*$//' | sed '/^$/N;/^\n*$/D'
}

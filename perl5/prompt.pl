#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "3964e68b34fdd804a417766ee3fbbf17d72e0e8f97578cda62ef210b60a081fa", "source_sha256": "352a1a62b1c8b533aa384124a35c3fda205031de642b3e77616b5f8618f2b813", "target_language": "perl5"}
# prompt.go — portiert nach perl5
# Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/prompt.go
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;

# Define package-like namespace
{
    package GlossaryEntry;
    sub new {
        my ($class, $source, $target) = @_;
        return bless {
            Source => $source,
            Target => $target,
        }, $class;
    }
}

sub pretty_language_label {
    my ($lang) = @_;
    my $trimmed = trim($lang);
    return $lang if $trimmed eq "";

    return "English"           if lc($trimmed) eq "en";
    return "Simplified Chinese" if lc($trimmed) eq "zh-cn";
    return "Japanese"          if lc($trimmed) eq "ja-jp";
    return "Ukrainian"         if lc($trimmed) eq "uk";
    return $trimmed;
}

sub translation_prompt {
    my ($src_lang, $tgt_lang, $glossary_ref) = @_;
    my $src_label = pretty_language_label($src_lang);
    my $tgt_label = pretty_language_label($tgt_lang);
    my $glossary_block = build_glossary_prompt($glossary_ref);

    if (lc($tgt_lang) eq "zh-cn") {
        return trim(sprintf(zh_cn_prompt_template(), $src_label, $tgt_label, $glossary_block));
    } elsif (lc($tgt_lang) eq "ja-jp") {
        return trim(sprintf(ja_jp_prompt_template(), $src_label, $tgt_label, $glossary_block));
    } else {
        return trim(sprintf(generic_prompt_template(), $src_label, $tgt_label, $glossary_block));
    }
}

sub zh_cn_prompt_template {
    return q{You are a translation function, not a chat assistant.
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
If the input contains only placeholders, output it unchanged.};
}

sub ja_jp_prompt_template {
    return q{You are a translation function, not a chat assistant.
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
If the input contains only placeholders, output it unchanged.};
}

sub generic_prompt_template {
    return q{You are a translation function, not a chat assistant.
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
If the input contains only placeholders, output it unchanged.};
}

sub build_glossary_prompt {
    my ($glossary_ref) = @_;
    return "" unless @$glossary_ref;

    my @lines = ("Required terminology (use exactly when the source term matches):");
    for my $entry (@$glossary_ref) {
        next if !$entry->{Source} || !$entry->{Target};
        push @lines, "- $entry->{Source} -> $entry->{Target}";
    }
    return join("\n", @lines);
}

# Helper function to mimic Go's strings.TrimSpace
sub trim {
    my ($str) = @_;
    $str =~ s/^\s+|\s+$//g;
    return $str;
}

1; # End of module-like block

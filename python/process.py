#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "bf9c460ba8d2a54970c46dbf5e1c993c568955a3c034b5ed204b49630eb9d5ce", "source_sha256": "d00d873eeab51d166892e3bc7f2dd08b6f535b2c11988d1bb7bc0c123b76e82d", "target_language": "python"}
# process.go — portiert nach python
# Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/process.go
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

import contextlib
import hashlib
import logging
import os
import re
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import yaml

# Constants
workflow_version = "1.0"

class TMEntry:
    def __init__(self, cache_key: str, segment_id: str, source_path: str, text_hash: str,
                 text: str, translated: str, provider: str, model: str,
                 src_lang: str, tgt_lang: str, updated_at: str):
        self.cache_key = cache_key
        self.segment_id = segment_id
        self.source_path = source_path
        self.text_hash = text_hash
        self.text = text
        self.translated = translated
        self.provider = provider
        self.model = model
        self.src_lang = src_lang
        self.tgt_lang = tgt_lang
        self.updated_at = updated_at


class TranslationMemory:
    def __init__(self):
        self.entries: Dict[str, TMEntry] = {}

    def get(self, cache_key: str) -> Tuple[Optional[TMEntry], bool]:
        entry = self.entries.get(cache_key)
        return entry, entry is not None

    def put(self, entry: TMEntry):
        self.entries[entry.cache_key] = entry


class Segment:
    def __init__(self, segment_id: str, text_hash: str, text: str):
        self.segment_id = segment_id
        self.text_hash = text_hash
        self.text = text
        self.cache_key = ""
        self.translated = ""


def docs_i18n_verbose_logs() -> bool:
    value = os.environ.get("OPENCLAW_DOCS_I18N_VERBOSE_LOGS", "").strip()
    if not value:
        return False
    return value.lower() in ["1", "true", "yes", "on", "debug", "verbose"]


def docs_pi_provider() -> str:
    return os.environ.get("DOCS_PI_PROVIDER", "default")


def docs_pi_model() -> str:
    return os.environ.get("DOCS_PI_MODEL", "default")


def cache_namespace() -> str:
    return os.environ.get("CACHE_NAMESPACE", "default")


def hash_text(text: str) -> str:
    return hashlib.sha256(text.encode('utf-8')).hexdigest()


def hash_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def cache_key(namespace: str, src_lang: str, tgt_lang: str, segment_id: str, text_hash: str) -> str:
    key_data = f"{namespace}:{src_lang}:{tgt_lang}:{segment_id}:{text_hash}"
    return hashlib.sha256(key_data.encode('utf-8')).hexdigest()


def resolve_docs_path(docs_root: str, file_path: str) -> Tuple[str, str, Optional[Exception]]:
    abs_path = os.path.join(docs_root, file_path)
    try:
        rel_path = os.path.relpath(abs_path, docs_root)
        return abs_path, rel_path, None
    except Exception as e:
        return "", "", e


def split_front_matter(content: str) -> Tuple[str, str]:
    if not content.startswith("---"):
        return "", content
    
    lines = content.split("\n")
    if len(lines) < 2:
        return "", content
    
    end_index = -1
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            end_index = i
            break
    
    if end_index == -1:
        return "", content
    
    front = "\n".join(lines[1:end_index])
    body = "\n".join(lines[end_index + 1:])
    if body.startswith("\n"):
        body = body[1:]
    
    return front, body


def encode_front_matter(front_data: Dict[str, Any], rel_path: str, source: bytes) -> Tuple[str, Optional[Exception]]:
    if front_data is None:
        front_data = {}
    
    front_data["x-i18n"] = {
        "source_path": rel_path,
        "source_hash": hash_bytes(source),
        "provider": docs_pi_provider(),
        "model": docs_pi_model(),
        "workflow": workflow_version,
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    }
    
    try:
        encoded = yaml.dump(front_data, allow_unicode=True, default_flow_style=False)
        return f"---\n{encoded}---\n\n", None
    except Exception as e:
        return "", e


def validate_frontmatter_scalar_translation(source: str, translated: str) -> Optional[Exception]:
    trimmed = translated.strip()
    if not trimmed:
        return Exception("empty translation")
    
    lower = trimmed.lower()
    forbidden_patterns = ["<frontmatter>", "</frontmatter>", "<body>", "</body>"]
    for pattern in forbidden_patterns:
        if pattern in lower:
            return Exception("tagged document wrapper detected")
    
    if "[[[fm_" in lower:
        return Exception("frontmatter marker leaked into scalar translation")
    
    if "\n---\n" in trimmed or trimmed.startswith("---\n"):
        return Exception("yaml document boundary detected")
    
    if "\n" not in source and trimmed.count("\n") >= 3:
        return Exception("unexpected multiline expansion")
    
    source_len = len(source.strip())
    translated_len = len(trimmed)
    if source_len > 0:
        limit = source_len * 8 + 256
        if limit < 512:
            limit = 512
        if translated_len > limit:
            return Exception(f"unexpected size expansion source={source_len} translated={translated_len}")
    
    forbidden_keys = ["title:", "summary:", "read_when:"]
    for key in forbidden_keys:
        if f"\n{key}" in lower or lower.startswith(key):
            return Exception("frontmatter key leaked into scalar translation")
    
    return None


def translate_snippet(ctx: contextlib.ExitStack, translator, tm: TranslationMemory, segment_id: str,
                      text_value: str, src_lang: str, tgt_lang: str) -> Tuple[str, Optional[Exception]]:
    if not text_value.strip():
        return text_value, None
    
    namespace = cache_namespace()
    text_hash = hash_text(text_value)
    ck = cache_key(namespace, src_lang, tgt_lang, segment_id, text_hash)
    
    entry, exists = tm.get(ck)
    if exists:
        return entry.translated, None
    
    translated, err = translator.translate(ctx, text_value, src_lang, tgt_lang)
    if err:
        return "", err
    
    should_cache = True
    validation_err = validate_frontmatter_scalar_translation(text_value, translated)
    if validation_err:
        if docs_i18n_verbose_logs():
            print(f"docs-i18n: frontmatter fallback {segment_id} reason={validation_err}", file=sys.stderr)
        translated = text_value
        should_cache = False
    
    entry = TMEntry(
        cache_key=ck,
        segment_id=segment_id,
        source_path=segment_id,
        text_hash=text_hash,
        text=text_value,
        translated=translated,
        provider=docs_pi_provider(),
        model=docs_pi_model(),
        src_lang=src_lang,
        tgt_lang=tgt_lang,
        updated_at=time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    )
    
    if should_cache:
        tm.put(entry)
    
    return translated, None


def translate_front_matter(ctx: contextlib.ExitStack, translator, tm: TranslationMemory,
                           data: Dict[str, Any], rel_path: str, src_lang: str, tgt_lang: str) -> Optional[Exception]:
    if not data:
        return None
    
    if "summary" in data and isinstance(data["summary"], str):
        summary = data["summary"]
        if docs_i18n_verbose_logs():
            print(f"docs-i18n: frontmatter start {rel_path} field=summary bytes={len(summary)}", file=sys.stderr)
        
        translated, err = translate_snippet(ctx, translator, tm, f"{rel_path}:frontmatter:summary", 
                                          summary, src_lang, tgt_lang)
        if err:
            return err
        
        if docs_i18n_verbose_logs():
            print(f"docs-i18n: frontmatter done {rel_path} field=summary out_bytes={len(translated)}", file=sys.stderr)
        
        data["summary"] = translated
    
    if "title" in data and isinstance(data["title"], str):
        title = data["title"]
        if docs_i18n_verbose_logs():
            print(f"docs-i18n: frontmatter start {rel_path} field=title bytes={len(title)}", file=sys.stderr)
        
        translated, err = translate_snippet(ctx, translator, tm, f"{rel_path}:frontmatter:title",
                                          title, src_lang, tgt_lang)
        if err:
            return err
        
        if docs_i18n_verbose_logs():
            print(f"docs-i18n: frontmatter done {rel_path} field=title out_bytes={len(translated)}", file=sys.stderr)
        
        data["title"] = translated
    
    if "read_when" in data and isinstance(data["read_when"], list):
        read_when = data["read_when"]
        translated_list = []
        for idx, item in enumerate(read_when):
            if not isinstance(item, str):
                translated_list.append(item)
                continue
            
            if docs_i18n_verbose_logs():
                print(f"docs-i18n: frontmatter start {rel_path} field=read_when[{idx}] bytes={len(item)}", file=sys.stderr)
            
            value, err = translate_snippet(ctx, translator, tm, 
                                         f"{rel_path}:frontmatter:read_when:{idx}",
                                         item, src_lang, tgt_lang)
            if err:
                return err
            
            if docs_i18n_verbose_logs():
                print(f"docs-i18n: frontmatter done {rel_path} field=read_when[{idx}] out_bytes={len(value)}", file=sys.stderr)
            
            translated_list.append(value)
        
        data["read_when"] = translated_list
    
    return None


def extract_segments(body: str, rel_path: str) -> Tuple[List[Segment], Optional[Exception]]:
    # This is a simplified implementation - you might need to adjust based on your actual segment extraction logic
    segments = []
    # Add your segment extraction logic here
    return segments, None


def translate_html_blocks(ctx: contextlib.ExitStack, translator, body: str, src_lang: str, tgt_lang: str) -> Tuple[str, Optional[Exception]]:
    # This is a placeholder implementation - add your HTML block translation logic
    return body, None


def apply_translations(body: str, segments: List[Segment]) -> str:
    # This is a placeholder implementation - add your translation application logic
    return body


def process_file(ctx: contextlib.ExitStack, translator, tm: TranslationMemory, docs_root: str, 
                file_path: str, src_lang: str, tgt_lang: str) -> Tuple[bool, str, Optional[Exception]]:
    abs_path, rel_path, err = resolve_docs_path(docs_root, file_path)
    if err:
        return False, "", err
    
    try:
        with open(abs_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        return False, "", e
    
    front_matter, body = split_front_matter(content)
    front_data = {}
    if front_matter:
        try:
            front_data = yaml.safe_load(front_matter) or {}
        except Exception as e:
            return False, "", Exception(f"frontmatter parse failed for {rel_path}: {e}")
    
    err = translate_front_matter(ctx, translator, tm, front_data, rel_path, src_lang, tgt_lang)
    if err:
        return False, "", err
    
    body, err = translate_html_blocks(ctx, translator, body, src_lang, tgt_lang)
    if err:
        return False, "", err
    
    segments, err = extract_segments(body, rel_path)
    if err:
        return False, "", err
    
    namespace = cache_namespace()
    for seg in segments:
        seg.cache_key = cache_key(namespace, src_lang, tgt_lang, seg.segment_id, seg.text_hash)
        entry, exists = tm.get(seg.cache_key)
        if exists:
            seg.translated = entry.translated
            continue
        
        translated, err = translator.translate(ctx, seg.text, src_lang, tgt_lang)
        if err:
            return False, "", Exception(f"translate failed ({rel_path}): {err}")
        
        seg.translated = translated
        entry = TMEntry(
            cache_key=seg.cache_key,
            segment_id=seg.segment_id,
            source_path=rel_path,
            text_hash=seg.text_hash,
            text=seg.text,
            translated=translated,
            provider=docs_pi_provider(),
            model=docs_pi_model(),
            src_lang=src_lang,
            tgt_lang=tgt_lang,
            updated_at=time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        )
        tm.put(entry)
    
    translated_body = apply_translations(body, segments)
    updated_front, err = encode_front_matter(front_data, rel_path, content.encode('utf-8'))
    if err:
        return False, "", err
    
    output_path = os.path.join(docs_root, tgt_lang, rel_path)
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    output = updated_front + translated_body
    try:
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(output)
        return False, output_path, None
    except Exception as e:
        return False, "", e

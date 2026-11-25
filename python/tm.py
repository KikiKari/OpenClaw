#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "ea41110da0d482de79dfb976779638b0749aca184694848a6ea3dd026889bd77", "source_sha256": "bd1408a3d37597ed2c41b37fe2104f806ee5ea009396e16c58748eb01356bfb6", "target_language": "python"}
# tm.go — portiert nach python
# Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/tm.go
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import json
import os
from typing import Dict, Tuple, Optional


class TMEntry:
    def __init__(self, cache_key: str = "", segment_id: str = "", source_path: str = "",
                 text_hash: str = "", text: str = "", translated: str = "",
                 provider: str = "", model: str = "", src_lang: str = "",
                 tgt_lang: str = "", updated_at: str = ""):
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

    @classmethod
    def from_dict(cls, data: dict):
        return cls(
            cache_key=data.get("cache_key", ""),
            segment_id=data.get("segment_id", ""),
            source_path=data.get("source_path", ""),
            text_hash=data.get("text_hash", ""),
            text=data.get("text", ""),
            translated=data.get("translated", ""),
            provider=data.get("provider", ""),
            model=data.get("model", ""),
            src_lang=data.get("src_lang", ""),
            tgt_lang=data.get("tgt_lang", ""),
            updated_at=data.get("updated_at", "")
        )

    def to_dict(self):
        return {
            "cache_key": self.cache_key,
            "segment_id": self.segment_id,
            "source_path": self.source_path,
            "text_hash": self.text_hash,
            "text": self.text,
            "translated": self.translated,
            "provider": self.provider,
            "model": self.model,
            "src_lang": self.src_lang,
            "tgt_lang": self.tgt_lang,
            "updated_at": self.updated_at
        }


class TranslationMemory:
    def __init__(self, path: str):
        self.path = path
        self.entries: Dict[str, TMEntry] = {}

    @classmethod
    def load_translation_memory(cls, path: str) -> 'TranslationMemory':
        tm = cls(path)
        if not os.path.exists(path):
            return tm

        try:
            with open(path, 'r', encoding='utf-8') as file:
                for line in file:
                    line = line.strip()
                    if line:
                        try:
                            data = json.loads(line)
                            entry = TMEntry.from_dict(data)
                            if entry.cache_key and entry.translated.strip():
                                tm.entries[entry.cache_key] = entry
                        except json.JSONDecodeError as e:
                            raise Exception(f"translation memory decode failed: {e}")
        except Exception as e:
            raise e

        return tm

    def get(self, cache_key: str) -> Tuple[TMEntry, bool]:
        entry = self.entries.get(cache_key)
        if not entry or not entry.translated.strip():
            return TMEntry(), False
        return entry, True

    def put(self, entry: TMEntry):
        if not entry.cache_key:
            return
        self.entries[entry.cache_key] = entry

    def save(self) -> Optional[Exception]:
        if not self.path:
            return None

        try:
            os.makedirs(os.path.dirname(self.path), mode=0o755, exist_ok=True)
        except Exception as e:
            return e

        tmp_path = self.path + ".tmp"
        try:
            with open(tmp_path, 'w', encoding='utf-8') as file:
                keys = sorted(self.entries.keys())
                for key in keys:
                    entry = self.entries[key]
                    payload = json.dumps(entry.to_dict(), ensure_ascii=False)
                    file.write(payload + "\n")
            
            os.replace(tmp_path, self.path)
            return None
        except Exception as e:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)
            return e

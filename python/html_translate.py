#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "f72782091835ba05cfe4dc34e8e535c91421702adfbcdc1b9091d20964db2772", "source_sha256": "04efde297083102c20b5caf33f76d4e5638a8f6b50c3d7c5e9b15e889a91b227", "target_language": "python"}
# html_translate.go — portiert nach python
# Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/html_translate.go
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import contextlib
import html.parser
from typing import List, Tuple, Optional, ContextManager
from dataclasses import dataclass
from html import escape
import re


@dataclass
class HTMLReplacement:
    start: int
    stop: int
    value: str


class DocsTranslator:
    """Interface for translation service"""
    def translate(self, ctx: contextlib.AbstractContextManager, text: str, src_lang: str, tgt_lang: str) -> str:
        raise NotImplementedError


def translate_html_blocks(ctx: contextlib.AbstractContextManager, translator: DocsTranslator, 
                         body: str, src_lang: str, tgt_lang: str) -> str:
    """
    Translate HTML blocks within markdown content.
    
    This function parses markdown content, identifies HTML blocks,
    and translates their text content while preserving structure.
    """
    # Since we don't have goldmark equivalent, we'll use a simple regex-based approach
    # to find HTML blocks in markdown
    
    # Find HTML blocks (simplified approach)
    html_blocks = []
    lines = body.split('\n')
    i = 0
    while i < len(lines):
        line = lines[i]
        if line.strip().startswith('<') and not line.strip().startswith('</'):
            start_line = i
            # Look for closing tag or end of block
            html_content_lines = [line]
            i += 1
            while i < len(lines):
                html_content_lines.append(lines[i])
                # Simple heuristic: if line contains closing tag matching opening tag
                if '</' in lines[i] and any(tag in lines[i].lower() 
                                          for tag in ['</div', '</p', '</span', '</section']):
                    break
                i += 1
            html_content = '\n'.join(html_content_lines)
            start_pos = body.find(line)
            end_pos = start_pos + len(html_content)
            html_blocks.append((start_pos, end_pos, html_content))
        i += 1
    
    if not html_blocks:
        return body
    
    replacements = []
    for start, stop, html_text in html_blocks:
        try:
            translated = translate_html_block(ctx, translator, html_text, src_lang, tgt_lang)
            replacements.append(HTMLReplacement(start=start, stop=stop, value=translated))
        except Exception as e:
            # In case of translation error, keep original
            continue
    
    if not replacements:
        return body
        
    return apply_html_replacements(body, replacements)


def apply_html_replacements(body: str, replacements: List[HTMLReplacement]) -> str:
    """Apply sorted replacements to the body text"""
    if not replacements:
        return body
    
    # Sort by start position
    replacements.sort(key=lambda r: r.start)
    
    result = []
    last = 0
    
    for rep in replacements:
        if rep.start < last:
            continue
        result.append(body[last:rep.start])
        result.append(rep.value)
        last = rep.stop
    
    result.append(body[last:])
    return ''.join(result)


class HTMLTranslationParser(html.parser.HTMLParser):
    def __init__(self, ctx: contextlib.AbstractContextManager, translator: DocsTranslator, 
                 src_lang: str, tgt_lang: str):
        super().__init__()
        self.ctx = ctx
        self.translator = translator
        self.src_lang = src_lang
        self.tgt_lang = tgt_lang
        self.result = []
        self.skip_depth = 0
        self.skip_tags = {'code', 'pre', 'script', 'style'}
        
    def handle_starttag(self, tag: str, attrs: List[Tuple[str, Optional[str]]]):
        self.result.append(f"<{tag}")
        for attr_name, attr_value in attrs:
            if attr_value is None:
                self.result.append(f' {attr_name}')
            else:
                escaped_value = escape(attr_value, quote=True)
                self.result.append(f' {attr_name}="{escaped_value}"')
        self.result.append(">")
        
        if tag.lower() in self.skip_tags:
            self.skip_depth += 1
            
    def handle_endtag(self, tag: str):
        self.result.append(f"</{tag}>")
        if tag.lower() in self.skip_tags and self.skip_depth > 0:
            self.skip_depth -= 1
            
    def handle_startendtag(self, tag: str, attrs: List[Tuple[str, Optional[str]]]):
        self.result.append(f"<{tag}")
        for attr_name, attr_value in attrs:
            if attr_value is None:
                self.result.append(f' {attr_name}')
            else:
                escaped_value = escape(attr_value, quote=True)
                self.result.append(f' {attr_name}="{escaped_value}"')
        self.result.append(" />")
        
    def handle_data(self, data: str):
        if self.should_translate_text(data):
            try:
                translated = self.translator.translate(self.ctx, data, self.src_lang, self.tgt_lang)
                self.result.append(translated)
            except Exception:
                # If translation fails, keep original text
                self.result.append(data)
        else:
            self.result.append(data)
            
    def handle_entityref(self, name: str):
        self.result.append(f"&{name};")
        
    def handle_charref(self, name: str):
        self.result.append(f"&#{name};")
        
    def should_translate_text(self, text: str) -> bool:
        """Determine if text should be translated"""
        return text.strip() != "" and self.skip_depth == 0
        
    def get_result(self) -> str:
        return ''.join(self.result)


def translate_html_block(ctx: contextlib.AbstractContextManager, translator: DocsTranslator, 
                        html_text: str, src_lang: str, tgt_lang: str) -> str:
    """
    Translate text content within an HTML block.
    
    Preserves HTML structure while translating text content,
    skipping content within certain tags like code, pre, script, style.
    """
    parser = HTMLTranslationParser(ctx, translator, src_lang, tgt_lang)
    parser.feed(html_text)
    return parser.get_result()


# Example usage (would need actual implementation of DocsTranslator)
if __name__ == "__main__":
    # This would be implemented with actual translator
    pass

#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "8cfa7d7b4ff5138e07b7e6bea7f64eb2d7fa512e12c7c65e35d3b78f62a805f3", "source_sha256": "a1a384d35f3380f69c57a009348f8a076cc5e3fc09ba866cde4cf59a1c6ac88b", "target_language": "python"}
# arg-utils.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/arg-utils.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import os
import sys
from typing import Any, Callable, Dict, List, Optional, Tuple, Union


def read_env_number(name: str, env: Optional[Dict[str, str]] = None) -> Optional[float]:
    """Read a numeric environment variable."""
    if env is None:
        env = os.environ
    raw = env.get(name, "").strip()
    if not raw:
        return None
    try:
        parsed = float(raw)
        return parsed if parsed != float('inf') and parsed != float('-inf') else None
    except ValueError:
        return None


def consume_string_flag(
    argv: List[str], index: int, flag: str, current_value: Optional[str]
) -> Optional[Dict[str, Union[int, str]]]:
    """Consume a string flag from arguments."""
    if index >= len(argv) or argv[index] != flag:
        return None
    next_index = index + 1
    value = argv[next_index] if next_index < len(argv) else current_value
    return {"nextIndex": next_index, "value": value}


def consume_string_list_flag(
    argv: List[str], index: int, flag: str
) -> Optional[Dict[str, Union[int, Optional[str]]]]:
    """Consume a string list flag from arguments."""
    if index >= len(argv) or argv[index] != flag:
        return None
    next_index = index + 1
    value = argv[next_index] if next_index < len(argv) else None
    if isinstance(value, str) and len(value) > 0:
        return {"nextIndex": next_index, "value": value}
    return {"nextIndex": next_index, "value": None}


def consume_int_flag(
    argv: List[str],
    index: int,
    flag: str,
    current_value: int,
    options: Optional[Dict[str, Any]] = None,
) -> Optional[Dict[str, Union[int, int]]]:
    """Consume an integer flag from arguments."""
    if options is None:
        options = {}
    if index >= len(argv) or argv[index] != flag:
        return None
    next_index = index + 1
    raw_value = argv[next_index] if next_index < len(argv) else ""
    min_val = options.get("min", float("-inf"))
    try:
        parsed = int(raw_value)
        if parsed >= min_val:
            return {"nextIndex": next_index, "value": parsed}
        else:
            return {"nextIndex": next_index, "value": current_value}
    except ValueError:
        return {"nextIndex": next_index, "value": current_value}


def consume_float_flag(
    argv: List[str],
    index: int,
    flag: str,
    current_value: float,
    options: Optional[Dict[str, Any]] = None,
) -> Optional[Dict[str, Union[int, float]]]:
    """Consume a float flag from arguments."""
    if options is None:
        options = {}
    if index >= len(argv) or argv[index] != flag:
        return None
    next_index = index + 1
    raw_value = argv[next_index] if next_index < len(argv) else ""
    min_val = options.get("min", float("-inf"))
    include_min = options.get("includeMin", True)
    try:
        parsed = float(raw_value)
        is_valid = (
            parsed != float('inf') and 
            parsed != float('-inf') and 
            parsed != float('nan')
        )
        if is_valid:
            if include_min and parsed >= min_val:
                return {"nextIndex": next_index, "value": parsed}
            elif not include_min and parsed > min_val:
                return {"nextIndex": next_index, "value": parsed}
        return {"nextIndex": next_index, "value": current_value}
    except ValueError:
        return {"nextIndex": next_index, "value": current_value}


def string_flag(flag: str, key: str):
    """Create a string flag specification."""
    
    def consume(argv: List[str], index: int, args: Dict[str, Any]):
        option = consume_string_flag(argv, index, flag, args.get(key))
        if not option:
            return None
        def apply_func(target):
            target[key] = option["value"]
        return {
            "nextIndex": option["nextIndex"],
            "apply": apply_func,
        }
    return {"consume": consume}


def string_list_flag(flag: str, key: str):
    """Create a string list flag specification."""
    
    def consume(argv: List[str], index: int, args: Dict[str, Any]):
        option = consume_string_list_flag(argv, index, flag)
        if not option:
            return None
        def apply_func(target):
            if option["value"]:
                target[key].append(option["value"])
        return {
            "nextIndex": option["nextIndex"],
            "apply": apply_func,
        }
    return {"consume": consume}


def create_assigned_value_flag(consume_option: Callable) -> dict:
    """Create a flag that assigns a computed value."""
    
    def consume(argv: List[str], index: int, args: Dict[str, Any]):
        option = consume_option(argv, index, args)
        if not option:
            return None
        def apply_func(target):
            target[option["key"]] = option["value"]
        return {
            "nextIndex": option["nextIndex"],
            "apply": apply_func,
        }
    return {"consume": consume}


def int_flag(flag: str, key: str, options=None):
    """Create an integer flag specification."""
    if options is None:
        options = {}
        
    def consume_option(argv, index, args):
        option = consume_int_flag(argv, index, flag, args.get(key, 0), options)
        if option:
            option["key"] = key
        return option
    
    return create_assigned_value_flag(consume_option)


def float_flag(flag: str, key: str, options=None):
    """Create a float flag specification."""
    if options is None:
        options = {}
        
    def consume_option(argv, index, args):
        option = consume_float_flag(argv, index, flag, args.get(key, 0.0), options)
        if option:
            option["key"] = key
        return option
    
    return create_assigned_value_flag(consume_option)


def boolean_flag(flag: str, key: str, value: bool = True):
    """Create a boolean flag specification."""
    
    def consume(argv: List[str], index: int, args: Dict[str, Any]):
        if index >= len(argv) or argv[index] != flag:
            return None
        def apply_func(target):
            target[key] = value
        return {
            "nextIndex": index,
            "apply": apply_func,
        }
    return {"consume": consume}


def parse_flag_args(
    argv: List[str],
    args: Dict[str, Any],
    specs: List[Dict],
    options: Optional[Dict[str, Any]] = None,
):
    """Parse command line arguments according to specifications."""
    if options is None:
        options = {}
    
    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg == "--" and options.get("ignoreDoubleDash"):
            i += 1
            continue
            
        handled = False
        for spec in specs:
            option = spec["consume"](argv, i, args)
            if not option:
                continue
                
            option["apply"](args)
            i = option["nextIndex"]
            handled = True
            break
            
        if handled:
            i += 1
            continue
            
        fallback_result = None
        if options.get("onUnhandledArg"):
            fallback_result = options["onUnhandledArg"](arg, args)
            
        if fallback_result == "handled":
            i += 1
            continue
            
        if not options.get("allowUnknownOptions") and arg.startswith("-"):
            raise ValueError(f"Unknown option: {arg}")
            
        i += 1
        
    return args

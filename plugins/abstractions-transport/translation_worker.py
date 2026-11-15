#!/usr/bin/env python3
"""Experimental JSON/stdin translation worker; not the historical runner.

The launcher must execute this process on the authorized node. --node is an
operator configuration check, not cryptographic proof of execution location.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request

from reconstructed_transport import IDENTITY, INPUTS, MAX_REQUEST_BYTES, MAX_RESPONSE_BYTES

API_URL = "https://openrouter.ai/api/v1/chat/completions"
MODELS = (
    "qwen/qwen3-coder", "deepseek/deepseek-chat-v3.1", "z-ai/glm-4.6",
    "mistralai/codestral-2508", "qwen/qwen-2.5-coder-32b-instruct",
)
ATTEMPTS = 3
MODEL_TIMEOUT = 240


def translate(job, node, api_key, *, opener=urllib.request.urlopen, sleep=time.sleep):
    if not isinstance(job, dict) or any(not isinstance(job.get(k), str) or not job[k].strip()
                                        for k in IDENTITY + INPUTS):
        raise ValueError("invalid job")
    if job["selected_node"] != node:
        raise ValueError("job does not match configured node")
    if not api_key.strip():
        raise ValueError("OPENROUTER_API_KEY is missing")
    hint = job.get("markup_hint", "")
    if not isinstance(hint, str):
        raise ValueError("invalid markup hint")
    prompt = (f"Portiere die folgende Datei {job['source_name']} von {job['source_language']} "
              f"nach {job['target_description']}.\n")
    if hint:
        prompt += hint + "\n"
    prompt += f"\n----- Beginn {job['source_name']} -----\n{job['source_text']}\n----- Ende {job['source_name']} -----"
    settings = job.get("model_settings")
    if settings is None:
        override = os.environ.get("ABSTRACTIONS_MODELL")
        models, attempts, model_timeout = ((override,) if override else MODELS), ATTEMPTS, MODEL_TIMEOUT
    else:
        if not isinstance(settings, dict):
            raise ValueError("invalid model settings")
        models, attempts, model_timeout = (settings.get("models"), settings.get("attempts"),
                                           settings.get("timeout_seconds"))
        if (not isinstance(models, list) or not models or len(models) > 10 or
            any(not isinstance(model, str) or not model.strip() for model in models) or
            type(attempts) is not int or not 1 <= attempts <= 3 or
            type(model_timeout) is not int or not 1 <= model_timeout <= MODEL_TIMEOUT):
            raise ValueError("invalid model settings")
    for model in models:
        for attempt in range(1, attempts + 1):
            payload = {"model": model,
                       "messages": [{"role": "system", "content": job["system_prompt"]},
                                    {"role": "user", "content": prompt}],
                       "temperature": 0.1, "max_tokens": 8000}
            request = urllib.request.Request(API_URL, data=json.dumps(payload).encode("utf-8"), headers={
                "Authorization": "Bearer " + api_key.strip(), "Content-Type": "application/json",
                "HTTP-Referer": "https://github.com/KikiKari/Projects", "X-Title": "Abstractions Manager"})
            try:
                with opener(request, timeout=model_timeout) as result:
                    raw = result.read(MAX_RESPONSE_BYTES + 1)
                if len(raw) > MAX_RESPONSE_BYTES:
                    raise ValueError("model response exceeds limit")
                choice = json.loads(raw)["choices"][0]
                code = choice["message"]["content"]
                if choice.get("finish_reason") != "stop" or not isinstance(code, str) or not code.strip():
                    raise ValueError("model response incomplete")
                return {**{key: job[key] for key in IDENTITY}, "status": "ok", "code": code}
            except urllib.error.HTTPError as error:
                status = error.code
                error.close()
                if status in (400, 401, 402, 404):
                    break
            except (urllib.error.URLError, TimeoutError, ValueError, TypeError, KeyError, IndexError):
                pass
            sleep(min(2 ** attempt, 20))
    raise ValueError("no model returned a complete response")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--node", required=True)
    args = parser.parse_args()
    try:
        raw = sys.stdin.buffer.read(MAX_REQUEST_BYTES + 1)
        if len(raw) > MAX_REQUEST_BYTES:
            raise ValueError("request exceeds limit")
        job = json.loads(raw)
        response = translate(job, args.node, os.environ.get("OPENROUTER_API_KEY", ""))
        encoded = json.dumps(response, ensure_ascii=False).encode("utf-8")
        if len(encoded) > MAX_RESPONSE_BYTES:
            raise ValueError("response exceeds limit")
        sys.stdout.buffer.write(encoded + b"\n")
        return 0
    except (ValueError, TypeError, KeyError, IndexError, OSError, urllib.error.URLError):
        # No request, response, credentials or provider error bodies in logs.
        print("translation worker failed", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
# generate-wavespeed.mjs — portiert nach python
# Quelle: javascript, Onboarding@main:scripts/generate-wavespeed.mjs
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

import asyncio
import base64
import json
import os
import urllib.request
from pathlib import Path


async def main():
    key = os.environ.get("WAVESPEED_API_KEY")
    if not key:
        raise Exception("WAVESPEED_API_KEY fehlt.")

    script_dir = Path(__file__).parent.resolve()
    jobs_path = script_dir.parent / "media-production" / "wavespeed-jobs.json"
    raw_dir = script_dir.parent / "media-production" / "raw"
    public_dir = script_dir.parent / "public" / "media"
    result_url = script_dir.parent / "media-production" / "wavespeed-results.json"

    raw_dir.mkdir(parents=True, exist_ok=True)
    public_dir.mkdir(parents=True, exist_ok=True)

    with open(jobs_path, "r", encoding="utf-8") as f:
        jobs = json.load(f)

    if result_url.exists():
        with open(result_url, "r", encoding="utf-8") as f:
            log = json.load(f)
    else:
        log = []

    for job in jobs:
        raw_path = raw_dir / f"{job['id']}.png"
        target_path = public_dir / f"{job['output']}.png"
        already_generated = raw_path.exists()

        if already_generated:
            if not any(entry["id"] == job["id"] for entry in log):
                log_entry = {
                    "id": job["id"],
                    "requestId": "completed-before-resume",
                    "model": "google/nano-banana-2/edit",
                    "resolution": "4k",
                    "plannedCostUsd": 0.14,
                    "output": target_path.name
                }
                log.append(log_entry)
                with open(result_url, "w", encoding="utf-8") as f:
                    json.dump(log, f, indent=2)
            print(f"Übersprungen: {job['id']} ist bereits vorhanden.")
            continue

        images = []
        for image in job["images"]:
            if image.startswith("http:") or image.startswith("https:") or image.startswith("data:"):
                images.append(image)
            else:
                image_path = script_dir.parent / image
                with open(image_path, "rb") as f:
                    image_data = f.read()
                encoded = base64.b64encode(image_data).decode("utf-8")
                images.append(f"data:image/png;base64,{encoded}")

        request_body = json.dumps({
            "prompt": job["prompt"],
            "images": images,
            "aspect_ratio": job["aspectRatio"],
            "resolution": "4k",
            "output_format": "png",
            "enable_web_search": False,
            "enable_image_search": False,
            "enable_sync_mode": False,
            "enable_base64_output": False,
        }).encode("utf-8")

        req = urllib.request.Request(
            "https://api.wavespeed.ai/api/v3/google/nano-banana-2/edit",
            data=request_body,
            headers={
                "Authorization": f"Bearer {key}",
                "Content-Type": "application/json"
            },
            method="POST"
        )

        try:
            with urllib.request.urlopen(req) as response:
                response_data = response.read()
        except urllib.error.HTTPError as e:
            detail = e.read().decode("utf-8")
            raise Exception(f"WaveSpeed submit fehlgeschlagen: {e.code} {detail}")

        submitted = json.loads(response_data)
        request_id = submitted.get("data", {}).get("id") or submitted.get("id")

        result = None
        for attempt in range(90):
            await asyncio.sleep(4)
            poll_req = urllib.request.Request(
                f"https://api.wavespeed.ai/api/v3/predictions/{request_id}/result",
                headers={"Authorization": f"Bearer {key}"}
            )
            try:
                with urllib.request.urlopen(poll_req) as poll_response:
                    result = json.loads(poll_response.read())
            except:
                continue

            status = result.get("data", {}).get("status")
            if status == "completed":
                break
            if status == "failed":
                raise Exception(f"WaveSpeed job fehlgeschlagen: {job['id']}")

        url = result.get("data", {}).get("outputs", [None])[0]
        if not url:
            raise Exception(f"Kein Output für {job['id']}")

        image_req = urllib.request.Request(url)
        with urllib.request.urlopen(image_req) as img_response:
            image_bytes = img_response.read()

        with open(raw_path, "wb") as f:
            f.write(image_bytes)

        with open(target_path, "wb") as f:
            f.write(image_bytes)

        log_entry = {
            "id": job["id"],
            "requestId": request_id,
            "model": "google/nano-banana-2/edit",
            "resolution": "4k",
            "plannedCostUsd": 0.14,
            "output": target_path.name
        }
        log.append(log_entry)
        with open(result_url, "w", encoding="utf-8") as f:
            json.dump(log, f, indent=2)

        print(f"Abgeschlossen: {job['id']}")

    with open(result_url, "w", encoding="utf-8") as f:
        json.dump(log, f, indent=2)

    total_cost = len(log) * 0.14
    print(f"WaveSpeed abgeschlossen: {len(log)} Assets, geplante Basiskosten ${total_cost:.2f}.")


if __name__ == "__main__":
    asyncio.run(main())

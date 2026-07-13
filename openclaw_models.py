"""Central access to the text/agent models configured by OpenClaw."""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any


DEFAULT_CONFIG_PATH = Path("/home/openclaw/.openclaw/openclaw.json")


class ModelConfigError(RuntimeError):
    """Raised when the OpenClaw model configuration cannot be used safely."""


def _config_path(path: str | Path | None = None) -> Path:
    if path is not None:
        return Path(path)
    return Path(os.environ.get("OPENCLAW_CONFIG", DEFAULT_CONFIG_PATH))


def load_model_config(path: str | Path | None = None) -> dict[str, Any]:
    config_path = _config_path(path)
    try:
        data = json.loads(config_path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ModelConfigError(f"OpenClaw-Konfiguration nicht gefunden: {config_path}") from exc
    except (OSError, json.JSONDecodeError) as exc:
        raise ModelConfigError(f"OpenClaw-Konfiguration ist nicht lesbar: {config_path}: {exc}") from exc

    defaults = data.get("agents", {}).get("defaults", {})
    models = defaults.get("models")
    model_selection = defaults.get("model")
    if not isinstance(models, dict) or not models:
        raise ModelConfigError("agents.defaults.models muss ein nicht-leeres Objekt sein")
    if not isinstance(model_selection, dict):
        raise ModelConfigError("agents.defaults.model muss ein Objekt sein")

    primary = model_selection.get("primary")
    fallbacks = model_selection.get("fallbacks")
    if not isinstance(primary, str) or not primary:
        raise ModelConfigError("agents.defaults.model.primary muss eine Modell-ID sein")
    if not isinstance(fallbacks, list) or not all(isinstance(item, str) and item for item in fallbacks):
        raise ModelConfigError("agents.defaults.model.fallbacks muss eine Liste von Modell-IDs sein")

    unknown = [model_id for model_id in [primary, *fallbacks] if model_id not in models]
    if unknown:
        raise ModelConfigError(f"Primär-/Fallbackmodelle sind nicht registriert: {sorted(set(unknown))}")

    for model_id, details in models.items():
        if not isinstance(model_id, str) or not model_id or not isinstance(details, dict):
            raise ModelConfigError("agents.defaults.models enthält einen ungültigen Eintrag")
        alias = details.get("alias")
        if not isinstance(alias, str) or not alias.strip():
            raise ModelConfigError(f"Alias fehlt für Modell: {model_id}")

    return data


def configured_models(path: str | Path | None = None) -> list[str]:
    """Return primary, fallbacks, then remaining registered models, deduplicated."""
    data = load_model_config(path)
    defaults = data["agents"]["defaults"]
    ordered = [defaults["model"]["primary"], *defaults["model"]["fallbacks"], *defaults["models"].keys()]
    return list(dict.fromkeys(ordered))


def configured_aliases(path: str | Path | None = None) -> dict[str, str]:
    data = load_model_config(path)
    return {
        model_id: details["alias"]
        for model_id, details in data["agents"]["defaults"]["models"].items()
    }

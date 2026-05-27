"""
create_abstraction.py — Erstellt eine einzelne Script-Portierung.

Portiert ein Quell-Script in eine Zielsprache mithilfe eines KI-Modells
und speichert das Ergebnis im Abstraktions-Repository.

Sicherheitsmaßnahmen:
    - Path-Traversal-Schutz via validate_source_file_path()
    - Zielsprachen-Allowlist via validate_target_language()
    - Atomisches Schreiben der Ausgabedatei
    - Hash-basierte Änderungserkennung (kein Re-Processing unveränderter Files)

Verwendung (CLI)::

    python3 create_abstraction.py \\
        --source /path/to/db_maintainer.py \\
        --target-lang perl5

    python3 create_abstraction.py \\
        --source /path/to/json_processor.py \\
        --target-lang javascript \\
        --model openrouter/anthropic/claude-3-5-sonnet-20241022 \\
        --dry-run

Author: OpenClaw Team
Version: 1.0.0
"""

import argparse
import hashlib
import json
import logging
import os
import subprocess
import sys
import tempfile
from pathlib import Path

from dotenv import load_dotenv

from exceptions import PortationError, ValidationError, StateFileError
from validators import (
    validate_source_file_path,
    validate_target_language,
    validate_ai_model_name,
    load_and_validate_api_key,
    ALLOWED_TARGET_LANGUAGES,
)
from logger import configure_application_logging

load_dotenv()

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Pfade
# ---------------------------------------------------------------------------

_WORKSPACE_BASE = Path("/home/openclaw/.openclaw/workspace")
_ABSTRACTIONS_REPO = _WORKSPACE_BASE / "git" / "Abstraktionen"
_STATE_FILE = _WORKSPACE_BASE / "db" / "abstractions_state.json"
_LOG_DIRECTORY = _WORKSPACE_BASE / "logs" / "abstractions-manager"

_DEFAULT_MODEL = "openrouter/anthropic/claude-3-5-sonnet-20241022"

#: Datei-Endungen je Zielsprache
LANGUAGE_FILE_EXTENSIONS: dict[str, str] = {
    "perl5":       ".pl",
    "perl6":       ".raku",
    "javascript":  ".js",
    "python":      ".py",
    "bash":        ".sh",
    "powershell":  ".ps1",
    "tcl":         ".tcl",
    "ruby":        ".rb",
    "lua":         ".lua",
    "go":          ".go",
}


# ---------------------------------------------------------------------------
# Hash / State
# ---------------------------------------------------------------------------

def compute_file_sha256(file_path: Path) -> str:
    """Berechnet den SHA-256 Hash einer Datei (streaming, speicherschonend).

    Args:
        file_path: Pfad zur Datei.

    Returns:
        Hex-String des SHA-256 Hashes.

    Raises:
        FileNotFoundError: Wenn die Datei nicht existiert.
        PermissionError: Wenn keine Leseberechtigung vorhanden ist.
    """
    sha256 = hashlib.sha256()
    with file_path.open("rb") as file_handle:
        for chunk in iter(lambda: file_handle.read(65536), b""):
            sha256.update(chunk)
    return sha256.hexdigest()


def load_abstraction_state(state_file_path: Path) -> dict:
    """Lädt den persistierten Abstraktions-State aus der JSON-Datei.

    Args:
        state_file_path: Pfad zur State-JSON-Datei.

    Returns:
        State-Dictionary. Leeres Dictionary wenn Datei nicht existiert.

    Raises:
        StateFileError: Bei Parse-Fehlern in der State-Datei.
    """
    if not state_file_path.exists():
        logger.info("State-Datei nicht gefunden — starte mit leerem State.")
        return {}

    try:
        with state_file_path.open("r", encoding="utf-8") as state_file:
            return json.load(state_file)
    except json.JSONDecodeError as parse_error:
        raise StateFileError(
            str(state_file_path), "parse", parse_error
        ) from parse_error


def save_abstraction_state_atomically(
    state_file_path: Path,
    updated_state: dict,
) -> None:
    """Speichert den Abstraktions-State atomar (Race-Condition-sicher).

    Schreibt in eine temporäre Datei und ersetzt die Zieldatei dann
    atomar via ``os.replace()`` (POSIX-garantiert atomar).

    Args:
        state_file_path: Pfad zur State-JSON-Datei.
        updated_state: Der zu persistierende State.

    Raises:
        StateFileError: Bei Schreibfehlern.
    """
    state_file_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            dir=state_file_path.parent,
            suffix=".tmp",
            delete=False,
            encoding="utf-8",
        ) as temp_file:
            json.dump(updated_state, temp_file, indent=2, ensure_ascii=False)
            temp_file_path = Path(temp_file.name)

        os.replace(temp_file_path, state_file_path)
        logger.debug("State-Datei atomar geschrieben: %s", state_file_path)

    except OSError as write_error:
        raise StateFileError(
            str(state_file_path), "write", write_error
        ) from write_error


def has_source_file_changed(
    file_path: Path,
    hash_cache: dict,
) -> bool:
    """Prüft ob eine Quelldatei seit dem letzten Lauf geändert wurde.

    Args:
        file_path: Pfad zur zu prüfenden Datei.
        hash_cache: Dictionary mit ``{dateipfad: letzter_hash}``.

    Returns:
        ``True`` wenn Datei neu oder geändert ist, sonst ``False``.
    """
    current_hash = compute_file_sha256(file_path)
    cached_hash = hash_cache.get(str(file_path))
    file_changed = current_hash != cached_hash

    if file_changed:
        logger.debug("Änderung erkannt: %s", file_path.name)
    else:
        logger.debug("Keine Änderung: %s (übersprungen)", file_path.name)

    return file_changed


# ---------------------------------------------------------------------------
# Portierungs-Logik
# ---------------------------------------------------------------------------

def create_single_abstraction(
    source_file_path: Path,
    target_language: str,
    ai_model_name: str = _DEFAULT_MODEL,
    output_repository_path: Path = _ABSTRACTIONS_REPO,
    dry_run: bool = False,
) -> Path:
    """Portiert ein einzelnes Script in eine Zielsprache.

    Liest das Quell-Script, generiert via KI-Modell eine Portierung und
    speichert das Ergebnis im Ziel-Repository mit einem Git-Commit.

    Args:
        source_file_path: Validierter Pfad zum Quell-Script.
        target_language: Validierte Zielsprache (z. B. ``"perl5"``).
        ai_model_name: KI-Modell für die Portierung.
        output_repository_path: Pfad zum Abstraktions-Repository.
        dry_run: Wenn ``True``, wird kein Commit gemacht und die
            Ausgabedatei hat den Suffix ``.dryrun``.

    Returns:
        Pfad zur erstellten Portierungs-Datei.

    Raises:
        PortationError: Wenn die KI-Portierung fehlschlägt.
        OSError: Bei Dateisystem-Fehlern.

    Example:
        >>> output = create_single_abstraction(
        ...     source_file_path=Path("/workspace/scripts/db_maintainer.py"),
        ...     target_language="perl5",
        ... )
        >>> print(output)
        /workspace/git/Abstraktionen/perl5/db_maintainer.pl
    """
    file_extension = LANGUAGE_FILE_EXTENSIONS[target_language]
    output_stem = source_file_path.stem
    output_directory = output_repository_path / target_language
    output_file_path = output_directory / f"{output_stem}{file_extension}"

    if dry_run:
        output_file_path = output_directory / f"{output_stem}{file_extension}.dryrun"

    output_directory.mkdir(parents=True, exist_ok=True)

    logger.info(
        "Starte Portierung: %s → %s (%s)",
        source_file_path.name,
        target_language,
        output_file_path.name,
    )

    # Quellcode lesen
    try:
        source_code = source_file_path.read_text(encoding="utf-8")
    except OSError as read_error:
        raise PortationError(
            source_file_path.name, target_language, read_error
        ) from read_error

    # Portierung via KI (Platzhalter — hier echten API-Call einsetzen)
    try:
        ported_code = _call_ai_portation_api(
            source_code=source_code,
            source_language=_detect_source_language(source_file_path),
            target_language=target_language,
            ai_model_name=ai_model_name,
        )
    except Exception as api_error:
        raise PortationError(
            source_file_path.name, target_language, api_error
        ) from api_error

    # Ausgabedatei atomisch schreiben
    _write_file_atomically(output_file_path, ported_code)

    if not dry_run:
        _commit_portation_to_git(
            repository_path=output_repository_path,
            file_path=output_file_path,
            source_script_name=source_file_path.name,
            target_language=target_language,
        )

    logger.info(
        "Portierung abgeschlossen: %s → %s",
        source_file_path.name,
        output_file_path,
    )
    return output_file_path


def _write_file_atomically(file_path: Path, content: str) -> None:
    """Schreibt eine Textdatei atomar via temporäre Zwischendatei.

    Args:
        file_path: Zielpfad der Ausgabedatei.
        content: Zu schreibender Inhalt.

    Raises:
        OSError: Bei Schreibfehlern.
    """
    with tempfile.NamedTemporaryFile(
        mode="w",
        dir=file_path.parent,
        suffix=".tmp",
        delete=False,
        encoding="utf-8",
    ) as temp_file:
        temp_file.write(content)
        temp_path = Path(temp_file.name)

    os.replace(temp_path, file_path)


def _detect_source_language(file_path: Path) -> str:
    """Erkennt die Quellsprache anhand der Datei-Extension.

    Args:
        file_path: Pfad zur Quelldatei.

    Returns:
        Erkannte Sprache als String (z. B. ``"python"``).
    """
    extension_to_language = {
        ".py": "python",
        ".js": "javascript",
        ".sh": "bash",
        ".pl": "perl5",
        ".raku": "perl6",
        ".rb": "ruby",
        ".go": "go",
        ".lua": "lua",
        ".tcl": "tcl",
        ".ps1": "powershell",
    }
    return extension_to_language.get(file_path.suffix.lower(), "unknown")


def _call_ai_portation_api(
    source_code: str,
    source_language: str,
    target_language: str,
    ai_model_name: str,
) -> str:
    """Ruft die KI-API auf um eine Code-Portierung zu erstellen.

    Args:
        source_code: Quellcode als String.
        source_language: Sprache des Quellcodes.
        target_language: Zielsprache der Portierung.
        ai_model_name: KI-Modell für die Portierung.

    Returns:
        Portierter Code als String.

    Raises:
        Exception: Bei API-Fehlern (wird von Aufrufer in PortationError gewrappt).
    """
    # Hier echten API-Call implementieren (Anthropic/OpenAI SDK)
    # Beispiel-Prompt-Template:
    prompt = (
        f"Port the following {source_language} code to {target_language}. "
        f"Preserve all functionality, add proper error handling, "
        f"and include docstrings/comments. Return only the code.\n\n"
        f"```{source_language}\n{source_code}\n```"
    )
    logger.debug(
        "KI-API-Aufruf: model=%s, source=%s, target=%s, prompt_len=%d",
        ai_model_name, source_language, target_language, len(prompt),
    )
    # TODO: Implementiere echten API-Call
    raise NotImplementedError(
        "KI-API-Integration muss implementiert werden. "
        "Verwende das Anthropic oder OpenAI SDK."
    )


def _commit_portation_to_git(
    repository_path: Path,
    file_path: Path,
    source_script_name: str,
    target_language: str,
) -> None:
    """Commitet eine Portierung ins Git-Repository.

    Args:
        repository_path: Pfad zum Git-Repository.
        file_path: Pfad zur neu erstellten Portierungs-Datei.
        source_script_name: Name des Original-Scripts.
        target_language: Zielsprache der Portierung.

    Raises:
        subprocess.CalledProcessError: Bei Git-Fehlern.
    """
    commit_message = (
        f"Add {target_language} version of {source_script_name}"
    )

    git_add_command = ["git", "-C", str(repository_path), "add", str(file_path)]
    git_commit_command = [
        "git", "-C", str(repository_path),
        "commit", "-m", commit_message,
    ]

    for git_command in [git_add_command, git_commit_command]:
        result = subprocess.run(
            git_command,
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 0:
            logger.error(
                "Git-Fehler: %s\nStdout: %s\nStderr: %s",
                " ".join(git_command),
                result.stdout,
                result.stderr,
            )
            raise subprocess.CalledProcessError(
                result.returncode, git_command, result.stdout, result.stderr
            )

    logger.info("Git-Commit: '%s'", commit_message)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _build_argument_parser() -> argparse.ArgumentParser:
    """Erstellt den CLI-Argument-Parser für create_abstraction.py.

    Returns:
        Konfigurierter ``ArgumentParser``.
    """
    parser = argparse.ArgumentParser(
        description="Erstellt eine einzelne Script-Portierung in eine Zielsprache.",
    )
    parser.add_argument(
        "--source",
        required=True,
        help="Pfad zum Original-Script (muss im Workspace liegen).",
    )
    parser.add_argument(
        "--target-lang",
        required=True,
        choices=sorted(ALLOWED_TARGET_LANGUAGES),
        help="Zielsprache der Portierung.",
    )
    parser.add_argument(
        "--model",
        default=_DEFAULT_MODEL,
        help=f"KI-Modell (Standard: {_DEFAULT_MODEL}).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        default=False,
        help="Erstellt .dryrun-Datei ohne Git-Commit.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        default=False,
        help="Auch portieren wenn keine Änderung erkannt wurde.",
    )
    return parser


def main() -> int:
    """CLI-Hauptfunktion für create_abstraction.py.

    Returns:
        Exit-Code: 0 bei Erfolg, 1 bei Fehler.
    """
    configure_application_logging(log_directory=_LOG_DIRECTORY)
    parser = _build_argument_parser()
    args = parser.parse_args()

    try:
        # Eingaben validieren
        validated_source = validate_source_file_path(args.source)
        validated_language = validate_target_language(args.target_lang)
        validated_model = validate_ai_model_name(args.model)

        # Change-Detection (überspringen wenn --force)
        if not args.force:
            state = load_abstraction_state(_STATE_FILE)
            hash_cache = state.get("file_hashes", {})
            if not has_source_file_changed(validated_source, hash_cache):
                logger.info(
                    "Keine Änderung erkannt — überspringe %s. "
                    "Nutze --force zum Erzwingen.",
                    validated_source.name,
                )
                return 0

        # Portierung durchführen
        output_path = create_single_abstraction(
            source_file_path=validated_source,
            target_language=validated_language,
            ai_model_name=validated_model,
            dry_run=args.dry_run,
        )

        # State aktualisieren
        if not args.dry_run:
            state = load_abstraction_state(_STATE_FILE)
            state.setdefault("file_hashes", {})[str(validated_source)] = (
                compute_file_sha256(validated_source)
            )
            save_abstraction_state_atomically(_STATE_FILE, state)

        print(f"Portierung erstellt: {output_path}")
        return 0

    except (ValidationError, FileNotFoundError) as input_error:
        logger.error("Eingabefehler: %s", input_error)
        print(f"Fehler: {input_error}", file=sys.stderr)
        return 1

    except PortationError as portation_error:
        logger.error("Portierungsfehler: %s", portation_error, exc_info=True)
        print(f"Fehler: {portation_error}", file=sys.stderr)
        return 1

    except Exception as unexpected_error:
        logger.critical(
            "Unerwarteter Fehler: %s", unexpected_error, exc_info=True
        )
        print(f"Unerwarteter Fehler: {unexpected_error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())

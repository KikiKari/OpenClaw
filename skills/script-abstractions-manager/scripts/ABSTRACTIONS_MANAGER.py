#!/usr/bin/env python3
"""
Script Abstractions Manager

Uebersetzt jede Quelldatei aus den drei Repositories KikiKari/OpenClaw,
KikiKari/Projects und KikiKari/Onboarding in zehn Zielsprachen und legt
das Ergebnis in den Sprachverzeichnissen des Abstraktions-Repositories ab.

Es entstehen vollstaendige Uebersetzungen, keine Ruempfe: jede Datei geht
als Ganzes an ein Sprachmodell, das lauffaehigen Code in der Zielsprache
zurueckgibt. Erzeugnisse, deren Syntax sich nicht pruefen laesst oder die
erkennbar unfertig sind, werden verworfen statt abgelegt.

Verwendung:
    python3 ABSTRACTIONS_MANAGER.py [--prioritaet high|medium|low|alle]
                                    [--anzahl N] [--probelauf]

Umgebung:
    OPENROUTER_API_KEY      Pflicht. Schluessel fuer die Uebersetzung.
    ABSTRACTIONS_WORKSPACE  Arbeitsverzeichnis, Vorgabe
                            /home/openclaw/.openclaw/workspace
    ABSTRACTIONS_MODELL     Modellkennung, Vorgabe siehe MODELLE
    ABSTRACTIONS_ANZAHL     Quelldateien je Lauf, Vorgabe 40
"""

from __future__ import annotations

import argparse
import hashlib
import json
import logging
import os
import re
import shutil
import atexit
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from html.parser import HTMLParser
from logging.handlers import RotatingFileHandler
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# ---------------------------------------------------------------------------
# Konfiguration
# ---------------------------------------------------------------------------

WORKSPACE: Path = Path(
    os.environ.get("ABSTRACTIONS_WORKSPACE", "/home/openclaw/.openclaw/workspace")
)
ABSTRACTIONS_REPO: Path = WORKSPACE / "git" / "OpenClaw-gateway1-abstractions"
QUELLEN_DIR: Path = WORKSPACE / "git" / "quellen"
LOG_DIR: Path = WORKSPACE / "logs" / "abstractions-manager"
STATE_FILE: Path = WORKSPACE / "db" / "abstractions_state.json"

GITHUB_BENUTZER = "KikiKari"

# Herkunft der Quelldateien. Projects wird ueber alle Branches gelesen, weil
# dort jedes Projekt in einem eigenen verwaisten Branch liegt.
QUELLEN: List[Dict[str, object]] = [
    {"repo": "OpenClaw",   "branches": ["main", "gateway1", "gateway2"]},
    {"repo": "Projects",   "branches": "alle"},
    {"repo": "Onboarding", "branches": ["main"]},
]

# Dateiendung -> Quellsprache. Bestimmt zugleich, was eingelesen wird.
QUELLSPRACHEN: Dict[str, str] = {
    ".pl": "perl5", ".pm": "perl5",
    ".raku": "perl6", ".rakumod": "perl6",
    ".rb": "ruby", ".lua": "lua", ".go": "go",
    ".ps1": "powershell", ".psm1": "powershell",
    ".sh": "shell", ".bash": "shell",
    ".tcl": "tcl",
    ".html": "html", ".htm": "html",
    ".js": "javascript", ".mjs": "javascript", ".cjs": "javascript",
    ".py": "python",
    ".css": "css",
    ".java": "java", ".c": "c", ".cpp": "cpp", ".cc": "cpp", ".cxx": "cpp",
    ".php": "php", ".fs": "fsharp", ".fsx": "fsharp",
}

# Die zehn Zielverzeichnisse, nach der Vorlage aus
# OpenClaw@gateway1-abstractions. Sie liegen im Wurzelverzeichnis des
# Abstraktions-Repositories.
ZIELSPRACHEN: Dict[str, Dict[str, str]] = {
    "javascript": {"ext": ".js",  "bezeichnung": "JavaScript fuer Node 20"},
    "perl5":      {"ext": ".pl",  "bezeichnung": "Perl 5 mit use strict und use warnings"},
    "powershell": {"ext": ".ps1", "bezeichnung": "PowerShell 7"},
    "python":     {"ext": ".py",  "bezeichnung": "Python 3.12"},
    "shell":      {"ext": ".sh",  "bezeichnung": "Bash 5 mit set -euo pipefail"},
    "tcl":        {"ext": ".tcl", "bezeichnung": "Tcl 8.6"},
    "perl6":      {"ext": ".raku", "bezeichnung": "Raku"},
    "ruby":       {"ext": ".rb", "bezeichnung": "Ruby"},
    "lua":        {"ext": ".lua", "bezeichnung": "Lua"},
    "go":         {"ext": ".go", "bezeichnung": "Go"},
    "java":       {"ext": ".java", "bezeichnung": "Java"},
    "c":          {"ext": ".c", "bezeichnung": "C"},
    "cpp":        {"ext": ".cpp", "bezeichnung": "C++"},
    "php":        {"ext": ".php", "bezeichnung": "PHP"},
    "fsharp":     {"ext": ".fs", "bezeichnung": "F#"},
    "css":        {"ext": ".css", "bezeichnung": "CSS"},
}

# Verzeichnisse und Muster, die nie eingelesen werden.
AUSSCHLUSS: Tuple[str, ...] = (
    "node_modules/", "/.git/", "__pycache__/", "dist/", "build/", "vendor/",
    ".venv/", "site-packages/", "python-hardener-workspace/", ".artifacts/",
    "coverage/", ".next/", "target/", "/work/", "/backups/",
)
MAX_BYTES = 200_000

# Reihenfolge der Ausweichmodelle. Geprueft gegen das Konto: die Anbieter von
# OpenAI und Anthropic sind dort ueber die Privatsphaere-Einstellung
# ausgeschlossen ("All providers have been ignored"), diese hier antworten.
MODELLE: List[str] = [
    "qwen/qwen3-coder",
    "deepseek/deepseek-chat-v3.1",
    "z-ai/glm-4.6",
    "mistralai/codestral-2508",
    "qwen/qwen-2.5-coder-32b-instruct",
]
API_URL = "https://openrouter.ai/api/v1/chat/completions"
ZEITLIMIT = 240
VERSUCHE = 3

# Mindestreserven auf dem Gateway und auf den entfernten Nodes.
GATEWAY_MIN_FREI = 40 * 1024**3
NODE_MIN_FREI = 4 * 1024**3
NODE_STATUS_MAX_ALTER_MS = 300_000


def node_speicherstatus() -> Dict[str, int]:
    """Liefert nur aktuelle freie Bytes, keyed by paired device identity."""
    try:
        result = subprocess.run(["openclaw", "nodes", "status", "--json"],
                                capture_output=True, text=True, timeout=10, check=True)
        status = json.loads(result.stdout)
        timestamp = status.get("ts")
        nodes = status.get("nodes")
        if isinstance(timestamp, bool) or not isinstance(timestamp, (int, float)) or not isinstance(nodes, list):
            return {}
        if abs(time.time() * 1000 - timestamp) > NODE_STATUS_MAX_ALTER_MS:
            return {}
        available = {}
        for node in nodes:
            if not isinstance(node, dict) or node.get("connected") is not True:
                continue
            node_id, stats = node.get("nodeId"), node.get("hostStats")
            if not isinstance(node_id, str) or not node_id or not isinstance(stats, dict):
                continue
            free, updated = stats.get("diskAvailableBytes"), stats.get("updatedAtMs")
            if (isinstance(free, bool) or not isinstance(free, int) or free < 0 or
                isinstance(updated, bool) or not isinstance(updated, (int, float)) or
                abs(timestamp - updated) > NODE_STATUS_MAX_ALTER_MS):
                continue
            available[node_id] = free
        return available
    except (OSError, subprocess.SubprocessError, ValueError, TypeError, AttributeError):
        return {}


def node_hat_reserve(node: str, device_id: str, frei: Dict[str, int]) -> bool:
    """Unbekannte Werte sind nicht als ausreichender Speicher nachgewiesen."""
    if node == "node1":
        try:
            return shutil.disk_usage(WORKSPACE).free >= GATEWAY_MIN_FREI
        except OSError:
            return False
    wert = frei.get(device_id)
    return isinstance(wert, int) and not isinstance(wert, bool) and wert >= NODE_MIN_FREI


# ---------------------------------------------------------------------------
# Protokoll
# ---------------------------------------------------------------------------


def _protokoll() -> logging.Logger:
    """Richtet die Protokollierung nach stdout und, wenn moeglich, in eine Datei ein."""
    log = logging.getLogger("abstractions")
    if log.handlers:
        return log
    log.setLevel(logging.INFO)
    form = logging.Formatter(
        "%(asctime)s | %(levelname)-7s | %(funcName)s:%(lineno)d | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    strom = logging.StreamHandler(sys.stdout)
    strom.setFormatter(form)
    log.addHandler(strom)
    try:
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        datei = RotatingFileHandler(LOG_DIR / "manager.log", maxBytes=2_000_000,
                                    backupCount=3, encoding="utf-8")
        datei.setFormatter(form)
        log.addHandler(datei)
    except OSError as fehler:
        log.warning("Protokolldatei nicht verfuegbar (%s) — es wird nur nach stdout geschrieben", fehler)
    return log


logger = _protokoll()

# ---------------------------------------------------------------------------
# Zustand
# ---------------------------------------------------------------------------


def zustand_laden() -> Dict:
    """Liest den Zustand. Er merkt sich je Quelldatei-Hash die bereits
    erzeugten Zielsprachen, damit ein erneuter Lauf nichts doppelt uebersetzt."""
    if STATE_FILE.exists():
        try:
            return json.loads(STATE_FILE.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as fehler:
            logger.error("Zustand unlesbar (%s) — Lauf wird angehalten", fehler)
            raise
    return {"erledigt": {}, "statistik": {}}


def zustand_speichern(zustand: Dict) -> None:
    """Schreibt den Zustand atomar, damit ein Abbruch ihn nicht zerstoert."""
    try:
        STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
        kennung, pfad = tempfile.mkstemp(dir=STATE_FILE.parent, prefix=".zustand_")
        with os.fdopen(kennung, "w", encoding="utf-8") as griff:
            json.dump(zustand, griff, ensure_ascii=False, indent=1)
        os.replace(pfad, STATE_FILE)
    except OSError as fehler:
        logger.error("Zustand konnte nicht gespeichert werden: %s", fehler)
        raise


# ---------------------------------------------------------------------------
# Quellen holen
# ---------------------------------------------------------------------------


def _git(*argumente: str, verzeichnis: Optional[Path] = None) -> subprocess.CompletedProcess:
    """Fuehrt einen Git-Befehl aus und gibt das Ergebnis zurueck, ohne zu werfen."""
    befehl = ["git"]
    if verzeichnis is not None:
        befehl += ["-C", str(verzeichnis)]
    befehl += list(argumente)
    return subprocess.run(befehl, capture_output=True, text=True, timeout=1800)


def _indizierter_quellbaum(spiegel: Path, repo: str, branch: str) -> Path:
    """Materialisiere nur erfasste Quelltypen aus genau einem Branch-Commit."""
    revision = _git("rev-parse", "--verify", "refs/heads/" + branch + "^{commit}", verzeichnis=spiegel)
    if revision.returncode != 0:
        raise RuntimeError("Branch-Commit nicht verfuegbar")
    sha = revision.stdout.strip()
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise RuntimeError("ungueltiger Branch-Commit")
    listing = subprocess.run(["git", "-C", str(spiegel), "ls-tree", "-r", "-z", "--full-tree", sha],
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=1800, check=True)
    paths = []
    for record in listing.stdout.split(b"\0"):
        if not record:
            continue
        metadata, path = record.split(b"\t", 1)
        if metadata.split(b" ")[1] != b"blob":
            continue
        if Path(os.fsdecode(path)).suffix.lower() in QUELLSPRACHEN:
            paths.append(path)
    parent = QUELLEN_DIR / "indizierte-baeume" / repo
    parent.mkdir(parents=True, exist_ok=True)
    baum = Path(tempfile.mkdtemp(prefix="quelle-", dir=parent))
    try:
        if paths:
            # checkout's pathspec matching can become very expensive with
            # thousands of entries. Use a private Git index and exact NUL-
            # delimited names; never mutate the mirror's shared index.
            with tempfile.TemporaryDirectory(prefix="quellindex-") as index_dir:
                env = dict(os.environ, GIT_INDEX_FILE=str(Path(index_dir) / "index"))
                subprocess.run(["git", "-C", str(spiegel), "read-tree", sha],
                               env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               timeout=1800, check=True)
                subprocess.run(["git", "-C", str(spiegel), "--work-tree", str(baum), "checkout-index", "--stdin", "-z",
                                "--prefix=" + str(baum) + "/"],
                               input=b"\0".join(paths) + b"\0", env=env,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=3000, check=True)
        atexit.register(shutil.rmtree, baum, ignore_errors=True)
        return baum
    except BaseException:
        shutil.rmtree(baum, ignore_errors=True)
        raise


def quellen_holen() -> List[Tuple[str, str, Path]]:
    """
    Holt oder aktualisiert die Quell-Repositories und legt fuer jeden Branch
    einen Arbeitsbaum an.

    Alle drei Repositories sind oeffentlich, es wird daher kein Token benoetigt.

    Returns:
        Liste aus (Repo, Branch, Pfad zum Arbeitsbaum).
    """
    QUELLEN_DIR.mkdir(parents=True, exist_ok=True)
    baeume: List[Tuple[str, str, Path]] = []

    for eintrag in QUELLEN:
        repo = str(eintrag["repo"])
        spiegel = QUELLEN_DIR / f"{repo}.git"
        url = f"https://github.com/{GITHUB_BENUTZER}/{repo}.git"

        if not spiegel.exists():
            logger.info("%s wird geholt", repo)
            ergebnis = _git("clone", "--mirror", "--filter=blob:none", url, str(spiegel))
            if ergebnis.returncode != 0:
                raise RuntimeError(f"{repo}: Quellspiegel konnte nicht geholt werden")
        else:
            ergebnis = _git("remote", "update", "--prune", verzeichnis=spiegel)
            if ergebnis.returncode != 0:
                raise RuntimeError(f"{repo}: Quellspiegel konnte nicht aktualisiert werden")

        gewuenscht = eintrag["branches"]
        if gewuenscht == "alle":
            aus = _git("for-each-ref", "--format=%(refname:short)", "refs/heads", verzeichnis=spiegel)
            branches = [z.strip() for z in aus.stdout.splitlines() if z.strip()]
        else:
            branches = list(gewuenscht)  # type: ignore[arg-type]

        for branch in branches:
            try:
                baum = _indizierter_quellbaum(spiegel, repo, branch)
            except (OSError, RuntimeError, subprocess.SubprocessError) as fehler:
                raise RuntimeError(f"{repo}@{branch}: indizierter Checkout fehlgeschlagen") from fehler
            baeume.append((repo, branch, baum))

    # Lokale Gateway-Skripte gehören zum ursprünglichen Arbeitsumfang und
    # müssen auch dann erfasst werden, wenn der Git-Sync noch aussteht.
    if os.environ.get("ABSTRACTIONS_EXECUTION", "gateway") == "gateway":
        if WORKSPACE.is_dir():
            baeume.append(("workspace", "local", WORKSPACE))
        # CSS-Quellen ausserhalb des Workspace: gesamtes OpenClaw-Verzeichnis.
        if WORKSPACE.parent.is_dir():
            baeume.append(("openclaw-css", "local", WORKSPACE.parent))

    logger.info("Quellen bereit: %d Arbeitsbaeume", len(baeume))
    return baeume


# ---------------------------------------------------------------------------
# Inventar
# ---------------------------------------------------------------------------


def _prioritaet(pfad: str, sprache: str) -> str:
    """
    Ordnet einer Quelldatei ihre Dringlichkeit zu.

    high   Betriebsscripte — alles unterhalb eines scripts-Verzeichnisses.
    medium uebriger ausfuehrbarer Code.
    low    Markup und Stilvorlagen, die nur der Vollstaendigkeit halber
           mituebersetzt werden.
    """
    if sprache in ("html", "css"):
        return "low"
    if pfad.startswith("scripts/") or "/scripts/" in pfad:
        return "high"
    return "medium"


def enthaelt_zugangsdaten(roh: bytes) -> bool:
    muster = rb'(?:sk-or-v1-[A-Za-z0-9_-]{20,}|sk-(?:proj-)?[A-Za-z0-9_-]{20,}|gh[opusr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|ntn_[A-Za-z0-9_]{20,}|tvly-[A-Za-z0-9_-]{20,}|nvapi-[A-Za-z0-9_-]{20,}|tskey-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9_-]{20,}|AKIA[A-Z0-9]{16}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----)'
    if re.search(muster, roh):
        return True
    for name, wert in os.environ.items():
        if any(k in name.upper() for k in ("TOKEN", "SECRET", "PASSWORD", "API_KEY")) and len(wert) >= 12:
            if wert.encode("utf-8") in roh:
                return True
    return False


def css_html_dateien(baum: Path):
    """Durchsucht lokale HTML-Quellen ohne ausgeschlossene Unterbaeume."""
    ausgeschlossen = {".git", "node_modules", "__pycache__", "dist", "build", "vendor", ".venv", "site-packages", "python-hardener-workspace", ".artifacts", "coverage", ".next", "target", "work", "backups", "logs", "log", "db", "state", "tmp", "temp", "cache", ".cache", "artifacts", "secrets", "credentials", ".credentials", "private", ".private"}
    for wurzel, verzeichnisse, dateien in os.walk(baum, followlinks=False):
        verzeichnisse[:] = [d for d in verzeichnisse if d.lower() not in ausgeschlossen]
        for name in dateien:
            if Path(name).suffix.lower() in (".html", ".htm"):
                yield Path(wurzel) / name


def inventar_bauen(baeume: List[Tuple[str, str, Path]]) -> List[Dict]:
    """
    Erfasst alle Quelldateien und fasst inhaltsgleiche Fundstellen zusammen.

    Deduplizierung geschieht ueber den SHA-256 des Inhalts. Eine Datei, die in
    mehreren Branches identisch vorliegt, wird genau einmal uebersetzt; alle
    Fundstellen bleiben als Herkunft vermerkt.

    Returns:
        Nach Dringlichkeit und Name sortierte Liste von Eintraegen.
    """
    dateien: Dict[str, Dict] = {}

    for repo, branch, baum in baeume:
        pfade = css_html_dateien(baum) if repo == "openclaw-css" else baum.rglob("*")
        for pfad in pfade:
            if not pfad.is_file():
                continue
            rel = str(pfad.relative_to(baum)).replace("\\", "/")
            if repo == "openclaw-css":
                # Dieser zusaetzliche Bestand dient ausschliesslich CSS.
                if pfad.suffix.lower() not in (".html", ".htm"):
                    continue
                teile = pfad.relative_to(baum).parts
                if any(t.lower() in ("work", "backups", "logs", "log", "db", "state", "tmp", "temp", "cache", ".cache", "artifacts", "secrets", "credentials", ".credentials", "private", ".private") for t in teile):
                    continue
                if any(teile[i:i+2] in (("git", "Abstraktionen"), ("git", "OpenClaw-gateway1-abstractions"), ("git", "quellen")) for i in range(len(teile)-1)):
                    continue
                try:
                    pfad.resolve().relative_to(baum.resolve())
                except (OSError, ValueError):
                    continue
            if repo == "workspace":
                # Ausgaben nicht als neue Quellen erneut übersetzen; die
                # Repository-Arbeitsbäume werden separat erfasst.
                teile = pfad.relative_to(baum).parts
                if teile[:2] in (("git", "Abstraktionen"), ("git", "OpenClaw-gateway1-abstractions"), ("git", "quellen")):
                    continue
                if any(t.lower() in ("work", "backups", "logs", "log", "db", "state", "tmp", "temp", "cache", ".cache", "artifacts", ".openclaw", "secrets", "credentials", ".credentials", "private", ".private") for t in teile):
                    continue
                try:
                    pfad.resolve().relative_to(baum.resolve())
                except (OSError, ValueError):
                    continue
            if any(muster in "/" + rel for muster in AUSSCHLUSS):
                continue
            sprache = QUELLSPRACHEN.get(pfad.suffix.lower())
            if sprache is None:
                continue
            try:
                roh = pfad.read_bytes()
            except OSError:
                continue
            if not roh.strip() or enthaelt_zugangsdaten(roh):
                continue

            schluessel = hashlib.sha256(roh).hexdigest()[:16]
            eintrag = dateien.get(schluessel)
            if eintrag is None:
                eintrag = {
                    "hash": schluessel,
                    "name": pfad.name,
                    "stamm": pfad.stem,
                    "sprache": sprache,
                    "bytes": len(roh),
                    "pfad": str(pfad),
                    "herkunft": [],
                    "prioritaet": _prioritaet(rel, sprache),
                    "css_only": repo == "openclaw-css",
                }
                dateien[schluessel] = eintrag
            elif repo != "openclaw-css":
                eintrag["css_only"] = False
            eintrag["herkunft"].append(f"{repo}@{branch}:{rel}")

    rang = {"high": 0, "medium": 1, "low": 2}
    liste = sorted(dateien.values(), key=lambda e: (rang[e["prioritaet"]], e["name"]))
    logger.info("Inventar: %d eindeutige Quelldateien aus %d Fundstellen",
                len(liste), sum(len(e["herkunft"]) for e in liste))
    return liste

# ---------------------------------------------------------------------------
# Uebersetzung
# ---------------------------------------------------------------------------

ANWEISUNG = """Du portierst Quellcode zwischen Programmiersprachen.

Regeln:
1. Gib ausschliesslich den vollstaendigen Code der Zielsprache aus. Keine
   Erklaerung davor oder danach, keine Code-Zaeune.
2. Uebersetze die gesamte Funktionalitaet. Kein TODO, kein "hier waere",
   kein leerer Rumpf, kein Platzhalter.
3. Erhalte Verhalten, Ein- und Ausgaben, Aufrufparameter und Rueckgabewerte.
4. Verwende die Mittel der Zielsprache statt einer woertlichen Abschrift.
   Wo eine Bibliothek fehlt, loese es mit Bordmitteln der Zielsprache.
5. Kommentare uebernimmst du sinngemaess in der Sprache des Originals.
6. Beginne mit der passenden Shebang-Zeile."""

MARKUP_HINWEIS = """Das Original ist {sprache}. Erzeuge ein Programm in der
Zielsprache, das dieses Dokument erzeugt und ueber einen Parameter in eine
Datei schreibt — kein blosses Einbetten als Zeichenkette, sondern eine
nachvollziehbare Erzeugung der Struktur."""

CSS_HINWEIS = "Erzeuge ausschliesslich CSS aus den vorhandenen Stilinformationen des HTML-Dokuments. Erfinde keine Anwendungslogik."


class _StilSuche(HTMLParser):
    def __init__(self):
        super().__init__()
        self.gefunden = False
        self.im_style = False

    def handle_starttag(self, tag, attrs):
        if tag.lower() == "style":
            self.im_style = True
        if any(k.lower() == "style" and v and v.strip() for k, v in attrs):
            self.gefunden = True

    def handle_data(self, data):
        if self.im_style and data.strip():
            self.gefunden = True

    def handle_endtag(self, tag):
        if tag.lower() == "style":
            self.im_style = False


def zielsprachen_fuer(quellsprache: str, quelle: Optional[str] = None) -> List[str]:
    """CSS ist nur fuer HTML-Quellen vorgesehen, nicht fuer Skriptlogik."""
    css = quellsprache == "html"
    if css and quelle is not None:
        parser = _StilSuche()
        parser.feed(quelle)
        css = parser.gefunden
    return [z for z in ZIELSPRACHEN if z != quellsprache and (z != "css" or css)]


def system_anweisung(zielsprache: str) -> str:
    if zielsprache in ("java", "c", "cpp", "php", "fsharp", "css"):
        return ANWEISUNG.replace("6. Beginne mit der passenden Shebang-Zeile.",
                                 "6. Gib Quelltext im gueltigen Format der Zielsprache aus; verwende keine Shebang-Zeile.")
    return ANWEISUNG


def markup_hinweis(quellsprache: str, zielsprache: str) -> str:
    if zielsprache == "css":
        return CSS_HINWEIS
    return MARKUP_HINWEIS.format(sprache=quellsprache.upper()) if quellsprache in ("html", "css") else ""


def _zaeune_entfernen(text: str) -> str:
    """Loest Code aus Markdown-Zaeunen, falls das Modell welche gesetzt hat."""
    zeilen = text.strip().splitlines()
    if zeilen and zeilen[0].lstrip().startswith("```"):
        zeilen = zeilen[1:]
        while zeilen and not zeilen[-1].lstrip().startswith("```"):
            if zeilen[-1].strip():
                break
            zeilen.pop()
        if zeilen and zeilen[-1].lstrip().startswith("```"):
            zeilen.pop()
    return "\n".join(zeilen).strip() + "\n"


def _modell_code_bereinigen(text: str, zielsprache: str) -> str:
    code = _zaeune_entfernen(text)
    # Go source files cannot contain the shebang requested in the shared prompt.
    if zielsprache in ("go", "java", "c", "cpp", "fsharp", "css") and code.startswith("#!"):
        code = code.partition("\n")[2]
    return code


def modell_fragen(quelle: str, quellsprache: str, zielsprache: str,
                  name: str, schluessel: str) -> Optional[str]:
    """
    Laesst eine Quelldatei in die Zielsprache uebersetzen.

    Bei Fehlschlag wird mit wachsender Wartezeit wiederholt und danach auf
    das naechste Modell der Liste ausgewichen.

    Returns:
        Der uebersetzte Code, oder None wenn kein Modell geantwortet hat.
    """
    ziel = ZIELSPRACHEN[zielsprache]["bezeichnung"]
    auftrag = f"Portiere die folgende Datei {name} von {quellsprache} nach {ziel}.\n"
    hinweis = markup_hinweis(quellsprache, zielsprache)
    if hinweis:
        auftrag += hinweis + "\n"
    auftrag += f"\n----- Beginn {name} -----\n{quelle}\n----- Ende {name} -----"

    modelle = [os.environ["ABSTRACTIONS_MODELL"]] if os.environ.get("ABSTRACTIONS_MODELL") else MODELLE

    for modell in modelle:
        for versuch in range(1, VERSUCHE + 1):
            rumpf = json.dumps({
                "model": modell,
                "messages": [
                    {"role": "system", "content": system_anweisung(zielsprache)},
                    {"role": "user", "content": auftrag},
                ],
                "temperature": 0.1,
                "max_tokens": 8000,
            }).encode("utf-8")
            anfrage = urllib.request.Request(API_URL, data=rumpf, headers={
                "Authorization": f"Bearer {schluessel}",
                "Content-Type": "application/json",
                "HTTP-Referer": "https://github.com/KikiKari/Projects",
                "X-Title": "Abstractions Manager",
            })
            try:
                with urllib.request.urlopen(anfrage, timeout=ZEITLIMIT) as antwort:
                    daten = json.loads(antwort.read().decode("utf-8"))
                inhalt = daten["choices"][0]["message"]["content"]
                if inhalt and inhalt.strip():
                    return _modell_code_bereinigen(inhalt, zielsprache)
                logger.warning("%s -> %s: leere Antwort von %s", name, zielsprache, modell)
            except urllib.error.HTTPError as fehler:
                text = fehler.read().decode("utf-8", "replace")[:200]
                logger.warning("%s -> %s: HTTP %s von %s (%s)",
                               name, zielsprache, fehler.code, modell, text)
                if fehler.code in (400, 401, 402, 404):
                    break
            except (urllib.error.URLError, TimeoutError, KeyError, json.JSONDecodeError) as fehler:
                logger.warning("%s -> %s: %s bei %s", name, zielsprache, type(fehler).__name__, modell)
            time.sleep(min(2 ** versuch, 20))

    logger.error("%s -> %s: kein Modell hat geliefert", name, zielsprache)
    return None


# ---------------------------------------------------------------------------
# Pruefung der Erzeugnisse
# ---------------------------------------------------------------------------

PRUEFBEFEHLE: Dict[str, List[str]] = {
    "javascript": ["node", "--check"],
    "perl5":      ["perl", "-c"],
    "powershell": ["pwsh", "-NoProfile", "-Command"],
    "shell":      ["bash", "-n"],
    "tcl":        ["tclsh"],
    "perl6":      ["raku", "-c"],
    "ruby":       ["ruby", "-c"],
    "lua":        ["luac", "-p"],
    "go":         ["gofmt", "-e"],
}

VERDACHT = ("TODO: Implementiere", "TODO: implement", "not implemented",
            "hier waere", "Platzhalter", "your code here", "pass  # TODO")

PARSER_SPRACHEN = frozenset({"java", "c", "cpp", "php", "fsharp", "css"})


def verfuegbare_parser() -> set:
    try:
        from tree_sitter_language_pack import available_languages
        return PARSER_SPRACHEN.intersection(available_languages())
    except (ImportError, OSError):
        return set()


PARSER_PROGRAMM = r'''import sys
from tree_sitter_language_pack import available_languages, get_parser
if sys.argv[1] not in available_languages():
    sys.exit(2)
tree = get_parser(sys.argv[1]).parse(sys.stdin.buffer.read())
sys.exit(1 if tree.root_node.has_error else 0)
'''


def erzeugnis_pruefen(code: str, zielsprache: str, quelle: str = "") -> Tuple[bool, str]:
    """
    Prueft ein Erzeugnis auf Brauchbarkeit.

    Zuerst inhaltlich: erkennbar Unfertiges wird abgelehnt, ebenso ein
    Erzeugnis, das gegenueber der Quelle auffaellig zusammengeschrumpft ist.
    Die Mindestlaenge richtet sich nach der Quelle — ein dreizeiliger Aufrufer
    darf auch in der Zielsprache drei Zeilen haben.

    Danach wird die Syntax mit dem passenden Interpreter geprueft. Ist die
    Pruefung nicht moeglich, wird das Erzeugnis nicht als validiert angenommen.

    Returns:
        (angenommen, Begruendung)
    """
    quellzeilen = len(quelle.splitlines())
    zeilen = len([z for z in code.strip().splitlines() if z.strip()])
    mindestens = max(2, min(6, quellzeilen // 3)) if quellzeilen else 5
    if zeilen < mindestens:
        return False, f"zu kurz ({zeilen} statt mindestens {mindestens} Zeilen)"

    # Ein Platzhalter zaehlt nur dann als Mangel, wenn er nicht schon im
    # Original steht. Sonst faellt jede treue Uebersetzung einer Datei durch,
    # die selbst Vorlagen mit TODO erzeugt.
    niedrig = quelle.lower()
    for muster in VERDACHT:
        if muster.lower() in code.lower() and muster.lower() not in niedrig:
            return False, f"unfertig ({muster})"

    if zielsprache == "python":
        try:
            compile(code, "<erzeugnis>", "exec")
            return True, "syntax ok"
        except SyntaxError as fehler:
            return False, f"Syntaxfehler Zeile {fehler.lineno}"

    if zielsprache in PARSER_SPRACHEN:
        if zielsprache == "php" and not code.startswith("<?php"):
            return False, "PHP-Datei muss mit <?php beginnen"
        try:
            pruefung = subprocess.run([sys.executable, "-c", PARSER_PROGRAMM, zielsprache],
                                      input=code, capture_output=True, text=True, timeout=30)
            if pruefung.returncode == 0:
                return True, "Syntaxbaum ohne Fehler"
            if pruefung.returncode == 1 and not pruefung.stderr:
                return False, "Syntaxfehler im Syntaxbaum"
            return False, "Syntaxpruefer oder Grammatik nicht verfuegbar"
        except (OSError, subprocess.TimeoutExpired):
            return False, "Syntaxpruefung nicht moeglich"

    befehl = PRUEFBEFEHLE.get(zielsprache)
    if not befehl:
        return False, "kein Syntaxpruefer konfiguriert"

    endung = ZIELSPRACHEN[zielsprache]["ext"]
    pfad = None
    try:
        kennung, pfad = tempfile.mkstemp(suffix=endung)
        with os.fdopen(kennung, "w", encoding="utf-8") as griff:
            griff.write(code)
        if zielsprache == "powershell":
            aufruf = befehl + [f"$null = [ScriptBlock]::Create((Get-Content -Raw '{pfad}'))"]
        elif zielsprache == "tcl":
            aufruf = ["tclsh", "/dev/stdin", pfad]
            pruefskript = ('if {[catch {set f [open [lindex $argv 0]]; '
                           'set code [read $f]; close $f; info complete $code} complete] '
                           '|| !$complete} {exit 1}\n')
            ergebnis = subprocess.run(aufruf, input=pruefskript,
                                      capture_output=True, text=True, timeout=30)
            return (ergebnis.returncode == 0), ("Tcl-Befehle vollstaendig" if ergebnis.returncode == 0 else "Tcl-Befehle unvollstaendig")
        else:
            aufruf = befehl + [pfad]
        ergebnis = subprocess.run(aufruf, capture_output=True, text=True, timeout=30)
        if ergebnis.returncode == 0:
            return True, "syntax ok"

        meldung = (ergebnis.stderr or ergebnis.stdout).strip()
        # Eine fehlende Fremdbibliothek ist kein Mangel des Erzeugnisses,
        # sondern eine Luecke dieser Pruefumgebung. perl -c und node --check
        # brechen dann ab, obwohl die Syntax stimmt.
        if "Can't locate" in meldung or "Cannot find module" in meldung:
            return False, "Fremdmodul fehlt hier — Syntax nicht abschliessend geprueft"
        erste = meldung.splitlines()[0][:90] if meldung.splitlines() else "unbekannt"
        return False, "Syntaxfehler: " + erste
    except FileNotFoundError:
        return False, "Interpreter fehlt — Syntaxpruefung nicht moeglich"
    except (OSError, subprocess.TimeoutExpired, IndexError):
        return False, "Syntaxpruefung nicht moeglich"
    finally:
        if pfad is not None:
            try:
                os.unlink(pfad)
            except OSError:
                pass

# ---------------------------------------------------------------------------
# Ablage
# ---------------------------------------------------------------------------


def _zieldatei(eintrag: Dict, zielsprache: str, belegt: Dict[str, str]) -> Path:
    """
    Bestimmt den Dateinamen im Sprachverzeichnis.

    Zwei verschiedene Quelldateien koennen denselben Stamm tragen — etwa
    db_manager.py in OpenClaw und in Projects. In dem Fall wird der zweite
    Name um die ersten sechs Stellen des Inhalts-Hashes ergaenzt, damit
    nichts still ueberschrieben wird.
    """
    endung = ZIELSPRACHEN[zielsprache]["ext"]
    stamm = eintrag["stamm"]
    schluessel = f"{zielsprache}/{stamm}"
    vorher = belegt.get(schluessel)
    if vorher is not None and vorher != eintrag["hash"]:
        stamm = f"{stamm}_{eintrag['hash'][:6]}"
    else:
        belegt[schluessel] = eintrag["hash"]
    verzeichnis = ABSTRACTIONS_REPO / zielsprache
    ziel = verzeichnis / f"{stamm}{endung}"
    if os.path.lexists(ziel):
        stamm = f"{eintrag['stamm']}_{eintrag['hash'][:6]}"
        ziel = verzeichnis / f"{stamm}{endung}"
        zaehler = 2
        while os.path.lexists(ziel):
            ziel = verzeichnis / f"{stamm}_{zaehler}{endung}"
            zaehler += 1
    return ziel


def _kopf(eintrag: Dict, zielsprache: str) -> str:
    """Setzt den Herkunftsvermerk als Kommentar in der Zielsprache."""
    zeichen = "//" if zielsprache in ("javascript", "go", "java", "c", "cpp", "php", "fsharp") else "--" if zielsprache == "lua" else "#"
    if zielsprache == "css":
        zeichen = "/*"
    heute = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    zeilen = [
        f"{zeichen} {eintrag['name']} — portiert nach {zielsprache}",
        f"{zeichen} Quelle: {eintrag['sprache']}, {eintrag['herkunft'][0]}",
    ]
    for weitere in eintrag["herkunft"][1:4]:
        zeilen.append(f"{zeichen} auch in: {weitere}")
    if len(eintrag["herkunft"]) > 4:
        zeilen.append(f"{zeichen} auch in: {len(eintrag['herkunft']) - 4} weiteren Fundstellen")
    zeilen.append(f"{zeichen} Erzeugt: {heute} durch ABSTRACTIONS_MANAGER.py")
    if zielsprache == "css":
        zeilen = [zeile.replace("*/", "* /") + " */" for zeile in zeilen]
    return "\n".join(zeilen) + "\n"


def ablegen(eintrag: Dict, zielsprache: str, code: str, belegt: Dict[str, str], quelle: str = "") -> Optional[Path]:
    """Schreibt ein geprueftes Erzeugnis atomar in sein Sprachverzeichnis."""
    ziel = _zieldatei(eintrag, zielsprache, belegt)
    try:
        ziel.parent.mkdir(parents=True, exist_ok=True)
        zeilen = code.splitlines()
        if zielsprache == "php":
            if not code.startswith("<?php"):
                return None
            inhalt = "<?php\n" + _kopf(eintrag, zielsprache) + code[len("<?php"):].lstrip("\n")
        elif zeilen and zeilen[0].startswith("#!"):
            inhalt = zeilen[0] + "\n" + _kopf(eintrag, zielsprache) + "\n" + "\n".join(zeilen[1:]).lstrip("\n") + "\n"
        else:
            inhalt = _kopf(eintrag, zielsprache) + "\n" + code
        # The marker and digest travel with the artifact. This permits recovery
        # if the process stops after os.replace but before saving its state.
        if eintrag.get("source_sha256"):
            prefix = "//" if zielsprache in ("javascript", "go", "java", "c", "cpp", "php", "fsharp") else "--" if zielsprache == "lua" else "/*" if zielsprache == "css" else "#"
            metadata = {"source_sha256": eintrag["source_sha256"], "target_language": zielsprache,
                        "artifact_sha256": hashlib.sha256(inhalt.encode("utf-8")).hexdigest()}
            markierung = prefix + " abstraction-provenance: " + json.dumps(metadata, sort_keys=True) + (" */" if zielsprache == "css" else "") + "\n"
            if inhalt.startswith(("#!", "<?php\n")):
                erste, rest = inhalt.split("\n", 1)
                inhalt = erste + "\n" + markierung + rest
            else:
                inhalt = markierung + inhalt
        if zielsprache in PARSER_SPRACHEN:
            gueltig, grund = erzeugnis_pruefen(inhalt, zielsprache, quelle)
            if not gueltig:
                logger.warning("%s: Erzeugnis nach Herkunftsvermerk ungueltig (%s)", ziel, grund)
                return None
        kennung, pfad = tempfile.mkstemp(dir=ziel.parent, prefix=".neu_",
                                         suffix=ZIELSPRACHEN[zielsprache]["ext"])
        with os.fdopen(kennung, "w", encoding="utf-8") as griff:
            griff.write(inhalt)
        os.replace(pfad, ziel)
        return ziel
    except OSError as fehler:
        logger.error("%s konnte nicht abgelegt werden: %s", ziel, fehler)
        return None


def vorhandenes_erzeugnis(eintrag: Dict, zielsprache: str, quelle: str) -> Optional[Path]:
    """Find one intact, validated artifact for this exact source and target."""
    verzeichnis = ABSTRACTIONS_REPO / zielsprache
    if not verzeichnis.is_dir():
        return None
    marker = " abstraction-provenance: "
    funde = []
    for pfad in verzeichnis.glob("*" + ZIELSPRACHEN[zielsprache]["ext"]):
        try:
            inhalt = pfad.read_text(encoding="utf-8")
            zeilen = inhalt.splitlines(keepends=True)
            indices = [i for i, zeile in enumerate(zeilen[:2]) if marker in zeile]
            if len(indices) != 1:
                continue
            index = indices[0]
            daten = json.loads(zeilen[index].split(marker, 1)[1].removesuffix("\n").removesuffix(" */"))
            ohne_marker = "".join(zeilen[:index] + zeilen[index + 1:])
            if (daten.get("source_sha256") != eintrag["source_sha256"] or
                daten.get("target_language") != zielsprache or
                daten.get("artifact_sha256") != hashlib.sha256(ohne_marker.encode("utf-8")).hexdigest()):
                continue
            if erzeugnis_pruefen(ohne_marker, zielsprache, quelle)[0]:
                funde.append((pfad, daten["artifact_sha256"]))
        except (OSError, UnicodeError, ValueError, TypeError, AttributeError):
            continue
    if len({digest for _, digest in funde}) > 1:
        raise RuntimeError("mehrere unterschiedliche gueltige Erzeugnisse fuer dieselbe Quelle")
    return funde[0][0] if funde else None


# ---------------------------------------------------------------------------
# Durchlauf
# ---------------------------------------------------------------------------


def uebersetzen(inventar: List[Dict], zustand: Dict, prioritaet: str,
                anzahl: int, probelauf: bool, schluessel: str,
                dispatcher=None, transport=None, state_saver=None) -> Dict[str, int]:
    """
    Arbeitet das Inventar ab und erzeugt fehlende Uebersetzungen.

    Jede Quelldatei wird in alle Zielsprachen ausser ihrer eigenen portiert.
    Bereits erledigte Paare aus dem Zustand werden uebersprungen, ebenso
    Zieldateien, die schon vorliegen.

    Returns:
        Zaehlwerk mit erzeugt, uebersprungen und verworfen.
    """
    zaehler = {"erzeugt": 0, "uebersprungen": 0, "verworfen": 0, "dateien": 0}
    belegt: Dict[str, str] = {}
    erledigt = zustand.setdefault("erledigt", {})
    parser_verfuegbar = verfuegbare_parser() if not probelauf else PARSER_SPRACHEN
    fehlend = PARSER_SPRACHEN - parser_verfuegbar
    if fehlend:
        logger.warning("Ziele ohne verfuegbaren Syntaxpruefer werden uebersprungen: %s", ", ".join(sorted(fehlend)))

    offen = [e for e in inventar if prioritaet == "alle" or e["prioritaet"] == prioritaet]
    cursor = zustand.get("auswahl_cursor", {}).get(prioritaet)
    if cursor:
        position = next((i for i, e in enumerate(offen) if e["hash"] == cursor), None)
        if position is not None:
            offen = offen[position + 1:] + offen[:position + 1]
    logger.info("Prioritaet %s: %d Quelldateien im Bestand", prioritaet, len(offen))

    for eintrag in offen:
        if zaehler["dateien"] >= anzahl:
            logger.info("Kontingent von %d Quelldateien erreicht", anzahl)
            break

        fertig = set(erledigt.get(eintrag["hash"], []))
        ziele = [z for z in zielsprachen_fuer(eintrag["sprache"]) if z not in fertig and z not in fehlend]
        if eintrag.get("css_only"):
            ziele = [z for z in ziele if z == "css"]
        if not ziele:
            continue

        if eintrag["bytes"] > MAX_BYTES:
            logger.warning("%s: %d Bytes überschreiten das Auftragslimit von %d Bytes", eintrag["name"], eintrag["bytes"], MAX_BYTES)
            zaehler["verworfen"] += 1
            continue

        try:
            roh = Path(eintrag["pfad"]).read_bytes()
            if enthaelt_zugangsdaten(roh):
                logger.warning("%s enthaelt Zugangsdaten und wird nicht gesendet", eintrag["name"])
                zaehler["verworfen"] += 1
                continue
            quelle = roh.decode("utf-8", errors="replace")
            ziele = [z for z in ziele if z in zielsprachen_fuer(eintrag["sprache"], quelle)]
            if not ziele:
                continue
            eintrag = {**eintrag, "source_sha256": hashlib.sha256(roh).hexdigest()}
        except OSError as fehler:
            logger.warning("%s nicht lesbar: %s", eintrag["name"], fehler)
            continue

        zaehler["dateien"] += 1
        if not probelauf:
            zustand.setdefault("auswahl_cursor", {})[prioritaet] = eintrag["hash"]
        if not probelauf:
            for zielsprache in list(ziele):
                vorhanden = vorhandenes_erzeugnis(eintrag, zielsprache, quelle)
                if vorhanden:
                    fertig.add(zielsprache)
                    erledigt[eintrag["hash"]] = sorted(fertig)
                    if state_saver:
                        from github_publisher import queue_artifact
                        queue_artifact(zustand, ABSTRACTIONS_REPO, vorhanden)
                        state_saver(zustand)
                    ziele.remove(zielsprache)
                    zaehler["uebersprungen"] += 1
            if not ziele:
                continue
        logger.info("[%s] %s (%s, %d B) -> %s",
                    eintrag["prioritaet"], eintrag["name"], eintrag["sprache"],
                    eintrag["bytes"], ", ".join(ziele))

        plan = None
        if dispatcher is not None and not probelauf:
            plan = dispatcher.dispatch(Path(eintrag["pfad"]), ziele,
                                       source_text=quelle,
                                       source_language=eintrag["sprache"])

        for index, zielsprache in enumerate(ziele):
            if probelauf:
                logger.info("  %s: Probelauf, nichts gesendet", zielsprache)
                zaehler["uebersprungen"] += 1
                continue

            if plan is None:
                code = modell_fragen(quelle, eintrag["sprache"], zielsprache,
                                     eintrag["name"], schluessel)
            else:
                try:
                    job = plan["translation_jobs"][index]
                    if job["target_language"] != zielsprache:
                        raise ValueError("dispatch plan language mismatch")
                    job["source_name"] = eintrag["name"]
                    job["source_sha256"] = eintrag["source_sha256"]
                    if hasattr(dispatcher, "node_ids"):
                        job["selected_device_id"] = dispatcher.node_ids.get(job["selected_node"])
                    job["target_description"] = ZIELSPRACHEN[zielsprache]["bezeichnung"]
                    job["system_prompt"] = system_anweisung(zielsprache)
                    override = os.environ.get("ABSTRACTIONS_MODELL")
                    job["model_settings"] = {"models": [override] if override else list(MODELLE),
                                             "attempts": VERSUCHE, "timeout_seconds": ZEITLIMIT}
                    job["markup_hint"] = markup_hinweis(eintrag["sprache"], zielsprache)
                    previous = zustand.get("auftraege", {}).get(eintrag["source_sha256"] + ":" + zielsprache)
                    if isinstance(previous, dict) and previous.get("status") != "rejected" and isinstance(previous.get("job"), dict):
                        job.update(previous["job"])
                    code = dispatcher.execute_translation(job, transport)
                    code = _modell_code_bereinigen(code, zielsprache)
                except OSError:
                    raise
                except Exception as fehler:
                    logger.warning("  %s: Transport fehlgeschlagen (%s)", zielsprache, type(fehler).__name__)
                    code = None
            if code is None:
                zaehler["verworfen"] += 1
                continue

            angenommen, grund = erzeugnis_pruefen(code, zielsprache, quelle)
            if not angenommen:
                logger.warning("  %s: verworfen — %s", zielsprache, grund)
                # Missing validation tools/dependencies do not make a new model
                # response useful: keep this result for a later recheck.
                pruefung_nicht_moeglich = ("Interpreter fehlt" in grund or
                                          "Fremdmodul fehlt" in grund or
                                          "Syntaxpruefer oder Grammatik nicht verfuegbar" in grund or
                                          "Syntaxpruefung nicht moeglich" in grund)
                if not pruefung_nicht_moeglich and transport is not None and hasattr(transport, "reject"):
                    transport.reject(job, grund)
                zaehler["verworfen"] += 1
                continue

            ziel = ablegen(eintrag, zielsprache, code, belegt, quelle)
            if ziel is None:
                zaehler["verworfen"] += 1
                continue

            logger.info("  %s: %s (%s)", zielsprache, ziel.name, grund)
            zaehler["erzeugt"] += 1
            fertig.add(zielsprache)
            erledigt[eintrag["hash"]] = sorted(fertig)
            if state_saver:
                from github_publisher import queue_artifact
                queue_artifact(zustand, ABSTRACTIONS_REPO, ziel)
                state_saver(zustand)

        erledigt[eintrag["hash"]] = sorted(fertig)

    return zaehler

# ---------------------------------------------------------------------------
# Bericht und Veroeffentlichung
# ---------------------------------------------------------------------------


def bericht_schreiben(inventar: List[Dict], zustand: Dict, zaehler: Dict[str, int]) -> bool:
    """Schreibt STATUS.md im Abstraktions-Repository fort."""
    if not ABSTRACTIONS_REPO.exists():
        logger.warning("Abstraktions-Repository fehlt: %s", ABSTRACTIONS_REPO)
        return False

    je_sprache = {}
    for sprache in ZIELSPRACHEN:
        verzeichnis = ABSTRACTIONS_REPO / sprache
        je_sprache[sprache] = sum(1 for p in verzeichnis.iterdir() if p.is_file()) \
            if verzeichnis.is_dir() else 0

    rang = {"high": 0, "medium": 1, "low": 2}
    je_prio = {p: sum(1 for e in inventar if e["prioritaet"] == p) for p in rang}
    erledigt = zustand.get("erledigt", {})
    offen = 0
    for e in inventar:
        quelle = None
        if e["sprache"] == "html":
            try:
                quelle = Path(e["pfad"]).read_text(encoding="utf-8", errors="replace")
            except OSError:
                quelle = ""
        ziele = set(zielsprachen_fuer(e["sprache"], quelle))
        if e.get("css_only"):
            ziele.intersection_update({"css"})
        offen += len(ziele - set(erledigt.get(e["hash"], [])))

    zeilen = [
        "# Script Abstractions — Status",
        "",
        f"**Letzter Lauf:** {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M')} UTC",
        "",
        "Quelldateien werden in die jeweils geeigneten Zielsprachen portiert.",
        "Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige",
        "Syntax oder mit Platzhaltern werden verworfen.",
        "",
        "## Bestand",
        "",
        "| Zielsprache | Dateien |",
        "|---|---:|",
    ]
    zeilen += [f"| {s} | {a} |" for s, a in sorted(je_sprache.items())]
    zeilen += [
        f"| **gesamt** | **{sum(je_sprache.values())}** |",
        "",
        "## Quellen",
        "",
        "| Prioritaet | Quelldateien | Bedeutung |",
        "|---|---:|---|",
        f"| high | {je_prio['high']} | Betriebsscripte aus scripts-Verzeichnissen |",
        f"| medium | {je_prio['medium']} | uebriger ausfuehrbarer Code |",
        f"| low | {je_prio['low']} | Markup und Stilvorlagen |",
        f"| **gesamt** | **{len(inventar)}** | nach Inhalt dedupliziert |",
        "",
        f"Noch offene Sprachpaare: **{offen}**",
        "",
        "## Letzter Lauf",
        "",
        f"- bearbeitete Quelldateien: {zaehler['dateien']}",
        f"- erzeugte Uebersetzungen: {zaehler['erzeugt']}",
        f"- verworfen: {zaehler['verworfen']}",
        "",
        "## Herkunft",
        "",
        "- `KikiKari/OpenClaw` — main, gateway1, gateway2",
        "- `KikiKari/Projects` — alle Branches",
        "- `KikiKari/Onboarding` — main",
        "",
        "Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.",
        "",
    ]
    try:
        (ABSTRACTIONS_REPO / "STATUS.md").write_text("\n".join(zeilen), encoding="utf-8")
        logger.info("STATUS.md fortgeschrieben")
        return True
    except OSError as fehler:
        logger.error("STATUS.md konnte nicht geschrieben werden: %s", fehler)
        return False


def veroeffentlichen(nachricht: str) -> bool:
    """Veroeffentlicht vorgemerkte Erzeugnisse einzeln und wiederholbar."""
    from github_publisher import publish_pending, synchronize_checkout
    zustand = zustand_laden()
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("ABSTRACTIONS_PUSH_TOKEN") or ""
    ergebnis = publish_pending(ABSTRACTIONS_REPO, zustand, zustand_speichern, token,
                               sync=synchronize_checkout)
    logger.info("Veroeffentlichung %s", "abgeschlossen" if ergebnis else "ausstehend")
    return ergebnis


# ---------------------------------------------------------------------------
# Einstiegspunkt
# ---------------------------------------------------------------------------


def main() -> int:
    """Holt die Quellen, uebersetzt eine Prioritaetsstufe und veroeffentlicht."""
    zerleger = argparse.ArgumentParser(description="Portiert Quellcode in konfigurierte Zielsprachen.")
    zerleger.add_argument("--prioritaet", choices=["high", "medium", "low", "alle"],
                          help="Nur diese Stufe bearbeiten. Ohne Angabe wird reihum gewechselt.")
    zerleger.add_argument("--anzahl", type=int,
                          default=int(os.environ.get("ABSTRACTIONS_ANZAHL", "40")),
                          help="Hoechstzahl Quelldateien je Lauf.")
    zerleger.add_argument("--probelauf", action="store_true",
                          help="Inventar aufbauen und Plan zeigen, ohne zu uebersetzen.")
    zerleger.add_argument("--nur-veroeffentlichen", action="store_true",
                          help="Gespeicherte Ergebnisse getrennt veroeffentlichen oder Push wiederholen.")
    argumente = zerleger.parse_args()

    logger.info("Abstractions Manager gestartet — Arbeitsverzeichnis %s", WORKSPACE)
    if argumente.nur_veroeffentlichen:
        if argumente.probelauf:
            logger.error("--probelauf und --nur-veroeffentlichen sind nicht kombinierbar")
            return 2
        return 0 if veroeffentlichen("auto: gespeicherte Uebersetzungen") else 1

    schluessel = ""
    dispatcher = transport = None
    ausfuehrung = os.environ.get("ABSTRACTIONS_EXECUTION", "gateway")
    if ausfuehrung not in ("gateway", "standalone"):
        logger.error("Unbekannte Ausfuehrungsart")
        return 2
    if not argumente.probelauf and ausfuehrung == "standalone":
        schluessel = os.environ.get("OPENROUTER_API_KEY", "").strip()
        if not schluessel:
            logger.error("OpenRouter-Zugang fuer eigenstaendigen Lauf fehlt")
            return 2
    if not argumente.probelauf and ausfuehrung == "gateway":
        import importlib.util
        from gateway_transport import GatewayTransport, TransportUnresolved, gateway_token
        gateway_url = os.environ.get("ABSTRACTIONS_GATEWAY_URL", "http://127.0.0.1:18789/plugins/abstractions-transport")
        token = gateway_token()
        try:
            transport = GatewayTransport(zustand_laden(), zustand_speichern, gateway_url, token)
            path = Path(__file__).resolve().parents[2] / "multi-nodes-utils/scripts/dispatch_job.py"
            spec = importlib.util.spec_from_file_location("abstractions_dispatcher", path)
            if spec is None or spec.loader is None:
                raise RuntimeError("dispatcher unavailable")
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            class GatewayDispatcher(module.JobDispatcher):
                def select_node(self, job_weight):
                    preferred = {"heavy": ("node1", "node2", "node5", "node6"),
                                 "medium": ("node1", "node2", "node3", "node6"),
                                 "light": ("node2", "node1", "node3", "node4")}[job_weight]
                    try:
                        states = transport.available()
                    except TransportUnresolved:
                        return None
                    ids = states.get("node_ids")
                    self.node_ids = ids if isinstance(ids, dict) else {}
                    frei = node_speicherstatus()
                    for node in preferred:
                        device_id = self.node_ids.get(node)
                        if states.get(node) is not True or not isinstance(device_id, str) or not device_id:
                            continue
                        if node_hat_reserve(node, device_id, frei):
                            return node
                        logger.warning("%s: Speicherreserve unterschritten oder nicht nachgewiesen", node)
                    return None
            dispatcher = GatewayDispatcher()
            transport.release_pending()
        except (ValueError, OSError, RuntimeError) as fehler:
            logger.error("Gateway-Transport nicht verfuegbar (%s)", type(fehler).__name__)
            return 2

    zustand = transport.state if transport is not None else zustand_laden()
    baeume = quellen_holen()
    if not baeume:
        logger.error("Keine Quellen verfuegbar")
        return 1

    inventar = inventar_bauen(baeume)
    if not inventar:
        logger.error("Inventar leer")
        return 1

    prioritaet = argumente.prioritaet or zustand.get("naechste_prioritaet", "high")
    zaehler = uebersetzen(inventar, zustand, prioritaet, argumente.anzahl,
                          argumente.probelauf, schluessel, dispatcher, transport,
                          state_saver=zustand_speichern)

    reihum = {"high": "medium", "medium": "low", "low": "high", "alle": "alle"}
    if not argumente.probelauf:
        zustand["naechste_prioritaet"] = reihum[prioritaet]
    zustand["statistik"] = {
        "letzter_lauf": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "quelldateien": len(inventar),
        **zaehler,
    }

    bericht_ok = bericht_schreiben(inventar, zustand, zaehler)
    if bericht_ok and not argumente.probelauf:
        from github_publisher import queue_artifact
        queue_artifact(zustand, ABSTRACTIONS_REPO, ABSTRACTIONS_REPO / 'STATUS.md')
    zustand_speichern(zustand)

    veroeffentlicht = True
    if not argumente.probelauf and zustand.get("ausstehende_veroeffentlichungen"):
        veroeffentlicht = veroeffentlichen("auto: gespeicherte Uebersetzungen")

    logger.info("Abgeschlossen: %d erzeugt, %d verworfen, %d Quelldateien bearbeitet",
                zaehler["erzeugt"], zaehler["verworfen"], zaehler["dateien"])
    return 1 if zaehler["verworfen"] or not veroeffentlicht or not bericht_ok else 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""
Sub-Agent spawner - Einfache CLI für sessions_spawn
"""

import argparse
import json
import os
import sys
from pathlib import Path

def load_models() -> list[str]:
    config_path = Path(os.environ.get("OPENCLAW_CONFIG", "/home/openclaw/.openclaw/openclaw.json"))
    try:
        config = json.loads(config_path.read_text(encoding="utf-8"))
        model_config = config["agents"]["defaults"]["model"]
        candidates = [model_config["primary"], *model_config["fallbacks"]]
    except (OSError, json.JSONDecodeError, KeyError, TypeError) as error:
        raise RuntimeError(f"Modellkonfiguration kann nicht geladen werden: {config_path}: {error}") from error
    models = list(dict.fromkeys(
        model for model in candidates
        if isinstance(model, str) and model and not model.startswith("anthropic/")
    ))
    if not models:
        raise RuntimeError(f"Keine allgemein verfügbaren Modelle in {config_path}")
    return models


MODELS = load_models()

class SubAgentSpawner:
    """Hilft beim Spawnen von Sub-Agents"""
    
    @staticmethod
    def get_spawn_config(
        task: str,
        label: str = None,
        model: str = None,
        thinking: str = None,
        timeout: int = None,
        thread: bool = False,
        mode: str = "run"
    ) -> dict:
        """Erstellt Konfiguration für sessions_spawn"""
        
        config = {
            "task": task
        }
        
        if label:
            config["label"] = label
        if model and model in MODELS:
            config["model"] = model
        if thinking:
            config["thinking"] = thinking
        if timeout:
            config["runTimeoutSeconds"] = timeout
        if thread:
            config["thread"] = True
            if mode == "run":
                config["mode"] = "session"  # thread requires session mode
        else:
            config["mode"] = mode
            
        return config
    
    @staticmethod
    def print_spawn_command(config: dict):
        """Gibt das equivalente Tool-Kommando aus"""
        print("\n🛠️  Tool-Aufruf:")
        print("=" * 50)
        print("sessions_spawn(")
        for key, value in config.items():
            if isinstance(value, str):
                print(f'    {key}="{value}"')
            else:
                print(f'    {key}={value}')
        print(")")
        print("=" * 50)
    
    @staticmethod
    def print_slash_command(config: dict):
        """Gibt das equivalente Slash-Kommando aus"""
        task = config.get("task", "")
        label = config.get("label", "agent")
        model = config.get("model", "")
        
        cmd = f"/subagents spawn {label} \"{task}\""
        if model:
            cmd += f" --model {model}"
        if config.get("thinking"):
            cmd += f" --thinking {config['thinking']}"
            
        print("\n💬 Slash Command:")
        print("=" * 50)
        print(cmd)
        print("=" * 50)

def main():
    parser = argparse.ArgumentParser(
        description="Sub-Agent Spawn Helper",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Beispiele:
  %(prog)s -t "Analyze logs" 
  %(prog)s -t "Code review" -m openai/gpt-5.6-sol --timeout 1800
  %(prog)s -t "Batch process" -l "batch-worker" --thread
        """
    )
    
    parser.add_argument("--task", "-t", required=True, help="Aufgabenbeschreibung")
    parser.add_argument("--label", "-l", help="Optionaler Label")
    parser.add_argument("--model", "-m", choices=MODELS, help="KI-Modell")
    parser.add_argument("--thinking", choices=["low", "medium", "high"], help="Thinking Level")
    parser.add_argument("--timeout", type=int, default=900, help="Timeout in Sekunden (default: 900)")
    parser.add_argument("--thread", action="store_true", help="Thread-Binding aktivieren")
    parser.add_argument("--mode", choices=["run", "session"], default="run", help="Run mode")
    parser.add_argument("--output", "-o", choices=["tool", "slash", "json"], default="tool", help="Output format")
    
    args = parser.parse_args()
    
    spawner = SubAgentSpawner()
    config = spawner.get_spawn_config(
        task=args.task,
        label=args.label,
        model=args.model,
        thinking=args.thinking,
        timeout=args.timeout,
        thread=args.thread,
        mode=args.mode
    )
    
    print("✅ Sub-Agent Konfiguration:")
    print(json.dumps(config, indent=2))
    
    if args.output == "tool":
        spawner.print_spawn_command(config)
    elif args.output == "slash":
        spawner.print_slash_command(config)
    elif args.output == "json":
        print("\n📄 JSON:")
        print(json.dumps(config))
        
        # Speichere als Datei
        output_file = Path("/tmp") / f"subagent_{config.get('label', 'spawn')}.json"
        with open(output_file, 'w') as f:
            json.dump(config, f, indent=2)
        print(f"💾 Gespeichert: {output_file}")

if __name__ == "__main__":
    main()

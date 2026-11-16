#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "951f61c07e67907677193023a8c0700b4a1814e09e33120cdd6947a5d9147ff1", "source_sha256": "cfa6fdcce252a97fa8be4d621d55955657d2f6616d52330d880db2123e1db43b", "target_language": "python"}
# check-ingress-agent-owner-context.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-ingress-agent-owner-context.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import os
import sys
from pathlib import Path
from typing import Set, List, Callable, Optional, Any
import ast
import asyncio

# Helper functions to simulate Node.js path behavior
def bundled_plugin_file(plugin_name: str, relative_path: str) -> str:
    """Simulate the bundledPluginFile function"""
    # This would need to be implemented based on your actual plugin structure
    # For now, returning a standard path pattern
    return f"plugins/{plugin_name}/{relative_path}"

def normalize_path_separators(path_str: str) -> str:
    """Normalize path separators to forward slashes"""
    return path_str.replace(os.sep, "/")

# TypeScript AST utilities simulation
class TypeScriptASTSimulator:
    """Simulate TypeScript AST functionality for Python"""
    
    @staticmethod
    def create_source_file(content: str, file_name: str = "source.ts") -> ast.AST:
        """Create AST from source code"""
        try:
            return ast.parse(content)
        except SyntaxError:
            # Return empty module if parsing fails
            return ast.Module(body=[])
    
    @staticmethod
    def is_identifier(node: Any) -> bool:
        """Check if node is an identifier"""
        return isinstance(node, ast.Name)
    
    @staticmethod
    def unwrap_expression(expr: Any) -> Any:
        """Unwrap expression to get the core identifier"""
        if isinstance(expr, ast.Call):
            return TypeScriptASTSimulator.unwrap_expression(expr.func)
        elif isinstance(expr, ast.Attribute):
            return expr.attr
        return expr

def collect_call_expression_lines(source_file: ast.AST, 
                                 predicate: Callable[[ast.Call], Optional[Any]]) -> List[int]:
    """Collect line numbers of call expressions matching predicate"""
    lines = []
    
    class CallVisitor(ast.NodeVisitor):
        def visit_Call(self, node):
            if predicate(node):
                lines.append(node.lineno)
            self.generic_visit(node)
    
    visitor = CallVisitor()
    visitor.visit(source_file)
    return lines

def find_legacy_agent_command_call_lines(content: str, file_name: str = "source.ts") -> List[int]:
    """Find lines with legacy agentCommand calls"""
    source_file = TypeScriptASTSimulator.create_source_file(content, file_name)
    
    def predicate(node: ast.Call) -> Optional[bool]:
        callee = TypeScriptASTSimulator.unwrap_expression(node.func)
        if TypeScriptASTSimulator.is_identifier(callee):
            return getattr(callee, 'id', '') == 'agentCommand'
        elif isinstance(callee, str):
            return callee == 'agentCommand'
        return False
    
    return collect_call_expression_lines(source_file, predicate)

async def run_callsite_guard(import_meta_url: str,
                           source_roots: List[str],
                           find_call_lines: Callable[[str, str], List[int]],
                           skip_relative_path: Callable[[str], bool],
                           header: str,
                           footer: str) -> None:
    """Run the callsite guard check"""
    print(header)
    
    found_issues = False
    
    for root in source_roots:
        if not os.path.exists(root):
            continue
            
        for root_dir, dirs, files in os.walk(root):
            for file in files:
                if file.endswith('.ts') and not file.endswith('.d.ts'):
                    file_path = os.path.join(root_dir, file)
                    
                    # Get relative path
                    rel_path = os.path.relpath(file_path, '.')
                    normalized_rel_path = normalize_path_separators(rel_path)
                    
                    if skip_relative_path(normalized_rel_path):
                        continue
                    
                    try:
                        with open(file_path, 'r', encoding='utf-8') as f:
                            content = f.read()
                        
                        lines = find_call_lines(content, file_path)
                        if lines:
                            found_issues = True
                            print(f"\n{file_path}:")
                            for line_num in lines:
                                print(f"  Line {line_num}")
                    except Exception as e:
                        print(f"Error processing {file_path}: {e}", file=sys.stderr)
    
    if found_issues:
        print(f"\n{footer}")
        sys.exit(1)

def run_as_script(current_file: str, main_func: Callable) -> None:
    """Run as script if this is the main module"""
    if os.path.abspath(sys.argv[0]) == os.path.abspath(current_file):
        asyncio.run(main_func())

# Configuration
source_roots = [
    "src/gateway", 
    bundled_plugin_file("discord", "src/voice")
]

enforced_files: Set[str] = {
    bundled_plugin_file("discord", "src/voice/manager.ts"),
    "src/gateway/openai-http.ts",
    "src/gateway/openresponses-http.ts",
    "src/gateway/server-methods/agent.ts",
    "src/gateway/server-node-events.ts",
}

async def main() -> None:
    """Main function"""
    def skip_relative_path(rel_path: str) -> bool:
        return rel_path not in enforced_files
    
    await run_callsite_guard(
        import_meta_url=__file__,
        source_roots=source_roots,
        find_call_lines=lambda content, filename: find_legacy_agent_command_call_lines(content, filename),
        skip_relative_path=skip_relative_path,
        header="Found ingress callsites using local agentCommand() (must be explicit owner-aware):",
        footer="Use agentCommandFromIngress(...) and pass senderIsOwner explicitly at ingress boundaries."
    )

if __name__ == "__main__":
    asyncio.run(main())

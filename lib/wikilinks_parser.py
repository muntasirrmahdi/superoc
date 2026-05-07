#!/usr/bin/env python3
"""
SuperOC Semantic Bridge - Wikilinks Parser
Parses [[Entity]] links and builds knowledge graph
Usage: lib/wikilinks_parser.py [--config CONFIG] [--output OUTPUT]
"""

import os
import re
import json
import sys
from pathlib import Path
from typing import Dict, List, Set
from datetime import datetime
import argparse
import fnmatch

# --- Configuration via Environment ---
WIKILINK_CONFIG = os.environ.get("SUPEROC_WIKILINK_CONFIG", "~/.superoc/wikilinks.json")
WIKILINK_OUTPUT = os.environ.get("SUPEROC_WIKILINK_OUTPUT", "~/.superoc/wikilinks_graph.json")

# Regex pattern for [[Entity]] or [[Entity|Alias]]
WIKILINK_PATTERN = re.compile(r"\[\[([^|\]]+)(?:\|([^|\]]+))?\]\]")

# Stop words - generic programming terms to filter out
STOP_WORDS = {
    "pass", "blank", "char", "int", "x", "y", "none", "true", "false",
    "test", "example", "data", "id", "key", "value", "item", "items",
    "index", "file", "path", "name", "type", "error", "message",
    "code", "result", "results", "content", "string", "float", "bool",
    "list", "dict", "object", "array", "json", "html", "css",
    "get", "post", "put", "delete", "set", "log", "ctx", "req", "res",
    "self", "cls", "args", "kwargs", "var", "let", "const", "return",
    "if", "else", "for", "while", "try", "catch", "throw", "new",
    "export", "import", "from", "default", "async", "await", "def",
    "class", "function", "method", "param", " retval", "callback",
}

def normalize_entity_id(name: str) -> str:
    """Normalize entity name to ID."""
    id_val = name.lower().strip()
    id_val = re.sub(r"[^\w\s-]", "", id_val)
    id_val = re.sub(r"[-\s]+", "-", id_val)
    return id_val

def is_valid_entity(name: str) -> bool:
    """Validate if entity name is meaningful."""
    normalized = normalize_entity_id(name)
    
    # Rule 1: Length 3-50 chars
    if not (3 <= len(normalized) <= 50):
        return False
    
    # Rule 2: Not a stop word
    if normalized in STOP_WORDS:
        return False
    
    # Rule 3: No code-like characters
    if re.search(r'[.(){}\[\]*+?$^=<>!&|:"`~@#%^]', name):
        return False
    
    # Rule 4: Must have at least one letter
    if not re.search(r'[a-zA-Z]', name):
        return False
    
    # Rule 5: Not purely numeric
    if name.isnumeric():
        return False
    
    return True

def is_excluded(path: Path, exclude_patterns: List[str]) -> bool:
    """Check if path should be excluded."""
    path_str = str(path)
    for pattern in exclude_patterns:
        if fnmatch.fnmatch(path_str, pattern):
            return True
    return False

def scan_wikilinks(sources: List[str], extensions: List[str], exclude: List[str]) -> Dict:
    """Scan sources for wikilinks and build graph."""
    entities: Dict[str, Dict] = {}
    backlinks: Dict[str, List[Dict]] = {}
    files_parsed: Set[str] = set()
    
    for source_str in sources:
        source = Path(source_str).expanduser()
        if not source.is_dir():
            print(f"Warning: Source not found: {source}")
            continue
        
        print(f"Scanning: {source}")
        
        for ext in extensions:
            for file_path in source.rglob(f"*{ext}"):
                if is_excluded(file_path, exclude):
                    continue
                
                file_str = str(file_path)
                if file_str in files_parsed:
                    continue
                
                try:
                    content = file_path.read_text(encoding="utf-8")
                except Exception as e:
                    print(f"Warning: Could not read {file_path}: {e}")
                    continue
                
                for i, line in enumerate(content.split("\n"), 1):
                    for match in WIKILINK_PATTERN.finditer(line):
                        entity_name, alias = match.groups()
                        entity_name = entity_name.strip()
                        
                        if not entity_name or not is_valid_entity(entity_name):
                            continue
                        
                        entity_id = normalize_entity_id(entity_name)
                        if not entity_id:
                            continue
                        
                        # Create or update entity
                        if entity_id not in entities:
                            entities[entity_id] = {
                                "id": entity_id,
                                "name": entity_name,
                                "type": "auto_detected",
                                "aliases": [],
                                "files": [],
                                "created": datetime.now().isoformat(),
                            }
                        
                        entity = entities[entity_id]
                        entity["updated"] = datetime.now().isoformat()
                        
                        if file_str not in entity["files"]:
                            entity["files"].append(file_str)
                        
                        if alias and alias.strip() not in entity["aliases"]:
                            entity["aliases"].append(alias.strip())
                        
                        # Add backlink
                        if entity_id not in backlinks:
                            backlinks[entity_id] = []
                        
                        start = max(0, match.start() - 50)
                        end = min(len(line), match.end() + 50)
                        
                        backlinks[entity_id].append({
                            "file": file_str,
                            "line": i,
                            "context": line[start:end],
                            "timestamp": datetime.now().isoformat(),
                        })
                
                files_parsed.add(file_str)
    
    # Build co-occurrence relationships
    relationships = []
    processed = set()
    
    file_to_entities = {}
    for entity_id, entity in entities.items():
        for file_path in entity.get("files", []):
            file_to_entities.setdefault(file_path, set()).add(entity_id)
    
    for entity_ids in file_to_entities.values():
        entity_list = sorted(list(entity_ids))
        for i in range(len(entity_list)):
            for j in range(i + 1, len(entity_list)):
                source, target = entity_list[i], entity_list[j]
                if (source, target) in processed:
                    continue
                
                relationships.append({
                    "source": source,
                    "target": target,
                    "type": "co_occurs_in",
                })
                processed.add((source, target))
    
    return {
        "entities": entities,
        "graph": {
            "nodes": [{"id": eid, "label": entities[eid]["name"]} for eid in entities],
            "edges": relationships,
        },
        "backlinks": backlinks,
        "metadata": {
            "parsed_at": datetime.now().isoformat(),
            "files_parsed": len(files_parsed),
            "entities_count": len(entities),
        },
    }

def main():
    parser = argparse.ArgumentParser(description="SuperOC Wikilinks Parser")
    parser.add_argument("--config", default=WIKILINK_CONFIG, help="Config file")
    parser.add_argument("--output", default=WIKILINK_OUTPUT, help="Output file")
    args = parser.parse_args()
    
    config_path = Path(args.config).expanduser()
    output_path = Path(args.output).expanduser()
    
    print("=== SuperOC Semantic Bridge ===")
    
    if not config_path.exists():
        print(f"Config not found: {config_path}")
        print("Create ~/.superoc/wikilinks.json with:")
        print('{"sources": ["~/projects"], "exclude": ["*.pyc", "node_modules"], "file_extensions": [".md", ".txt"]}')
        sys.exit(1)
    
    try:
        config = json.loads(config_path.read_text(encoding="utf-8"))
    except Exception as e:
        print(f"Error reading config: {e}")
        sys.exit(1)
    
    sources = config.get("sources", [])
    extensions = config.get("file_extensions", [".md"])
    exclude = config.get("exclude", [])
    
    graph_data = scan_wikilinks(sources, extensions, exclude)
    
    print(f"\n--- Statistics ---")
    print(f"   Files Scanned: {graph_data['metadata']['files_parsed']}")
    print(f"   Entities Found: {graph_data['metadata']['entities_count']}")
    
    output_data = {"wikilinks_graph": graph_data}
    output_path.write_text(json.dumps(output_data, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Graph written to: {output_path}")

if __name__ == "__main__":
    main()
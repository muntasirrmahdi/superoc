#!/usr/bin/env python3

import os
import sys
import json
import argparse
from pathlib import Path
from datetime import datetime


def read_transcript(transcript_path: str) -> str:
    try:
        content = Path(transcript_path).read_text(encoding="utf-8")
        lines = content.split("\n")
        last_lines = lines[-200:] if len(lines) > 200 else lines
        return "\n".join(last_lines)
    except Exception as e:
        print(f"ERROR reading transcript: {e}")
        return ""


def extract_with_openai(api_key: str, transcript: str) -> dict:
    try:
        import openai
        client = openai.OpenAI(api_key=api_key)
        
        response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "Extract key facts, decisions, and learnings from this session transcript. Return JSON with keys: facts (list), decisions (list), learnings (list)."},
                {"role": "user", "content": transcript}
            ],
            temperature=0.3,
            max_tokens=500
        )
        
        content = response.choices[0].message.content
        return json.loads(content) if content else {}
    except Exception as e:
        print(f"OpenAI extraction failed: {e}")
        return {}


def extract_with_anthropic(api_key: str, transcript: str) -> dict:
    try:
        import anthropic
        client = anthropic.Anthropic(api_key=api_key)
        
        response = client.messages.create(
            model="claude-3-haiku-20240307",
            max_tokens=500,
            messages=[{"role": "user", "content": f"Extract key facts, decisions, and learnings from this session transcript. Return JSON with keys: facts (list), decisions (list), learnings (list).\n\nTranscript:\n{transcript}"}]
        )
        
        content = response.content[0].text if response.content else ""
        return json.loads(content) if content else {}
    except Exception as e:
        print(f"Anthropic extraction failed: {e}")
        return {}


def update_memory_files(superoc_dir: str, extraction: dict):
    learning_model_path = Path(superoc_dir) / "learning-model.md"
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    entry = f"\n\n## Session Learning ({timestamp})\n"
    if extraction.get("facts"):
        entry += "\n### Facts\n"
        for fact in extraction["facts"]:
            entry += f"- {fact}\n"
    if extraction.get("decisions"):
        entry += "\n### Decisions\n"
        for decision in extraction["decisions"]:
            entry += f"- {decision}\n"
    if extraction.get("learnings"):
        entry += "\n### Learnings\n"
        for learning in extraction["learnings"]:
            entry += f"- {learning}\n"
    
    with open(learning_model_path, "a", encoding="utf-8") as f:
        f.write(entry)


def main():
    parser = argparse.ArgumentParser(description="SuperOC LLM Extraction")
    parser.add_argument("--transcript", required=True, help="Session transcript path")
    parser.add_argument("--superoc-dir", default=os.path.expanduser("~/.superoc"), help="SuperOC directory")
    args = parser.parse_args()
    
    print("=== SuperOC LLM Extraction ===")
    
    transcript = read_transcript(args.transcript)
    if not transcript:
        print("ERROR: Could not read transcript")
        sys.exit(1)
    
    print(f"Transcript length: {len(transcript)} chars")
    
    extraction = {}
    openai_key = os.environ.get("OPENAI_API_KEY", "")
    anthropic_key = os.environ.get("ANTHROPIC_API_KEY", "")
    
    if openai_key and "sk-" in openai_key:
        print("Using OpenAI API...")
        extraction = extract_with_openai(openai_key, transcript)
    elif anthropic_key:
        print("Using Anthropic API...")
        extraction = extract_with_anthropic(anthropic_key, transcript)
    else:
        print("WARNING: No LLM API keys found. Using simulation mode.")
        extraction = {
            "facts": [],
            "decisions": [],
            "learnings": ["LLM extraction simulated - no API key available"]
        }
    
    if extraction:
        print(f"Extracted: {len(extraction.get('facts', []))} facts, {len(extraction.get('decisions', []))} decisions, {len(extraction.get('learnings', []))} learnings")
        update_memory_files(args.superoc_dir, extraction)
        print("Memory files updated.")
    else:
        print("WARNING: No extraction results.")
    
    print("Extraction complete.")
    sys.exit(0)


if __name__ == "__main__":
    main()

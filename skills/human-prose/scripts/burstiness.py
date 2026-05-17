#!/usr/bin/env python3
"""
Burstiness check for prose meant to feel human.

Computes sentence-length standard deviation. Per analysis of high-engagement
human writing, std dev falls in 4.8-7.2; typical LLM output is 2.0-3.8.

Also computes the last-5-sentences word-count spread (proxy useful while
drafting before the script can be run).

Usage:
    python burstiness.py <file>
    python burstiness.py <file> --json
"""

import argparse
import json
import math
import re
import sys
from pathlib import Path


HUMAN_RANGE = (4.8, 7.2)
AI_RANGE = (2.0, 3.8)
MIN_LAST_5_SPREAD = 8


def strip_for_analysis(text: str) -> str:
    """Strip frontmatter, code blocks, headers, and markdown formatting."""
    text = re.sub(r'^---\n.*?\n---\n', '', text, count=1, flags=re.DOTALL)
    text = re.sub(r'```.*?```', '', text, flags=re.DOTALL)
    text = re.sub(r'`[^`]+`', '', text)
    text = re.sub(r'^#{1,6}\s.*$', '', text, flags=re.MULTILINE)
    text = re.sub(r'^[\s]*[-*+]\s', '', text, flags=re.MULTILINE)
    text = re.sub(r'^[\s]*\d+\.\s', '', text, flags=re.MULTILINE)
    text = re.sub(r'\*\*([^*\n]+)\*\*', r'\1', text)
    text = re.sub(r'__([^_\n]+)__', r'\1', text)
    text = re.sub(r'(?<!\*)\*([^*\n]+)\*(?!\*)', r'\1', text)
    text = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', text)
    return text


def split_sentences(text: str) -> list:
    """Naive sentence splitter with abbreviation handling."""
    abbrevs = ['Mr.', 'Mrs.', 'Ms.', 'Dr.', 'Prof.', 'Sr.', 'Jr.', 'vs.',
               'e.g.', 'i.e.', 'etc.', 'cf.', 'Inc.', 'Ltd.', 'Co.', 'Corp.',
               'St.', 'Ave.', 'No.', 'U.S.', 'U.K.']
    ph_map = {}
    for i, ab in enumerate(abbrevs):
        ph = f'__ABBR{i}__'
        ph_map[ph] = ab
        text = text.replace(ab, ph)

    sentences = re.split(r'(?<=[.!?])\s+', text)

    restored = []
    for s in sentences:
        for ph, ab in ph_map.items():
            s = s.replace(ph, ab)
        s = s.strip()
        if s and len(s.split()) >= 2:
            restored.append(s)
    return restored


def std_dev(values: list) -> float:
    if len(values) < 2:
        return 0.0
    mean = sum(values) / len(values)
    variance = sum((x - mean) ** 2 for x in values) / len(values)
    return math.sqrt(variance)


def classify_range(stddev: float) -> str:
    if HUMAN_RANGE[0] <= stddev <= HUMAN_RANGE[1]:
        return "human_range"
    if AI_RANGE[0] <= stddev <= AI_RANGE[1]:
        return "ai_range"
    if stddev < AI_RANGE[0]:
        return "very_uniform"
    if stddev > HUMAN_RANGE[1]:
        return "above_human_range"
    return "between_ranges"


def analyze(text: str) -> dict:
    stripped = strip_for_analysis(text)
    sentences = split_sentences(stripped)
    lengths = [len(s.split()) for s in sentences]

    if not lengths:
        return {"error": "no sentences found", "sentence_count": 0}

    mean_length = sum(lengths) / len(lengths)
    stddev = std_dev(lengths)

    last_5 = lengths[-5:] if len(lengths) >= 5 else lengths
    last_5_spread = max(last_5) - min(last_5) if last_5 else 0

    range_class = classify_range(stddev)

    return {
        "sentence_count": len(sentences),
        "mean_sentence_length": round(mean_length, 2),
        "stddev_sentence_length": round(stddev, 2),
        "human_range": HUMAN_RANGE,
        "ai_range": AI_RANGE,
        "range_class": range_class,
        "pass_stddev": stddev >= AI_RANGE[1],
        "last_5_word_counts": last_5,
        "last_5_spread": last_5_spread,
        "min_last_5_spread": MIN_LAST_5_SPREAD,
        "pass_last_5_spread": last_5_spread >= MIN_LAST_5_SPREAD,
    }


def format_human(result: dict) -> str:
    if 'error' in result:
        return f"Error: {result['error']}"
    lines = []
    lines.append(f"Sentences: {result['sentence_count']}")
    lines.append(f"Mean length: {result['mean_sentence_length']} words")
    lines.append(f"Std dev: {result['stddev_sentence_length']} ({result['range_class']})")
    lines.append(f"  Human range: {result['human_range'][0]}-{result['human_range'][1]}")
    lines.append(f"  AI range:    {result['ai_range'][0]}-{result['ai_range'][1]}")
    lines.append(f"  {'[OK]' if result['pass_stddev'] else '[FAIL] in AI range or below'}")
    lines.append("")
    lines.append(f"Last 5 sentence word counts: {result['last_5_word_counts']}")
    lines.append(f"Spread: {result['last_5_spread']} (min target: {result['min_last_5_spread']})")
    lines.append(f"  {'[OK]' if result['pass_last_5_spread'] else '[FAIL] too uniform'}")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('file', help='Path to the prose file')
    parser.add_argument('--json', action='store_true', help='Output JSON')
    args = parser.parse_args()

    path = Path(args.file)
    if not path.exists():
        print(f"Error: file not found: {path}", file=sys.stderr)
        sys.exit(2)

    text = path.read_text(encoding='utf-8')
    result = analyze(text)

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(format_human(result))

    overall = result.get('pass_stddev', False) and result.get('pass_last_5_spread', False)
    sys.exit(0 if overall else 1)


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""
Format scan for prose meant to feel human.

Counts typographic and structural tells: em-dashes, smart quotes, bold,
italics, headers, bullet lists, numbered lists. Outputs JSON with per-metric
pass/fail against the caps defined in the human-prose skill.

Usage:
    python format_scan.py <file>
    python format_scan.py <file> --json
"""

import argparse
import json
import re
import sys
from pathlib import Path


# Caps from the human-prose skill
EM_DASH_CAP_PER_500_WORDS = 1
SMART_QUOTES_CAP = 0
BOLD_CAP = 1
HEADERS_CAP_UNDER_2000_WORDS = 1
HEADERS_CAP_UNDER_5000_WORDS = 3


def strip_for_word_count(text: str) -> str:
    """Strip frontmatter, code blocks, and inline code before word counting."""
    text = re.sub(r'^---\n.*?\n---\n', '', text, count=1, flags=re.DOTALL)
    text = re.sub(r'```.*?```', '', text, flags=re.DOTALL)
    text = re.sub(r'`[^`]+`', '', text)
    return text


def count_words(text: str) -> int:
    return len(strip_for_word_count(text).split())


def count_em_dashes(text: str) -> int:
    """Count em-dash (U+2014). En-dashes (U+2013) for numerical ranges
    are correct typography, not an AI tell, so they're excluded."""
    return text.count('\u2014')


def count_smart_quotes(text: str) -> int:
    """Count curly quote characters."""
    chars = ['\u201c', '\u201d', '\u2018', '\u2019']
    return sum(text.count(c) for c in chars)


def count_bold_phrases(text: str) -> int:
    """Count bold markdown patterns: **...** or __...__ (excluding code blocks)."""
    text = re.sub(r'```.*?```', '', text, flags=re.DOTALL)
    text = re.sub(r'`[^`]+`', '', text)
    bold_pattern = re.compile(r'\*\*([^*\n]+)\*\*|__([^_\n]+)__')
    return len(bold_pattern.findall(text))


def count_italics(text: str) -> int:
    """Count italic markdown: *...* (not part of **...**), or _..._"""
    text = re.sub(r'\*\*[^*\n]+\*\*', '', text)
    text = re.sub(r'__[^_\n]+__', '', text)
    text = re.sub(r'```.*?```', '', text, flags=re.DOTALL)
    text = re.sub(r'`[^`]+`', '', text)
    italic_pattern = re.compile(r'(?<!\*)\*([^*\n]+)\*(?!\*)|(?<!_)_([^_\n]+)_(?!_)')
    return len(italic_pattern.findall(text))


def count_headers(text: str) -> int:
    """Count markdown headers: lines starting with # ## ### etc."""
    return len(re.findall(r'^#{1,6}\s', text, flags=re.MULTILINE))


def count_bullet_items(text: str) -> int:
    """Count bullet list items. Lines starting with - or * or + followed by space."""
    return len(re.findall(r'^[\s]*[-*+]\s', text, flags=re.MULTILINE))


def count_numbered_items(text: str) -> int:
    """Count numbered list items. Lines starting with N. followed by space."""
    return len(re.findall(r'^[\s]*\d+\.\s', text, flags=re.MULTILINE))


def scan(text: str) -> dict:
    word_count = count_words(text)
    em_dash_count = count_em_dashes(text)
    em_dash_cap = max(1, word_count // 500)

    headers = count_headers(text)
    if word_count < 2000:
        header_cap = HEADERS_CAP_UNDER_2000_WORDS
        word_tier = "under_2000"
    elif word_count < 5000:
        header_cap = HEADERS_CAP_UNDER_5000_WORDS
        word_tier = "under_5000"
    else:
        header_cap = max(3, word_count // 1500)
        word_tier = "long_form"

    bold_count = count_bold_phrases(text)
    smart_quotes = count_smart_quotes(text)
    bullets = count_bullet_items(text)
    numbered = count_numbered_items(text)
    italics = count_italics(text)

    return {
        "word_count": word_count,
        "checks": {
            "em_dashes": {
                "count": em_dash_count,
                "cap": em_dash_cap,
                "ratio_per_500_words": round(em_dash_count / max(word_count, 1) * 500, 2),
                "pass": em_dash_count <= em_dash_cap,
            },
            "smart_quotes": {
                "count": smart_quotes,
                "cap": SMART_QUOTES_CAP,
                "pass": smart_quotes == 0,
            },
            "bold_phrases": {
                "count": bold_count,
                "cap": BOLD_CAP,
                "pass": bold_count <= BOLD_CAP,
            },
            "headers": {
                "count": headers,
                "cap": header_cap,
                "word_count_tier": word_tier,
                "pass": headers <= header_cap,
            },
            "italics": {
                "count": italics,
                "note": "no cap; italics for titles, foreign words, and true semantic emphasis only",
            },
            "bullet_items": {
                "count": bullets,
                "note": "near-zero in essays, blogs, op-eds, newsletters; appropriate in reference content",
            },
            "numbered_items": {
                "count": numbered,
                "note": "same test as bullets",
            },
        },
        "all_pass": all([
            em_dash_count <= em_dash_cap,
            smart_quotes == 0,
            bold_count <= BOLD_CAP,
            headers <= header_cap,
        ]),
        "caveat": "These caps assume essay-shaped prose. For reference content (API docs, instructional skills), structural elements legitimately scale higher; interpret accordingly.",
    }


def format_human(result: dict) -> str:
    lines = [f"Word count: {result['word_count']}", ""]
    checks = result['checks']
    for name, check in checks.items():
        count = check['count']
        if 'pass' in check:
            mark = "[OK]" if check['pass'] else "[FAIL]"
            cap = check.get('cap')
            extra = ""
            if name == "em_dashes":
                extra = f" ({check['ratio_per_500_words']} per 500 words)"
            lines.append(f"  {name}: {count} (cap: {cap}){extra} {mark}")
        else:
            lines.append(f"  {name}: {count}  -- {check.get('note', '')}")
    lines.append("")
    lines.append(f"Overall: {'PASS' if result['all_pass'] else 'FAIL'}")
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
    result = scan(text)

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(format_human(result))

    sys.exit(0 if result['all_pass'] else 1)


if __name__ == '__main__':
    main()

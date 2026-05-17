#!/usr/bin/env python3
"""
Skill metrics for evaluate-skill audits.

Given a skill (SKILL.md file or skill directory), compute objective
metrics for the nine evaluation principles: word counts, formatting,
description quality, anti-pattern occurrences, bundled resources.

Usage:
    python skill_metrics.py path/to/SKILL.md
    python skill_metrics.py path/to/skill-dir/
    python skill_metrics.py path/to/skill --json
"""

import argparse
import json
import re
import sys
from pathlib import Path


GENERIC_ADVICE_PATTERNS = [
    r'\bbe\s+careful\b',
    r'\bbe\s+thorough\b',
    r'\bbe\s+specific\b',
    r'\bbe\s+honest\b',
    r'\bbe\s+clear\b',
    r'\bbe\s+mindful\b',
    r'\bconsider\s+all\b',
    r'\bthink\s+step\s+by\s+step\b',
    r'\buse\s+your\s+judgment\b',
    r'\bas\s+appropriate\b',
    r'\bas\s+needed\b',
    r'\bhandle\s+edge\s+cases\b',
]

ASPIRATIONAL_PREAMBLE_PATTERNS = [
    r'this skill empowers',
    r'this skill enables you',
    r'this skill helps you',
    r'welcome to',
    r'this comprehensive',
    r'this powerful',
    r'this innovative',
    r'this is a guide',
    r'in this skill,? we',
]

ALL_CAPS_DIRECTIVES = re.compile(r'\b(MUST|NEVER|ALWAYS|MUST NOT|SHALL|SHALL NOT)\b')


def parse_frontmatter(text: str) -> tuple:
    """Return (frontmatter_dict, body_text). Empty dict if no frontmatter."""
    m = re.match(r'^---\n(.*?)\n---\n(.*)$', text, re.DOTALL)
    if not m:
        return {}, text
    fm_text = m.group(1)
    body = m.group(2)

    # Naive YAML for simple fields (preserves multi-line description)
    fm = {}
    current_key = None
    current_value_lines = []
    for line in fm_text.split('\n'):
        match = re.match(r'^([a-zA-Z_]+):\s*(.*)$', line)
        if match:
            if current_key:
                fm[current_key] = ' '.join(current_value_lines).strip()
            current_key = match.group(1)
            current_value_lines = [match.group(2)] if match.group(2) else []
        elif current_key:
            current_value_lines.append(line.strip())
    if current_key:
        fm[current_key] = ' '.join(current_value_lines).strip()
    return fm, body


def strip_for_word_count(text: str) -> str:
    text = re.sub(r'```.*?```', '', text, flags=re.DOTALL)
    text = re.sub(r'`[^`]+`', '', text)
    return text


def strip_for_anti_pattern_check(text: str) -> str:
    """Strip code blocks, blockquotes, and quoted phrases before anti-pattern
    detection. Phrases inside quotes are usually examples being flagged, not
    the skill author's own directives."""
    text = re.sub(r'```.*?```', '', text, flags=re.DOTALL)
    text = re.sub(r'`[^`]+`', '', text)
    text = re.sub(r'^>\s.*$', '', text, flags=re.MULTILINE)
    text = re.sub(r'"[^"\n]*"', '""', text)
    text = re.sub(r"'[^'\n]{4,}'", "''", text)  # 4+ char single-quoted phrases (skip contractions)
    return text


def count_words(text: str) -> int:
    return len(strip_for_word_count(text).split())


def count_pattern_occurrences(text: str, patterns: list) -> dict:
    counts = {}
    for pattern in patterns:
        matches = re.findall(pattern, text, flags=re.IGNORECASE)
        if matches:
            counts[pattern] = len(matches)
    return counts


def analyze_description(desc: str) -> dict:
    word_count = len(desc.split())
    quoted_phrases = re.findall(r'"[^"]+"', desc)
    has_non_trigger = bool(re.search(
        r'\b(do not|don\'?t|never)\s+use\b|\bnot\s+for\b',
        desc, re.IGNORECASE
    ))
    pushy_markers = re.findall(
        r'\b(whenever|even if|also use|always|including casually|including\s+short|by default)\b',
        desc, re.IGNORECASE
    )
    has_action_verb_lead = bool(re.match(
        r'^[A-Z][a-z]+\s+', desc.strip()
    ))
    return {
        "word_count": word_count,
        "quoted_phrase_count": len(quoted_phrases),
        "quoted_phrases_sample": quoted_phrases[:5],
        "has_explicit_non_triggers": has_non_trigger,
        "pushy_marker_count": len(pushy_markers),
        "starts_with_action_verb": has_action_verb_lead,
    }


def detect_worked_example(body: str) -> bool:
    patterns = [
        r'^#+\s*(?:worked\s+example|example\b)',
        r'^before:?\s*$',
        r'^after:?\s*$',
        r'\bexample\s+\d+:',
        r'^>\s',  # blockquoted content often == example
    ]
    for p in patterns:
        if re.search(p, body, re.IGNORECASE | re.MULTILINE):
            return True
    return False


def detect_decision_rules(body: str) -> int:
    """Heuristic: count explicit decision-rule patterns."""
    patterns = [
        r'\buse\s+\w+\s+when\b',
        r'\bif\s+[^.]+,\s+(?:use|then|do)\b',
        r'\bwhen\s+[^.]+,\s+(?:use|do)\b',
        r'\botherwise[:,]',
        r'\bstage\s+\d+\b',
        r'\bcap[:\s]',
        r'\bthreshold[:\s]',
    ]
    total = 0
    for p in patterns:
        total += len(re.findall(p, body, re.IGNORECASE))
    return total


def detect_verification_artifact(body: str) -> bool:
    """Heuristic: does the skill mandate an artifact for verification?"""
    patterns = [
        r'/tmp/[\w\-]+',
        r'\.log\b',
        r'\.json\b',
        r'evidence\s+on\s+disk',
        r'verification\s+artifact',
        r'capture\s+to\s+`',
        r'>\s*/tmp/',
    ]
    for p in patterns:
        if re.search(p, body, re.IGNORECASE):
            return True
    return False


def detect_failure_enumeration(body: str) -> dict:
    """Heuristic: look for specific failure-mode enumeration patterns."""
    has_lazy_patch_list = bool(re.search(
        r'(lazy\s+patch|reject\s+the\s+(?:lazy|cheap)|do not propose)',
        body, re.IGNORECASE
    ))
    has_retry_ladder = bool(re.search(
        r'(stage\s+\d.+stage\s+\d|retry\s+ladder|layered\s+retry)',
        body, re.IGNORECASE | re.DOTALL
    ))
    has_stop_out_cases = bool(re.search(
        r'(stop[- ]out|escalate\s+to\s+(?:the\s+)?user|halt and surface)',
        body, re.IGNORECASE
    ))
    return {
        "has_lazy_patch_list": has_lazy_patch_list,
        "has_retry_ladder": has_retry_ladder,
        "has_stop_out_cases": has_stop_out_cases,
    }


def count_headers(text): return len(re.findall(r'^#{1,6}\s', text, flags=re.MULTILINE))
def count_bullets(text): return len(re.findall(r'^[\s]*[-*+]\s', text, flags=re.MULTILINE))
def count_numbered(text): return len(re.findall(r'^[\s]*\d+\.\s', text, flags=re.MULTILINE))


def count_bold(text):
    text = re.sub(r'```.*?```', '', text, flags=re.DOTALL)
    text = re.sub(r'`[^`]+`', '', text)
    return len(re.findall(r'\*\*[^*\n]+\*\*|__[^_\n]+__', text))


def count_italics(text):
    text = re.sub(r'\*\*[^*\n]+\*\*', '', text)
    text = re.sub(r'__[^_\n]+__', '', text)
    text = re.sub(r'```.*?```', '', text, flags=re.DOTALL)
    text = re.sub(r'`[^`]+`', '', text)
    return len(re.findall(r'(?<!\*)\*([^*\n]+)\*(?!\*)|(?<!_)_([^_\n]+)_(?!_)', text))


def evaluate_skill(skill_path: Path) -> dict:
    if skill_path.is_dir():
        skill_md = skill_path / 'SKILL.md'
        if not skill_md.exists():
            return {"error": f"No SKILL.md in directory {skill_path}"}
        skill_dir = skill_path
    else:
        skill_md = skill_path
        skill_dir = skill_path.parent

    text = skill_md.read_text(encoding='utf-8')
    fm, body = parse_frontmatter(text)

    body_word_count = count_words(body)

    has_scripts_dir = (skill_dir / 'scripts').exists()
    has_references_dir = (skill_dir / 'references').exists()
    has_assets_dir = (skill_dir / 'assets').exists()
    scripts_files = []
    if has_scripts_dir:
        scripts_files = sorted(
            f.name for f in (skill_dir / 'scripts').iterdir() if f.is_file()
        )

    desc_analysis = analyze_description(fm.get('description', ''))
    body_for_ap_check = strip_for_anti_pattern_check(body)
    generic_advice = count_pattern_occurrences(body_for_ap_check, GENERIC_ADVICE_PATTERNS)
    aspirational = count_pattern_occurrences(body_for_ap_check, ASPIRATIONAL_PREAMBLE_PATTERNS)
    all_caps_directives = ALL_CAPS_DIRECTIVES.findall(body_for_ap_check)

    failure_enum = detect_failure_enumeration(body)

    return {
        "path": str(skill_md),
        "frontmatter": {
            "has_name": 'name' in fm,
            "has_description": 'description' in fm,
            "has_tools_field": 'tools' in fm,
            "has_model_field": 'model' in fm,
            "name": fm.get('name', '<MISSING>'),
            "is_agent_style": ('tools' in fm) or ('model' in fm),
        },
        "description": desc_analysis,
        "body": {
            "word_count": body_word_count,
            "header_count": count_headers(body),
            "bullet_count": count_bullets(body),
            "numbered_count": count_numbered(body),
            "bold_count": count_bold(body),
            "italic_count": count_italics(body),
            "has_worked_example": detect_worked_example(body),
            "decision_rule_signals": detect_decision_rules(body),
            "has_verification_artifact": detect_verification_artifact(body),
            "failure_mode_signals": failure_enum,
        },
        "bundled_resources": {
            "scripts_dir_exists": has_scripts_dir,
            "scripts_files": scripts_files,
            "references_dir_exists": has_references_dir,
            "assets_dir_exists": has_assets_dir,
        },
        "anti_patterns": {
            "generic_advice_phrases": generic_advice,
            "aspirational_preamble_phrases": aspirational,
            "all_caps_directives_count": len(all_caps_directives),
            "all_caps_directives_sample": all_caps_directives[:10],
        },
        "size_class": (
            "tiny" if body_word_count < 500
            else "small" if body_word_count < 1500
            else "medium" if body_word_count < 3000
            else "large" if body_word_count < 5000
            else "very_large"
        ),
    }


def format_human(r: dict) -> str:
    if 'error' in r:
        return f"Error: {r['error']}"
    out = []
    out.append(f"Skill: {r['frontmatter']['name']}")
    out.append(f"Path: {r['path']}")
    out.append(f"Style: {'agent (has tools/model)' if r['frontmatter']['is_agent_style'] else 'skill'}")
    out.append("")

    out.append("Frontmatter:")
    fm = r['frontmatter']
    out.append(f"  name: {'[OK]' if fm['has_name'] else '[MISSING]'}")
    out.append(f"  description: {'[OK]' if fm['has_description'] else '[MISSING]'}")
    out.append("")

    out.append("Description quality:")
    d = r['description']
    out.append(f"  word_count: {d['word_count']} (target: 80+ for substantive skills)")
    out.append(f"  quoted phrasings: {d['quoted_phrase_count']} (target: 5+)")
    out.append(f"  explicit non-triggers: {'YES' if d['has_explicit_non_triggers'] else 'NO -- add Do-NOT clauses'}")
    out.append(f"  pushy markers: {d['pushy_marker_count']}")
    out.append(f"  starts with action verb: {'YES' if d['starts_with_action_verb'] else 'NO'}")
    out.append("")

    out.append(f"Body ({r['size_class']}):")
    b = r['body']
    out.append(f"  word count: {b['word_count']}")
    out.append(f"  headers: {b['header_count']}")
    out.append(f"  bullets: {b['bullet_count']}")
    out.append(f"  numbered items: {b['numbered_count']}")
    out.append(f"  bold phrases: {b['bold_count']}")
    out.append(f"  italics: {b['italic_count']}")
    out.append(f"  worked example present: {'YES' if b['has_worked_example'] else 'NO'}")
    out.append(f"  decision-rule signals: {b['decision_rule_signals']}")
    out.append(f"  verification artifact specified: {'YES' if b['has_verification_artifact'] else 'NO'}")
    fe = b['failure_mode_signals']
    out.append(f"  lazy-patch list: {'YES' if fe['has_lazy_patch_list'] else 'NO'}")
    out.append(f"  retry ladder: {'YES' if fe['has_retry_ladder'] else 'NO'}")
    out.append(f"  stop-out cases: {'YES' if fe['has_stop_out_cases'] else 'NO'}")
    out.append("")

    out.append("Bundled resources:")
    br = r['bundled_resources']
    if br['scripts_dir_exists']:
        out.append(f"  scripts/: YES -- {', '.join(br['scripts_files']) or '(empty)'}")
    else:
        out.append("  scripts/: NO")
    out.append(f"  references/: {'YES' if br['references_dir_exists'] else 'NO'}")
    out.append(f"  assets/: {'YES' if br['assets_dir_exists'] else 'NO'}")
    out.append("")

    out.append("Anti-patterns:")
    ap = r['anti_patterns']
    if ap['generic_advice_phrases']:
        out.append("  Generic advice phrases (flag for review):")
        for p, c in ap['generic_advice_phrases'].items():
            out.append(f"    {p}: {c}")
    else:
        out.append("  Generic advice phrases: NONE")
    if ap['aspirational_preamble_phrases']:
        out.append("  Aspirational preamble:")
        for p, c in ap['aspirational_preamble_phrases'].items():
            out.append(f"    {p}: {c}")
    else:
        out.append("  Aspirational preamble: NONE")
    out.append(f"  All-caps directives (MUST/NEVER/ALWAYS): {ap['all_caps_directives_count']}")
    if ap['all_caps_directives_count'] > 0:
        out.append("    Note: skill-creator flags these as a yellow flag")
    return "\n".join(out)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('path', help='Path to SKILL.md file or skill directory')
    parser.add_argument('--json', action='store_true', help='Output JSON')
    args = parser.parse_args()

    path = Path(args.path)
    if not path.exists():
        print(f"Error: path not found: {path}", file=sys.stderr)
        sys.exit(2)

    result = evaluate_skill(path)

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(format_human(result))


if __name__ == '__main__':
    main()
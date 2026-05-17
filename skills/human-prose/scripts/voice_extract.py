#!/usr/bin/env python3
"""
Voice feature extractor for sample-based voice matching.

Given 2-3 sample files written by a specific author, extract concrete
stylistic features: sentence length, burstiness, em-dash density,
contraction frequency, paragraph patterns, punctuation tics, top
content words, and sentence openers. Outputs voice-match guidance the
skill should follow.

Usage:
    python voice_extract.py sample1.txt sample2.txt [sample3.txt ...]
    python voice_extract.py samples/*.md --json
"""

import argparse
import json
import math
import re
import sys
from collections import Counter
from pathlib import Path


STOPWORDS = set("""
a an the and but or for nor so yet if then else when while as because since
i you he she it we they me him her us them my your his its our their this that
these those is are was were be been being am do does did have has had having
of to in on at by with from up down into onto over under above below between
about against during before after through within without
not no never always sometimes often rarely usually
can could should would may might must will shall just only also too very
""".split())


def strip_markdown(text: str) -> str:
    text = re.sub(r'^---\n.*?\n---\n', '', text, count=1, flags=re.DOTALL)
    text = re.sub(r'```.*?```', '', text, flags=re.DOTALL)
    text = re.sub(r'`[^`]+`', '', text)
    text = re.sub(r'^#{1,6}\s.*$', '', text, flags=re.MULTILINE)
    text = re.sub(r'\*\*([^*\n]+)\*\*', r'\1', text)
    text = re.sub(r'__([^_\n]+)__', r'\1', text)
    text = re.sub(r'(?<!\*)\*([^*\n]+)\*(?!\*)', r'\1', text)
    text = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', text)
    return text


def split_sentences(text: str) -> list:
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


def get_paragraphs(text: str) -> list:
    paras = [p.strip() for p in re.split(r'\n\s*\n', text)]
    return [p for p in paras if p and not p.startswith('#')]


def std_dev(values: list) -> float:
    if len(values) < 2:
        return 0.0
    mean = sum(values) / len(values)
    variance = sum((x - mean) ** 2 for x in values) / len(values)
    return math.sqrt(variance)


def count_contractions(text: str) -> int:
    pattern = re.compile(r"\b\w+(?:'(?:s|d|ll|ve|re|m)|n't)\b", re.IGNORECASE)
    return len(pattern.findall(text))


def build_guidance(em_dash_per_500, contraction_rate, sentence_stddev):
    notes = []
    if em_dash_per_500 > 1.0:
        notes.append(
            f"User uses em-dashes at {em_dash_per_500} per 500 words. "
            f"The default cap of 1 per 500 relaxes; match the user's rate."
        )
    elif em_dash_per_500 < 0.3:
        notes.append("User uses very few em-dashes. Stay at or below their rate.")
    if contraction_rate > 0.5:
        notes.append(
            f"Contraction rate {contraction_rate} per sentence: casual register. "
            "Default to contractions in the output."
        )
    elif contraction_rate < 0.1:
        notes.append(
            f"Contraction rate {contraction_rate} per sentence: formal register. "
            "Avoid contractions in the output."
        )
    if sentence_stddev > 7:
        notes.append(
            f"High burstiness (stddev {sentence_stddev:.1f}). "
            "Match the variance; don't smooth toward AI-uniform rhythm."
        )
    elif sentence_stddev < 4:
        notes.append(
            f"Low burstiness (stddev {sentence_stddev:.1f}). "
            "Unusual for human writing; consider whether the samples are representative."
        )
    return notes


def extract_features(texts: list, names: list) -> dict:
    combined = "\n\n".join(texts)
    combined = strip_markdown(combined)
    sentences = split_sentences(combined)

    paragraphs = []
    for text in texts:
        stripped = strip_markdown(text)
        paragraphs.extend(get_paragraphs(stripped))

    sentence_lengths = [len(s.split()) for s in sentences]
    para_sentence_counts = []
    for p in paragraphs:
        para_sents = split_sentences(p)
        if para_sents:
            para_sentence_counts.append(len(para_sents))

    word_count = len(combined.split())

    em_dash_count = combined.count('\u2014')
    em_dash_per_500 = round(em_dash_count / max(word_count, 1) * 500, 2)
    smart_quotes = sum(combined.count(c) for c in '\u201c\u201d\u2018\u2019')
    semicolons = combined.count(';')
    parentheticals = len(re.findall(r'\([^)]+\)', combined))

    contractions = count_contractions(combined)
    contraction_rate = round(contractions / max(len(sentences), 1), 3)

    one_sentence_paras = sum(1 for c in para_sentence_counts if c == 1)
    one_sentence_para_rate = round(
        one_sentence_paras / max(len(para_sentence_counts), 1), 3
    )

    words = re.findall(r"\b[a-z]+(?:'[a-z]+)?\b", combined.lower())
    content_words = [w for w in words if w not in STOPWORDS and len(w) > 2]
    top_words = Counter(content_words).most_common(50)

    openers = Counter()
    for s in sentences:
        toks = s.split()
        if toks:
            opener = toks[0].lower().rstrip('.,;:!?"\'')
            openers[opener] += 1
    top_openers = openers.most_common(20)

    sentence_stddev = std_dev(sentence_lengths)

    return {
        "sample_files": names,
        "total_word_count": word_count,
        "total_sentences": len(sentences),
        "total_paragraphs": len(paragraphs),
        "sentence_length": {
            "mean": round(sum(sentence_lengths) / max(len(sentence_lengths), 1), 2),
            "stddev": round(sentence_stddev, 2),
            "min": min(sentence_lengths) if sentence_lengths else 0,
            "max": max(sentence_lengths) if sentence_lengths else 0,
        },
        "paragraph_length_sentences": {
            "mean": round(sum(para_sentence_counts) / max(len(para_sentence_counts), 1), 2),
            "stddev": round(std_dev(para_sentence_counts), 2),
        },
        "one_sentence_paragraph_rate": one_sentence_para_rate,
        "punctuation_tics": {
            "em_dash_count": em_dash_count,
            "em_dash_per_500_words": em_dash_per_500,
            "smart_quotes": smart_quotes,
            "semicolons": semicolons,
            "parentheticals": parentheticals,
        },
        "contraction_rate_per_sentence": contraction_rate,
        "top_content_words": top_words,
        "top_sentence_openers": top_openers,
        "voice_match_guidance": build_guidance(
            em_dash_per_500, contraction_rate, sentence_stddev
        ),
    }


def format_human(result: dict) -> str:
    lines = []
    lines.append(f"Samples: {', '.join(result['sample_files'])}")
    lines.append(
        f"Total: {result['total_word_count']} words, "
        f"{result['total_sentences']} sentences, "
        f"{result['total_paragraphs']} paragraphs"
    )
    lines.append("")
    sl = result['sentence_length']
    lines.append(
        f"Sentence length: mean {sl['mean']}, stddev {sl['stddev']}, "
        f"range {sl['min']}-{sl['max']}"
    )
    pl = result['paragraph_length_sentences']
    lines.append(
        f"Paragraph length: mean {pl['mean']} sentences, stddev {pl['stddev']}"
    )
    lines.append(
        f"One-sentence paragraphs: {result['one_sentence_paragraph_rate']*100:.1f}%"
    )
    lines.append("")
    pt = result['punctuation_tics']
    lines.append("Punctuation tics:")
    lines.append(f"  em-dashes: {pt['em_dash_count']} ({pt['em_dash_per_500_words']} per 500 words)")
    lines.append(f"  smart quotes: {pt['smart_quotes']}")
    lines.append(f"  semicolons: {pt['semicolons']}")
    lines.append(f"  parentheticals: {pt['parentheticals']}")
    lines.append(f"Contraction rate: {result['contraction_rate_per_sentence']} per sentence")
    lines.append("")
    lines.append("Top content words:")
    for word, count in result['top_content_words'][:20]:
        lines.append(f"  {word}: {count}")
    lines.append("")
    lines.append("Top sentence openers:")
    for opener, count in result['top_sentence_openers'][:10]:
        lines.append(f"  {opener!r}: {count}")
    lines.append("")
    if result['voice_match_guidance']:
        lines.append("Voice-match guidance:")
        for note in result['voice_match_guidance']:
            lines.append(f"  - {note}")
    else:
        lines.append("Voice-match guidance: samples within default ranges; apply skill defaults.")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('files', nargs='+', help='Sample files by the target author')
    parser.add_argument('--json', action='store_true', help='Output JSON')
    args = parser.parse_args()

    texts = []
    names = []
    for f in args.files:
        path = Path(f)
        if not path.exists():
            print(f"Error: file not found: {f}", file=sys.stderr)
            sys.exit(2)
        texts.append(path.read_text(encoding='utf-8'))
        names.append(path.name)

    result = extract_features(texts, names)

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(format_human(result))

    sys.exit(0)


if __name__ == '__main__':
    main()

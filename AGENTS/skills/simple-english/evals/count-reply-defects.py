#!/usr/bin/env python3
"""Count reply-style defects in agent replies.

Four classes.

HARD       Punctuation and manners. A violation under every option of the rule.
           The target is zero: em-dash, contraction, opener, closer.

SLOP       A word that carries no fact, named by the skill's own two lists: the
           rule 10 ban list in SKILL.md, and references/word-swaps.md. The target
           is zero. Quoted error text is out of scope for this class, so a reply
           that quotes an upstream message can show a false hit.

DECORATOR  Formatting, counted and reported rather than failed, because the rule
           permits structure when the reply needs it: bold, header, bullet, table
           row, horizontal rule, emoji. The emoji class excludes the variation
           selector U+FE0F, which is a modifier and would double-count one glyph.

SHAPE      Present only when --prompts is given. Compares the reply against the
           shape its prompt declares. MISSING means the prompt needs labels and the
           reply has none. SPURIOUS means the prompt needs none and the reply
           carries a heading, a list, or a table. Either is a defect.

Fenced code blocks are removed before counting, because code legitimately contains
'#', '*', and apostrophes.

Usage:
    python3 count-reply-defects.py REPLY.md [MORE.md ...]
    python3 count-reply-defects.py --prompts evals/reply-prompts.txt OUT/*.md
    python3 count-reply-defects.py --json [--prompts FILE] OUT/*.md
"""

import json
import os
import re
import sys

FENCED = re.compile(r"^[ \t]*```.*?^[ \t]*```", re.S | re.M)

EM_DASH = re.compile(r"[\u2014\u2013]")
CONTRACTION = re.compile(
    r"\b\w+(?:n['\u2019]t|['\u2019](?:re|ll|ve|d|m))\b"
    r"|\b(?:it|that|there|what|let|he|she|who|here)['\u2019]s\b",
    re.I,
)
BOLD = re.compile(r"\*\*[^*\n]+\*\*")
HEADER = re.compile(r"^#{1,6}[ \t]+\S", re.M)
BULLET = re.compile(r"^[ \t]*(?:[-*+][ \t]+|\d+\.[ \t]+)", re.M)
TABLE_ROW = re.compile(r"^[ \t]*\|.*\|[ \t]*$", re.M)
HRULE = re.compile(r"^[ \t]*(?:-{3,}|\*{3,}|_{3,})[ \t]*$", re.M)
EMOJI = re.compile(
    "[\U0001F000-\U0001FAFF\U00002600-\U000027BF\U00002B00-\U00002BFF]"
)
OPENER = re.compile(
    r"^(?:certainly|great question|good question|sure thing|of course|absolutely)\b", re.I
)
CLOSER = re.compile(
    r"\b(?:i hope this helps|hope that helps|let me know|feel free to|happy to help)\b", re.I
)

# The rule 10 ban list in SKILL.md, and the single words from references/word-swaps.md.
# Common words the swap table also lists (just, easily, ensure, as needed) are left
# out, because legitimate technical prose uses them and a false hit teaches nothing.
SLOP_WORDS = [
    "leverage", "utilize", "simply", "seamless", "seamlessly", "effortless",
    "effortlessly", "robust", "powerful", "comprehensive", "performant",
    "functionality", "facilitate", "streamline", "crucial", "crucially",
    "pivotal", "paramount",
]
SLOP_PHRASES = [
    "in order to", "it is worth noting", "it is important to", "when it comes to",
    "in the event that", "due to the fact that", "is designed to", "aims to",
    "enables you to", "allows you to", "gracefully handles", "out of the box",
    "under the hood", "blazingly fast", "dive into", "delve into",
]
SLOP = re.compile(
    r"\b(?:"
    + "|".join(
        re.escape(w) for w in sorted(SLOP_WORDS + SLOP_PHRASES, key=len, reverse=True)
    )
    + r")\b",
    re.I,
)

WORD = re.compile(r"[A-Za-z0-9']+")

USAGE = (
    "usage: count-reply-defects.py [--json] [--prompts FILE] REPLY.md [MORE.md ...]"
)

HARD_KEYS = ["em_dash", "contraction", "opener", "closer"]
DECORATOR_KEYS = ["bold", "header", "bullet", "table_row", "hrule", "emoji"]
STRUCTURE_KEYS = ["header", "bullet", "table_row"]


def strip_fenced(text):
    return FENCED.sub("\n", text)


def edges(text):
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    if not lines:
        return "", ""
    return lines[0], lines[-1]


def measure(text):
    body = strip_fenced(text)
    first, last = edges(body)
    return {
        "words": len(WORD.findall(body)),
        "em_dash": len(EM_DASH.findall(body)),
        "contraction": len(CONTRACTION.findall(body)),
        "opener": len(OPENER.findall(first)),
        "closer": len(CLOSER.findall(last)),
        "slop": len(SLOP.findall(body)),
        "bold": len(BOLD.findall(body)),
        "header": len(HEADER.findall(body)),
        "bullet": len(BULLET.findall(body)),
        "table_row": len(TABLE_ROW.findall(body)),
        "hrule": len(HRULE.findall(body)),
        "emoji": len(EMOJI.findall(body)),
    }


def read(path):
    if path == "-":
        return sys.stdin.read()
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            return handle.read()
    except OSError as error:
        raise SystemExit(f"cannot read {path}: {error}") from error


def expected_shapes(prompts_path):
    """Map 1-based prompt order to the shape each prompt declares."""
    shapes = {}
    index = 0
    for line in read(prompts_path).splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        index += 1
        shapes[index] = line.split("|", 1)[0].strip()
    return shapes


def reply_index(path):
    match = re.match(r"(\d+)", os.path.basename(path))
    return int(match.group(1)) if match else None


def shape_verdict(counts, expected):
    if expected is None:
        return "-"
    has_structure = any(counts[key] for key in STRUCTURE_KEYS)
    if expected == "structure":
        return "ok" if has_structure else "MISSING"
    if expected == "prose":
        return "SPURIOUS" if has_structure else "ok"
    return "?"


def main():
    args = sys.argv[1:]
    as_json = False
    prompts_path = None
    paths = []
    i = 0
    while i < len(args):
        if args[i] == "--json":
            as_json = True
            i += 1
        elif args[i] == "--prompts":
            if i + 1 >= len(args):
                print("--prompts needs a file", file=sys.stderr)
                return 2
            prompts_path = args[i + 1]
            i += 2
        else:
            paths.append(args[i])
            i += 1

    if not paths:
        print(USAGE, file=sys.stderr)
        return 2

    shapes = expected_shapes(prompts_path) if prompts_path else {}

    rows = []
    for path in paths:
        counts = measure(read(path))
        hard = sum(counts[k] for k in HARD_KEYS)
        decorators = sum(counts[k] for k in DECORATOR_KEYS)
        index = reply_index(path)
        verdict = shape_verdict(counts, shapes.get(index)) if shapes else "-"
        rows.append(
            {
                "file": path,
                "hard": hard,
                "slop": counts["slop"],
                "decorators": decorators,
                "shape": verdict,
                **counts,
            }
        )

    if as_json:
        print(json.dumps(rows, indent=2))
        return 0

    width = max(len(r["file"]) for r in rows)
    show_shape = bool(shapes)
    head = f"{'file':<{width}}  {'words':>6}  {'HARD':>4}  {'SLOP':>4}  {'deco':>5}"
    if show_shape:
        head += f"  {'shape':<8}"
    print(head + "  detail")
    for r in rows:
        hard_detail = ",".join(f"{k}={r[k]}" for k in HARD_KEYS if r[k]) or "clean"
        deco_detail = ",".join(f"{k}={r[k]}" for k in DECORATOR_KEYS if r[k]) or "none"
        line = (
            f"{r['file']:<{width}}  {r['words']:>6}  {r['hard']:>4}  {r['slop']:>4}"
            f"  {r['decorators']:>5}"
        )
        if show_shape:
            line += f"  {r['shape']:<8}"
        print(line + f"  hard[{hard_detail}] deco[{deco_detail}]")

    words = sum(r["words"] for r in rows) or 1
    hard = sum(r["hard"] for r in rows)
    slop = sum(r["slop"] for r in rows)
    decorators = sum(r["decorators"] for r in rows)
    print()
    print(
        f"TOTAL  files={len(rows)}  words={words}  HARD={hard}"
        f"  hard per 100 words={100 * hard / words:.2f}  SLOP={slop}  decorators={decorators}"
    )
    if show_shape:
        missing = sum(1 for r in rows if r["shape"] == "MISSING")
        spurious = sum(1 for r in rows if r["shape"] == "SPURIOUS")
        print(f"SHAPE  MISSING={missing}  SPURIOUS={spurious}  ok={len(rows) - missing - spurious}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

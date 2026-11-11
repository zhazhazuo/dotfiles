#!/usr/bin/env python3
"""Score agent replies against the global Reply Style, using the vendored STE linter.

Four classes.

HARD       Punctuation and manners. A violation under every option of the rule.
           The target is zero: em-dash, contraction, opener, closer. The first two
           come from `ste_lint.py --type reply`; openers and closers are reply-only
           tells that the STE linter does not model, so they are counted here.

SLOP       A word that carries no fact, from the vendored `slop.tsv` lexicon union
           the core list, both inside `ste_lint.py`. The target is zero. Quoted error
           text stays in scope and can produce a false hit.

DECORATOR  Formatting, counted and reported rather than failed, because the rule
           permits structure when the reply needs it: bold, header, bullet, table
           row, horizontal rule, emoji. Bold, header, and bullet come from
           `ste_lint.py --type reply`; table rows, rules, and emoji are counted
           here. The emoji class excludes the variation selector U+FE0F, which is a
           modifier and would double-count one glyph.

SHAPE      Present only when --prompts is given. Compares the reply against the
           shape its prompt declares. MISSING means the prompt needs labels and the
           reply has none. SPURIOUS means the prompt needs none and the reply
           carries a heading, a list, or a table. Either is a defect.

STE        Issue 9 constraints on the reply: sentence over 20 words, banned modal
           (should, would, may, might, could), perfect tense, ing clause, semicolon,
           Latin abbreviation, trailing condition, synonym rotation. The reply is
           now held to the standard, so the target is zero. Contraction, em-dash,
           and slop are excluded here because HARD and SLOP already count them.
           Approved vocabulary is not scored: the dictionary is copyrighted and not
           vendored, so an unapproved word is invisible to this measure.

REGISTER   The `### Register` block in AGENTS.md bans shapes that stage a finding instead
           of stating it. Three families are counted, because a regex reaches them:
           staging, flat certainty, and the confiding moves. Compressed syntax is a
           fourth family and is not counted: a noun stack, a verbed noun, a dropped
           `that` and a distant verb need a parse. Quoted spans and inline code are
           removed before matching, because the rule keeps a quoted error message in
           its own words.

LEAD       Not a count. `--lead` prints each reply's first sentence and the first
           sentence of its last paragraph, so a reader can judge whether the
           conclusion leads. Ordering is meaning, so no regex scores it. A reply
           that states the decision only at the end is inverted.

Fenced code blocks and inline code spans are removed by `ste_lint.py` before it
counts, because code legitimately contains '#', '*', and apostrophes.

Usage:
    python3 score-replies.py REPLY.md [MORE.md ...]
    python3 score-replies.py --prompts evals/reply-prompts.txt OUT/*.md
    python3 score-replies.py --json [--prompts FILE] OUT/*.md
    python3 score-replies.py --lead OUT/*.md

`ste_lint.py` and `slop.tsv` are vendored verbatim from github.com/AminBlg/SimpleEnglish
at commit a6fcb4f. Update them by copying the new files over, keeps no local edits.
"""

import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

try:
    import ste_lint  # noqa: E402  vendored, unmodified
except ImportError as error:
    raise SystemExit(f"cannot import the vendored ste_lint.py next to this script: {error}") from error

FENCED = re.compile(r"^[ \t]*```.*?^[ \t]*```", re.S | re.M)
TABLE_ROW = re.compile(r"^[ \t]*\|.*\|[ \t]*$", re.M)
HRULE = re.compile(r"^[ \t]*(?:-{3,}|\*{3,}|_{3,})[ \t]*$", re.M)
EMOJI = re.compile("[\U0001F000-\U0001FAFF\U00002600-\U000027BF\U00002B00-\U00002BFF]")
OPENER = re.compile(
    r"^(?:certainly|great question|good question|sure thing|of course|absolutely)\b", re.I
)
CLOSER = re.compile(
    r"\b(?:i hope this helps|hope that helps|let me know|feel free to|happy to help)\b", re.I
)
WORD = re.compile(r"[A-Za-z0-9']+")

# Terms the global Reply Style bans and the vendored lexicon does not match. Every
# entry is verified against `ste_lint.SLOP` by `--self-check`, so a reply can never be
# counted twice for the same word. `functionality` and `effortless` come from the
# skill's own ban list; the phrases come from the rule that names "it is worth noting".
SLOP_EXTRA_TERMS = [
    "functionality",
    "effortless",
    "it is worth noting",
    "it is important to",
    "when it comes to",
    "in the event that",
    "is designed to",
    "aims to",
    "enables you to",
    "allows you to",
    "gracefully handles",
    "out of the box",
    "under the hood",
    "dive into",
]
SLOP_EXTRA = re.compile(
    r"\b(?:" + "|".join(re.escape(t) for t in sorted(SLOP_EXTRA_TERMS, key=len, reverse=True)) + r")\b",
    re.I,
)

# The `### Register` block in AGENTS.md bans shapes that carry no content. Only the
# families a regex reaches are counted, each taken from the `declauding` register
# (tag `declauding-v0.13.0`) and narrowed to the terms that cost a technical reply.
# Compressed syntax (entries 53 to 56) is not counted: a noun stack, a verbed noun, a
# dropped `that` and a distant verb need a parse, and the register says so.
#
# Quoted spans and inline code are removed before matching, because the rule keeps a
# quoted error message and an error string in the author's own words.
REGISTER_PATTERNS = {
    "staged_reveal": [
        r"\b(?:it|that|this|they)\s+(?:is|was|are|were)\s+not\b[^.!?\n]{0,80}[.!?]\s*(?:it|that|this|they)\s+(?:is|was|are|were)\b",
        r"\bnot (?:an?|the) [a-z-]+ (?:answer|question|bug|problem|failure|measure), but\b",
    ],
    "significance": [
        r"\bthe (?:leg|part|piece|thing|detail|one|row|line) that (?:answers|matters|counts|decides)\b",
        r"\bthe real (?:question|issue|problem|story|work)\b",
        r"\bwhat (?:actually|really) matters\b",
        r"\bthe (?:whole|entire) (?:point|trick|business)\b",
    ],
    "abstraction_agency": [
        r"\b(?:the|this|that) (?:table|list|median|data|metric|chart|graph|report|row|column|number|test)\s+(?:shows|hides|tells|refuses|admits|decides|knows|chooses|wants)\b",
    ],
    "flat_certainty": [
        r"\b(?:plainly|quietly|provably|vacuously|demonstrably|empirically|structurally)\b",
        r"\b(?:byte|bit)-(?:identical|exact|for-byte)\b",
        r"\b(?:mutation|live|hand|root)-(?:checked|verified|tested|caused)\b",
        r"\bre-(?:derived|verified|measured|confirmed)\b",
        r"\b(?:unwired|ungated|unguarded|unmeasured|unverifiable|unparseable)\b",
        r"\b(?:admits|verdict|carve-out|precedent)\b",
    ],
    "confiding": [
        r"\b(?:let'?s be honest|to be clear|i won'?t pretend|frankly|honestly)\b",
        r"\byou (?:do not|don'?t) have to take my word\b",
        r"\bthat'?s why\b[^.!?\n]{0,40}\bmattered\b",
        r"\b\w+ is dead\b",
        # A sentence that lands on a bare auxiliary. The earned case names both halves in one
        # clause ("PostgreSQL does and MySQL does not"), so a sentence-initial subject is required.
        r"(?:^|[.!?]\s+)[A-Z][a-z]+ (?:[a-z]+ )?(?:did|does|was|were) not\.",
    ],
}
REGISTER_KEYS = list(REGISTER_PATTERNS)
REGISTER = {key: [re.compile(p, re.I) for p in pats] for key, pats in REGISTER_PATTERNS.items()}
QUOTED = re.compile(r'"[^"\n]{0,300}"|\u201c[^\u201d\n]{0,300}\u201d|`[^`\n]+`')

USAGE = "usage: score-replies.py [--json] [--lead] [--prompts FILE] REPLY.md [MORE.md ...]"

# An em-dash is a reported diagnostic, not a hard violation: AGENTS.md released the ban
# on 2026-10-27, because ASD-STE100 Issue 9 Rule 8.1 permits the mark.
HARD_KEYS = ["contraction", "opener", "closer"]
DIAGNOSTIC_KEYS = ["em_dash"]
STE_KEYS = [
    "sentence_over_limit",
    "banned_modal",
    "perfect_tense",
    "ing_clause",
    "semicolon",
    "latin_abbrev",
    "trailing_condition",
    "synonym_rotation",
]
DECORATOR_KEYS = ["bold", "header", "bullet", "table_row", "hrule", "emoji"]
STRUCTURE_KEYS = ["header", "bullet", "table_row"]


def strip_fenced(text):
    """Remove fenced code only. `ste_lint.strip_code` also rewrites table rows and
    blanks headings, which would hide the structure this measure scores."""
    return FENCED.sub("\n", text.replace("\r\n", "\n"))


def register_counts(text):
    """Count the reply-register tics. Quoted spans and inline code are out of scope."""
    body = QUOTED.sub(" ", strip_fenced(text))
    return {key: sum(len(p.findall(body)) for p in pats) for key, pats in REGISTER.items()}


def edges(text):
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    if not lines:
        return "", ""
    return lines[0], lines[-1]


def measure(text):
    """One reply's counts: the vendored linter first, then the reply-only layer."""
    reply = ste_lint.reader_check(text)["counts"]
    descriptive = ste_lint.lint(text, "descriptive")["violations"]
    ste = ste_lint.lint(text, "procedural")["violations"]
    body = strip_fenced(text)
    first, last = edges(body)
    return {
        "words": len(WORD.findall(body)),
        "em_dash": reply["em_dash"],
        "contraction": reply["contraction"],
        "opener": len(OPENER.findall(first)),
        "closer": len(CLOSER.findall(last)),
        "slop": descriptive["slop_word"] + len(SLOP_EXTRA.findall(body)),
        "bold": reply["bold_spans"],
        "header": reply["headers"],
        "bullet": reply["bullets"],
        "table_row": len(TABLE_ROW.findall(body)),
        "hrule": len(HRULE.findall(body)),
        "emoji": len(EMOJI.findall(body)),
        **{key: ste[key] for key in STE_KEYS},
        **register_counts(text),
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


SENTENCE = re.compile(r"(?<=[.!?])[\"')\]]*\s+")


def sentences(text):
    """Split a reply into sentences, with fenced code removed first."""
    body = strip_fenced(text).strip()
    if not body:
        return []
    return [part.strip() for part in SENTENCE.split(body) if part.strip()]


def lead_report(paths):
    """Print what a reader meets first and what the last paragraph says first.

    Ordering is meaning, so this prints the two sentences that decide whether the
    conclusion leads, and leaves the verdict to the reader.
    """
    for path in paths:
        body = strip_fenced(read(path))
        parts = sentences(body)
        paras = [p.strip() for p in body.split("\n\n") if p.strip()]
        print(f"{os.path.basename(path)}  sentences={len(parts)}  paragraphs={len(paras)}")
        if parts:
            print(f"  first: {parts[0][:220]}")
        if len(paras) > 1:
            tail = sentences(paras[-1])
            if tail:
                print(f"  last paragraph opens: {tail[0][:220]}")
        print()
    return 0


def shape_verdict(counts, expected):
    if expected is None:
        return "-"
    has_structure = any(counts[key] for key in STRUCTURE_KEYS)
    if expected == "structure":
        return "ok" if has_structure else "MISSING"
    if expected == "prose":
        return "SPURIOUS" if has_structure else "ok"
    return "?"


def self_check():
    """Prove the addendum adds coverage without double-counting.

    Three claims, each asserted: no addendum term is already matched by the vendored
    lexicon, every addendum term scores exactly one hit, and the two vendored files
    are the ones this scorer expects.
    """
    for term in SLOP_EXTRA_TERMS:
        overlap = ste_lint.SLOP.search(term)
        assert not overlap, f"addendum term {term!r} is already matched by ste_lint as {overlap.group(0)!r}"
        hits = measure(f"Note that {term} holds.")["slop"]
        assert hits == 1, f"addendum term {term!r} scored {hits}, expected 1"
    clean = measure("Postgres listens on port 5432. Restart the worker.")
    assert clean["slop"] == 0 and clean["em_dash"] == 0 and clean["contraction"] == 0, clean
    assert not any(clean[key] for key in REGISTER_KEYS), clean
    # One positive control per family, and one quotation that must not count.
    register_controls = {
        "staged_reveal": "It is not a wrong answer. It is a non-answer.",
        "significance": "The real question is whether the cache holds.",
        "abstraction_agency": "The median hides it.",
        "flat_certainty": "The retry is provably safe.",
        "confiding": "Let's be honest: the run was late.",
    }
    for key, sample in register_controls.items():
        hits = measure(sample)[key]
        assert hits == 1, f"control for {key!r} scored {hits}, expected 1"
    quoted = measure("The log says \"It is not a wrong answer. It is a non-answer.\" and stops.")
    assert quoted["staged_reveal"] == 0, quoted
    # The register's own earned case: both halves named in one clause.
    earned = measure("PostgreSQL rolls back DDL and MySQL does not.")
    assert earned["confiding"] == 0, earned
    assert measure("The disk was full \u2014 the deploy failed.")["em_dash"] == 1
    assert measure("It's safe.")["contraction"] == 1
    opener_case = measure("Certainly. The port defaults to 443.")
    assert opener_case["opener"] == 1, opener_case
    closer_case = measure("The port defaults to 443. I hope this helps.")
    assert closer_case["closer"] == 1, closer_case
    assert measure("## Tradeoffs\n\n| A | B |\n|---|---|\n| 1 | 2 |")["table_row"] == 3
    assert measure("```\n# not a header\n**not bold**\n```\nPlain.")["header"] == 0
    print(f"self-check OK: {len(SLOP_EXTRA_TERMS)} addendum terms, none double-counted")


def main():
    args = sys.argv[1:]
    as_json = False
    as_lead = False
    prompts_path = None
    paths = []
    i = 0
    while i < len(args):
        if args[i] == "--self-check":
            self_check()
            return 0
        if args[i] == "--json":
            as_json = True
            i += 1
        elif args[i] == "--lead":
            as_lead = True
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

    if as_lead:
        return lead_report(paths)

    shapes = expected_shapes(prompts_path) if prompts_path else {}

    rows = []
    for path in paths:
        counts = measure(read(path))
        hard = sum(counts[k] for k in HARD_KEYS)
        decorators = sum(counts[k] for k in DECORATOR_KEYS)
        ste = sum(counts[k] for k in STE_KEYS)
        register = sum(counts[k] for k in REGISTER_KEYS)
        index = reply_index(path)
        verdict = shape_verdict(counts, shapes.get(index)) if shapes else "-"
        rows.append(
            {
                "file": path,
                "hard": hard,
                "slop": counts["slop"],
                "ste": ste,
                "register": register,
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
    head = f"{'file':<{width}}  {'words':>6}  {'HARD':>4}  {'SLOP':>4}  {'STE':>4}  {'REG':>4}  {'deco':>5}"
    if show_shape:
        head += f"  {'shape':<8}"
    print(head + "  detail")
    for r in rows:
        hard_detail = ",".join(f"{k}={r[k]}" for k in HARD_KEYS if r[k]) or "clean"
        dash_detail = ",".join(f"{k}={r[k]}" for k in DIAGNOSTIC_KEYS if r[k]) or "none"
        deco_detail = ",".join(f"{k}={r[k]}" for k in DECORATOR_KEYS if r[k]) or "none"
        ste_detail = ",".join(f"{k}={r[k]}" for k in STE_KEYS if r[k]) or "clean"
        register_detail = ",".join(f"{k}={r[k]}" for k in REGISTER_KEYS if r[k]) or "clean"
        line = (
            f"{r['file']:<{width}}  {r['words']:>6}  {r['hard']:>4}  {r['slop']:>4}"
            f"  {r['ste']:>4}  {r['register']:>4}  {r['decorators']:>5}"
        )
        if show_shape:
            line += f"  {r['shape']:<8}"
        print(
            line
            + f"  hard[{hard_detail}] ste[{ste_detail}] reg[{register_detail}]"
            + f" deco[{deco_detail}] dash[{dash_detail}]"
        )

    words = sum(r["words"] for r in rows) or 1
    hard = sum(r["hard"] for r in rows)
    slop = sum(r["slop"] for r in rows)
    ste = sum(r["ste"] for r in rows)
    register = sum(r["register"] for r in rows)
    decorators = sum(r["decorators"] for r in rows)
    print()
    print(
        f"TOTAL  files={len(rows)}  words={words}  HARD={hard}"
        f"  hard per 100 words={100 * hard / words:.2f}  SLOP={slop}  STE={ste}"
        f"  REGISTER={register}  decorators={decorators}"
    )
    if show_shape:
        missing = sum(1 for r in rows if r["shape"] == "MISSING")
        spurious = sum(1 for r in rows if r["shape"] == "SPURIOUS")
        print(f"SHAPE  MISSING={missing}  SPURIOUS={spurious}  ok={len(rows) - missing - spurious}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

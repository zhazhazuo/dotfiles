---
name: refine-knowledge-base
description: Use when the user asks about a feature, module, or code path that is missing or incomplete in ./repoWiki/
allowed-tools: Read, Grep
---

## Trigger Condition

Load this skill when:
- The user asks about a specific feature, module, or code path
- AND you cannot fully answer from `./repoWiki/` (entry is absent or incomplete)

---

## What You Must Do

Follow this sequence exactly:

```
1. Load gap-detection.md — confirm the gap before touching any code
2. If gap confirmed → load execution-plan.md and follow its 6 steps
3. Step 3 dispatches a subagent to read code — wait for it to return before writing
4. Load knowledge-base-writer rules before writing any file
5. Write only what is missing — do not regenerate existing files
```

Default: do not read source code directly. The subagent in Step 3 reads code; the main agent writes KB files from its output.

Exceptions:
- Symbol fast path: if `explore-repository` already read one scoped source file and passed findings, skip subagent dispatch and write from those findings.
- Subagents unavailable: the main agent may perform the same scoped read using the Step 3 prompt constraints, then record that fallback in the working notes.

---

## Sub-files

### Load `gap-detection.md` immediately after reading this file.

It gives you a 3-check method to confirm whether a gap actually exists.
Without it you may write over correct documentation or miss where the gap is.

### Load `execution-plan.md` only after the gap is confirmed.

It contains the 6 steps: confirm gap, identify scope, dispatch subagent or scoped fallback, write KB files, sync RUNBOOK, update META.
Loading it before confirming the gap wastes effort — the gap check may show documentation already exists.

### Load `knowledge-base-writer` sub-files before writing any file.

- `knowledge-base-writer/file-generation-rules.md` — required sections per file type (module table, feature flowchart, etc.)
- `knowledge-base-writer/output-style.md` — tone and format rules; skip this and output will be inconsistent with existing KB files

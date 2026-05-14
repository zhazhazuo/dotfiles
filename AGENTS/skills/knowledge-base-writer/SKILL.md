---
name: knowledge-base-writer
description: Shared writing rules for all knowledge base skills — load this before writing any file to ./docs/
allowed-tools: Read, Grep
---

## What the KB Is

The KB is an abstract indexing layer — not a second copy of the source code.

Every entry in the KB does exactly one of three things:
- Describes the big picture (what a feature/module/system does in 1–3 lines)
- Points to another KB file (cross-link for deeper context)
- Points to raw code (exact file path + one-line role)

**Consequence for writing:** do not paraphrase code at length. Extract the pointer, not the content. Use concise behavior summaries only when they improve routing or preserve an invariant. If explaining a function body takes more than one or two lines, replace it with the file path and a one-line description. The code is the source of truth — the KB is the index into it.

---

## What This Skill Does

Defines HOW to write knowledge base files. It has no trigger condition — it is always loaded by another skill before any write operation.

Read the constraints below before touching any file, then load sub-files as directed.

---

## Output Structure

All files go under `./docs/`:

```
docs/
├── META.md
├── RUNBOOK.md
├── 00_overview/
│   ├── big_picture.md
│   └── tech_stack.md
├── 01_maps/
│   ├── system_map.md
│   ├── feature_map.md
│   └── module_map.md
├── 02_guides/
│   ├── dev.md
│   ├── deploy.md
│   └── debug.md
├── 03_index/
│   ├── file_index.md
│   └── api_index.md
├── 04_modules/
│   └── <name>.md
├── 05_symbols/
│   └── <module-slug>.md
└── 06_features/
    └── <kebab-name>.md
```

---

## Constraints

Enforce these on every file you write — no exceptions:

- Do NOT invent features that do not exist
- Prefer extraction over assumption
- Keep each file < 200 lines
- Use bullet points over paragraphs
- Every concept must be linkable
- No emojis in any generated file
- Every `06_features/` file MUST contain a Mermaid flowchart in the Architecture section
- Every `04_modules/` file MUST contain a Scope Table (markdown table with Implementation and Consumer rows)
- Every `05_symbols/` file MUST declare its parent module and feature in the header (`Module:` and `Feature:` links)
- `05_symbols/` files are write-through only — never generated speculatively

---

## Sub-files

### Load `file-generation-rules.md` before writing any file.

It defines the required sections for every file type in `./docs/` (00_overview through 06_features).
Without it you will produce files with missing sections — especially the mandatory Scope Table and Mermaid flowchart.

### Load `heuristics.md` when scanning an unfamiliar codebase.

It tells you how to detect backend framework, frontend, database, CI/CD, and infra from project files.
Use it before deciding which KB files to generate and what to include in system_map and tech_stack.

### Load `mermaid-rules.md` before adding any diagram.

It defines which files require diagrams, which diagram type to use, and style constraints (max nodes, naming).
Skipping it produces diagrams that are either missing where required or overly complex where they should be simple.

### Load `output-style.md` before writing any prose.

It enforces the arrow-and-short-phrase style used across all KB files.
If you skip it, your output will use paragraph prose instead of the structured format the rest of the KB expects.

### Load `meta-template.md` when creating or updating `./docs/META.md`.

It defines the exact fields (`schema_version`, `generated`, `last_synced`, `last_commit`) and how to capture the commit SHA.
Do not write META.md from memory — field names and update rules are defined there.

### Load `RUNBOOK-template.md` only when writing or updating `./docs/RUNBOOK.md`.

It is the exact template for the RUNBOOK, including the metadata block and navigation sections.
Do not write RUNBOOK.md from memory — always use this template to ensure consistency.

---
name: initialize-knowledge-base
description: Use when ./docs/RUNBOOK.md does not exist and a knowledge base needs to be generated from scratch for the current project
allowed-tools: Read, Grep
---

## Trigger Condition

Check for `./docs/RUNBOOK.md`. If the file does not exist, run this skill now.

---

## What You Must Do

Follow this sequence exactly:

```
1. Load knowledge-base-writer skill — all writing rules live there
2. Load execution-plan.md — follow its 9 steps in order (Step 9 creates META.md)
3. Exploration steps use subagents — dispatch and wait before writing
4. Writing steps are done by the main agent using subagent output
5. Do not skip steps or reorder them
```

Subagent steps: 1+2 (Stack & Structure Scanner), 5 (File Indexer), 6 (Module Extractors, parallel), 7 (Guide Extractor)
Main agent writing steps: 3, 4, 8, 9

---

## Sub-files

### Load `execution-plan.md` immediately after reading this file.

It contains the 9 ordered steps you must follow to build the full `./docs/` directory.
Without it you have no procedure — do not begin writing any file before loading it.

### Load `knowledge-base-writer` sub-files as directed by execution-plan.md.

Each step in execution-plan.md tells you which writer sub-file to load at that point:

- `knowledge-base-writer/heuristics.md` — pass to the Stack & Structure Scanner subagent at Steps 1+2
- `knowledge-base-writer/file-generation-rules.md` — load before writing any file, defines required sections per file type
- `knowledge-base-writer/mermaid-rules.md` — load when writing files that require diagrams
- `knowledge-base-writer/output-style.md` — load before writing any file, enforces tone and format
- `knowledge-base-writer/RUNBOOK-template.md` — load at Step 9, use as the exact template for RUNBOOK.md

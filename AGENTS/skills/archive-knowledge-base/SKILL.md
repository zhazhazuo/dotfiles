---
name: archive-knowledge-base
description: Use when the user has completed a feature development task and the feature is not yet documented in ./docs/06_features/
allowed-tools: Read, Grep
---

## Trigger Condition

Load this skill when ANY of the following occur:
- `KB_SYNC_REQUIRED` appears in context (fired by the git push hook in `setup/hooks.md`)
- The user explicitly signals completion: "done", "finished", "ready to merge", "pushed", "PR is up", "tests pass"
- AND `./docs/06_features/<feature-name>.md` does not yet exist

If `KB_SYNC_REQUIRED` fires but no new feature work was done this session, run gap-detection only — exit cleanly if nothing is missing.

---

## What You Must Do

Follow this sequence exactly:

```
1. Load execution-plan.md — follow its 7 steps in order
2. Load feature-doc-template.md at Step 4 to create the feature document
3. Load knowledge-base-writer rules before writing any file
4. Update ./docs/RUNBOOK.md after feature and index files, then update ./docs/META.md last
```

Do not create the feature document before reading the changed code (Step 3 in execution-plan.md).

---

## Sub-files

### Load `execution-plan.md` immediately after reading this file.

It contains the 7 ordered steps: extract feature name, identify changed files, read code, create doc, update indexes, update RUNBOOK, update META.
Without it you will miss steps and produce an incomplete or inconsistent KB entry.

### Load `feature-doc-template.md` at Step 4 of execution-plan.md.

It defines the exact structure the feature document must follow.
Using it ensures the output matches existing `./docs/06_features/` files in format.

### Load `knowledge-base-writer` sub-files before writing any file.

- `knowledge-base-writer/file-generation-rules.md` — enforces the Mermaid flowchart requirement in Architecture and the Scope Table requirement in module files
- `knowledge-base-writer/output-style.md` — tone rules; the feature doc must use the same arrow-and-short-phrase style as the rest of the KB

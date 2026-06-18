# Execution Plan

## Roles

- **Subagent**: reads source code within the identified scope, returns structured findings
- **Main agent**: receives subagent output, writes or updates KB files

If subagents are unavailable, the main agent may perform the same scoped read using the
subagent prompt constraints below. Do not broaden scope during fallback.

---

## Step 1 — Confirm Gap

Use `gap-detection.md` to verify the topic is missing or incomplete in `./repoWiki/`.

If fully documented → stop, answer from existing docs.

---

## Step 2 — Identify Scope

Determine the minimum set of files needed to fill the gap:

- Which module or feature is missing?
- Which KB files need to be created or updated?
  - `04_modules/<name>.md` for module gaps
  - `01_maps/feature_map.md` for feature gaps
  - `03_index/file_index.md` for path gaps
  - `05_symbols/<module-slug>.md` for symbol gaps

Produce a concrete file list before dispatching the subagent.

---

## Step 2b — Symbol Gap Fast Path

If `gap type == symbol`, use this path instead of Step 3:

### Findings already provided (e.g. from explore-repository Step 6):

```
Skip Step 3 — subagent dispatch is not needed
Go directly to Step 4: write the symbol entry to 05_symbols/<module-slug>.md
```

### No findings provided (direct refine call):

```
Scope = single source file containing the function
Dispatch lightweight subagent with this prompt (substitute bracketed values):

  Read ONLY: <source-file-path>
  Find function: <function-name>

  Return ONLY the block below. No prose.

  SYMBOL: <function-name>
  FILE: <source-file-path>
  MODULE: <module-name>
  FEATURE: <feature-name>
  SIGNATURE: <params> → <return type>
  BEHAVIOR: <one line — what this function does>
  CONSTRAINTS: <bullet list of side-effects, invariants, throws — or "none">
```

After subagent returns, go to Step 4 (write to `05_symbols/<module-slug>.md`).
Skip Steps 4a (feature_map) and 4b (module file) — they are not affected by symbol gaps.

---

## Step 3 — Subagent: Scoped Code Explorer

Dispatch ONE subagent with this prompt (substitute bracketed values from Step 2):

```
You are a focused code explorer. Read ONLY the files listed below.
Do NOT open any file outside this list.

Files to read:
<list every file path identified in Step 2>

Gap type: <module | feature | path>
Gap name: <name>

Return ONLY the block below. No prose. Omit any field where data is not found.

GAP_SCOPE: <name>

FINDINGS:
  RESPONSIBILITY: <one line — what this module or feature owns>
  ENTRY_POINTS:
    <path> → <role>
  KEY_FILES:
    <path> → <role>
  CONSTRAINTS:
    - <rule or invariant>
  NEW_PATHS:
    <path> → <one-line meaning for file_index>
  FEATURE_MAP_ENTRY:
    <feature name> → <path> → <one-line description>
  SCOPE_TABLE:
    Implementation:
      <path> → <what it implements>
    Consumer:
      <path> → <how/why it uses this module>
```

Wait for the subagent to return before writing any file.

If using fallback because subagents are unavailable, read only the listed files and produce
the same structured findings block before writing any KB file.

---

## Step 4 — Write or Update KB Files (main agent)

From the subagent output (or provided findings), apply `knowledge-base-writer` rules to:

- **Symbol gap**: write or update `05_symbols/<module-slug>.md`
  - Add header if file is new: `Module:` link + `Feature:` link
  - Add source file section if missing
  - Add function entry: `` `name(params)` → behavior `` + constraints
  - If `04_modules/<slug>.md` exists, add or update its `Symbols:` field pointing to `05_symbols/<slug>.md`
- **Module gap**: create `04_modules/<name>.md` — use RESPONSIBILITY, ENTRY_POINTS, KEY_FILES, CONSTRAINTS, SCOPE_TABLE from findings
- **Feature gap**: add entry to `01_maps/feature_map.md` — use FEATURE_MAP_ENTRY
- **Path gap**: add paths to `03_index/file_index.md` — use NEW_PATHS

If gap is partial, update only the missing sections of existing files.

refine-knowledge-base is the ONLY skill that writes to ./repoWiki/ — never delegate writes elsewhere.

Follow `knowledge-base-writer/file-generation-rules.md` for format.
Follow `knowledge-base-writer/output-style.md` for tone.

---

## Step 5 — Sync RUNBOOK (main agent)

If new files were created:

- Add link to `./repoWiki/RUNBOOK.md` under the appropriate section

---

## Step 6 — Update META (main agent)

In `./repoWiki/META.md`:

Run:

```
git rev-parse --short HEAD   → last_commit
```

- Set `last_synced` to today's ISO date
- Update `last_commit`

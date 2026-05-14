# Version Check

## When to Run

Run this check BEFORE opening any KB file or source code.
If `./docs/META.md` does not exist → skip this check and trigger `initialize-knowledge-base` instead.

---

## Step 1 — Read META

Open `./docs/META.md`. Extract:

- `last_commit`

---

## Step 2 — Detect Source Changes

Run:

```
git diff --name-only last_commit HEAD -- ':!docs'
```

This lists source files that changed between `last_commit` and `HEAD`, excluding the `docs/` directory.

If `last_commit` is unreachable (rebased away, force-pushed) → treat as full mismatch, trigger `refine-knowledge-base`.

---

## Step 3 — Evaluate Changes

### No changes

```
git diff returns empty output
```

→ No source files changed since last sync. KB is current for this read.
Do not edit `META.md` during read-only exploration. Proceed to navigation.

---

### Changes found — check KB coverage and source relevance

Run through each changed file path and check whether it appears in KB index files:

1. `./docs/03_index/file_index.md`
2. `./docs/04_modules/*.md` — Entry Points, Key Files, and Scope Table sections

For each changed file path, search these KB files for a reference to that path (full path or matching filename).

Also classify unreferenced changed files:

- generated/cache/build artifact → irrelevant drift
- docs-only or metadata-only change already excluded by the diff → irrelevant drift
- new or changed app/source/config file that affects behavior → possible KB gap

| Coverage result                                      | Meaning                                  | Action                                                                                                                 |
| ---------------------------------------------------- | ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Only generated/cache/noise files changed             | Changes are irrelevant to documented topics | Proceed to navigation. Do not edit META during read-only exploration.                                                   |
| One or more changed files have KB coverage           | Documented code may have drifted         | Trigger `refine-knowledge-base` with the list of covered changed files. After refine completes, proceed to navigation. |
| Unreferenced app/source/config files changed or were added | KB may be missing a path or feature      | Trigger `refine-knowledge-base` with gap type `path` or `topic`. After refine completes, proceed to navigation.        |

Only `initialize-knowledge-base`, `refine-knowledge-base`, and `archive-knowledge-base`
update `META.md`. `explore-repository` checks freshness but does not write sync metadata.

---

## Why Diff-Based Instead of Commit Equality

Storing `last_commit` and checking equality fails when updating META itself creates a new commit — the stored SHA is always behind HEAD. Using `git diff --name-only` instead avoids false mismatches because it excludes `docs/` from the diff, so META-only commits produce no output (no changes). This also directly answers the right question: "Has source code that the KB tracks changed since last sync?"

# Execution Plan

## Step 1 — Extract Feature Name

Determine the kebab-case feature name from:

- User's description of the completed work
- Current git branch name: `git rev-parse --abbrev-ref HEAD`

Example: "menu bar default scene" → `menu-bar-default`

---

## Step 2 — Identify Changed Files

Determine which files were modified:

- From conversation context (files mentioned or edited)
- Or via: `git diff --name-only main` (or relevant base branch)

List all changed files before proceeding.

---

## Step 3 — Read Changed Code

Read the changed files to extract:

- Architecture decisions made
- Key data flows or patterns introduced
- Constraints or invariants to preserve
- Dependencies on external modules

Do NOT summarize commit messages — read the actual code.

---

## Step 4 — Create Feature Document

Create `./repoWiki/06_features/<kebab-name>.md` using `feature-doc-template.md`.

Fill in all sections from the code you read in Step 3.

---

## Step 5 — Update Index Files

Update both index files:

- `./repoWiki/01_maps/feature_map.md` — add entry: `<feature name> → ./06_features/<kebab-name>.md`
- `./repoWiki/03_index/file_index.md` — add any new file paths identified in Step 2

---

## Step 6 — Update RUNBOOK

In `./repoWiki/RUNBOOK.md`:

- Add link under the **Features** section: `- [<Feature Name>](./06_features/<kebab-name>.md)`

---

## Step 7 — Update META

In `./repoWiki/META.md`:

Run:
```
git rev-parse --short HEAD   → last_commit
git rev-parse HEAD:repoWiki      → repoWiki_tree_hash
```

- Set `last_synced` to today's ISO date
- Update `last_commit` and `repoWiki_tree_hash`

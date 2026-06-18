# Gap Detection

## How to Confirm a Documentation Gap

Run these checks in order. If ALL three return no result, the gap is confirmed.

---

### Check 1 — Feature Map

Open `./repoWiki/01_maps/feature_map.md`.

- Search for the feature name or related keyword
- If no entry found → gap candidate

---

### Check 2 — Module Files

Scan `./repoWiki/04_modules/` directory.

- Look for a file covering the module in question
- If no file found or file lacks the relevant section → gap candidate

---

### Check 3 — File Index

Open `./repoWiki/03_index/file_index.md`.

- Search for the file path(s) related to the topic
- If path is absent → gap confirmed

---

---

### Check 4 — Symbols

Open `./repoWiki/05_symbols/<module-slug>.md`.

- Search for the function or symbol name
- If file does not exist or function entry is not found → symbol gap confirmed

---

## Gap Confirmed

If none of the applicable checks yield relevant documentation:
- Proceed to `execution-plan.md`
- Scope the gap to the minimum set of files needed

## Gap Partial

If some documentation exists but is incomplete:
- Note which section is missing
- Proceed to `execution-plan.md` Step 4 directly (skip Steps 1–2)

## Gap Partial (Symbol)

If a `05_symbols/<slug>.md` entry exists but is missing fields (e.g. no Constraints, no Signature):
- Note which fields are absent
- Proceed to `execution-plan.md` Step 4 directly (write only the missing fields)

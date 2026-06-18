# Verification Protocol

## When to Verify

Verify KB against code when:
- You are about to make a change to a module described in `./repoWiki/`
- The KB description seems inconsistent with other KB files
- The user's question implies behavior not matching the KB

Do NOT verify speculatively. Only verify when acting on a specific KB claim.

---

## How to Verify

### Step 1 — Identify the specific claim

Extract the exact claim from the KB:

- "Module X owns responsibility Y"
- "File path A does B"
- "Feature F lives in module M"

### Step 2 — Read the minimum code needed

Open only the file(s) the KB points to.
Do NOT browse the full codebase.

### Step 3 — Compare

| KB says | Code shows | Result |
|---------|------------|--------|
| Matches | Confirmed | Continue |
| Partially matches | Partially outdated | Refine that section |
| Contradicts | KB is stale | Refine KB |
| KB has no entry | Gap | Refine KB |

---

## When Mismatch is Found

**Do NOT silently use the code version and ignore the KB.**

Trigger `refine-knowledge-base`:

1. Note the exact KB file and section that is wrong
2. Note what the code actually shows
3. Run `refine-knowledge-base` to update that section
4. Continue your original task with the corrected KB

---

## Mismatch Severity

| Type | Action |
|------|--------|
| Minor (wrong line count, stale path) | Inline fix during refine |
| Structural (wrong module ownership) | Full module re-extraction |
| Architectural (system layers changed) | Refine system_map + big_picture |

---

## After Verification

Always answer from the KB — not from raw code.
The KB is the shared memory. Code is the ground truth for verification only.

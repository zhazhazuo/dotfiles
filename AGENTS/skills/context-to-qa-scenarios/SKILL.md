---
name: context-to-qa-scenarios
description: Compare a context document (PRD, proposal, or Jira bug description) against the current codebase implementation and produce a behavior-driven QA test scenario list for unit tests and E2E tests. Each test scenario links to a stable S-N identifier from the companion plain scenarios doc so coverage is traceable to source. Use when Walker asks to derive test cases / QA scenarios from a spec, proposal, or bug report, when a feature or phase needs test coverage, when a context doc is updated and scenarios need refresh, or when asking "what do we need to test" for a feature or fix.
---

# Context → QA Test Scenarios

Turn a context document (PRD, proposal, or Jira bug description) and the current implementation state into a behavior-driven QA test scenario list for unit tests and E2E tests. Each test scenario is linked to a stable `S-N` identifier from the companion plain scenarios doc so every checkbox is traceable back to the source.

## When to Use

- A feature, fix, or phase needs test coverage
- A context document (PRD, proposal, bug report) has been updated and scenarios need refresh
- Walker asks "what do we need to test" for a feature or fix

## Relationship to `context-to-plain-scenarios`

This skill is the **QA tracking layer** that sits on top of the plain scenarios doc.

| Dimension | `context-to-plain-scenarios` | `context-to-qa-scenarios` (this skill) |
|---|---|---|
| Purpose | Discussion, estimation, traceability | QA tracking, automation |
| Format | Plain statements with `S-` IDs + source refs | Checkboxes with behavior IDs + `S-N` links |
| IDs | One unique `S-N` per scenario statement | Behavior IDs (`B-N`, `R-N`) + links to `S-N` |
| Source refs | Required on every scenario | Inherited via the `S-N` link |

**Run order:** Plain scenarios first (`context-to-plain-scenarios`) → QA test scenarios next (this skill), reusing the plain doc's `S-N` IDs as the stable bridge. The plain doc is the source of truth for what each scenario means and where it came from; this doc is the source of truth for pass/fail tracking.

## Inputs

1. **Context document** — PRD, proposal, or Jira bug description (file path or URL)
2. **Project context** — existing project notes, open questions, blockers
3. **Codebase state** — gathered via direct code inspection (read, grep, file listing)
4. **Plain scenarios doc** — `<Project>/<scope>-plain-scenarios.md` if it exists (see Step 0)

## Steps

### 0. Locate the Plain Scenarios Doc (required)

Before writing any test scenario, look for `<Project>/<scope>-plain-scenarios.md`:

- **If it exists** — read it. Reuse its `S-N` identifiers and `B-N` / `R-N` behavior IDs exactly. Each test scenario you write must link to the `S-N` of the plain scenario it verifies.
- **If it does not exist** — emit a note at the top of the output: "No plain scenarios doc found. Run `context-to-plain-scenarios` first for full traceability. `S-N` links below are provisional and should be reconciled." Then derive `S-N` IDs yourself in the same order you would have produced the plain doc, keeping them stable so a later plain doc run can adopt them.

Do not invent a parallel ID space. The `S-N` in this doc must be the same `S-N` as in the plain doc.

### 1. Read the Context Document

- Confirm the document is accessible (file readable or URL fetchable). If not, ask Walker before proceeding.
- Extract scope, expected behaviors / acceptance criteria (with IDs if present), constraints, out-of-scope items
- Note per-variant or per-environment differences called out in the document (e.g. locale, tier, config)
- Flag ambiguities as open questions

### 2. Check Current Implementation

Inspect the codebase directly to understand what's already built.

- Read and search the codebase to map current behavior
- Drill into specific gaps or blockers with targeted reads
- Identify: what exists, what's missing, what's stale

### 3. Compare Context vs Implementation

For each expected behavior / acceptance criterion:

- Is it already implemented and matching the document? → regression test
- Is it implemented but **diverges from the document**? → defect scenario + flag as blocker
- Is it new? → new test scenario
- Is it ambiguous? → open question

### 4. Write Test Scenarios (QA View)

Write from the **behavior** perspective, not implementation:

```
- [ ] [B-x] (S-N) [actor/context] + [condition] → [expected behavior]
```

- `[B-x]` (or `[R-x]` for regression) — the behavior ID, reused from the plain doc
- `(S-N)` — the link to the plain scenario this test verifies. Required when a plain doc exists.

Rules:

- No code references (no file names, no function names)
- No implementation details (no "check enum", no "extend function")
- Group by behavior category (visibility, language, exclusion, regression, etc.)
- Include regression scenarios for existing features
- **One scenario = one assertion.** Split compound expectations into separate scenarios — e.g. `login → redirect` and `login → cookie set` are two scenarios, not one.
- Tag each scenario with its expected-behavior / acceptance-criterion ID (e.g. `[AC-3]` or `[BUG-42]`) so coverage is auditable. If the document has no IDs, reuse the `B-N` / `R-N` IDs from the plain doc; if no plain doc exists, derive stable IDs (B-1, B-2, …) and list them in a Coverage section.
- **Link each test scenario to exactly one `S-N` from the plain doc.** If one plain scenario maps to multiple test cases, create additional `S-N` sub-IDs in the plain doc rather than duplicating links here. If a test scenario has no corresponding plain scenario, add the plain scenario first (or flag it in Blockers).
- For per-variant behavior, emit one scenario per variant unless behavior is identical across variants.
- Mark open questions and blockers separately (see definitions in Step 5)

### 5. Output

Write to an individual file in the project folder:

```
<Project>/<scope>-test-scenarios.md
```

`<scope>` is the feature, fix, or bug id from the context document — the **same `<scope>` as the plain scenarios doc** so the pair is discoverable. The file is overwritten on refresh; rely on git history for prior versions. If multiple phases need parallel tracking, suffix with the date: `<scope>-test-scenarios-<YYYY-MM-DD>.md`.

Structure:

1. Scope line + plain-doc reference (`Companion: <scope>-plain-scenarios.md`)
2. Scenarios grouped by behavior category
3. Coverage table (expected behavior / acceptance criterion → `S-N` IDs)
4. Blockers table
5. Open questions

**Blocker vs Open Question:**

- **Blocker** — cannot write a scenario because something is missing or broken (implementation gap, context gap, diverging behavior, or no corresponding plain scenario can be traced). No scenario can be emitted until resolved.
- **Open Question** — a scenario can be written but rests on an assumption that needs confirmation. The scenario is still emitted.

## Output Format

```markdown
# <Scope> — Test Scenarios

Scope: <one line>. Companion plain scenarios: `<scope>-plain-scenarios.md`.
<If no plain doc exists, emit the provisional note from Step 0 here.>

## <Category>

- [ ] [B-1] (S-1) <scenario> → <expected behavior>
- [ ] [B-1] (S-2) <scenario> → <expected behavior>

## Coverage

| ID | Description | Scenarios |
|---|---|---|
| B-1 | <expected behavior> | S-1, S-2 |
| B-2 | <expected behavior> | — |

## Blockers

| Item | Status | Owner |
|---|---|---|

## Open Questions

1. <question>
```

## Constraints

- QA scenarios only — never write implementation tasks
- Do NOT reference code files or functions
- Scenarios must be testable by QA or automated E2E
- Each scenario = one assertion
- Every expected behavior / acceptance criterion must map to at least one scenario (or appear in Blockers / Open Questions)
- Always include regression scenarios for existing functionality
- **Every test scenario must link to exactly one `S-N` from the plain scenarios doc** (or be flagged in Blockers if no plain scenario can be traced). Do not invent a parallel ID space — the `S-N` here must match the plain doc.
- Use the same `<scope>` filename stem as the plain doc so the pair is discoverable.
- If the plain scenarios doc is refreshed and `S-N` IDs change, refresh this doc in the same pass to keep links consistent.

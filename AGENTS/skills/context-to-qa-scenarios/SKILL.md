---
name: context-to-qa-scenarios
description: Compare a context document (PRD, proposal, or Jira bug description) against the current codebase implementation and produce a behavior-driven QA test scenario list. Use when Walker asks to derive test cases / QA scenarios from a spec, proposal, or bug report, when a feature or phase needs test coverage, when a context doc is updated and scenarios need refresh, or when asking "what do we need to test" for a feature or fix.
---

# Context → QA Test Scenarios

Turn a context document (PRD, proposal, or Jira bug description) and the current implementation state into a behavior-driven QA test scenario list for unit tests and E2E tests.

## When to Use

- A feature, fix, or phase needs test coverage
- A context document (PRD, proposal, bug report) has been updated and scenarios need refresh
- Walker asks "what do we need to test" for a feature or fix

## Inputs

1. **Context document** — PRD, proposal, or Jira bug description (file path or URL)
2. **Project context** — existing project notes, open questions, blockers
3. **Codebase state** — gathered via direct code inspection (read, grep, file listing)

## Steps

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
- [ ] [ID] [actor/context] + [condition] → [expected behavior]
```

Rules:

- No code references (no file names, no function names)
- No implementation details (no "check enum", no "extend function")
- Group by behavior category (visibility, language, exclusion, regression, etc.)
- Include regression scenarios for existing features
- **One scenario = one assertion.** Split compound expectations into separate scenarios — e.g. `login → redirect` and `login → cookie set` are two scenarios, not one.
- Tag each scenario with its expected-behavior / acceptance-criterion ID (e.g. `[AC-3]` or `[BUG-42]`) so coverage is auditable. If the document has no IDs, derive stable IDs (B-1, B-2, …) and list them in a Coverage section.
- For per-variant behavior, emit one scenario per variant unless behavior is identical across variants.
- Mark open questions and blockers separately (see definitions in Step 5)

### 5. Output

Write to an individual file in the project folder:

```
<Project>/<scope>-test-scenarios.md
```

`<scope>` is the feature, fix, or bug id from the context document. The file is overwritten on refresh; rely on git history for prior versions. If multiple phases need parallel tracking, suffix with the date: `<scope>-test-scenarios-<YYYY-MM-DD>.md`.

Structure:

1. Scenarios grouped by behavior category
2. Coverage table (expected behavior / acceptance criterion → scenario IDs)
3. Blockers table
4. Open questions

**Blocker vs Open Question:**

- **Blocker** — cannot write a scenario because something is missing or broken (implementation gap, context gap, diverging behavior). No scenario can be emitted until resolved.
- **Open Question** — a scenario can be written but rests on an assumption that needs confirmation. The scenario is still emitted.

## Output Format

```markdown
# <Scope> — Test Scenarios

## <Category>

- [ ] [AC-3] <scenario> → <expected behavior>

## Coverage

| ID | Description | Scenarios |
|---|---|---|
| AC-1 | <expected behavior> | S1, S2 |
| AC-2 | <expected behavior> | — |

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

---
name: context-to-plain-scenarios
description: Build a plain scenarios document from a context document (PRD, proposal, or spec) with stable S- identifiers and source references tracing each scenario back to the originating lines. Use when Walker asks to distill a PRD or spec into traceable plain scenarios that support a QA test scenario doc, when a feature needs a scenario list for discussion/estimation with auditable provenance, or as the companion to context-to-qa-scenarios.
---

# Context → Plain Scenarios

Turn a context document (PRD, proposal, or spec) into a plain scenarios document with stable `S-` identifiers and **source references** that trace each scenario back to the originating document's lines. The output supports — and is the provenance backbone of — the QA test scenario document produced by `context-to-qa-scenarios`.

## When to Use

- Walker asks to distill a PRD / spec / proposal into traceable plain scenarios
- A feature or phase needs a scenario list for discussion, estimation, or task mapping — with auditable provenance
- The QA test scenario doc (`context-to-qa-scenarios`) needs a companion that explains where each scenario comes from
- A context document has been updated and the plain scenario list needs refresh

## Relationship to `context-to-qa-scenarios`

| Dimension | `context-to-plain-scenarios` (this skill) | `context-to-qa-scenarios` |
|---|---|---|
| Purpose | Discussion, estimation, traceability | QA tracking, automation |
| Format | Plain statements with `S-` IDs + source refs | Checkboxes with behavior IDs |
| IDs | One unique `S-N` per scenario statement | Behavior IDs (`B-N`, `R-N`) + scenario IDs |
| Source refs | **Required** on every scenario | Optional |
| Output | `<scope>-plain-scenarios.md` | `<scope>-test-scenarios.md` |

**Run order:** Plain scenarios first (this skill) → QA test scenarios next (`context-to-qa-scenarios`), reusing the `S-` IDs as the stable bridge. The plain doc is the source of truth for what each scenario means and where it came from; the QA doc is the source of truth for pass/fail tracking.

## Inputs

1. **Context document** — PRD, proposal, or spec (file path or URL). Must be readable.
2. **Business updates / verbal notes** — captured in the project's `notes.md` or supplied inline. Tagged as a separate source.
3. **Project context** — existing project notes, open questions, blockers.

## Steps

### 1. Read the Context Document

- Confirm the document is accessible. If not, ask Walker before proceeding.
- Read it fully and record line numbers for every extractable requirement, rule, constraint, acceptance criterion, and assumption.
- Extract: scope, expected behaviors, acceptance criteria, constraints, out-of-scope items, per-variant differences (locale, tier, market, config).
- Flag ambiguities as open questions — do not invent content to resolve them.

### 2. Identify All Source Streams

A plain scenario doc must distinguish where each scenario comes from. Define a source legend at the top of the output. Common streams:

| Tag | Meaning |
|---|---|
| `PRD L#` | Context document, line # (auditable) |
| `BUS` | Business verbal update captured in `notes.md` or supplied inline (not yet in the PRD) |
| `DR` | Derived regression — from Constraints/Assumptions + existing system behavior |

Add other streams as needed (e.g. `DESIGN`, `TICKET`). Every scenario must carry exactly one primary source tag; secondary sources can be listed.

### 3. Enumerate Behaviors

From the context document, derive a stable set of expected behaviors with IDs:

- `B-N` — Behavior N (new expected behavior from the spec)
- `R-N` — Regression N (existing behavior that must not change)

If the companion QA doc already exists, reuse its behavior IDs exactly. If not, derive them now in the same order they appear in the spec.

### 4. Write Plain Scenarios

One statement per scenario. Each scenario gets a **unique `S-N` identifier** — one ID per physical scenario statement, even if a statement supports multiple behaviors.

Format per scenario:

```
- **S-N** [B-x] *(source)* actor/context + condition → expected behavior
```

Rules:

- **One scenario = one assertion.** Split compound expectations into separate scenarios.
- **Source reference required** in parentheses immediately after the behavior tag(s). Use `PRD L#` for line references; `BUS` for verbal updates; `DR` for derived regressions. Multiple sources allowed: `*(PRD L86, L89)*`.
- **No code references** — no file names, no function names, no implementation details.
- Group by behavior category with section headers.
- For per-variant behavior (one rule, N locales/markets/tiers), emit one scenario per variant unless behavior is identical across variants.
- Include regression scenarios for existing functionality that must not change.
- Mark blocked scenarios inline with an assumption note (`*(assumption — process undefined)*`) and explain in a Blockers section.
- Preserve any scope/ownership annotations from the context (e.g. "controlled by BE", "out of scope") as callouts under the section header.

### 5. Build Coverage Summary

Produce a table mapping each behavior ID to its scenarios:

```
| Behavior | Scenarios | Count | Primary source |
|---|---|---|---|
| B-1 | S-1, S-2, S-3 | 3 | BUS |
```

Every behavior must map to at least one scenario (or appear in Blockers / Open Questions).

### 6. Traceability Notes

Write a closing section that:

- Explains the source tag scheme.
- Flags scenarios whose only source is a verbal/business update (`BUS`) — these are the highest traceability risk until formalized in the PRD.
- Flags scenarios with no formal source (blockers).
- Notes any `DR` (derived regression) scenarios and the constraints/assumptions they derive from.

### 7. Output

Write to an individual file in the project folder:

```
<Project>/<scope>-plain-scenarios.md
```

`<scope>` is the feature, fix, or phase id from the context document. The file is overwritten on refresh; rely on git history for prior versions. If multiple phases need parallel tracking, suffix with the date: `<scope>-plain-scenarios-<YYYY-MM-DD>.md`.

Structure:

1. Scope line
2. Source Legend
3. Scenarios grouped by behavior category (with scope/ownership callouts where relevant)
4. Coverage Summary table (behavior → scenarios, count, primary source)
5. Blockers table (if any)
6. Open Questions (if any)
7. Traceability Notes

## Output Format

```markdown
# <Scope> — Plain Scenarios

Scope: <one line>.

This document lists the scenarios for <scope> in plain statement form, with stable `S-` identifiers and source references. Use it for discussion, estimation, and traceability. Use `<scope>-test-scenarios.md` for QA tracking.

## Source Legend

| Tag | Meaning |
|---|---|
| `PRD L#` | `<context-doc>` line # |
| `BUS` | Business update captured in `notes.md` (not yet in PRD) |
| `DR` | Derived regression — from Constraints/Assumptions + existing behavior |

## <Category>

> <scope/ownership callout if relevant, e.g. "⚙️ Controlled by BE — ...">
> Source: <where this category comes from>

- **S-1** [B-1] *(PRD L17)* <scenario> → <expected behavior>
- **S-2** [B-1] *(BUS)* <scenario> → <expected behavior>

## Coverage Summary

| Behavior | Scenarios | Count | Primary source |
|---|---|---|---|
| B-1 | S-1, S-2 | 2 | PRD L17 / BUS |

**Total: N plain scenarios**

## Blockers

| Item | Status | Owner |
|---|---|---|

## Open Questions

1. <question>

## Traceability Notes

- <explanation of source tag scheme>
- <flag BUS-only scenarios as traceability risk>
- <flag scenarios with no formal source>
- <note DR derivations>
```

## Constraints

- Plain scenarios only — never write implementation tasks or code references.
- A source reference is **required** on every scenario. If you cannot trace a scenario to a source, it goes in Blockers, not in the scenario list.
- One unique `S-N` per physical scenario statement. Do not reuse IDs across statements.
- If the companion QA doc exists, reuse its behavior IDs; otherwise derive them and keep them stable across both docs.
- Scenarios must be behavior-level and testable by QA or automated E2E, but written as plain statements (not checkboxes).
- Every behavior must map to at least one scenario (or appear in Blockers / Open Questions).
- Always include regression scenarios for existing functionality.
- Preserve scope/ownership annotations ("controlled by BE", "out of scope") as callouts, not as scenario content.

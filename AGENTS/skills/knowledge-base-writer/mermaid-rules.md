# Mermaid Rules

## When to Use

- system flow
- module dependency
- feature interaction
- request lifecycle
- deployment pipeline

---

## When NOT to Use

- simple lists
- file indexes
- API lists

---

## Diagram Types

- `flowchart LR` → runtime flow
- `graph TD` → dependencies

---

## Placement

- system_map.md → REQUIRED
- module_map.md → REQUIRED
- deploy.md → REQUIRED
- modules/*.md → if flow exists
- feature_map.md → optional
- 06_features/*.md → REQUIRED (simplify diagram rather than omit)

---

## Style Constraints

- max 7–10 nodes
- simple names only (API, Core, DB)
- no file paths
- no deep nesting

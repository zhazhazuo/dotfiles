# File Generation Rules

## General

- Use relative paths only
- No long paragraphs
- Prefer lists and maps
- No emojis

---

## 00_overview/ Files

### big_picture.md
- What the system does (1–3 lines)
- Core flow (arrows preferred)
- Constraints

### tech_stack.md
- Sections: runtime / frontend / backend / storage / infra
- Format: `name → version/role`

---

## 01_maps/ Files

Format:
- `name → path`
- `feature → module link`

### system_map.md
- Core layers and integrations
- Mermaid diagram REQUIRED

### feature_map.md
- Feature name → path + brief description
- Mermaid optional

### module_map.md
- Module name → entry file
- Mermaid diagram REQUIRED

---

## 02_guides/ Files

Must include:
- steps (ordered)
- commands
- env variables (if found)

### dev.md
- Setup steps
- Dev server command
- Test command

### deploy.md
- Build steps
- Deploy command
- Mermaid pipeline REQUIRED

### debug.md
- Common issues → resolution
- Log locations

---

## 03_index/ Files

### file_index.md
- Format: `path → one-line meaning`
- Group by top-level folder

### api_index.md (if backend detected)
- Format: `METHOD /path → purpose`
- Group by resource

---

## 04_modules/ Files

Must include:
- **Responsibility** — what this module owns
- **Entry Points** — key files agents should open first
- **Key Files** — path → role
- **Constraints** — rules or invariants to preserve
- **Symbols** — `→ repoWiki/05_symbols/<slug>.md` (omit if no symbols file exists yet)
- **Scope Table** — REQUIRED markdown table with columns:

| Layer | Item | Description |
|-------|------|-------------|
| Implementation | `path/to/file.ts` | what it implements |
| Consumer | `path/to/caller.ts` | how/why it uses this module |

Include every significant implementation file and every known caller/consumer. This is the boundary definition of the module.

---

## 05_symbols/ Files

One file per module. Added on-demand (write-through only — never generated speculatively).

Filename: `<module-slug>.md` matching the corresponding `04_modules/<module-slug>.md`

Required header:
```
# Symbols: <module-name>

Module: → repoWiki/04_modules/<slug>.md
Feature: → repoWiki/06_features/<kebab-name>.md
```

Per source file section:
```
## <source-file-path>

- `functionName(params)` → one-line behavior
  - constraints / side-effects (omit if none)
```

Rules:
- Add entries on-demand as code is read — never pre-populate
- One entry per function or exported symbol that was actually read by an agent
- Keep file < 200 lines; if it grows beyond that, split by source file into separate sections
- Do NOT paraphrase function bodies — one line max per symbol

---

## 06_features/ Files

Each completed feature gets its own file:

Must include:
- **Overview** — 1–3 lines
- **Architecture** — Mermaid flowchart REQUIRED. Use `flowchart LR` or `flowchart TD` to show how the feature works end-to-end (trigger → processing → output). This is mandatory even for simple features — simplify the diagram rather than omitting it.
- **Key Files** — `path → role`
- **Implementation Notes** — constraints, decisions, gotchas
- **Dependencies** — external modules touched

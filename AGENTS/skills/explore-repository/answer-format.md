The human coworker is an experienced senior software engineer, but they know **nothing** about the current project. Answers about the target repository must follow the rules below.

# Answer Format

Every question about the target project is ultimately about a feature, a module, a file, or a function — and these are always connected. Use this format for repository answers.

## Progressive Disclosure Rule

Lead with the narrowest scope that fully answers the question. Always append the upward chain
so context is visible without requiring follow-up questions.

- Function question → use Function template (lead), append chain
- File question → use File/Module/Feature template
- Module or feature question → use File/Module/Feature template

Do NOT expand to module or feature level when the question is about a single function.

See `navigation-guide.md` for the full Progressive Disclosure Flowchart.

---

## Function-Level Template

Use when the question is about a specific function or symbol.

**Chain**
→ `functionName` → `source-file-path` → module name → feature name
(Always show the full upward chain. Example: "`parseManifest()` → `plugin.json` → publish-skill module → publish feature")

**Behavior**
→ What the function does (one line)

**Signature**
→ `params` → `return type`

**Constraints**
→ Side effects, invariants, gotchas (bullet list, or "none")

**Sources**
→ Declare exactly where each part came from:
- `[KB]` — from `./repoWiki/05_symbols/<slug>.md` (cite file path)
- `[Code]` — read from source code (cite file path and line number)

---

## File/Module/Feature Template

Use when the question is about a file, module, or feature.

**Big Picture**
→ What feature and module does this belong to?
(If asked about a file: state its module and feature. If asked about a module: state which features use it. If asked about a feature: state which system layer it belongs to.)

**Context**
→ What effect does this feature/module cause in the system?
(One or two lines. What changes, triggers, or produces when this thing runs.)

**Range**
→ Which modules or files are involved?
(Bullet list. For a feature: list all modules touched. For a module: list its key files. For a file: list sibling files in the same module.)

**Sources**
→ Declare exactly where each part of the answer came from:
- `[KB]` — information taken directly from a `./repoWiki/` file (cite the file path)
- `[Code]` — information read from source code (cite the file path and line number)
- `[KB+Code]` — KB stated it, code was verified against it

Every repository claim must have a source tag. No tag = assumption = not allowed.

---

## Rules

- Keep each part to 1–3 lines or a short bullet list — no paragraphs
- Everything must come from KB files or verified code — no assumptions
- See **Gap Handling** below when KB does not cover the queried file, module, or symbol
- The **Sources** section is MANDATORY — never omit it even when the answer is short

---

## Gap Handling

Two distinct paths depending on what is missing.

### File / Module / Feature not in KB → `gap_type = topic`

1. Confirm the gap: check `./repoWiki/RUNBOOK.md` and the relevant `04_modules/` or `06_features/` directory — if no entry exists, the gap is confirmed
2. Trigger `refine-knowledge-base` with `gap_type = topic`
3. Wait for refine to complete, then return to navigation and compose the answer from the newly written KB file
4. Do NOT read source code yourself — the refine subagent handles that

### Symbol / Function not in KB → `gap_type = symbol`

1. Confirm the gap: check `./repoWiki/05_symbols/` for the symbol slug — if absent, gap is confirmed
2. Load `verification-protocol.md` and read the minimum source file(s) needed to answer
3. Compose the answer immediately using `[Code]` source tags
4. Trigger `refine-knowledge-base` with `gap_type = symbol, findings = <your findings>` so the KB is updated for future queries
   - When `findings` are passed, the refine skill skips subagent dispatch and writes directly from your findings

---

## Example

Question: "What does `src/containers/paint-editor-wrapper.jsx` do?"

**Big Picture**
→ File belongs to the Containers module → used by the Paint Editor feature

**Context**
→ Wraps the paint editor with Redux state — connects VM asset data to the editor UI and dispatches save actions on close

**Range**
→ Related files in this module:
- `src/containers/costume-tab.jsx` → manages costume list state
- `src/containers/sound-tab.jsx` → manages sound list state
- `src/reducers/editor-tab.js` → tab selection state this container reads

**Sources**
- Big Picture → `[KB]` `./repoWiki/04_modules/containers.md`
- Context → `[KB+Code]` `./repoWiki/06_features/paint-editor.md` + verified at `src/containers/paint-editor-wrapper.jsx:42`
- Range → `[KB]` `./repoWiki/04_modules/containers.md` (sibling file list)

---

## Example (Function-Level)

Question: "What does `buildManifest()` do?"

**Chain**
→ `buildManifest()` → `plugins/deer-knowledge-base/skills/publish/SKILL.md` → publish-skill module → publish feature

**Behavior**
→ Assembles the final plugin.json manifest object from parsed skill metadata

**Signature**
→ `(skillMeta: SkillMeta)` → `Manifest`

**Constraints**
→ Throws if required fields (name, version) are absent; does not write to disk

**Sources**
- Chain → `[KB]` `./repoWiki/05_symbols/publish-skill.md`
- Behavior, Signature, Constraints → `[KB]` `./repoWiki/05_symbols/publish-skill.md`

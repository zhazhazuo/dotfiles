# Navigation Guide

## Starting Point

Always open `./docs/RUNBOOK.md` first.
It is the router — it tells you where everything lives.

---

## Progressive Disclosure Flowchart

```mermaid
flowchart TD
    Q([User question]) --> D{Classify scope}

    D -->|function / symbol| F1[Check 05_symbols/module-slug.md]
    D -->|file path| P1[Check 03_index/file_index.md]
    D -->|module| M1[Open 04_modules/name.md]
    D -->|feature| FT1[Open 06_features/name.md]

    F1 -->|entry found| F2[Use Function template\nChain · Behavior · Signature · Constraints]
    F1 -->|not found| F3[Read source code\ntrigger refine gap=symbol]
    F3 --> F2

    P1 -->|found| P2[Resolve module via Scope Table\nResolve feature via feature_map]
    P1 -->|not found| P3[trigger refine gap=path\nthen retry]
    P3 --> P2
    P2 --> P4[Use File/Module/Feature template\nBig Picture · Context · Range]

    M1 --> P4
    FT1 --> P4

    F2 --> OUT([Compose answer at function scope\nappend chain only])
    P4 --> OUT2([Compose answer at file/module/feature scope])

    style F2 fill:#d4edda,stroke:#28a745
    style P4 fill:#d4edda,stroke:#28a745
    style F3 fill:#fff3cd,stroke:#ffc107
    style P3 fill:#fff3cd,stroke:#ffc107
    style OUT fill:#cce5ff,stroke:#004085
    style OUT2 fill:#cce5ff,stroke:#004085
```

---

## Navigate by Intent

### "What does this project do?"
1. `./docs/00_overview/big_picture.md`
2. `./docs/01_maps/system_map.md`

### "What tech stack / dependencies?"
1. `./docs/00_overview/tech_stack.md`

### "Where is feature X?"
1. `./docs/01_maps/feature_map.md` — search for feature name
2. Follow link to `./docs/04_modules/<name>.md`

### "Where is module / folder X?"
1. `./docs/01_maps/module_map.md` — find module
2. Open `./docs/04_modules/<name>.md` → Key Files section

### "What does function/symbol X do?"
1. `./docs/03_index/file_index.md` — find the source file that contains the function
2. `./docs/05_symbols/<module-slug>.md` — look up the function entry
3. If found → compose answer using `answer-format.md` (function scope) — no code read needed
4. If not found → read the source file, find the function → trigger `refine-knowledge-base` (gap type=symbol, findings in hand) → compose answer

### "What does file path X do?"
1. `./docs/03_index/file_index.md` — get the one-line meaning of the path
2. `./docs/04_modules/` — find which module's Scope Table lists this path (Implementation or Consumer row)
3. `./docs/01_maps/feature_map.md` — find which feature points to that module
4. Compose answer using `answer-format.md` — the file belongs to a module which belongs to a feature

### "How do I run / build / deploy?"
1. `./docs/02_guides/dev.md` — local development
2. `./docs/02_guides/deploy.md` — build and deploy
3. `./docs/02_guides/debug.md` — debugging

### "How do I add a feature / fix a bug / refactor?"
1. `./docs/02_guides/dev.md` — local workflow, test, and run commands
2. `./docs/02_guides/debug.md` — debugging workflow and known issues
3. `./docs/01_maps/module_map.md` — find the module likely to change

### "Tell me about completed feature X"
1. `./docs/01_maps/feature_map.md` — find feature link
2. `./docs/06_features/<kebab-name>.md`

---

## Navigation Order (general exploration)

1. `RUNBOOK.md` → get bearings
2. `00_overview/big_picture.md` → understand intent
3. `01_maps/feature_map.md` or `module_map.md` → locate scope
4. `04_modules/<name>.md` → understand responsibilities
5. `03_index/file_index.md` → find exact files
6. Open the smallest necessary code scope only after completing steps 1–5

---

## Stop Conditions

Stop reading KB and proceed to answering when:
- For function questions: you have the symbol entry from `05_symbols/` (chain: symbol → file → module → feature)
- For file questions: you have the file path, its module, and its feature
- You have enough context to fill all parts of `answer-format.md` at the appropriate scope level

Stop reading KB and proceed to code when:
- KB gives you a specific file path to act on
- You've confirmed a gap (→ use `refine-knowledge-base`)
- You need source-grounded verification before implementing or changing behavior

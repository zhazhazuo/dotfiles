# Skill Structure

Use this layout unless the task clearly needs less:

```text
skill-name/
├── SKILL.md
└── references/
    └── focused-topic.md
```

Add only what the skill actually needs:

- `references/` for detailed instructions, variants, or heavy reference material
- `scripts/` for deterministic helpers
- `assets/` for files used in outputs

Do not add:

- `README.md`
- `CHANGELOG.md`
- `QUICK_REFERENCE.md`
- process notes unrelated to using the skill

Root file rule:

- `SKILL.md` is the router
- reference files hold the detail
- keep references one level deep

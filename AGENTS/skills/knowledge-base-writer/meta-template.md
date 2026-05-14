# META

<!-- Auto-managed by knowledge-base skills. Do not edit manually. -->

```
schema_version:  1
generated:       <ISO date>
last_synced:     <ISO date>
last_commit:     <git rev-parse --short HEAD>
docs_tree_hash:  <git rev-parse HEAD:docs>
```

---

## Fields

- `schema_version` — integer; increment when KB directory structure changes
- `generated` — ISO date when KB was first initialized
- `last_synced` — ISO date of the most recent skill write operation
- `last_commit` — short commit SHA at sync time; changes on rebase
- `docs_tree_hash` — git tree object hash of the `./docs/` directory at sync time; only changes when KB file content changes, survives clean rebase

---

## How to Capture Values

```
git rev-parse --short HEAD   → last_commit
git rev-parse HEAD:docs      → docs_tree_hash
```

If the repository has no commits yet, use `"init"` for both fields.
If `./docs/` is not yet committed, use `"untracked"` for `docs_tree_hash`.

---

## When to Update

| Skill | Action |
|-------|--------|
| `initialize-knowledge-base` | Create file; set all fields |
| `archive-knowledge-base` | Update `last_synced`, `last_commit`, `docs_tree_hash` |
| `refine-knowledge-base` | Update `last_synced`, `last_commit`, `docs_tree_hash` |
| `explore-repository` | Read only; never update META during exploration |

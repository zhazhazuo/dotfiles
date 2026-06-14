# nvim - Runbook

<!-- metadata
generated: 2026-05-23
last_synced: 2026-05-23
-->

Agent-optimized knowledge base for nvim dotfiles project.

---

## Quick Links

### Getting Started
- [Big Picture](./00_overview/big_picture.md) - What the system does
- [Tech Stack](./00_overview/tech_stack.md) - Dependencies and tools

### Navigation

**Maps** - Find files and understand structure
- [System Map](./01_maps/system_map.md) - Core layers and integrations
- [Feature Map](./01_maps/feature_map.md) - Features and entry points
- [Module Map](./01_maps/module_map.md) - Key modules

**Index** - File reference
- [File Index](./03_index/file_index.md) - Path to meaning

**Modules** - Deep dive
- [Plugin Management](./04_modules/plugin-management.md)
- [Language Tooling](./04_modules/language-tooling.md)
- [Editor Core](./04_modules/editor-core.md)
- [Theme System](./04_modules/theme-system.md)

### How-To

**Guides**
- [Development](./02_guides/dev.md) - Commands and environment
- [Debug](./02_guides/debug.md) - Common issues
- [Deploy](./02_guides/deploy.md) - Build and deploy

---

## Features

- Add feature docs under `06_features/` after feature work is complete.

---

## Rules

1. Always locate feature before editing code
2. Prefer modifying existing modules over creating new ones
3. Keep API backward compatible unless explicitly required
4. Check module constraints in `./04_modules/*`

---

## Navigation Strategy (for agents)

1. Start from feature_map → identify feature
2. Go to module_map → locate module
3. Use file_index → find exact files
4. Follow guides → perform action


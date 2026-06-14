# Language Tooling

## Responsibility

- LSP client setup, Mason tool installation, language-adjacent plugins, and formatter integration.

## Entry Points

- `lua/plugins/lsp.lua` → plugin specs and Mason package lists
- `lua/config/lspconfig.lua` → Neovim LSP server definitions and enablement

## Key Files

- `lua/config/lspconfig.lua` → LSP capabilities, callbacks, server configs, and enabled servers
- `lua/plugins/lsp.lua` → nvim-lspconfig, Mason, mason-lspconfig, diagnostics, and code action specs
- `lua/plugins/formatter.lua` → formatter setup
- `lua/plugins/synax.lua` → syntax plugin setup
- `lua/plugins/blade.lua` → Blade-specific language setup

## Constraints

- `mason-lspconfig` uses `automatic_enable = false`; servers must be explicitly enabled in `lua/config/lspconfig.lua`.
- Add installable Mason LSP server names to `mason_lsp_servers`; add Mason package IDs to `mason_packages`.
- Preserve shared capabilities from `blink.cmp`.

## Scope Table

| Layer | Item | Description |
|-------|------|-------------|
| Implementation | `lua/config/lspconfig.lua` | configures and enables Neovim LSP servers |
| Implementation | `lua/plugins/lsp.lua` | declares LSP-related plugins and Mason package installation |
| Implementation | `lua/plugins/formatter.lua` | configures formatting tools |
| Implementation | `lua/plugins/synax.lua` | configures syntax tooling |
| Consumer | `lua/config/lazy.lua` | imports plugin specs through Lazy.nvim |


# Big Picture

- Neovim configuration → Lua-based editor setup for plugins, options, mappings, LSP, formatting, themes, and filetype-specific tooling.
- Core flow → `init.lua` → `lua/config/lazy.lua` → `lua/plugins/*` → feature configs under `lua/config/*`, `lua/auto_cmds/*`, and plugin modules.
- Constraints → preserve Lazy.nvim module import shape; prefer focused edits in existing plugin/config files.


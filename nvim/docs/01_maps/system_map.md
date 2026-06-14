# System Map

```mermaid
flowchart LR
  Init[init.lua] --> Lazy[Lazy.nvim]
  Lazy --> Plugins[lua/plugins]
  Plugins --> Config[lua/config]
  Plugins --> Tools[Mason tools]
  Config --> Runtime[Neovim runtime]
```

- init → `init.lua`
- plugin loading → `lua/config/lazy.lua`
- plugin specs → `lua/plugins/*`
- runtime config → `lua/config/*`
- external tools → Mason packages configured in `lua/plugins/lsp.lua`


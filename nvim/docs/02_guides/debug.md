# Debug

## Common Issues

- plugin load failure → run `:Lazy` and inspect plugin errors
- missing LSP server → run `:Mason` or `:MasonInstallAll`
- LSP not attached → run `:LspInfo` and verify filetype/root detection
- formatting mismatch → inspect `lua/plugins/formatter.lua`

## Logs

- Neovim messages → `:messages`
- LSP logs → `:LspLog`
- Lazy.nvim state → `:Lazy`
- Mason state → `:Mason`


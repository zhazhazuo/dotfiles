# ── Environment Variables ──────────────────────────────────────────────

export EDITOR=nvim

# ── Secrets (.env) ────────────────────────────────────────────────────
if test -f "$HOME/.config/fish/.env"
    while read -l line
        # skip comments and empty lines
        string match -qr '^\s*(#|$)' "$line" && continue
        set -l kv (string split -m 1 '=' "$line")
        set -gx $kv[1] $kv[2]
    end <"$HOME/.config/fish/.env"
end

# ── Paths ─────────────────────────────────────────────────────────────

# PROXY
export HTTP_PROXY=http://127.0.0.1:7897
export HTTPS_PROXY=http://127.0.0.1:7897

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
fish_add_path $PYENV_ROOT/bin

# Go
export GOPATH="$HOME/go"
fish_add_path $GOPATH/bin

# pnpm
set -gx PNPM_HOME "$HOME/Library/pnpm"
fish_add_path $PNPM_HOME

# bun
export BUN_INSTALL="$HOME/.bun"
fish_add_path $BUN_INSTALL/bin

# NVM
export NVM_DIR="$HOME/.nvm"

# Qoder
export QODERCN_PAT=
export QODER_REGION=

# local bins
fish_add_path $HOME/.local/bin

# Github, Qoder and Confluence credentials live in .env, which is gitignored.

# Confluence
export CONFLUENCE_READ_ONLY=false
export CONFLUENCE_PI_WRITES=true
export CONFLUENCE_PI_WRITE_SPACES=OF

# Pi-MCP-Adapter
export MCP_UI_VIEWER=none

# ── Environment Variables ─────────────────────────────────────────────
# Values a machine must not share live in hosts/<hostname -s>/fish/conf.d/, which
# init.sh links into conf.d with a zz- prefix, so a host fragment loads after
# this file. Credentials live in ~/.config/secrets/.env, outside every repository,
# and are loaded below.

export EDITOR=nvim

# ── Secrets (.env) ────────────────────────────────────────────────────
if test -f "$HOME/.config/secrets/.env"
    while read -l line
        # skip comments and empty lines
        string match -qr '^\s*(#|$)' "$line" && continue
        set -l kv (string split -m 1 '=' "$line")
        set -gx $kv[1] $kv[2]
    end <"$HOME/.config/secrets/.env"
end

# ── Paths ─────────────────────────────────────────────────────────────

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

# local bins
fish_add_path $HOME/.local/bin

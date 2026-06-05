# ── Interactive Session Settings ───────────────────────────────────────
if status is-interactive
    set -g fish_greeting
    fish_vi_key_bindings

    # Ctrl+E → accept autosuggestion in insert mode
    bind -M insert \ce accept-autosuggestion
end

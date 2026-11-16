#!/bin/sh
# After running this script, all symlinks will be set up successfully.

set -e

# Hosts
# hosts/<hostname -s>/ holds the values a machine must not share. The shared
# files carry no proxy, no Confluence flags and no default pi model, so a
# machine with no directory here would start on an incomplete configuration.
# Test before the script changes anything.
HOST_NAME=$(hostname -s)
HOST_DIR=~/dotfiles/hosts/"$HOST_NAME"
if [ ! -d "$HOST_DIR" ]; then
  printf 'init.sh: no host configuration for %s\n' "$HOST_NAME" >&2
  printf 'init.sh: it looked for %s/\n' "$HOST_DIR" >&2
  printf 'init.sh: copy hosts/VCN/ there and edit the values\n' >&2
  exit 1
fi

# git
rm -rf ~/.gitconfig
ln -sf ~/dotfiles/git/.gitconfig ~/.gitconfig

# Neovim
rm -rf ~/.config/nvim
ln -sf ~/dotfiles/nvim ~/.config/nvim

# Fish
rm -rf ~/.config/fish
ln -sf ~/dotfiles/fish ~/.config/fish

# Hosts: link the fish fragments into conf.d after the shared files. The
# zz- prefix sorts them last, so a host value wins.
if [ -d "$HOST_DIR/fish/conf.d" ]; then
  for fragment in "$HOST_DIR"/fish/conf.d/*.fish; do
    ln -sf "$fragment" ~/.config/fish/conf.d/
  done
fi

# Tmux
rm -rf ~/.tmux.conf
ln -sf ~/dotfiles/tmux/.tmux.conf ~/.tmux.conf

# herdr
rm -rf ~/.config/herdr/config.toml
ln -sf ~/dotfiles/herdr/config.toml ~/.config/herdr/config.toml

# Rex
rm -rf ~/.config/rex
ln -sf ~/dotfiles/rex ~/.config/rex
# The Raycast extension switches windows through this, and it is off by default.
defaults write com.superlogical.rex rex.client.remoteControl -bool true
# The theme importer, the daemons, and the golden ratio binary are implementation and live in
# ~/Research/rice-configuration/packages/rex-themes and rex-services. `rice apply` runs them.

# Ghostty
rm -rf ~/.config/ghostty
ln -sf ~/dotfiles/ghostty ~/.config/ghostty

# Aerospace
rm -rf ~/.config/aerospace
ln -sf ~/dotfiles/aerospace ~/.config/aerospace

# Sketchybar
# The bar scripts are implementation and live in ~/Research/rice-configuration/packages/sketchybar-bar.
# That package links them into ~/.config/sketchybar, so this script must not delete that directory.

# OpenCode
mkdir -p ~/.config/opencode
rm -f ~/.config/opencode/agent ~/.config/opencode/opencode.json
ln -sf ~/dotfiles/opencode/agent ~/.config/opencode/agent
ln -sf ~/dotfiles/opencode/opencode.json ~/.config/opencode/opencode.json

# Gemini
mkdir -p ~/.gemini
rm -f ~/.gemini/commands
ln -sf ~/dotfiles/gemini/commands ~/.gemini/commands

# AGENT
mkdir -p ~/.config/opencode ~/.gemini ~/.claude ~/.pi/agent
rm -f ~/.config/opencode/AGENTS.md ~/.gemini/GEMINI.md ~/.claude/CLAUDE.md ~/.agents/AGENTS.md
ln -sf ~/dotfiles/AGENTS/AGENTS.md ~/.config/opencode/AGENTS.md
ln -sf ~/dotfiles/AGENTS/AGENTS.md ~/.gemini/GEMINI.md
ln -sf ~/dotfiles/AGENTS/AGENTS.md ~/.claude/CLAUDE.md
ln -sf ~/dotfiles/AGENTS/AGENTS.md ~/.agents/AGENTS.md
mkdir -p ~/.agents/skills
for item in ~/dotfiles/AGENTS/skills/*; do
  # A skill directory that already exists in place cannot take a symlink; skip it.
  ln -sf "$item" ~/.agents/skills/ 2>/dev/null || true
done

# Pi
rm -f ~/.pi/agent/AGENTS.md
ln -sf ~/dotfiles/AGENTS/AGENTS.md ~/.pi/agent/AGENTS.md
ln -sf ~/dotfiles/pi/keybindings.json ~/.pi/agent/keybindings.json
# settings.json is a single file with no include mechanism, so the host
# overlay merges over the shared file into a generated copy at ~/.pi/agent.
# A stale symlink from an older layout must go first, or the merge writes
# through it into the repository.
rm -f ~/.pi/agent/settings.json
cp ~/dotfiles/pi/settings.json ~/.pi/agent/settings.json
if [ -f "$HOST_DIR/pi-settings.json" ]; then
  python3 - "$HOME/.pi/agent/settings.json" "$HOST_DIR/pi-settings.json" <<'PY'
import json, sys

live_path, overlay_path = sys.argv[1], sys.argv[2]
with open(live_path) as f:
    live = json.load(f)
with open(overlay_path) as f:
    overlay = json.load(f)
live.update(overlay)
with open(live_path, "w") as f:
    json.dump(live, f, indent=2)
    f.write("\n")
PY
fi
rm -rf ~/.pi/agent/themes
ln -sf ~/dotfiles/pi/themes ~/.pi/agent/themes
# The rpiv-todo package reads its config from ~/.config/rpiv-todo/config.json.
rm -rf ~/.config/rpiv-todo
ln -sf ~/dotfiles/pi/rpiv-todo ~/.config/rpiv-todo
# The extensions are implementation and live in ~/Research/rice-configuration/packages/pi-extensions,
# which links them here. This script must not replace those links.

# Taskwarrior
rm -f ~/.taskrc
ln -sf ~/dotfiles/task/.taskrc ~/.taskrc

# Rice packages
# Custom macOS rice work lives in its own monorepo. RICE_DIR overrides the clone location.
RICE_DIR="${RICE_DIR:-$HOME/Research/rice-configuration}"
if [ -x "$RICE_DIR/bin/rice" ]; then
	"$RICE_DIR/bin/rice" apply
fi

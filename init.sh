#!/bin/sh
# After running this script, all symlinks will be set up successfully.

set -e

# git
rm -rf ~/.gitconfig
ln -sf ~/dotfiles/git/.gitconfig ~/.gitconfig

# Neovim
rm -rf ~/.config/nvim
ln -sf ~/dotfiles/nvim ~/.config/nvim

# Fish
rm -rf ~/.config/fish
ln -sf ~/dotfiles/fish ~/.config/fish

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
  ln -sf "$item" ~/.agents/skills/
done

# Pi
rm -f ~/.pi/agent/AGENTS.md
ln -sf ~/dotfiles/AGENTS/AGENTS.md ~/.pi/agent/AGENTS.md
ln -sf ~/dotfiles/pi/keybindings.json ~/.pi/agent/keybindings.json
ln -sf ~/dotfiles/pi/settings.json ~/.pi/agent/settings.json
rm -rf ~/.pi/agent/themes
ln -sf ~/dotfiles/pi/themes ~/.pi/agent/themes
mkdir -p ~/.pi/agent/extensions
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

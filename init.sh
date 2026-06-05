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

# Ghostty
rm -rf ~/.config/ghostty
ln -sf ~/dotfiles/ghostty ~/.config/ghostty

# Aerospace
rm -rf ~/.config/aerospace
ln -sf ~/dotfiles/aerospace ~/.config/aerospace

# Sketchybar
rm -rf ~/.config/sketchybar
ln -sf ~/dotfiles/sketchybar ~/.config/sketchybar

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

# Taskwarrior
rm -f ~/.taskrc
ln -sf ~/dotfiles/task/.taskrc ~/.taskrc

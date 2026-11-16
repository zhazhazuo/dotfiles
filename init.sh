#!/bin/sh
# After running this script, all symlinks will be set up successfully.

set -e

# Hosts
# hosts/<profile>/ holds the values a machine must not share. The shared files
# carry no proxy, no Confluence flags and no default pi model, so a machine with
# no directory for its profile would start on an incomplete configuration. Test
# before the script changes anything.
#
# The profile is a label, not always the hostname: a Mac that answers
# `hostname -s` with a serial uses a readable profile such as `VCN`. A machine
# names its profile as the first argument, or records it in the zz-host.fish
# link that an earlier run made, or else takes its hostname.
link=~/.config/fish/conf.d/zz-host.fish
target=
if [ -L "$link" ]; then
  target=$(readlink "$link")
fi
profile=${1:-}
if [ -z "$profile" ]; then
  case $target in
  */hosts/*/fish/conf.d/zz-host.fish)
    profile=${target#*/hosts/}
    profile=${profile%%/*}
    ;;
  esac
fi
if [ -z "$profile" ]; then
  profile=$(hostname -s)
fi
HOST_DIR=~/dotfiles/hosts/"$profile"
if [ ! -d "$HOST_DIR" ]; then
  printf 'init.sh: no host configuration for %s\n' "$profile" >&2
  printf 'init.sh: it looked for %s/\n' "$HOST_DIR" >&2
  printf 'init.sh: copy hosts/VCN/ to hosts/%s/ and edit the values,\n' "$profile" >&2
  printf 'init.sh: then run sh init.sh %s\n' "$profile" >&2
  exit 1
fi

# Every source this script links. Each pair deletes its target before making the
# link, so a missing source leaves the account without that configuration. Test
# them all before the first change.
for source in \
  ~/dotfiles/git/.gitconfig \
  ~/dotfiles/nvim \
  ~/dotfiles/fish \
  ~/dotfiles/tmux/.tmux.conf \
  ~/dotfiles/herdr/config.toml \
  ~/dotfiles/rex \
  ~/dotfiles/ghostty \
  ~/dotfiles/aerospace \
  ~/dotfiles/AGENTS/AGENTS.md \
  ~/dotfiles/AGENTS/skills \
  ~/dotfiles/pi/keybindings.json \
  ~/dotfiles/pi/settings.json \
  ~/dotfiles/pi/themes \
  ~/dotfiles/pi/tool-whitelist.json \
  ~/dotfiles/pi/subagent-manager/settings.json \
  ~/dotfiles/pi/subagent-manager/agents \
  ~/dotfiles/pi/rpiv-todo \
  ~/dotfiles/task/.taskrc; do
  if [ ! -e "$source" ]; then
    printf 'init.sh: missing source %s\n' "$source" >&2
    printf 'init.sh: nothing was changed\n' >&2
    exit 1
  fi
done

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
ln -sf ~/dotfiles/pi/tool-whitelist.json ~/.pi/agent/tool-whitelist.json
# The subagent manager refuses a symlinked path. It lstats settings.json and
# agents/, warns "Unsafe symlink path", and drops that layer: the settings fall
# back to its defaults and every agent type disappears. So both are copied, as
# ~/.pi/agent/settings.json is. A save in `/agents settings` writes the copy, and
# a run of this script restores the file from the tree.
mkdir -p ~/.pi/agent/subagent-manager/agents
rm -f ~/.pi/agent/subagent-manager/settings.json
cp ~/dotfiles/pi/subagent-manager/settings.json ~/.pi/agent/subagent-manager/settings.json
cp -R ~/dotfiles/pi/subagent-manager/agents/. ~/.pi/agent/subagent-manager/agents/
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

if status is-interactive
    # Commands to run in interactive sessions can go here
    fish_vi_key_bindings

    # Bind Ctrl+E to accept autosuggestion in insert mode
    bind -M insert \ce accept-autosuggestion
end

# [GitHub](https://github.com/starship/starship)
starship init fish | source

export EDITOR=nvim
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"

export GOPATH="$HOME/go"
export PATH="$PATH:$GOPATH/bin"

export https_proxy="http://127.0.0.1:7890"
export http_proxy="http://127.0.0.1:7890"

####### Custom Function

# yazi
function y
	set tmp (mktemp -t "yazi-cwd.XXXXXX")
	yazi $argv --cwd-file="$tmp"
	if set cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
		builtin cd -- "$cwd"
	end
	rm -f -- "$tmp"
end

function vim
    nvim $argv 

end

function vi
    nvim $argv

end

# Taskwarrior
function t
  task $argv
end
function tls
  task list
end

# Taskwarrior TUI
function tui
  taskwarrior-tui
end

# quickly search the process
function fp
  lsof -i :$argv
end

function lg
    set -x LAZYGIT_NEW_DIR_FILE ~/.lazygit/newdir

    lazygit $argv

    if test -f $LAZYGIT_NEW_DIR_FILE
        cd (cat $LAZYGIT_NEW_DIR_FILE)
        rm -f $LAZYGIT_NEW_DIR_FILE
    end
end

# eza
function ls
  eza --icons --group-directories-first
end

function lt
  eza -T -a -L 2 --git --icons
end

function ll
  eza -la --git --icons --group-directories-first --header --time-style=long-iso
end

# terminal MR 
function gmr
  git-split-diffs --color | less -RFX
end

# For NVM
export NVM_DIR="$HOME/.nvm"

# thefuck
thefuck --alias | source

# z
zoxide init fish | source

# pnpm
set -gx PNPM_HOME "/Users/lplp/Library/pnpm"
if not string match -q -- $PNPM_HOME $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end

fish_add_path /Users/lplp/.pnpm/bin

# fnm
fnm env --use-on-cd --shell fish | source

# python2
pyenv init - fish | source

# fzf
fzf --fish | source
set -g FZF_CTRL_T_COMMAND "command find -L \$dir -type f 2> /dev/null | sed '1d; s#^\./##'"

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH


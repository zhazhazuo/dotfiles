if status is-interactive
    # Commands to run in interactive sessions can go here
    set -g fish_greeting
    fish_vi_key_bindings
    fzf_configure_bindings --directory=\cf --git_log=\cg --git_status=\ct --history=\cr --processes=\cp --variables=\cv

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

export GOOGLE_CLOUD_PROJECT="inbound-dahlia-464105-f8"
export ANTHROPIC_BASE_URL="https://opencode.ai/zen/go"
export ANTHROPIC_API_KEY="sk-XXd7Qsce3PmmklJbOeviyyTbc1bTTdJjnoTtTdtMlx5OfZMhkFQxHlVL7ABqKlz7"

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
function ti
  task $argv info
end
function tls
  task list
end
function tt
    if test (count $argv) -gt 0
        task list due.before:today+$argv[1]d $argv[2..-1]
    else
        task list due.before:tomorrow
    end
end
function tu
    set ids (task export status:pending estimate.any: due.any: | python3 -c "                                                                                          
import sys, json, datetime                                                                                                                                             
now = datetime.datetime.now(datetime.timezone.utc).date()
ids = []
for t in json.load(sys.stdin):
    due_str = t.get('due')
    est_val = t.get('estimate')
    if not due_str or est_val is None:
        continue
    due = datetime.datetime.strptime(due_str, '%Y%m%dT%H%M%SZ').replace(tzinfo=datetime.timezone.utc).date()
    est = float(est_val)
    if (now + datetime.timedelta(days=est)) >= due:
        ids.append(str(t['id']))
print(','.join(ids))
")
    if test -n "$ids"
        task $ids list rc.report.list.columns='id,estimate,due,description' \
                        rc.report.list.labels='ID,Est,Due,Description'
    else
        echo "No urgent tasks found."
    end
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
  eza --icons --group-directories-first $argv
end

function lt
  eza -T -a -L 2 --git --icons $argv
end

function ll
  eza -la --git --icons --group-directories-first --header --time-style=long-iso $argv
end

# terminal MR 
function gmr
  git-split-diffs --color | less -RFX
end

### ABBR
abbr -a g git
abbr -a gl git pull
abbr -a gp git push
abbr -a gst git status
abbr -a ga git add
abbr -a gc git commit

# For NVM
export NVM_DIR="$HOME/.nvm"

# thefuck
# thefuck --alias | source

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
# pyenv init - fish | source

# fzf
fzf --fish | source
set -g FZF_CTRL_T_COMMAND "command find -L \$dir -type f 2> /dev/null | sed '1d; s#^\./##'"

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

fish_add_path $HOME/.local/bin

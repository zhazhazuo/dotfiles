set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",tmux-256color:RGB"

# Position the status line on top.
set -g status-position top

set-option -g default-shell /usr/local/bin/fish

# test for vim-tmux-navigator
set -s escape-time 50
set -g focus-events on

# Binding the custom Key
set -g prefix C-s
unbind C-b
bind-key C-s send-prefix

unbind %
bind | split-window -h 

unbind '"'
bind - split-window -v

# switch between the two last windows
unbind-key -T prefix w
bind-key -T prefix w last-window

# switch between the two last sessions
bind-key -T prefix Tab switch-client -l

unbind r
bind r source-file ~/.tmux.conf

bind j resize-pane -D 5
bind k resize-pane -U 5
bind l resize-pane -R 5
bind h resize-pane -L 5

###

bind -r m resize-pane -Z

set -g mouse on

set-window-option -g mode-keys vi

bind-key -T copy-mode-vi 'v' send -X begin-selection # start selecting text with "v"
bind-key -T copy-mode-vi 'y' send -X copy-selection # copy text with "y"

unbind -T copy-mode-vi MouseDragEnd1Pane # don't exit copy mode when dragging with mouse

# remove delay for exiting insert mode with ESC in Neovim
set -sg escape-time 10

# list of tmux plugins
set -g @plugin 'christoomey/vim-tmux-navigator'
set -g @plugin 'tmux-plugins/tmux-resurrect' # persist tmux sessions after computer restart
set -g @plugin 'tmux-plugins/tmux-continuum' # automatically saves sessions for you every 15 minutes
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-cpu'
set -g @plugin 'tmux-plugins/tmux-online-status'
set -g @plugin 'tmux-plugins/tmux-battery'
set -g @plugin 'xamut/tmux-network-bandwidth'
set -g @plugin 'tmux-plugins/tmux-open'
# tpm plugin
set -g @plugin 'tmux-plugins/tpm'

set -g @resurrect-capture-pane-contents 'on'
set -g @continuum-restore 'on'

set -ga terminal-overrides ',*:Ss=\E[%p1%d q:Se=\E[2 q'

run ~/.config/tmux/plugins/catppuccin/tmux/catppuccin.tmux

# Configure Catppuccin
set -g @catppuccin_flavor "macchiato"
set -g @catppuccin_status_background "none"
set -g @catppuccin_window_status_style "none"
set -g @catppuccin_pane_status_enabled "off"
set -g @catppuccin_pane_border_status "off"

# Configure Online
set -g @online_icon "ok"
set -g @offline_icon "nok"
set -g @thm_bg "default"

# status left look and feel
set -g status-left-length 100
set -g status-left ""
set -ga status-left "#{?client_prefix,#{#[bg=#{@thm_red},fg=#{@thm_bg},bold]  #S },#{#[bg=#{@thm_bg},fg=#{@thm_green}]  #S }}"
set -ga status-left "#[bg=#{@thm_bg},fg=#{@thm_overlay_0},none]│"
set -ga status-left "#[bg=#{@thm_bg},fg=#{@thm_maroon}]  #{pane_current_command} "
set -ga status-left "#[bg=#{@thm_bg},fg=#{@thm_overlay_0},none]│"
set -ga status-left "#[bg=#{@thm_bg},fg=#{@thm_blue}]  #{=/-32/...:#{s|$USER|~|:#{b:pane_current_path}}} "
set -ga status-left "#[bg=#{@thm_bg},fg=#{@thm_overlay_0},none]#{?window_zoomed_flag,│,}"
set -ga status-left "#[bg=#{@thm_bg},fg=#{@thm_yellow}]#{?window_zoomed_flag, 󰁌 ZOOM ,}"

# status right look and feel
# set -g status-right-length 100
set -g status-right ""
set -ga status-right "#[bg=#{@thm_bg},fg=#{@thm_mauve}] 󰖳 "

set -g status-bg "default"

# example how to set a item.
# set -ga status-right "#[bg=#{@thm_bg},fg=#{@thm_mauve}] 󰻠 #{cpu_percentage} "

# bootstrap tpm
if "test ! -d ~/.tmux/plugins/tpm" \
   "run 'git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm && ~/.tmux/plugins/tpm/bin/install_plugins'"

# Initialize TMUX plugin manager (keep this line at the very bottom of tmux.conf)
run '~/.tmux/plugins/tpm/tpm'

# Configure Tmux
set -g status-position top
set -g status-justify "right"

# pane border look and feel
setw -g pane-border-status top
setw -g pane-border-format ""

# window look and feel
set -wg automatic-rename on
set -g automatic-rename-format "Window"

set -g window-status-format " #I#{?#{!=:#{window_name},Window}, #W,} "
set -g window-status-style "bg=#{@thm_bg},fg=#{@thm_rosewater}"
set -g window-status-last-style "bg=#{@thm_bg},fg=#{@thm_rosewater}"
set -g window-status-activity-style "bg=#{@thm_red},fg=#{@thm_bg}"
set -g window-status-bell-style "bg=#{@thm_red},fg=#{@thm_bg},bold"
set -gF window-status-separator "#[bg=#{@thm_bg},fg=#{@thm_overlay_0}]|"

set -g window-status-current-format " #I#{?#{!=:#{window_name},Window}, #W,} "
set -g window-status-current-style "fg=#{@thm_peach},bold"
# Initialize TMUX plugin manager (keep this line at the very bottom of tmux.conf)


# After run this sh, the all symlinks will be set up successfully.

# Neovim
rm -rf ~/.config/nvim
ln -s ~/dotfiles/nvim ~/.config/nvim

# Fish
rm -rf ~/.config/fish
ln -s ~/dotfiles/fish ~/.config/fish

# Tmux
ln -sf ~/dotfiles/tmux/.tmux.conf ~/.tmux.conf

# Ghostty
rm -rf ~/.config/ghostty
ln -s ~/dotfiles/ghostty ~/.config/ghostty

# Aerospace
rm -rf ~/.config/aerospace
ln -s ~/dotfiles/aerospace ~/.config/aerospace

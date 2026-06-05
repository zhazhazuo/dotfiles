##### Bar Appearance #####
sketchybar --bar position=top height=32 blur_radius=30 color=0x40000000

##### Default Item Styles #####
default=(
  padding_left=5
  padding_right=5
  icon.font="Hack Nerd Font:Bold:12.0"
  label.font="Hack Nerd Font:Bold:10.0"
  icon.color=0xffffffff
  label.color=0xffffffff
  icon.padding_left=4
  icon.padding_right=4
  label.padding_left=4
  label.padding_right=4
)
sketchybar --default "${default[@]}"

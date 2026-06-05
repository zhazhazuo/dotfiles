##### Left: Aerospace Workspaces #####
WORKSPACE_NAMES=("B" "T" "N" "M" "I" "P" "A")
for i in "${!WORKSPACE_NAMES[@]}"
do
  name="${WORKSPACE_NAMES[i]}"
  space=(
    icon="$name"
    icon.padding_left=7
    icon.padding_right=7
    icon.color=0xffaaaaaa
    icon.highlight_color=0xffffffff
    background.color=0xff40a02b
    background.corner_radius=5
    background.height=20
    background.drawing=off
    label.drawing=off
    script="$PLUGIN_DIR/aerospace_workspaces.sh"
    click_script="aerospace workspace $name"
  )
  sketchybar --add item space."$name" left --set space."$name" "${space[@]}"
done

sketchybar --add event aerospace_workspace_change \
           --set space.T space.N space.M space.I space.P space.B space.A \
                 script="$PLUGIN_DIR/aerospace_workspaces.sh" \
           --subscribe space.T space.N space.M space.I space.P space.B space.A aerospace_workspace_change

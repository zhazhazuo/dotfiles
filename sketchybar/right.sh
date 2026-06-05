##### Right: Status Items #####
sketchybar --add item volume right \
           --set volume script="$PLUGIN_DIR/volume.sh" \
           --subscribe volume volume_change

sketchybar --add item battery right \
           --set battery update_freq=120 script="$PLUGIN_DIR/battery.sh" \
           --subscribe battery system_woke power_source_change

sketchybar --add item ip right \
           --set ip update_freq=60 icon=󰩟 script="$PLUGIN_DIR/ip.sh"

sketchybar --add item date right \
           --set date update_freq=60 icon=󰸗 script="$PLUGIN_DIR/date.sh"

sketchybar --add item week right \
           --set week update_freq=60 icon=󰃭 script="$PLUGIN_DIR/week.sh"

sketchybar --add item time right \
           --set time update_freq=30 icon=󰥔 script="$PLUGIN_DIR/time.sh"

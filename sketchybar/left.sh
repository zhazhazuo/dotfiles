##### Left: Focused Application #####
sketchybar --add item front_app left \
           --set front_app icon.drawing=off script="$PLUGIN_DIR/front_app.sh" \
           --subscribe front_app front_app_switched

##### Center: Agent Monitor #####
sketchybar --add event agent_monitor_update \
           --add item agent_monitor center \
           --set agent_monitor drawing=off \
                                icon.padding_left=8 \
                                icon.padding_right=4 \
                                label.padding_left=2 \
                                script="$PLUGIN_DIR/agent_monitor.sh" \
           --subscribe agent_monitor agent_monitor_update mouse.clicked

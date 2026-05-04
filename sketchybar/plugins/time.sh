#!/bin/sh

DE_TIME=$(TZ=Europe/Berlin date '+%Z %H:%M')
CN_TIME=$(TZ=Asia/Shanghai date '+%Z %H:%M')

sketchybar --set "$NAME" label="${CN_TIME} / ${DE_TIME}"

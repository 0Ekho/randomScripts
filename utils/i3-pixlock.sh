#!/bin/bash

# requires ffmpeg and i3lock

# exit if screen is already locked
if pgrep i3lock; then
    exit 1
fi

tmpbg="/tmp/lockscreen.png"
dir="$HOME/Pictures/lockscreen/"

images=($(find "${dir}" -name 'lock_*.png'))
rand=$(( RANDOM % ${#images[@]} ))
pic=${images[$rand]}

# so any menus used to lock have time to close (eg, Xfce whiskermenu)
sleep 0.5

ffmpeg -hide_banner -v error -f x11grab -video_size 7200x1080 -i "$DISPLAY"\
 -filter_complex "scale=iw/8:ih/8:flags=area,scale=8*iw:8*ih:flags=neighbor"\
 -vframes 1 -y "$tmpbg"

# fix stupid error caused by different sized screens, you shouldn't need this
# and should be able to comment/remove it
ffmpeg -hide_banner -v error -i "$tmpbg"\
 -vf drawbox=5760:0:1440:180:0x090909:t=max -vframes 1 -y "$tmpbg"

if [ -f "$pic" ]; then
    # add overlay image/logo to second screen
    ffmpeg -hide_banner -v error -i "$tmpbg" -i "$pic" -filter_complex\
     'overlay=1920:0' -y "$tmpbg"
fi

i3lock\
 -f -e -i "$tmpbg"\
 >> /dev/null &

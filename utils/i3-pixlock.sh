#!/bin/bash

# requires imagemagick and i3lock
 
tmpbg="/tmp/lockscreen.png"
dir="$HOME/Pictures/lockscreen/"

images=($(find ${dir} -name 'lock_*.png'))
rand=$(( $RANDOM % ${#images[@]} ))
pic=${images[$rand]}

# so any menues used to lock have time to close
sleep 4 
# ffmpeg is faster than imagemagick
ffmpeg -hide_banner -v error -f x11grab -video_size 7200x1080 -i $DISPLAY \
-vframes 1 -y "$tmpbg"
#import -window root +repage "$tmpbg"

# fix stupid error caused by different sized screens
convert "$tmpbg" -fill "#090909" -draw "rectangle 5760,0,7200,179" "$tmpbg"

#convert "$tmpbg" -scale 10% -scale 1000% -blur 0x8 "$tmpbg"
convert "$tmpbg" -scale 20% -scale 500% -blur 0x2 "$tmpbg"
#convert "$tmpbg" -scale 10% -scale 1000% -colorize 25% "$tmpbg"

if [ -f "$pic" ]; then
    convert "$tmpbg" "$pic" -gravity northwest -geometry +1920+0 -composite -matte "$tmpbg"
fi
 
i3lock -n -e -i "$tmpbg" >> /dev/null &

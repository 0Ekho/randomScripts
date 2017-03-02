#!/bin/bash

# requires imagemagick and i3lock (ffmpeg also to use the faster commands)
# slowly adding ffmpeg to completly replace imagemagick for speed

tmpbg="/tmp/lockscreen.png"
dir="$HOME/Pictures/lockscreen/"

images=($(find ${dir} -name 'lock_*.png'))
rand=$(( $RANDOM % ${#images[@]} ))
pic=${images[$rand]}

# so any menus used to lock have time to close (eg, Xfce whiskermenu)
sleep 1
# ffmpeg is faster than imagemagick
ffmpeg -hide_banner -v error -f x11grab -video_size 7200x1080 -i $DISPLAY \
-vframes 1 -y "$tmpbg"
#import -window root +repage "$tmpbg"

# fix stupid error caused by different sized screens, you shouldn't need this
#convert "$tmpbg" -fill "#090909" -draw "rectangle 5760,0,7200,179" "$tmpbg"
# ffmpeg is faster (~3s vs ~1s)
ffmpeg -hide_banner -v error -i "$tmpbg" \
-vf drawbox=5760:0:1440:180:0x090909:t=max -vframes 1 -y "$tmpbg"

#convert "$tmpbg" -scale 10% -scale 1000% -blur 0x8 "$tmpbg"
#convert "$tmpbg" -scale 20% -scale 500% -blur 0x3 "$tmpbg"
#convert "$tmpbg" -scale 10% -scale 1000% -colorize 25% "$tmpbg"
convert "$tmpbg" -scale 10% -scale 1000% -colorize 10% -blur 0x2 "$tmpbg"

if [ -f "$pic" ]; then
    # add overlay image/logo to second screen
	#convert "$tmpbg" "$pic" -gravity northwest -geometry +1920+0 -composite \
	#-matte "$tmpbg"
	ffmpeg -hide_banner -v error -i $tmpbg -i $pic -filter_complex \
	'overlay=1920:0' -y $tmpbg
fi

i3lock -n -e -i "$tmpbg" >> /dev/null &
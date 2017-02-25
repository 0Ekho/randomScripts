#!/bin/bash

# converts audio or video to taged opus files for use in music players
# place in dir with media files and run, files should be named
# "artist - title.ext" artist cannot contain '-'. opus files with tags
# will be in the "cleaned" directory. currently accepts: webm, mp3, mp4

mkdir -p ./cleaned

cover_img="0"
#WIP
#if [ -f "cover_img.jpg" ]; then
#cover_img="cover_img.jpg"
#elif [ -f "cover_img.png" ]; then
#cover_img="cover_img.png"
#fi

c2opus() 
{
		codec=`ffprobe -v error -show_entries stream=codec_name -of \
default=nokey=1:noprint_wrappers=1 "$1"`
        fullname=$(basename "$1")
        name="${fullname%.*}"
		artist="${name%%-*}"
		# trim whitespace
		artist="${artist#"${artist%%[![:space:]]*}"}"
		artist="${artist%"${artist##*[![:space:]]}"}"
		title="${name#*-}"
        # trim whitespace
        title="${title#"${title%%[![:space:]]*}"}"
        title="${title%"${title##*[![:space:]]}"}"
        if [ "`grep "opus" <<< $codec`" == "opus" ]; then
            echo "Codec of file: $codec"
			if [ "$cover_img" != "0" ]; then
				ffmpeg -hide_banner -i "$1" -c copy -metadata:s:a:0 \
TITLE="$title" -metadata:s:a:0 ARTIST="$artist" "cleaned/$name.opus"
			else
            	ffmpeg -hide_banner -i "$1" -c copy -metadata:s:a:0 \
TITLE="$title" -metadata:s:a:0 ARTIST="$artist" "cleaned/$name.opus"
        	fi
		else
            echo "Codec of file: $codec"
            b_rate_raw=`ffprobe -v error -select_streams a:0 -show_entries \
stream=bit_rate -of default=nokey=1:noprint_wrappers=1 "$1"`
            b_rate=$(($b_rate_raw / 1000))
			if [ "$cover_img" != "0"  ]; then
				ffmpeg -hide_banner -i "$1" -b:a "$b_rate"K -metadata:s:a:0 \
TITLE="$title" -metadata:s:a:0 ARTIST="$artist" "cleaned/$name.opus"
			else
            	ffmpeg -hide_banner -i "$1" -b:a "$b_rate"K -metadata:s:a:0 \
TITLE="$title" -metadata:s:a:0 ARTIST="$artist" "cleaned/$name.opus"
			fi
        fi
}
if test -n "$(shopt -s nullglob; echo *.mp?)"; then
	for item in ./*.mp?; do
		c2opus "$item"
	done
fi
if test -n "$(shopt -s nullglob; echo *.webm)"; then
	for item in ./*.webm; do
		c2opus "$item"
	done
fi

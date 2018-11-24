#!/usr/bin/env bash

# usage ./oegen.sh 'path/to/info.file' 'output name'
# info.file should contain
#   /path/to/video/file
#   start time (formated for ffmpeg -ss, 00:00:00.000)
#   end time  (formated for ffmpeg -to, 00:00:00.000)
# mpv plugin savetime.lua is usefull for this

if="$(sed -n '1p' "$1")"
of="$2"

st="$(sed -n '2p' "$1")"
et="$(sed -n '3p' "$1")"

plog="oe2pass_$(head /dev/urandom |  tr -dc A-Za-z0-9 | head -c 4)"

ffmpeg -hide_banner -ss "$st" -i "$if" -to "$et" -pass 1 -passlogfile "$plog"\
 -threads 6 -c:v libvpx-vp9 -b:v 4M -crf 23 -minrate 400K -maxrate 8M\
 -deadline good -cpu-used 4 -tile-columns 4 -frame-parallel 1 -g 240\
 -an -sn -y -f webm /dev/null

ffmpeg -hide_banner -ss "$st" -i "$if" -to "$et" -pass 2 -passlogfile "$plog"\
 -threads 6 -c:v libvpx-vp9 -b:v 4M -crf 23 -minrate 400K -maxrate 8M\
 -deadline good -cpu-used 2 -slices 4 -tile-columns 4 -frame-parallel 1\
 -auto-alt-ref 1 -lag-in-frames 25 -g 240 -sn -c:a libopus -b:a 160k\
 -vbr constrained -af "channelmap=channel_layout=stereo" -map 0:0 -map 0:1\
 -metadata:s:a:0 title="opus" -f webm "$of.webm"

rm "$plog-0.log"

#!/bin/bash
# This script adjusts the volume of mocp playback.
# Usage: `./moc_vol.sh +/-percent_change` MOC must be playing.
# This script does not have much checks against incorrect usage.

set -euo pipefail
IFS=$(echo -en "\n\b")

arg1=$1
if [ -z "$arg1" ]; then
    echo "must provide percent to change"
    exit 1
fi
oper="+"
if [ "$arg1" -lt "0" ]; then
    oper="-"
fi
arg1=${arg1//[!0-9]/}

# Really hacked way to get the index and volume for the mocp sink-input.
# This is probably not even slightly reliable.
moc_info=( $(pacmd list-sink-inputs | \
awk '$1 == "index:" {i=$2}; $1 == "volume:" {v=$3}; $1 == "application.name" && $5 == "[mocp]\"" {print i"\n"v}') )

if [ ! -v moc_info ];then 
    echo "MOC not found"
    exit 2
fi

change=$(dc -e "4k 65535 $arg1 100 /*p")
# 100% there is a better way to floor() with dc but not sure what it is.
change=$(dc -e "0k $change 1 /p")

new_vol=$(( ${moc_info[1]} $oper $change ))
if [ "$new_vol" -lt "0" ]; then
    new_vol=0
fi
if [ "$new_vol" -gt "65536" ]; then
    new_vol=65536
fi

pacmd set-sink-input-volume "${moc_info[0]}" "$new_vol"

notify-send -t 1000 "MOC volume set to $(( new_vol * 100 / 65536 ))%"

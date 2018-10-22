#!/usr/bin/env sh

last_img=''
delay=10
ifile=/tmp/coverdisplay

update_img() {
    img="$(mocp --format '%file')"
    if [ "$last_img" != "$img" ]; then
        last_img="$img"
        exiftool -b -G4 '-Picture' "$img" > "$ifile"
    fi
}

while true; do
    update_img
    sleep "$delay" 
done & 

eloop_pid="$!"

# wait for img to be extracted
sleep 2;

feh -g '256x256+6577+754' -N -R "$delay" -x -. "$ifile"

kill "$eloop_pid"

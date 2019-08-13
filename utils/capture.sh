#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Simple script for capturing screenshots and uploading them or another file
# to a simple file hosting site. depends on ffmpeg and exiftool
# if xfce needs xfce4-screenshooter, else can uncomment xwd and use that instead
# (but area select will not work currently)
# you will need to edit to work with your site


folder=$(dirname "$0")
archive="$folder/archive"
# WARNING, deleting this file will cause the couter to reset and new
# files to overwrite the old ones.
if [ ! -f "$folder/counter.txt" ]; then
    echo "0" > "$folder/counter.txt"
fi
count=$(cat "$folder/counter.txt")
file_name="SN$(printf %07d "$count")"
((count++))
echo $count > "$folder/counter.txt"

# this mess will use ffmpeg to add a timestamp to the image
# NOTE: do not call this with on non screenshot files, destroys original file
timestamp()
{
    fontpath='/usr/share/fonts/truetype/hack/Hack-Regular.ttf'
    height=$(exiftool -b -ImageHeight "$file_path");
    width=$(exiftool -b -ImageWidth "$file_path");
    # readable text wont fit on something too small so skip
    if (( height <= 25 )) || (( width <= 100 )); then
        notify-send -t 4000 "Image to small for timestamp to be added."
    else
        # smaller images get a smaller font to make things fit better
        if (( height <= 250 )) || (( width <= 500 )); then
            pntsize=12
            ofst=2
            srkwdt=1
        else
            pntsize=18
            ofst=4
            srkwdt=2
        fi
        timestamp=$(date "+%Y-%m-%d %H\\\\\\:%M\\\\\\:%S")
        tf=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 4)
        mv "$file_path" "/tmp/capts_$tf"
        ffmpeg -i "/tmp/capts_$tf" -vf "$(printf '%s%s%s'\
         "drawtext=fontfile=${fontpath}:text=${timestamp}:fontsize=${pntsize}"\
         ":fontcolor=white:borderw=${srkwdt}:bordercolor=black"\
         ":x=(w-${ofst}-${pntsize}*11):y=(h-${ofst}-${pntsize})")" "$file_path"
        rm "/tmp/capts_$tf"
    fi
}
upload_file_site()
{
    apikey=$(cat "$folder/apikey.txt")
    time_stamp=$(date "+%Y-%m-%d %H:%M:%S")
    notify-send -t 2000 "File is being uploaded..."
    # upload file to site and save response to file and grep url uploaded to
    response=$(curl -s --limit-rate 125K -F "file=@$file_path" -F "apikey=$apikey" \
    https://x88.moe/api/v1/upload.php)
    # get just the url for the file
    url=$(echo "$response" | grep -Po '(?<="url":").*?(?=")')
    # save response so can find/delete it if wanted later.
    printf "File: %s, Time: %s, Response: %s\\n" "$(readlink -f "$file_path")" \
    "$time_stamp" "$response" >> "$folder/history.txt"
    echo -n "$url" | xclip -i -selection c
    notify-send -t 4000 "File Uploaded to: $url and link copied to clipboard"
}
copy_file()
{
    tmpfile_name=$(basename "$file_path")
    exten="${tmpfile_name##*.}"
    new_path="$archive/$file_name.$exten"
    cp "$file_path" "$new_path"
    file_path="$new_path"
}
share_file()
{
    # if no file screenshot was cancelled
    if [ -e "$file_path" ]; then
        if [ "$copy" -eq 1 ]; then
            copy_file
        fi
        upload_file_site
    else
        notify-send -t 4000 "Screenshot Cancelled"
    fi
}

share=0
copy=0
# parse the input
for i in "$@"; do
    case $i in
        -f=*|--file=*)
            file_path=$(readlink -f "${i#*=}")
        ;;
        -a|--area)
            file_path="$archive/$file_name.png"
            xfce4-screenshooter -r -s "$file_path"
        ;;
        -w|--window)
            file_path="$archive/$file_name.png"
            #rand=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 4)
            # for some reason pipe break ffmpeg
            #xwd -id "$(xprop -root 32x '\t$0' _NET_ACTIVE_WINDOW | cut -f 2)"\
            # -out "/tmp/tc_${rand}.xwd"
            #ffmpeg -i "/tmp/tc_${rand}.xwd" -vframes 1 "$file_path"
            #rm "/tmp/tc_${rand}.xwd"
            xfce4-screenshooter -w -s "$file_path"
        ;;
        -x|--fullscreen)
            file_path="$archive/$file_name.png"
            #rand=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 4)
            # for some reason pipe break ffmpeg
            #xwd -root -out "/tmp/tc_${rand}.xwd"
            #ffmpeg -i "/tmp/tc_${rand}.xwd" -vframes 1 "$file_path"
            #rm "/tmp/tc_${rand}.xwd"
            xfce4-screenshooter -f -s "$file_path"
            # fix error caused by different sized screens, you shouldn't need
            # this
            mv "$file_path" "/tmp/cap_fix.png"
            ffmpeg -hide_banner -v error -i "/tmp/cap_fix.png"\
             -vf drawbox=5760:0:1440:180:0x090909:t=fill -vframes 1 -y\
             "$file_path"
            rm "/tmp/cap_fix.png"
        ;;
        -t|--area-timestamp)
            file_path="$archive/$file_name.png"
            xfce4-screenshooter -r -s "$file_path"
            timestamp
        ;;
        -g|--window-timestamp)
            file_path="$archive/$file_name.png"
            #rand=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 4)
            # for some reason pipe break ffmpeg
            #xwd -id "$(xprop -root 32x '\t$0' _NET_ACTIVE_WINDOW | cut -f 2)"\
            # -out "/tmp/tc_${rand}.xwd"
            #ffmpeg -i "/tmp/tc_${rand}.xwd" -vframes 1 "$file_path"
            #rm "/tmp/tc_${rand}.xwd"
            xfce4-screenshooter -w -s "$file_path"
            timestamp
        ;;
        # maybe sometime make clipboard data type automatically checked
        -c|--clipboard)
            file_path="$archive/$file_name.txt"
            xclip -selection clipboard -o > "$file_path"
        ;;
        -z|--clipboard-image)
            file_path="$archive/$file_name.png"
            xclip -selection clipboard -t image/png -o > "$file_path"
        ;;
        -r|--tmp-capture)
            rand=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 4)
            file_path="/tmp/tc$rand.png"
            #xwd -id "$(xprop -root 32x '\t$0' _NET_ACTIVE_WINDOW | cut -f 2)"\
            # -out "/tmp/tc_${rand}.xwd"
            #ffmpeg -i "/tmp/tc_${rand}.xwd" -vframes 1 "$file_path"
            #rm "/tmp/tc_${rand}.xwd"
            xfce4-screenshooter -w -s "$file_path"
            echo -n "$file_path" | xclip -i -selection c
            notify-send -t 4000 "File saved to $file_path"
        ;;
        -b|--copy)
            copy=1
        ;;
        -s|--share)
            share=1
        ;;
        *)
            echo "unknown argument : $i, Exiting."
            exit
        ;;
    esac
done
# if no args default to area && share
if [ -z "${file_path+x}" ]; then
    file_path="$archive/$file_name.png"
    xfce4-screenshooter -w -s "$file_path"
    share=1
fi
if [ $share -eq 1 ]; then
    share_file
fi

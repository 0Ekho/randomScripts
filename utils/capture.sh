#!/bin/bash

# MIT License
# Copyright (c) 2019 Ekho <ekho@ekho.email>

# Simple script for capturing screenshots and uploading them or another file
# to a simple file hosting site. 
# depends on ffmpeg, exiftool, and sharenix.py
# (which needs python3-pycurl and python3-dbus and xclip)

# also needs xfce4-screenshooter, or can uncomment xwd and use that instead 
# (but area select will not work currently)

# you will need to edit the curl commands in sharenix.py to work with your file
# host of choice

set -euo pipefail
IFS=$'\n\t'


main_dir="$HOME/.sharenix"
archive_dir="$main_dir/archive"

# use PNG for images
iext='png'

# WARNING, deleting this file will cause the couter to reset and new
# files to overwrite the old ones.
if [ ! -f "$main_dir/count" ]; then
    echo "0" > "$main_dir/count"
fi
count=$(cat "$main_dir/count")
file_name="$(printf "SN_%07d" "$count")"
((count++))
echo $count > "$main_dir/count"


# mktemp but with file extensions, for ffmpeg format detection
mktmp()
{
    mktf=$(mktemp "$1")
    mv "$mktf" "$mktf.$2"
    echo "$mktf.$2"
}

# this mess will use ffmpeg to add a timestamp to the image
# NOTE: do not call this with on non screenshot files, destroys original file
timestamp()
{
    # set to font of choice, may have to chage size values for other fonts
    fontpath='/usr/share/fonts/truetype/hack/Hack-Regular.ttf'

    height=$(exiftool -b -ImageHeight "$file_path");
    width=$(exiftool -b -ImageWidth "$file_path");
    # readable text wont fit on something too small so skip
    if (( height <= 25 )) || (( width <= 100 )); then
        sharenix.py notify "Image too small for timestamp to be added." ""  2000
    else
        # smaller images get a smaller font to make things fit better
        if (( height <= 250 )) || (( width <= 500 )); then
            pntsize=12
            pxw=7
            ofst=4
            srkwdt=1
        else
            pntsize=20
            pxw=12
            ofst=8
            srkwdt=2
        fi

        # ffmpeg escaping .-.
        timestamp=$(date "+%Y-%m-%d %H\\\\\\:%M\\\\\\:%S")
        tf=$(mktmp "/tmp/snts_XXXXXXXX" "$iext")

        # TODO: apparently ffmpeg has gmtime, use instead
        ffmpeg -hide_banner -v warning -i "$file_path" -vf "$(printf '%s%s%s'\
         "drawtext=fontfile=${fontpath}:text=${timestamp}:fontsize=${pntsize}"\
         ":fontcolor=white:borderw=${srkwdt}:bordercolor=black"\
         ":x=(w-${ofst}-${pxw}*19):y=(h-${ofst}/2-${pntsize})")" -y "$tf"

        mv "$tf" "$file_path"
    fi
}

upload_file_site()
{
    apikey=$(cat "$main_dir/apikey")
    upload_time=$(date "+%Y-%m-%d %H:%M:%S")
    fail=0
    # upload file to site
    if ! response="$(sharenix.py upload "$file_path" "$apikey")"; then
        fail=$?
    fi

    # save response, needed for deletion links
    # CSV header: 'upload_time,file_path,response'
    # NOTE: there is no quoting or escaping currently, so ',' in filenames can
    # cause issues parsing this file later
    printf "%s,%s,%s\\n" "$upload_time" "$(readlink -f "$file_path")"\
            "$response" >> "$main_dir/history.csv"

    echo "$response"
    if (( fail != 0 )); then
        exit "$fail"
    fi
}

# -----------------------------------------------------------------------------

share=0
add_ts=0

# parse the input
for i in "$@"; do
    case $i in
        -u=*|--upload-file=*)
            file_path=$(readlink -f "${i#*=}")
            share=1
            add_ts=-1
        ;;
        -a|--area|-r|--region)
            file_path="$archive_dir/$file_name.$iext"
            xfce4-screenshooter -r -s "$file_path"
        ;;
        -w|--window)
            file_path="$archive_dir/$file_name.$iext"

            # pipes break ffmpeg with xwd unfortunatly
            #tf=$(mktemp "/tmp/snts_XXXXXXXX")
            #xwd -id "$(xprop -root 32x '\t$0' _NET_ACTIVE_WINDOW | cut -f 2)"\
            # -out "$tf"
            #ffmpeg -hide_banner -v warning\
            # -f xwd_pipe -i "$tf" -vframes 1 "$file_path"
            #rm "$tf"

            xfce4-screenshooter -w -s "$file_path"
        ;;
        -f|--fullscreen)
            file_path="$archive_dir/$file_name.$iext"

            #tf=$(mktemp "/tmp/snts_XXXXXXXX")
            #xwd -root -out "$tf"
            #ffmpeg -hide_banner -v warning\
            # -f xwd_pipe -i "$tf" -vframes 1 "$file_path"
            #rm "$tf"

            xfce4-screenshooter -f -s "$file_path"

            # fix error caused by different sized screens, you shouldn't need
            # this
            tf=$(mktmp "/tmp/snts_XXXXXXXX" "$iext")
            mv "$file_path" "$tf"
            ffmpeg -hide_banner -v warning -i "$tf"\
             -vf drawbox=5760:0:1440:180:0x090909:t=fill -vframes 1 -y\
             "$file_path"
            rm "$tf"
        ;;
        -h|--tmp-capture)
            rand=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 4)
            file_path="/tmp/tc_$rand.$iext"

            #tf=$(mktemp "/tmp/snts_XXXXXXXX")
            #xwd -id "$(xprop -root 32x '\t$0' _NET_ACTIVE_WINDOW | cut -f 2)"\
            # -out "$tf"
            #ffmpeg -hide_banner -v warning\
            # -f xwd_pipe -i "$tf" -vframes 1 "$file_path"
            #rm "$tf"

            xfce4-screenshooter -w -s "$file_path"
            echo -n "$file_path" | xclip -i -selection clipboard
            sharenix.py notify "File saved to" "$file_path" 4000

        ;;
        -e|--edit)
            # TODO: open file in editor (gimp) first to allow for blocking out
            # private information easily
        ;;
        -t|--timestamp)
            if [ $add_ts -eq 0 ]; then
                add_ts=1
            else
                echo "refusing to timestamp non screenshot file, "\
                 "timestamp destructivly modifies original"
            fi
        ;;
        -s|--share)
            share=1
        ;;
        *)
            echo "unknown argument : $i, Exiting."
            exit 5
        ;;
    esac
done


if [ $add_ts -eq 1 ]; then
    timestamp
fi

if [ $share -eq 1 ]; then
    # if no file screenshot was cancelled
    if [ -e "$file_path" ]; then
        upload_file_site
    else
        sharenix.py notify "Screenshot Cancelled" "" 4000
    fi
fi

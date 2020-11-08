#!/bin/bash

# MIT License
# Copyright (c) 2019 Ekho <ekho@ekho.email>

# Simple script for capturing screenshots and uploading them or another file
# to a simple file hosting site.
# depends on ffmpeg, exiftool, and sharenix.py
# (which needs python3-pycurl and python3-dbus and xclip)

# also needs scrot for taking the screenshots, or use tool of your choice

# you will need to edit the curl commands in sharenix.py to work with your file
# host of choice

# use `capture.sh 'command "$file_path"' [flags]`
# example `capture.sh 'scrot -u "$file_path"' -s`
#
# or `capture.sh 'xwd_window "$file_path"' -s` to use xwd to capture current
# window, which does not merge composite windows
# or `capture.sh 'scrot -u "$file_path" && gimp "$file_path"' -s` to edit the
# image first (make sure to overwrite original when saving)
#
# first argument is command to eval for screenshot, with "$file_path" included
# literally to the save path argument of your command

set -euo pipefail
IFS=$'\n\t'


main_dir="$HOME/.sharenix"
archive_dir="$main_dir/archive"

# use PNG for images
iext='png'

# mktemp but with file extensions, for ffmpeg, etc. format detection
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
        sharenix.py notify -t 2000 "Image too small for timestamp to be added." ""
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

# capture active window with xwd
xwd_window() {
    # pipes break ffmpeg with xwd unfortunately
    tf=$(mktemp "/tmp/snts_XXXXXXXX")
    xwd -id "$(xprop -root 32x '\t$0' _NET_ACTIVE_WINDOW | cut -f 2)"\
     -out "$tf"
    ffmpeg -hide_banner -v warning\
     -f xwd_pipe -i "$tf" -vframes 1 "$1"
    rm "$tf"
}

# -----------------------------------------------------------------------------

share=0
# flag may set negative to force disable timestamps if incompatable (such as if
# it uses an existing file, which must not be modified)
add_ts=0 # currently useless as now the actual screenshot command is unknown

# parse the input
file_name="$(date '+SN_%s')"
file_path="$archive_dir/$file_name.$iext"
if [ -f "$file_path" ]; then
    # try to avoid overwriting / erroring on existing files
    # still can race and unlikely to help much if screen_shot takes a long time
    # before creating the file, add nanoseconds to timestamp to get reliability
    # (eg. interactive selection, don't screenshot taking a screenshot)
    # even if screen_shot avoids overwrites in the case a race occurs,
    # if share is set the wrong (old, existing file) will be uploaded
    file_name="$(mktemp "${file_name}_XXXXXXXX")"
    file_path="$archive_dir/$file_name.$iext"
fi
screen_shot=$1
shift

for i in "$@"; do
    case $i in
        -h|--tmp-capture)
            file_path="$(mktemp -u "/tmp/tc_XXXX").$iext"
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

# actually take screen shot
eval "$screen_shot"
# ---------

if [ $add_ts -eq 1 ]; then
    timestamp
fi

if [ $share -eq 1 ]; then
    # if no file screenshot was cancelled
    if [ -e "$file_path" ]; then
        # upload file to site
        if ! sharenix.py upload "$file_path"; then
            exit "$?"
        fi
    else
        sharenix.py notify -t 4000 "Screenshot Cancelled" ""
    fi
else
    echo -n "$file_path" | xclip -i -selection clipboard
    sharenix.py notify -t 4000 "File saved to" "$file_path"
fi

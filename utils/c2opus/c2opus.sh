#!/bin/bash

# this script was never intended to last more than a few hours
# I should probably fix a lot of it and is generally terrible

# usage: ./c2opus [-i cover.png *.webm]

# converts audio or video to tagged opus files for use in music players
# files should be named "artist [& artist2] - title.ext" artist cannot
# contain '-' or '&'. opus files with tags will be output in a directory
# named "out_c2o".

# TODO: actually add spliting artists, currently it is all taken as one long
# artist name and not split on '&'

# to use just pass the path to the file you want to convert

# you can use -i to provide a png or jpg and it will be added as cover art
# this required you to have imagemagick and use a patched version of ffmpeg
# (the ffmpeg_metadata.patch file). the patched ffmpeg should be placed in
# the same directory as this script and be named "ffmpeg_patched"
# the image is recommened to have 1:1 aspect ratio and it MUST be less than
# 5MiB or it will be cut off and leave the image tage corrupted as there is
# base64 overhead and only the first 7MiB are read (including the tag name)

mkdir -p ./out_c2o

cover_img="0"
patched_ffmpeg="0"
if [ -f "ffmpeg_patched" ]; then
    patched_ffmpeg="1"
fi

die()
{
    printf '%s\n' "$1" >&2
    exit 1
}

c2opus()
{
    # get input codec
    make_ffmeta "$1"
    echo "File: $1"
    codec=$(ffprobe -v error -show_entries stream=codec_name -of \
default=nokey=1:noprint_wrappers=1 "$1")
    # if already opus don't re-encode
    if [ "$(grep "opus" <<< "$codec")" == "opus" ]; then
        echo "Codec of file: $codec"
        if [ "$cover_img" != "0" ]; then
            ./ffmpeg_patched -hide_banner -i "$1" -i /tmp/c2o.ffmeta \
-map_metadata:s:a:0 1: -codec copy "out_c2o/$name.opus"
        else
            ffmpeg -hide_banner -i "$1" -i /tmp/c2o.ffmeta \
-map_metadata:s:a:0 1: -codec copy "out_c2o/$name.opus"
        fi
    else
        echo "Codec of file: $codec"
        # try to get bitrate of file
        b_rate_raw=$(ffprobe -v error -select_streams a:0 -show_entries \
stream=bit_rate -of default=nokey=1:noprint_wrappers=1 "$1")
        case $b_rate_raw in
            ''|*[!0-9]*)
                echo "unable to determine bitrate, falling back to 192kbps"
                b_rate=192
            ;;
            *)
                b_rate=$((b_rate_raw / 1000))
                echo "input bitrate is ${b_rate}kbps"
            ;;
        esac
        if [ "$cover_img" != "0"  ]; then
            ./ffmpeg_patched -hide_banner -i "$1" -i /tmp/c2o.ffmeta \
-map_metadata:s:a:0 1: -b:a "$b_rate"K "out_c2o/$name.opus"
        else
            ffmpeg -hide_banner -i "$1" -i /tmp/c2o.ffmeta \
-map_metadata:s:a:0 1: -b:a "$b_rate"K "out_c2o/$name.opus"
        fi
    fi
}
block_picture()
{
    # I'm 100% sure this is a terrible idea
    mkdir -p '/tmp/c2o'
    cover_img=$1
    image_width=$(identify -format %w "$cover_img");
    image_height=$(identify -format %h "$cover_img");
    image_depth=$(identify -format %z "$cover_img");
    image_size=$(stat --printf="%s" "$cover_img");
    # make frame header in hex
    # https://xiph.org/flac/format.html#metadata_block_picture
    printf %08x 3 > /tmp/c2o/cover.hex # front cover
    # mime string
    if [[ "${cover_img##*.}" == "jpg" ]]; then
        printf %08x 10 >> /tmp/c2o/cover.hex
        echo -n "image/jpeg" | xxd -p >> /tmp/c2o/cover.hex
    elif [[ "${cover_img##*.}" == "png" ]]; then
        printf %08x 9 >> /tmp/c2o/cover.hex
        echo -n "image/png" | xxd -p >> /tmp/c2o/cover.hex
    else
        die "invalid image type, Exiting"
    fi
    # description string
    { printf %08x 13;
    echo -n "Cover (front)" | xxd -p;
    printf %08x "$image_width";
    printf %08x "$image_height";
    printf %08x "$image_depth";
    printf %08x 0; #no color index
    printf %08x "$image_size"; } >> '/tmp/c2o/cover.hex'
    ## dump image to hex appending to the frame header
    ## xxd -p $cover_img >> /tmp/c2o/cover.hex
    # convert back to binary
    xxd -p -r '/tmp/c2o/cover.hex' > '/tmp/c2o/cover.bin'
    # append image to header
    cat "$cover_img" >> '/tmp/c2o/cover.bin'
    # convert to base 64 for use in opus file
    base64 -w 0 < '/tmp/c2o/cover.bin' > '/tmp/c2o/cover.b64'
    rm '/tmp/c2o/cover.hex'
    rm '/tmp/c2o/cover.bin'
}
make_ffmeta()
{
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

    echo ";FFMETADATA1" > '/tmp/c2o.ffmeta'
    { echo "ARTIST=$artist";
    echo "TITLE=$title";
    echo "LANGUAGE=und"; } >> '/tmp/c2o.ffmeta'
    if [ "$cover_img" != "0" ]; then
        echo -n "METADATA_BLOCK_PICTURE=" >> '/tmp/c2o.ffmeta'
        cat '/tmp/c2o/cover.b64' >> '/tmp/c2o.ffmeta'
    fi
}

while [[ $# -gt 1 ]]; do
    case $1 in
        -i)
            if [ "$patched_ffmpeg" != "1" ]; then
                die 'ERROR: patched ffmpeg is required to attached cover a image'
            fi
            if [ "$2" ]; then
                cover_img="$2"
                shift
            else
                die 'no image path provided'
            fi
            ;;
        *)
            break
            ;;
    esac
    shift
done

if [ "$cover_img" != "0" ]; then
    echo "$cover_img will be attached as cover front"
    if [[ "${cover_img##*.}" != "jpg" ]] && \
    [[ "${cover_img##*.}" != "png" ]]; then
        die 'cover image must be .png or .jpg'
    fi
    if (( $(stat -c%s "$cover_img") > 5242880 )); then
        die 'cover image must be less than 5MiB'
    fi
    block_picture "$cover_img"
fi

for item in "$@"; do
    c2opus "$item"
done

# cleanup
#rm '/tmp/c2o.ffmeta'
if [ "$cover_img" != "0"  ]; then
    rm '/tmp/c2o/cover.b64'
    rmdir '/tmp/c2o'
fi

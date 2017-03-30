#!/bin/bash

# converts audio or video to taged opus files for use in music players
# place in dir with media files and run, files should be named
# "artist - title.ext" artist cannot contain '-'. opus files with tags
# will be in the "cleaned" directory. currently accepts: webm, mp3, mp4

# if cover_img.jpg or cover_img.png is placed in the same dir as the script
# it will be added as cover art (Imagemagick REQUIRED) The image should be
# 1:1 aspect and less than or equal to 512x512px, the image also MUST be 
# smaller than 100kB or the script will error with Argument list too long
# as currently catting the data into the ffmpeg args, if I find a better
# way to get data into ffmpeg for metadata tags I can fix the size limit
mkdir -p ./cleaned

cover_img="0"
if [ -f "cover_img.jpg" ]; then
cover_img="cover_img.jpg"
elif [ -f "cover_img.png" ]; then
cover_img="cover_img.png"
fi

c2opus() 
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
		# get input codec
        codec=`ffprobe -v error -show_entries stream=codec_name -of \
default=nokey=1:noprint_wrappers=1 "$1"`
		# if already opus don't re-encode
        if [ "`grep "opus" <<< $codec`" == "opus" ]; then
            echo "Codec of file: $codec"
			if [ "$cover_img" != "0" ]; then
				block_picture $cover_img

				ffmpeg -hide_banner -i "$1" -c copy -metadata:s:a:0 \
TITLE="$title" -metadata:s:a:0 ARTIST="$artist" -metadata:s:a:0 LANGUAGE="" \
-metadata:s:a:0 METADATA_BLOCK_PICTURE="`cat tmp/cover.b64`" \
"cleaned/$name.opus"
			else
            	ffmpeg -hide_banner -i "$1" -c copy -metadata:s:a:0 \
TITLE="$title" -metadata:s:a:0 ARTIST="$artist" -metadata:s:a:0 LANGUAGE="" \
"cleaned/$name.opus"
        	fi
		else
            echo "Codec of file: $codec"
			# try to get bitrate of file
            b_rate_raw=`ffprobe -v error -select_streams a:0 -show_entries \
stream=bit_rate -of default=nokey=1:noprint_wrappers=1 "$1"`
			case $b_rate_raw in
				''|*[!0-9]*) 
					echo "unable to determine bitrate, falling back to 192kpbs"
					b_rate=192
				;;
				*)
					# even number out a little
					b_rate=$(($b_rate_raw / 1000))
					echo "input bitrate is $b_rate"
				;;
			esac
			if [ "$cover_img" != "0"  ]; then
				block_picture $cover_img
				#echo ";FFMETADATA1" >> tmp/metadata.txt
				#echo "TITLE=$title" >> tmp/metadata.txt
                #echo "ARTIST=$artist" >> tmp/metadata.txt
				#echo -n "METADATA_BLOCK_PICTURE=" >> tmp/metadata.txt
				#cat "tmp/cover.b64" >> tmp/metadata.txt
				#echo "" >> tmp/metadata.txt
				#ffmpeg -hide_banner -i "$1" -i "tmp/metadata.txt" -map_metadata 1:s:0 -b:a "$b_rate"K "cleaned/$name.opus"
				ffmpeg -hide_banner -i "$1" -b:a "$b_rate"K -metadata:s:a:0 \
TITLE="$title" -metadata:s:a:0 ARTIST="$artist" -metadata:s:a:0 \
METADATA_BLOCK_PICTURE="`cat tmp/cover.b64`" -metadata:s:a:0 LANGUAGE="" \
"cleaned/$name.opus"
			else
            	ffmpeg -hide_banner -i "$1" -b:a "$b_rate"K -metadata:s:a:0 \
TITLE="$title" -metadata:s:a:0 ARTIST="$artist" -metadata:s:a:0 LANGUAGE="" \
"cleaned/$name.opus"
			fi
        fi
}
block_picture()
{
	mkdir -p tmp
	cover_img=$1
	image_width=$(identify -format %w "$cover_img");
	image_height=$(identify -format %h "$cover_img");
	image_depth=$(identify -format %z "$cover_img");
	image_size=$(stat --printf="%s" "$cover_img");
	# make frame header in hex 
	# https://xiph.org/flac/format.html#metadata_block_picture
	printf %08x 3 >> tmp/cover.hex # front cover
	# mime string
	if [[ "${cover_img##*.}" == "jpg" ]]; then
	    printf %08x 10 >> tmp/cover.hex
	    echo -n "image/jpeg" | xxd -p >> tmp/cover.hex
	elif [[ "${cover_img##*.}" == "png" ]]; then
	    printf %08x 9 >> tmp/cover.hex
	    echo -n "image/png" | xxd -p >> tmp/cover.hex
	else
	    echo "invalid image type, Exiting"
	    exit 1
	fi
	# description string
	printf %08x 13 >> tmp/cover.hex
	echo -n "Cover (front)" | xxd -p >> tmp/cover.hex
	printf %08x $image_width >> tmp/cover.hex
	printf %08x $image_height >> tmp/cover.hex
	printf %08x $image_depth >> tmp/cover.hex
	printf %08x 0 >> tmp/cover.hex #no color index
	printf %08x $image_size >> tmp/cover.hex
	# dump image to hex appending to the frame header
	xxd -p $cover_img >> tmp/cover.hex
	# convert back to binary
	xxd -p -r tmp/cover.hex > tmp/cover.bin
	# convert to base 64 for use in opus file
	base64 -w 0 < tmp/cover.bin > tmp/cover.b64
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
if test -n "$(shopt -s nullglob; echo *.flac)"; then
    for item in ./*.flac; do
        c2opus "$item"
    done
fi

# cleanup
if [ "$cover_img" != "0"  ]; then
	rm tmp/cover.hex
	rm tmp/cover.bin
	rm tmp/cover.b64
	#rm tmp/metadata.txt
	rmdir tmp
fi

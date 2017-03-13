#!/bin/bash

# Simple script for capturing screenshots and uploading them or another file
# to a simple file hosting site. imagemagick required
# you will need to edit to work with your site


folder=`dirname $0`
archive=$"$folder/archive"
# WARNING, deleting this file will cause the couter to reset and new 
# files to overwrite the old ones.
if [ ! -f $folder/counter.txt ]; then
	echo "0" > "$folder/counter.txt"
fi
count=`cat $folder/counter.txt`
file_name="SN$(printf %07d $count)"
# this mess will use imagemagik to add a timestamp to the image
timestamp()
{
	height=$(identify -format %h $file_path);
	width=$(identify -format %w $file_path);
	# readable text wont fit on something too small so skip
	if (($height <= 25 || $width <= 100)); then
		notify-send -t 4000 "Image to small for timestamp to be added."
	else
		# smaller images get a  smaller font to make things fit better
		if (($height <= 250 || $width <= 500 )); then
			pntsize=8
			ofst="+2+2"
			srkwdt=1
		else
			pntsize=12
			ofst="+4+4"
			srkwdt=2
		fi
		timestamp=$(date "+%Y-%m-%d %H:%M:%S")
		convert $file_path -gravity SouthEast -font Noto-Sans -pointsize \
		$pntsize -fill white -stroke black -strokewidth $srkwdt -annotate \
		$ofst "$timestamp" -stroke none -annotate $ofst "$timestamp" $file_path
	fi
}
copy=0
# parse the input
for i in "$@"; do
	case $i in
	   	-f=*|--file=*)
			file_path=`readlink -f "${i#*=}"`
	   	;;
	   	-a|--area)
	   		file_path="$archive/$file_name.png"
	   		import +repage $file_path
	   	;;
	   	-w|--window)
	   		file_path="$archive/$file_name.png"
	   		import -frame -screen -window $(xprop -root 32x '\t$0' _NET_ACTIVE_WINDOW | cut -f 2) +repage $file_path
	   	;;
	   	-x|--fullscreen)
	   		file_path="$archive/$file_name.png"
	   		import -window root +repage $file_path
	   	;;
		-t|--area-timestamp)
	   		file_path="$archive/$file_name.png"
	   		import +repage $file_path
			timestamp
	   	;;
		-g|--window-timestamp)
	   		file_path="$archive/$file_name.png"
	   		import -screen -window $(xprop -root 32x '\t$0' _NET_ACTIVE_WINDOW | cut -f 2) +repage $file_path
			timestamp
	   	;;
	   	# maybe sometime make clipboard data type automatically checked
	   	-c|--clipboard)
	   		file_path="$archive/$file_name.txt"
			xclip -selection clipboard -o > $file_path
		;;
	   	-z|--clipboard-image)
	   		file_path="$archive/$file_name.png"
			xclip -selection clipboard -t image/png -o > $file_path
		;;
		-p|--copy)
			copy=1
		;;
		*)
	   		echo "unknown argument : $i, Exiting."
			exit
	   	;;
	esac
done
# if no args default to area
if [ -z ${file_path+x} ]; then
	file_path="$archive/$file_name.png"
	import +repage $file_path
fi
# if no file screenshot was cancelled
if [ -e "$file_path" ]; then
	if [ $copy -eq 1 ]; then
    	tmpfile_name=$(basename "$file_path")
    	exten="${tmpfile_name##*.}"
    	new_path=$archive/$file_name.$exten
    	cp $file_path "$new_path"
    	file_path="$new_path"
	fi
	apikey=`cat $folder/apikey.txt`
	time_stamp=$(date "+%Y-%m-%d %H:%M:%S")
	((count++))
	echo $count > "$folder/counter.txt"
	notify-send -t 2000 "File is being uploaded..."
	# upload file to site and save response to file and grep url uploaded to
	response=$(curl -s -F "file2Upload=@$file_path" -F "apiKey=$apikey" \
	https://api.x88.moe/upload.php)
	# get just the url for the file
	url=`echo "$response" | grep -Po '(?<="url":").*?(?=")'`
	# save response so can find/delete it if wanted later.
	printf "\nFile: `readlink -f $file_path`, Time: $time_stamp, Response: $response " >> $folder/history.txt
	echo -n "$url" | xclip -i -selection c
	notify-send -t 4000 "File Uploaded to: $url and link copied to clipboard"
else
	notify-send -t 4000 "Screenshot Cancelled"
fi

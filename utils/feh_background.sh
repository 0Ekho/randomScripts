#!/bin/bash
set -euo pipefail
IFS=$'\n'
# sets random background with feh put in a cron for automatic changing
# this is for 4* monitors, will need to be adjusted for more / less
# backgrounds should be a \n delimited file containing the full paths to the 
# background images you want
# $find -type f /full/path/to/imgdir > backgrounds is a good way to generate it
# current should be made once with 4* image paths and a '0' (\n delimited)
location=`dirname $0`
if [ `cat $location/fb_stop` -eq "0" ]; then
	declare -a current
	declare -a bg_list
	current=( `cat "$location/current"` )
	bg_list=( `cat "$location/backgrounds"` )
	new_number=$(( $RANDOM % ${#bg_list[@]} ))
	current[${current[4]}]="${bg_list[$new_number]}"
	feh --bg-fill "${current[0]}" "${current[1]}" "${current[2]}" "${current[3]}"
	printf "${current[0]}\n${current[1]}\n${current[2]}\n${current[3]}\n\
$(( (${current[4]} + 1) % 4))" > "$location/current"
fi
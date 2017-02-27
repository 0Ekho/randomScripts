#!/bin/bash
set -euo pipefail
IFS=$'\n'
# sets a random background
# this is for 4* monitors, will need to be adjusted for more / less
# backgrounds should be a '\n' delimited file
# $find -type f /full/path/to/imgdir > backgrounds is a good way to generate it
location=`dirname $0`
if [ `cat $location/fb_stop` -eq "0" ]; then
	declare -a current
	declare -a bg_list
	current=( `cat "$location/current"` )
	bg_list=( `cat "$location/backgrounds"` )
	new_number=$(( $RANDOM % ${#bg_list[@]} ))
	current[${current[4]}]="${bg_list[$new_number]}"
	# feh option
	feh --bg-fill "${current[0]}" "${current[1]}" "${current[2]}" "${current[3]}"
	# switched to xfce and feh doesn't seem to work on 4.12
	#xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image -s "${current[0]}"
    #xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor1/workspace0/last-image -s "${current[1]}"
    #xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor2/workspace0/last-image -s "${current[2]}"
    #xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor3/workspace0/last-image -s "${current[3]}"
	printf "${current[0]}\n${current[1]}\n${current[2]}\n${current[3]}\n\
$(( (${current[4]} + 1) % 4))" > "$location/current"
fi
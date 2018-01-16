#!/bin/bash
# sets an area for wacom CTH-480

rand_area() {
    #aspect=$(( ($RANDOM % 40) + 160 ))
    aspect=178 # close to 16:9
    height=$(( ($RANDOM % 1000) + 4500 ))
    width=$(( ($height * $aspect) / 100 ))

    top=50
    bottom=$(( $height + 50 ))

    # center the area width on tablet
    #left=$(( (15200 - $width) / 2 ))
    #right=$(( 15200 - ((15200 - $width) / 2) ))

    # place on right side
    left=$(( 15100 - $width ))
    right=15100

    area="$left $top $right $bottom"
}

get=0

case "$1" in
    osu)
        area="6300 50 15100 4975"
        #area="3200 50 12000 4975"
        ;;
    osu_rand)
        rand_area
        ;;
    full)
        area="0 0 15200 9400"
        ;;
    get)
        get=1;
        ;;
    *)
        echo "unknown area option"
        exit 1
        ;;
esac

if [ "$get" -eq "0" ]; then
    xsetwacom -s set "Wacom Intuos PT S Pen stylus" Area $area
    xsetwacom -s set "Wacom Intuos PT S Pen eraser" Area $area
else
    area=`xsetwacom get "Wacom Intuos PT S Pen stylus" Area`
fi
notify-send -t 2000 "Area is set to: $area"

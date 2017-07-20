#!/bin/bash

# sets a (constrained) random area for my wacom CTH-480 small

# full_area="0 0 15200 9400"
# Get a number between 160 and 200 for the aspact ratio
aspect=$(( (RANDOM % 40) + 160 ))
# Get a number between 4500 and 5500 for the area height
height=$(( (RANDOM % 1000) + 4500 ))
# take the height and apply the aspect ratio to it to get the width
width=$(( (height * aspect) / 100 ))
# set the tablet area coordinates
top=50
bottom=$(( height + 50 ))
#center the area width on the tablet
left=$(( (15200 - width) / 2 ))
right=$(( 15200 - ((15200 - width) / 2) ))
area="$left $top $right $bottom"
xsetwacom -s set "Wacom Intuos PT S Pen stylus" Area "$area"
xsetwacom -s set "Wacom Intuos PT S Pen eraser" Area "$area"
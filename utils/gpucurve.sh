#!/bin/bash

nvidia-settings -a "[gpu:0]/GPUFanControlState=1"
# I hope this doesnt need comments explaining
while true
do
	gputemp=`nvidia-settings --query [gpu:0]/GPUCoreTemp -t`
	case "${gputemp}" in
		1[0-9])
			newfanspeed="15"
			;;
		2[0-9])
			newfanspeed="20"
			;;
		3[0-9])
			newfanspeed="25"
			;;
		4[0-3])
			newfanspeed="30"
			;;
		4[4-6])
			newfanspeed="35"
			;;
		4[7-9])
			newfanspeed="38"
			;;
		5[0-3])
			newfanspeed="40"
			;;
		5[4-5])
			newfanspeed="42"
			;;
		5[6-7])
			newfanspeed="45"
			;;
		5[8-9])
			newfanspeed="50"
			;;
		6[0-4])
			newfanspeed="53"
			;;
		6[5-9])
			newfanspeed="57"
			;;
		7[0-4])
			newfanspeed="60"
			;;
		7[5-9])
			newfanspeed="65"
			;;
		8[0-9])
			newfanspeed="80"
			;;
		9[0-9])
			newfanspeed="90"
			;;
		*)
			newfanspeed="95"
			# sounds like computer will fly away :)
			;;
	esac
	nvidia-settings -a [fan:0]/GPUTargetFanSpeed=$newfanspeed
	sleep 5s
done
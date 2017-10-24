#!/usr/bin/env bash

# Generate timelapse videos from videos in subfolders
# Videos in subfolders must be named in correct order
# Final video will be named as subfolder + video extension (e.g. mkv)

Extension="mkv"

function generateStills() {

    thisDIR="$1"

    typeset -i NUM
    NUM=0

    # for prefixing the running number with zeroes
    zeroes="000000000"

    # generate stills
    find "${thisDIR}" \( -type f -o -type l \) | egrep -i "(mp4|m4v|mkv|mpg)$" | sort | while read X
    do
        pad="${zeroes}${NUM}"
        ffmpeg -i "${X}" -r 1 -f image2 -vsync cfr "${thisDIR}.ffmpeg_temp"/${pad:(-9)}%05d.png
        (( NUM = NUM + 1 ))
    done

}

function End() {
    RC=$1
    if [ "${ENDmsg}" != "" ]
    then
        echo -e "${ENDmsg}"
    fi
    if [ "${RC}" != "" ]
    then
        exit ${RC}
    else
        exit 0
    fi
}

trap End EXIT

ENDmsg=""

for DIR in *
do

    [ -d "${DIR}" ] || continue
    [ -e "${DIR}.${Extension}" ] && continue
    [ "${DIR##*.}" == "ffmpeg_temp" ] && continue

    if [ -e "${DIR}.ffmpeg_temp" ]
    then
        if [ -d "${DIR}.ffmpeg_temp" ]
        then
            rm -rf "${DIR}.ffmpeg_temp"/*
            rm -rf "${DIR}.ffmpeg_temp"/.*
            true
        else
            echo "Temp folder exists but is no directory"
            End 1
        fi
    else
        mkdir "${DIR}.ffmpeg_temp"
        generateStills "${DIR}"
    fi

    if [ ! -e "${DIR}".${Extension} ]
    then
        ffmpeg -pattern_type glob -i "${DIR}.ffmpeg_temp"'/*.png' -c:v libx265 -crf 26 -pix_fmt yuv420p "${DIR}".${Extension}

        if [ $? -eq 0 ]
        then
            if [ -d "${DIR}.ffmpeg_temp" ]
            then
                rm -rf "${DIR}.ffmpeg_temp"
            fi
        else
            echo "Video generation generated an error ..."
            End 2
        fi
    else
        ENDmsg="${ENDmsg}Video ${DIR}.${Extension} already available. To regenerate, delete it first.\n"
    fi

done

exit 0

#!/usr/bin/env bash

# Generate timelapse videos from videos in subfolders
# Videos in subfolders must be named in correct order
# Final video will be named as subfolder + video extension (e.g. mkv)

Extension="mkv"

function generateStills() {

    thisDIR="$1"

    typeset -i NUM
    NUM=0

    zeroes="000000000"

    # generate stills
    for X in "${thisDIR}"/*.{mp4,m4v,mkv}
    do
        pad="${zeroes}${NUM}"
        ffmpeg -i "${X}" -r 1 -f image2 -vsync cfr "${DIR}.ffmpeg_temp"/${pad:(-9)}%05d.png
        #ffmpeg -i "${X}" -vf "select=eq(pict_type\,I)" -vsync cfr "${DIR}.ffmpeg_temp"/${pad:(-9)}%05d.png
        #ffmpeg -i "${X}" -vf "select=eq(pict_type\,I)" -vsync vfr -vf "drawtext=fontfile=/Library/Fonts/Tahoma.ttf: timecode='00\:00\:00\:00': r=25: x=(w-tw)/2: y=h-(2*lh): fontcolor=white: box=1: boxcolor=0x00000000@1" "${DIR}.ffmpeg_temp"/${pad:(-9)}%05d.png
        #ffmpeg -i "${X}" -vf "select=eq(pict_type\,I)" -vsync vfr -vf "drawtext=fontfile=/Library/Fonts/Tahoma.ttf :expansion=normal: text=%{metadata\\\\:creation_time}: \ x=(w-tw)/2: y=h-(2*lh): fontcolor=white@0.8" "${DIR}.ffmpeg_temp"/${pad:(-9)}%05d.png
        #ffmpeg -i "${X}" -vf "select=eq(pict_type\,I)" -vsync vfr -strftime 1 "%Y-%m-%d_%H-%M-%S.png"
        #ffmpeg -i "${X}" -r 1 -f image2 -vsync cfr -vf "drawtext='fontfile=/Library/Fonts/Tahoma.ttf': text='%{metadata\: creation_time}': x=10: y=10: fontcolor=white@0.5: box=1: boxcolor=0x00000000@0.5" "${DIR}.ffmpeg_temp"/${pad:(-9)}%05d.png
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

    #ffmpeg -i ffmpeg_temp/%014d.png -q:v 0 test.${Extension}
    #ffmpeg -f image2 -r 25 -i ffmpeg_temp/%014d.png -vcodec libx264 -crf 22 test.${Extension}
    #ffmpeg -i ffmpeg_temp/%014d.png -framerate 25 -pix_fmt yuv420p -q:v 0 test.${Extension}
    if [ ! -e "${DIR}".${Extension} ]
    then
        ffmpeg -pattern_type glob -i "${DIR}.ffmpeg_temp"'/*.png' -c:v libx264 "${DIR}".${Extension}

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

#ffmpeg -y -i S1480002.MP4 -vf "drawtext=fontfile=arial.ttf :expansion=normal: text=%{metadata\\:creation_time}: \ x=(w-tw)/2: y=h-(2*lh): fontcolor=white@0.8" output.mp4

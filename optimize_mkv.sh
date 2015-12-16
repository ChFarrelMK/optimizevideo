#!/bin/bash
##########################################################################
#    optimize_mkv.sh
#    Copyright (C) 2015  Andreas Wenzel (https://github.com/awenny)
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
##########################################################################

#
# Look for files with "mkv" extension in current folder
# use ffmpeg to convert it into a more optimized (H264) codec
# All audio tracks are copied as they are
# only video will be optimized
#

# set defaults
[ "${CRF}" = "" ] && CRF="20"
[ "${VCODEC}" = "" ] && VCODEC="libx265"

# who am I
myself1=${0##*/}
myself=${myself1%.*}

declare -a FILES

if [ "$1" != "" ]
then
    i=1
    while [ "${1}" != "" ]
    do
        X="${1}"
        shift
        if [[ -e "${X}" && -s "${X}" && -r "${X}" ]]
        then
            FILES[$i]="${X}"
            (( i = i + 1 ))
        fi
    done
else
    i=1
    for X in *.mkv
    do
        if [[ -e "${X}" && -s "${X}" && -r "${X}" ]]
        then
            FILES[$i]="${X}"
            (( i = i + 1 ))
        fi
    done
fi

function renameFile {
    chmod 664 "${workFILE}"
    chgrp users "${workFILE}"

    mv "${FILE}" "${oriFILE}"
    mv "${workFILE}" "${newFILE}"
}

function LogMessage {
    TS=""
    if [ "$1" = "TS" ]
    then
        TS=$(date +"%Y-%m-%d %H:%M:%S")
        echo -n "[${TS}] "
    fi

    NL=""
    Postfix=""

    if [ "$2" = "NL" ]
    then
        NL=""
    elif [ "$2" = "NoNL" ]
    then
        NL="-n"
        Postfix="... "
    fi

    if [ "$3" != "" ]
    then
        echo ${NL} "$3" "${Postfix}"
    fi
}

echo "Found following files to process:"
printf '    %s\n' "${FILES[@]}"

Errors=0

for FILE in "${FILES[@]}"
do

    if [ -e STOP ]
    then
        LogMessage TS NL "Stopped on user request"
        rm STOP
        break
    elif [ -e PAUSE ]
    then
        LogMessage TS NL "Pause on user request"
        while [ -e PAUSE ]
        do
            sleep 60
        done
        LogMessage TS NL "Resume on user request"
    fi

    LogMessage TS NoNL "${FILE}"

    Ext=${FILE##*.}
    workFILE="${FILE%.${Ext}}.${VCODEC}.mkv"
    oriFILE="${FILE%.${Ext}}.ori.${Ext}"
    newFILE="${FILE%.${Ext}}.mkv"

    if [ -e "${workFILE}" ] || [ -e "${oriFILE}" ]
    then
        LogMessage NoTS NL "file exists. Skipping it"
        continue
    fi

    # read existing config file for current folder
    if [ -e .${myself}.conf ]
    then
        . .${myself}.conf
    fi

    # set parameters
    argCODEC=" -c:v ${VCODEC}"
    argCRF=" -crf ${CRF}"

    echo "Command: ffmpeg -i "${FILE}" -map 0 ${argCRF} ${argCODEC} -c:a copy "${workFILE}" >"${workFILE%.*}.log" 2>&1" >"${workFILE%.*}.log"
    ffmpeg -i "${FILE}" -map 0 ${argCRF} ${argCODEC} -c:a copy "${workFILE}" >>"${workFILE%.*}.log" 2>&1

    if [ $? -eq 0 ]
    then

        LogMessage NoTS NL "done"

        renameFile

    else
        if [ $(grep -c "^Subtitle encoding failed" "${workFILE%.*}.log") -eq 1 ]
        then
            LogMessage NoTS NoNL "error with subtitle, trying without"
            echo "Command: ffmpeg -i "${FILE}" -map 0 ${argCRF} ${argCODEC} -c:a copy -sn "${workFILE}" >"${workFILE%.*}.log" 2>&1" >>"${workFILE%.*}.log"
            rm -f "${workFILE}" >/dev/null 2>&1
            ffmpeg -i "${FILE}" -map 0 ${argCRF} ${argCODEC} -c:a copy -sn "${workFILE}" >>"${workFILE%.*}.log" 2>&1
            if [ $? -eq 0 ]
            then
                LogMessage NoTS NL " done"
                renameFile
            fi
        else
            LogMessage NoTS NL "fail"
            (( Errors = Errors + 1))
        fi
    fi

done

if [ ${Errors} -gt 0 ]
then
    LogMessage TS NL "Finished with ${Errors} errors"
else
    LogMessage TS NL "Finished"
fi

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
[ "${CRF}" = "" ] && defaultCRF="20"
[ "${VCODEC}" = "" ] && defaultVCODEC="libx265"

# who am I
myself1=${0##*/}
myself=${myself1%.*}

declare -a FILES

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

function optimizeSize {
    value=$1
    if [ ${value} -lt 1024 ]
    then
        ret="${value}b"
    elif [ ${value} -lt 1048576 ]
    then
        (( re = value / 1024 ))
        ret="${re}k"
    elif [ ${value} -lt 1073741824 ]
    then
        (( re = value / 1024 / 1024 ))
        ret="${re}m"
    elif [ ${value} -lt 1099511627776 ]
    then
        (( re = value / 1024 / 1024 / 1024 ))
        ret="${re}g"
    elif [ ${value} -lt 1125899906842624 ]
    then
        (( re = value / 1024 / 1024 / 1024 / 1024 ))
        ret="${re}t"
    elif [ ${value} -lt 1152921504606846976 ]
    then
        (( re = value / 1024 / 1024 / 1024 / 1024 / 1024 ))
        ret="${re}p"
    elif [ ${value} -lt 1180591620717411303424 ]
    then
        (( re = value / 1024 / 1024 / 1024 / 1024 / 1024 / 1024 ))
        ret="${re}e"
    fi

    echo $ret
}

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
            siz=$(stat -c%s "${X}")
            SIZE[$i]=$siz
            syz=$(optimizeSize $siz)
            FILESTATUS[$i]="${X} [${syz}]"
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
            siz=$(stat -c%s "${X}")
            SIZE[$i]=$siz
            syz=$(optimizeSize $siz)
            FILESTATUS[$i]="${X} [${syz}]"
            (( i = i + 1 ))
        fi
    done
fi

echo "Found following files to process:"
printf '    %s\n' "${FILESTATUS[@]}"

Errors=0
Skipped=0

for (( i=1; i<=${#FILES[@]}; i++ ))
do

    FILE=${FILES[$i]}

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

    # read existing config file for current folder or look in upper folders
    myDIR="${PWD}"
    while [ "${myDIR}" != "" ]
    do
        if [ -e "${myDIR}/.${myself}.conf" ]
        then
            . "${myDIR}/.${myself}.conf"
            break
        else
            myDIR=${myDIR%/*}
        fi
    done

    if [ "${myDIR}" == "" ]
    then
        # set default parameters
        VCODEC="${defaultVCODEC}"
        CRF="${defaultCRF}"
    fi

    # set argument here
    argCODEC=" -c:v ${VCODEC}"
    argCRF=" -crf ${CRF}"

    Ext=${FILE##*.}
    workFILE="${FILE%.${Ext}}.${VCODEC}.${CRF}.mkv"
    oriFILE="${FILE%.${Ext}}.ori.${Ext}"
    newFILE="${FILE%.${Ext}}.mkv"

    # Check if file has been already processed
    x="${FILE%.${Ext}}"
    if [ "${x%.ori}" != "${x}" ]
    then
        LogMessage NoTS NL "file already processed. Skipping it"
        (( Skipped = Skipped + 1 ))
        continue
    fi

    if [ -e "${workFILE}" ] || [ -e "${oriFILE}" ]
    then
        LogMessage NoTS NL "file exists. Skipping it"
        (( Skipped = Skipped + 1 ))
        continue
    fi

    echo "Command: ffmpeg -i "${FILE}" -map 0 ${argCRF} ${argCODEC} -c:a copy "${workFILE}" >"${workFILE%.*}.log" 2>&1" >"${workFILE%.*}.log"
    ffmpeg -i "${FILE}" -map 0 ${argCRF} ${argCODEC} -c:a copy "${workFILE}" >>"${workFILE%.*}.log" 2>&1

    if [ $? -eq 0 ]
    then

        siz=$(stat -c%s "${workFILE}")
        Factor=$(echo "scale=1; ${SIZE[$i]}/${siz}" | bc -l)

        LogMessage NoTS NL "done [${Factor}x]"

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
                siz=$(stat -c%s "${workFILE}")
                Factor=$(echo "scale=1; ${SIZE[$i]}/${siz}" | bc -l)
        
                LogMessage NoTS NL "done [${Factor}x]"

                renameFile
            fi
        else
            LogMessage NoTS NL "fail"
            (( Errors = Errors + 1))
        fi
    fi

done

if [[ ${Errors} -gt 0 && ${Skipped} -gt 0 ]]
then
    LogMessage TS NL "Finished with ${Errors} errors and ${Skipped} skipped"
elif [ ${Skipped} -gt 0 ]
then
    LogMessage TS NL "Finished with ${Skipped} skipped"
else
    LogMessage TS NL "Finished"
fi

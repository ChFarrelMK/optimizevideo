#!/bin/bash
##########################################################################
#    optimize_videos.sh
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

CRF=23
VCODEC=h264

# set default values
if [ "${CRF}" = "" ]
then
	argCRF=" -crf 23"
else
	argCRF=" -crf ${CRF}"
fi

# set default values
if [ "${VCODEC}" = "" ]
then
    argCODEC=" -c:v h264"
else
    argCODEC=" -c:v ${CODEC}"
fi

if [ "$1" != "" ]
then
    mask="$1"
else
    mask=""
fi


for FILE in ${mask}*.mkv
do

    TS=$(date +"%Y-%m-%d %H:%M:%S")

    echo -n "[${TS}] ${FILE} ..."
    newFILE="${FILE%.mkv}.x264.mkv"
    oriFILE="${FILE}.ori"

    # keep some backups
    [ -e "${newFILE}.new2" ] && rm -f "${newFILE}.new2"
    [ -e "${newFILE}.new1" ] && mv "${newFILE}1" "${newFILE}.new2"
    [ -e "${newFILE}.new" ]  && mv "${newFILE}"  "${newFILE}.new1"

    ffmpeg -i "${FILE}" -map 0 ${argCRF} ${argCODEC} -c:a copy "${newFILE}" >/dev/null 2>&1

    if [ $? -eq 0 ]
    then
        echo " done"

        # keep some backups
        [ -e "${oriFILE}2" ] && rm -f "${oriFILE}2"
        [ -e "${oriFILE}1" ] &&	mv "${oriFILE}1" "${oriFILE}2"
        [ -e "${oriFILE}"  ] && mv "${oriFILE}"  "${oriFILE}1"

        mv "${FILE}" "${oriFILE}"
        mv "${newFILE}" "${FILE}"
    else
        echo " fail"
        exit 1
    fi

done

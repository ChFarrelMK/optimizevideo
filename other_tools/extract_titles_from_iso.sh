#!/bin/bash
##########################################################################
#    extract_titles_from_iso.sh
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
# Scan current folder for ISO files and extract titles into separate h264/mkv files
#

CONTAINER="mp4"
FORMAT="x264"

for ISO in *.[Ii][Ss][Oo]
do
    TITLES=$(HandBrakeCLI -i "${ISO}" -t 0 2>&1 | awk '/scan: DVD has [0-9]+ title/ {print $5}')
    for (( TITLE=1; TITLE <= TITLES; TITLE++ ))
    do
        if [ ! -e "${ISO%.*}_${TITLE}.mp4" ]
        then
            HandBrakeCLI -i "${ISO}" \
                         -o "${ISO%.*}_${TITLE}.${CONTAINER}" \
                         -t ${TITLE} \
                         -m \
                         -e ${FORMAT} \
                         -q 20.0 \
                         -B 160,160 \
                         -6 dpl2,auto \
                         -R Auto,Auto \
                         -D 0.0,0.0 \
                         -a 2,1 \
                         -E "copy:*" \
                         --audio-copy-mask aac,ac3,dtshd,dts,mp3 \
                         --audio-fallback ffac3 \
                         -f ${CONTAINER} \
                         -4 \
                         --decomb \
                         --loose-anamorphic \
                         --modulus 2 \
                         --x264-preset medium \
                         --h264-profile high \
                         --h264-level 4.1 2>&1 | tee "${ISO%.*}_${TITLE}.log"
            if [ ${PIPESTATUS[0]} -eq 0 ]
            then
                echo "File ${ISO%.*}_${TITLE}.mp4 successfully generated" >>all.${PID}.log
            else
                echo "File ${ISO%.*}_${TITLE}.mp4 error. Look at (${ISO%.*}_${TITLE}.log)" >>all.${PID}.log
            fi
        fi
    done
done

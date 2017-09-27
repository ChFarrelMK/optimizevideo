#!/bin/bash
##########################################################################
#    extract_titles_from_vobs.sh
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
# Scan current folder for VIDEO_TS folders and extract titles into separate video files
#

CONTAINER="mkv"
CONTAINER_EXT="mkv"
FORMAT="x265"
LANGUAGES="eng,deu"

for BASEDIR in *
do
    if [ ! -d "${BASEDIR}/VIDEO_TS" ]
    then
        continue
    fi

    TITLES=$(HandBrakeCLI -i "${BASEDIR}"/[Vv][Ii][Dd][Ee][Oo]_[Tt][Ss] -t 0 2>&1 | awk '/scan: DVD has [0-9]+ title/ {print $5}')
    for (( TITLE=1; TITLE <= TITLES; TITLE++ ))
    do
        if [ ! -e "${BASEDIR%.*}_${TITLE}.${CONTAINER_EXT}" ]
        then
            HandBrakeCLI -i "${BASEDIR}/VIDEO_TS" \
                         -o "${BASEDIR%.*}_${TITLE}.${CONTAINER_EXT}" \
                         -t ${TITLE} \
                         -m \
                         -e ${FORMAT} \
                         -q 22.0 \
                         -E "copy" \
                         --audio-lang-list "${LANGUAGES}" \
                         --all-audio \
                         --subtitle-lang-list "${LANGUAGES}" \
                         --all-subtitles \
                         -f ${CONTAINER} \
                         --decomb \
                         --loose-anamorphic \
                         --modulus 2 \
                         2>&1 | tee "${BASEDIR%.*}_${TITLE}.log"
            if [ ${PIPESTATUS[0]} -eq 0 ]
            then
                echo "File ${BASEDIR%.*}_${TITLE}.${CONTAINER_EXT} successfully generated" >>all.${PPID}.log
            else
                [ -e "${BASEDIR%.*}_${TITLE}.${CONTAINER_EXT}" ] && rm "${BASEDIR%.*}_${TITLE}.${CONTAINER_EXT}"
                echo "File ${BASEDIR%.*}_${TITLE}.${CONTAINER_EXT} error. Look at (${BASEDIR%.*}_${TITLE}.log)" >>all.${PPID}.log
            fi
        fi
        exit
    done
done


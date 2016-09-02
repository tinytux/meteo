#!/bin/bash
echo "Meteo Script"

CONFIG="/vagrant/config/server.inc"
if [[ ! -e ${CONFIG} ]]; then
    CONFIG="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../config/server.inc"
    if [[ ! -e ${CONFIG} ]]; then
        echo "Can not find config file: ${CONFIG}"
    fi
fi
source ${CONFIG}

if [[ -z ${ZIP_CODE} ]]; then
    echo "ZIP_CODE not defined. Check the configuration file:"
    echo "  ${CONFIG}"
    exit 1
fi

LOCATION="${ZIP_CODE}"
OUTPUT_FILE="meteo-${LOCATION}.png"

# 1440 x 2560 pixels => 720x...
echo "Downloading meteo image..."
wget -q --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 10 --no-dns-cache -O - "http://meteo.search.ch/images/chart/${LOCATION}.png?show=time&lang=de&width=380&height=180" >today.png
RETCODE=$?
if [[ ${RETCODE} -ne 0 ]]; then
    echo "Download failed: ${RETCODE}"
    exit ${RETCODE}
fi

if [[ "$(pgrep -c cutycapt)" -gt 0 ]]; then 
    echo "Hanging process detected. Killing..."
    killall -9 cutycapt
fi

if [[ "$(hostname)" == "apu" ]] || [[ -f /.dockerinit ]]; then
    xvfb-run --server-args="-screen 0, 1024x768x24" cutycapt --url=http://meteo.search.ch/nidau.de.html --user-agent='Mozilla/5.0 (Android; Mobile; rv:26.0) Gecko/26.0 Firefox/26.0' --out=days.png
else
    cutycapt --url=http://meteo.search.ch/${LOCATION}.de.html --user-agent='Mozilla/5.0 (Android; Mobile; rv:26.0) Gecko/26.0 Firefox/26.0' --out=days.png
fi

function day_mini() {
    convert day_${1}.png +repage -crop 139x139+6+22 -resize x65  day_${1}_icon_mini_tmp.png   # 65x65
    montage day_${1}_icon_mini_tmp.png -geometry 65x65+12+0      day_${1}_icon_mini.png       # 65x65
    convert day_${1}.png +repage -crop 25x18+0+2                 day_${1}_title.png           # 25x18
    convert day_${1}.png +repage -crop 30x22+0+168               day_${1}_min.png             # 30x23
    convert day_${1}.png +repage -crop 32x22+116+168             day_${1}_max.png             # 32x23

    convert day_${1}_title.png day_${1}_min.png day_${1}_max.png +append day_${1}_min_max.png              # 87x23

    montage day_${1}_icon_mini.png day_${1}_min_max.png -mode Concatenate -tile 1x4 day_${1}_mini.png      # 87 x 108
    rm -f day_${1}_icon_mini.png day_${1}_title.png day_${1}_min.png day_${1}_max.png day_${1}_min_max.png
}

DAY_HEIGHT=184
DAY_WIDTH=150
DAYS_Y_OFFSET=693
DAYS_X_OFFSET=12
DAYS_SPACE=6

convert days.png  +repage -crop ${DAY_WIDTH}x${DAY_HEIGHT}+$(awk "BEGIN {print ($DAYS_X_OFFSET + 1 * ($DAY_WIDTH + $DAYS_SPACE)); exit}")+${DAYS_Y_OFFSET} day_1.png
day_mini 1

convert days.png  +repage -crop ${DAY_WIDTH}x${DAY_HEIGHT}+$(awk "BEGIN {print ($DAYS_X_OFFSET + 2 * ($DAY_WIDTH + $DAYS_SPACE)); exit}")+${DAYS_Y_OFFSET} day_2.png
day_mini 2

convert days.png  +repage -crop ${DAY_WIDTH}x${DAY_HEIGHT}+$(awk "BEGIN {print ($DAYS_X_OFFSET + 3 * ($DAY_WIDTH + $DAYS_SPACE)); exit}")+${DAYS_Y_OFFSET} day_3.png
day_mini 3

convert days.png  +repage -crop ${DAY_WIDTH}x${DAY_HEIGHT}+$(awk "BEGIN {print ($DAYS_X_OFFSET + 4 * ($DAY_WIDTH + $DAYS_SPACE)); exit}")+${DAYS_Y_OFFSET} day_4.png
day_mini 4

montage day_1_mini.png day_2_mini.png day_3_mini.png day_4_mini.png -mode Concatenate -tile 2x4 day_1_2_3_4_mini.png # 174 x 216

convert today.png day_1_2_3_4_mini.png +append -background white -alpha remove week.png

convert week.png -font Liberation-Sans -pointsize 28 -fill white -annotate +15+35 "$(date +"%H:%M")" -gravity West -crop +0+8 -gravity East -crop +6 ${OUTPUT_FILE}

rm day*.png today.png week.png
#cp *.png /vagrant/

if [[ ! -e ${OUTPUT_FILE} ]]; then
    echo "File ${OUTPUT_FILE} not found, can not upload!"
else
    if [[ -z ${SCP_HOST} ]]; then
        echo "SCP_HOST not defined, can not upload. Check the configuration file:"
        echo "  ${CONFIG}"
        exit 1
    else
        echo "Uploading ${OUTPUT_FILE} to ${SCP_USER}@${SCP_HOST}:${SCP_PATH}..."
        scp ${OUTPUT_FILE} ${SCP_USER}@${SCP_HOST}:${SCP_PATH}
    fi
fi


#!/bin/bash

res=$(tput sgr 0)
red=$(tput setaf 1)
grn=$(tput setaf 2)
ylw=$(tput setaf 3)
blu=$(tput setaf 4)
pur=$(tput setaf 5)
cyn=$(tput setaf 6)

INFO="[ ${blu}INFO${res} ]"
SUCC="[ ${grn}SUCC${res} ]"
FAIL="[ ${red}FAIL${res} ]"

LOADING=("[      ]" \
         "[${ylw}=     ${res}]" \
         "[${ylw}==    ${res}]" \
         "[${ylw}===   ${res}]" \
         "[${ylw} ===  ${res}]" \
         "[${ylw}  === ${res}]" \
         "[${ylw}   ===${res}]" \
         "[${ylw}    ==${res}]" \
         "[${ylw}     =${res}]")

confirm() {

    sleepy_echo
    read -p "         Do you want to continue? " -r
    [[ ! $REPLY =~ ^(y|Y|yes|Yes)$ ]] && echo && exit 0
    sleepy_echo

}

slow_echo() {

    text="$1"

    for ((i=0; i<${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep 0.001
    done
    echo

}

sleepy_echo() {

    echo -e "$1"
    sleep 0.01

}

check_file_argument() {

    if [ -z $2 ]
    then
        slow_echo "$FAIL Missing parameter: ${ylw}${1}${res}"
        exit 1
    else
        if [ ! -f $2 ]
        then
            slow_echo "$FAIL File does not exist: ${ylw}${2}${res}"
            exit 1
        fi
    fi

}

write_to_cartridge() {

    slow_echo "$INFO Going to write ${ylw}${1}${res} to ${ylw}/dev/${DEVICE}${res}"
    confirm

    dd if=$1 of=/dev/${DEVICE} bs=512 seek=$2 conv=fdatasync &> /dev/null &
    pid=$!

    while kill -0 $! &> /dev/null
    do
        loading "Writing..."
    done

    wait $pid

    if [ $? -eq 0 ]
    then
        printf "\r%s" "$SUCC Writing finished successfully"
    else
        printf "\r%s" "$FAIL Writing failed"
    fi
    echo

}

copy_from_cartridge() {

    file=$(ls ${MOUNT_POINT} 2>/dev/null | grep -E $1 | head -1)

    if [ -z "$2" ]
    then
        destination="./"
        destination_message="current working directory"
        filename="$(date +"%Y-%m-%d-%H%M%S")-${file}"
    else
        destination=$2
        destination_message="${ylw}${2}${res}"
    fi

    if [ -z "$file" ]
    then
        slow_echo "$FAIL No such file found in: ${ylw}${MOUNT_POINT}/$file${res}"
        exit 1
    fi

    cp ${MOUNT_POINT}/${file} ${destination}${filename} &> /dev/null &
    pid=$!

    while kill -0 $! &> /dev/null
    do
        loading "Copying..."
    done

    wait $pid

    if [ $? -eq 0 ]
    then
        printf "\r%s" "$SUCC Save file ${ylw}${file}${res} copied to ${destination_message}"
    else
        printf "\r%s" "$FAIL Could not copy ${ylw}${file}${res}"
    fi
    echo
}

copy_photos_from_cartridge() {

    if [ -z "$1" ]
    then
        destination="./"
        destination_message="current working directory"
    else
        destination=$(echo "$1" | sed 's![^/]$!&/!')
        destination_message="${ylw}${1}${res}"
    fi

    if [ ! -d $1 ]
    then
        slow_echo "$FAIL Destination directory ${ylw}${destination}${res} not exist"
        exit 1
    fi

    blank_photo_md5="4cba8627f35c85b1dc4353d1e1ac9268"
    all_photos=$(ls -l ${MOUNT_POINT} 2> /dev/null | grep -E '*.bmp' | awk '{ print $NF }')

    i=1
    for photo in $all_photos
    do
        frame=${LOADING[$i]}
        printf "\r%s" "$frame Checking photos on cartridge..."
        photo_md5=$(md5sum ${MOUNT_POINT}/${photo} 2> /dev/null | awk '{ print $1 }')
        if [ "$photo_md5" != "$blank_photo_md5" ]
        then
            md5_list=$(echo -e "$md5_list"; echo -e "$photo_md5 $photo")
        fi
        ((i=i+1))
        [ $i -eq 9 ] && i=0
    done

    all_photos=$(echo -e "$md5_list" | sed "/^$/d")
    total_count=$(echo -e "$all_photos" | wc -l)

    if [ -z "$all_photos" ]
    then
        printf "\r%s" "$FAIL No photos found"
        echo
        exit 1
    fi

    printf "\r%s" "$SUCC ${ylw}$total_count${res} photo(s) found on cartridge"
    echo

    i=1
    duplicates=0
    for photo in $(ls -l "$destination" 2> /dev/null | grep -E '*.bmp' | awk '{ print $NF }')
    do
        frame=${LOADING[$i]}
        printf "\r%s" "$frame Checking for duplicates in $destination_message..."
        photo_md5=$(md5sum ${destination}${photo} 2> /dev/null | awk '{ print $1 }')
        if echo -e "$all_photos" | grep -q "$photo_md5"
        then
            ((duplicates=duplicates+1))
            all_photos=$(echo -e "$all_photos" | sed "/^$photo_md5.*$/d" 2>/dev/null)
        fi
        ((i=i+1))
        [ $i -eq 9 ] && i=0
    done

    all_photos=$(echo -e "$all_photos" | sed "/^$/d")

    if [ -z "$all_photos" ]
    then
        printf "\r%s" "$INFO All photos already present in $destination_message"
        echo
        exit 0
    fi

    if [ $duplicates -gt 0 ]
    then
        printf "\r%s" "$INFO Skipping ${ylw}${duplicates}${res} photo(s) as they are already present in $destination_message"
        echo
        exit 0
    fi

    count=1
    i=1
    failed=0

    for photo in $(echo -e "$all_photos" | awk '{ print $2 }')
    do
        frame=${LOADING[$i]}
        printf "\r%s" "$frame Copying... ($count/$total_count)"

        if ! cp ${MOUNT_POINT}/${photo} ${destination}$(date +"%Y-%m-%d-%H%M%S")-${photo} &> /dev/null
        then
            ((failed=failed+1))
        fi

        ((count=count+1))
        ((i=i+1))
        [ $i -eq 9 ] && i=0

        sleep 0.02

    done

    if [ $failed -gt 0 ]
    then
        printf "\r%s" "$FAIL Failed to copy $failed photo(s)"
        echo
        exit 1
    else
        printf "\r%s" "$SUCC Photos copied to ${destination_message}"
        echo
    fi

}

read_debug_file() {

    if [ ! -f "$DEBUG_FILE" ]
    then
        slow_echo "$FAIL File does not exist: ${ylw}${DEBUG_FILE}${res}"
        exit 1
    fi

    content=$(echo -e "$DEBUG_CONTENT" | sed '/^\s*$/d' | sed 's/^/         /')

    slow_echo "$INFO Content of ${ylw}DEBUG.TXT${res}"
    sleepy_echo
    while IFS= read -r line; do
        echo "$line"
        sleep 0.01
    done <<< $content
    echo

}

set-mode() {

    new_mode=$(echo $1 | tr 'a-z' 'A-Z')

    if [ "$2" != "force" ]
    then
        if [ -z "$new_mode" ]
        then
            slow_echo "$FAIL Missing parameter: ${ylw}<MODE>${res}"
            exit 1
        fi

        if [[ ! $new_mode =~ ^(UPDATE|AUTO|CAM|GBC|GBA|MGBA[0-7]|MULTI[1-4]|ECSD|CPLD|NPC|FCE[10])$ ]]
        then
            slow_echo "$FAIL Unknown mode: ${ylw}${new_mode}${res}, following modes are supported:"
            sleepy_echo
            sleepy_echo "           ${ylw}UPDATE           ${res}"
            sleepy_echo "           ${ylw}AUTO             ${res}"
            sleepy_echo "           ${ylw}GBC              ${res}"
            sleepy_echo "           ${ylw}GBA              ${res}"
            sleepy_echo "           ${ylw}MGBA${cyn}[0-7]  ${res}"
            sleepy_echo "           ${ylw}MULTI${cyn}[1-4] ${res}"
            sleepy_echo "           ${ylw}ECSD             ${res}"
            sleepy_echo "           ${ylw}CPLD             ${res}"
            sleepy_echo "           ${ylw}NPC              ${res}"
            sleepy_echo "           ${ylw}FCE${cyn}[10]    ${res}"
            sleepy_echo "           ${ylw}CAM              ${res}"
            sleepy_echo

            exit 1
        fi

        get_joey_info

        if [ "$mode" = "$new_mode" ]
        then
            slow_echo "$INFO Current mode is already set to: ${ylw}${mode}${res}"
            exit 0
        fi
    fi

    echo -n "$new_mode" > /tmp/mode.tmp
    remaining_bytes=$((512 - $(stat -c %s "/tmp/mode.tmp")))
    dd if=/dev/zero bs=1 count="$remaining_bytes" >> /tmp/mode.tmp 2>/dev/null
    dd if=/tmp/mode.tmp of=/dev/${DEVICE} bs=512 seek=66725 conv=fdatasync &> /dev/null &

    pid=$!

    while kill -0 $! &> /dev/null
    do
        loading "Setting mode to: ${ylw}${new_mode}${res}"
    done

    wait $pid
    printf "\r%s" "$INFO Finished setting mode to: ${ylw}${new_mode}${res}"
    echo

    rm -f /tmp/mode.tmp

    if [ "$2" != "force" ]
    then
        wait_for_joey
        sleep 1
        get_joey_info

        if [ "$mode" = "$new_mode" ]
        then
            slow_echo "$SUCC Mode set to: ${ylw}${new_mode}${res}"
        else
            slow_echo "$FAIL Could not set mode to: ${ylw}${new_mode}${res}"
        fi
    fi

}

loading() {

    for frame in "${LOADING[@]}"
    do
        if [ -z "$2" ]
        then
            printf "\r%s" "$frame $1"
        else
            printf "\r%s" "$frame $1 ($2/$3)"
        fi
        sleep 0.1
    done

}

update-firmware() {

    check_file_argument "<FIRMWARE_FILE>" "$1"
    set-mode "UPDATE"
    sleep 1
    write_to_cartridge $1 66469

}

refresh() {

    if [ -f ${MOUNT_POINT}/MODE.TXT ]
    then
        if cp ${MOUNT_POINT}/MODE.TXT /tmp/mode.tmp
        then

            dd if=/tmp/mode.tmp of=/dev/${DEVICE} bs=512 seek=66725 conv=fdatasync &> /dev/null &
            pid=$!

            while kill -0 $! &> /dev/null
            do
                loading "Refreshing Joey Jr..."
            done

            wait $pid
            printf "\r%s" "$SUCC Refreshing Joey Jr..."
            echo

            rm -f /tmp/mode.tmp

        else
            slow_echo "$FAIL Could not copy ${ylw}MODE.TXT${res} to /tmp"
            exit 1
        fi
    else
        slow_echo "$FAIL File ${ylw}MODE.TXT${res} does not exist, setting mode to: ${ylw}$MODE${res}"
        set-mode "$MODE" "force"
    fi

}

wait_for_joey() {

    for i in {1..20}
    do
        loading "Waiting for Joey Jr." $i 20
        if [ ! -z "$(lsblk | grep BENNVENN)" ]
        then
            printf "\r%s" "$SUCC Joey Jr. device reconnected"
            echo
            return 0
        else
            continue
        fi
    done

    printf "\r%s" "$FAIL Joey Jr. did not recconect"
    echo
    exit 1

}

get_joey_info () {

    DEBUG_FILE="$MOUNT_POINT/DEBUG.TXT"
    MODE_FILE="$MOUNT_POINT/MODE.TXT"
    DEBUG_CONTENT=$(strings $DEBUG_FILE)

    if [ ! -f "${MODE_FILE}" ]
    then
        if [ -f "${MOUNT_POINT}/MODE!.TXT" ]
        then
            MODE_FILE="${MOUNT_POINT}/MODE!.TXT"
        fi
    fi

    VERS=$(echo -e "$DEBUG_CONTENT" | grep "Joey Jr. Firmware" | awk '{ print $4 }')
    GAME=$(echo -e "$DEBUG_CONTENT" | grep "Game Title" | awk -F": " '{ print $2 }')
    CHSM=$(echo -e "$DEBUG_CONTENT" | grep "Checksum Correct")
    FLSH=$(echo -e "$DEBUG_CONTENT" | grep "Flash Detected.")

    if [ -f "${MODE_FILE}" ]; then
        MODE=$(tr -d '\0' < ${MODE_FILE} | head -1)
        if [ ! -z "$MODE" ]
        then
            mode=$MODE
        else
            MODE="AUTO"
            mode="${red}Unknown${res}"
        fi

    else
        MODE="AUTO"
        mode="${red}Neither ${ylw}MODE.TXT${red} nor ${ylw}MODE!.TXT${red} is available${res}"
    fi

    if [ -z "$GAME" ]; then
        game="${red}Unknown${res}"
    else
        game="${GAME}"
    fi

    if [ -z "$VERS" ]; then
        vers="${red}Unknown${res}"
    else
        vers="${VERS}"
    fi

    if [ -z "$CHSM" ]; then
        chsm="${red}false${res}"
    else
        chsm="${grn}true${res}"
    fi

    if [ -z "$FLSH" ]; then
        flsh="${red}false${res}"
    else
        flsh="${grn}true${res}"
    fi

}

if [[ "$1" =~ ^(-h|--help|help)$ ]]
then
    slow_echo "$INFO Following options and parameters are supported:"
    sleepy_echo
    sleepy_echo "           ${cyn}write  ${pur}rom      ${ylw}<ROM_FILE>${res}"
    sleepy_echo "           ${cyn}write  ${pur}sram     ${ylw}<SRAM_FILE>${res}"
    sleepy_echo "           ${cyn}write  ${pur}flash    ${ylw}<FLASH_FILE>${res}"
    sleepy_echo "           ${cyn}write  ${pur}eeprom   ${ylw}<EEPROM_FILE>${res}"
    sleepy_echo
    sleepy_echo "           ${cyn}copy   ${pur}rom      ${ylw}<DESTINATION>${res} (optional*)"
    sleepy_echo "           ${cyn}copy   ${pur}save     ${ylw}<DESTINATION>${res} (optional*)"
    sleepy_echo "           ${cyn}copy   ${pur}photos   ${ylw}<DESTINATION>${res} (optional*)"
    sleepy_echo
    sleepy_echo "           ${cyn}debug${res}"
    sleepy_echo "           ${cyn}refresh${res}"
    sleepy_echo "           ${cyn}set-mode        ${ylw}<MODE>${res}"
    sleepy_echo "           ${cyn}update-romlist  ${ylw}<ROMLIST_FILE>${res}  ${red}NOT TESTED!${res}"
    sleepy_echo "           ${cyn}update-firmware ${ylw}<FIRMWARE_FILE>${res} ${red}NOT TESTED!${res}"
    sleepy_echo
    sleepy_echo "           * If destination is not specified,"
    sleepy_echo "             file is copied to current working directory"
    sleepy_echo "             with timestamp before it's filename"
    sleepy_echo
    exit 0
fi

# Try to detect Joye Jr.
       BENNVENN=$(lsblk | grep BENNVENN)
         DEVICE=$(echo $BENNVENN | awk '{ print $1 }')
    MOUNT_POINT=$(echo $BENNVENN | awk '{ print $7 }')

[ -z "$BENNVENN" ] && slow_echo "$FAIL Joey Jr. is not connected" && exit 1

# Print information about detected Joey Jr.
slow_echo "$INFO Joey Jr. device found"
sleepy_echo
sleepy_echo "         ${cyn}Device:              ${ylw}/dev/${DEVICE}${res}"
sleepy_echo "         ${cyn}Mount point:         ${ylw}${MOUNT_POINT}${res}"
sleepy_echo

get_joey_info

sleepy_echo "         ${cyn}Firmware version:    ${ylw}${vers}${res}"
sleepy_echo "         ${cyn}Mode set:            ${ylw}${mode}${res}"
sleepy_echo
sleepy_echo "         ${cyn}Detected ROM:        ${ylw}${game}${res}"
sleepy_echo "         ${cyn}Checksum correct:    ${ylw}${chsm}${res}"
sleepy_echo "         ${cyn}ROM flashable:       ${ylw}${flsh}${res}"
sleepy_echo

# If no option passed, exit
[ -z "$1" ] && exit 0

case $1 in
    "write")
        case $2 in
            "rom")
                check_file_argument "<ROM_FILE>" "$3"
                if [ -z "$FLSH" ]; then
                    slow_echo "$FAIL Flash not detected for cartridge"
                    exit 1
                fi
                write_to_cartridge $3 37
                refresh
                wait_for_joey
                ;;
            "sram")
                check_file_argument "<SRAM_FILE>" "$3"
                write_to_cartridge $3 65829
                ;;
            "flash")
                check_file_argument "<FLASH_FILE>" "$3"
                write_to_cartridge $3 65573
                ;;
            "eeprom")
                check_file_argument "<EEPROM_FILE>" "$3"
                write_to_cartridge $3 66085
                ;;
            *)
                slow_echo "$FAIL Unknown option '${pur}${2}${res}', use '${cyn}help${res}' to see supported options"
                ;;
        esac
        ;;
    "copy")
        case $2 in
            "rom")
                copy_from_cartridge "\.GB|\.GBC|\.GBA" $3
                ;;
            "save")
                copy_from_cartridge "\.SAV|.FLASH|\.EEPROM" $3
                ;;
            "photos")
                copy_photos_from_cartridge $3
                ;;
            *)
                slow_echo "$FAIL Unknown option '${pur}${2}${res}', use '${cyn}help${res}' to see supported options"
                ;;
        esac
        ;;
    "update-romlist")
        check_file_argument "<ROMLIST_FILE>" "$2"
        write_to_cartridge $2 66341
        ;;
    "update-firmware")
        check_file_argument "<FIRMWARE_FILE>" "$2"
        set-mode "UPDATE" force
        wait_for_joey
        sleep 1
        get_joey_info
        if [ "$mode" = "UPDATE" ]
        then
            write_to_cartridge $2 66469
            sleep 1
            refresh
            wait_for_joey
        else
            slow_echo "$FAIL Could not set mode to: ${ylw}UPDATE${res}"
        fi
        ;;
    "set-mode")
        set-mode $2
        ;;
    "debug")
        read_debug_file
        ;;
    "refresh")
        refresh
        wait_for_joey
        ;;
    *)
        slow_echo "$FAIL Unknown option '${cyn}${1}${res}', use '${cyn}help${res}' to see supported options"
        ;;

esac


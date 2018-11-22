#!/usr/bin/env bash
# Utility for dealing with ADB
# CC-0 Ixtli Orange 2018

TEMPPACKAGESDB=$(mktemp)
_UtilityForDrawingWindows="whiptail"

# if width is 0 or less than 60, make it 80
# if width is greater than 178 then make it 120
calc_whiptail_size(){
    WT_HEIGHT=20
    WT_WIDTH=$(tput cols)

    if [ -z "$WT_WIDTH" ] || [ "$WT_WIDTH" -lt 50 ]; then
        WT_WIDTH=60
    fi
    if [ "$WT_WIDTH" -gt 60 ]; then
        WT_WIDTH=60
    fi

    WT_MENU_HEIGHT=$(($WT_HEIGHT-7))
}

do_update_package_database(){
    adb shell pm list packages \
        > $TEMPPACKAGESDB
    [[ "$?" -ne "0" ]] && exit 1
    whiptail --textbox "Packages found: $(cat $TEMPPACKAGESDB | wc -l)" 10 20
}

do_about() {
    whiptail --msgbox "
    This utility is designed to make ADB a bit less painful
        " 20 70 1
}

do_enable_tcp_on_usb_device(){
    whiptail --textbox "$(adb tcpip 5555)" 10 20
}

do_connect_to_device_over_IP(){
    IP=$(whiptail --inputbox "What is the IP address of the device?" 8 78 \
        --title "IP INPUT" 3>&1 1>&2 2>&3)
    adb connect $IP
}

do_look_for_running_packaged(){
    # list all packages and then get all the IDs for the ones that are running
    while read package; do 
        packageName=$(echo "$package" | cut -d":" -f2)
        isRunning="0"
        isRunning=$(adb shell pidof $packageName)
        [[ "$isRunning" -ne "0" ]] && \
            echo "$packageName running as $isRunning"
    done < $TEMPPACKAGESDB
}

do_package_list_downloads(){
    local i=0
    local s=65    # decimal ASCII "A"
    while read file; do
        # convert to octal then ASCII character for selection tag
        files[$i]=$(echo -en "\0$(( $s / 64 * 100 + $s % 64 / 8 * 10 + $s % 8 ))")
        files[$i+1]="$file"    # save file name
        ((i+=2))
        ((s++))
    done < $TEMPPACKAGESDB

    local PACKAGE=$(whiptail --title "Download a package" \
        --menu "Please select the package you want to download" 14 40 6 "${files[@]}" \
        3>&1 1>&2 2>&3)
    local RET=$?

    ((index = 2 * ( $( printf "%d" "'$PACKAGE" ) - 65 ) + 1 ))

    if [ $RET -eq 1 ]; then
        exit 1
    elif [ $RET -eq 0 ]; then
        do_android_pull "${files[$index]}"
    else
        break
    fi
}

do_android_pull(){
    # adb pull $1
    echo "Downloading $1"
    sleep 1
}

#
# Interactive loop
#

calc_whiptail_size
while true; do
    FUN=$(whiptail --title "HAndHold" --menu "options" $WT_HEIGHT $WT_WIDTH \
        $WT_MENU_HEIGHT --cancel-button Finish --ok-button Select \
    "1 Connect to IP" "Connect to an IP address of a ADB Device" \
    "2 Update Package Database" "Download a list of packages on the device" \
    "3 USB->IP" "Enable Network ADB on USB connected device" \
    "4 Download APKs" "Download individual APKs" \
    "5 About" "What's this all about?" \
    3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -eq 1 ]; then
        exit 1
    elif [ $RET -eq 0 ]; then
        case "$FUN" in
            1\ *) do_connect_to_device_over_IP ;;
            2\ *) do_update_package_database ;;
            3\ *) do_enable_tcp_on_usb_device ;;
            4\ *) do_package_list_downloads ;;
            5\ *) do_about ;;
            *) whiptail --msgbox "Unrecognised option" 20 60 1 ;;
        esac
    else
        exit 1
    fi
done

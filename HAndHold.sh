#!/usr/bin/env bash
# Utility for dealing with ADB
# CC-0 Ixtli Orange 2018

# if width is 0 or less than 60, make it 80
# if width is greater than 178 then make it 120

INTERFACE="usb0"
TEMPPACKAGESDB=$(mktemp)

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
    adb tcpip 5555
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

#
# Interactive loop
#

calc_whiptail_size
while true; do
    FUN=$(whiptail --title "HAnd Hold" --menu "options" $WT_HEIGHT $WT_WIDTH \
        $WT_MENU_HEIGHT --cancel-button Finish --ok-button Select \
    "1 About" "What's this all about?" \
    "2 Update Package Database" "Download a list of packages on the device" \
    3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -eq 1 ]; then
        exit 1
    elif [ $RET -eq 0 ]; then
        case "$FUN" in
            1\ *) do_about ;;
            2\ *) do_update_package_database ;;
            *) whiptail --msgbox "Unrecognised option" 20 60 1 ;;
        esac
    else
        exit 1
    fi
done


#!/usr/bin/env bash
# Utility for dealing with ADB
# CC-0 Orange 2021

TEMPPACKAGESDB=$(mktemp)
_UtilityForDrawingWindows="whiptail"
ignoreSystemApps=1
SCRIPTDIR=$(dirname $0)
APKDIR=${1:-~/APKS}
DEVICE=${2:-emulator-5554}

mkdir -p $APKDIR >/dev/null

# if width is 0 or less than 60, make it 60
# if width is greater than 120 then make it 120
calc_whiptail_size(){
    WT_HEIGHT=20
    WT_WIDTH=$(tput cols)

    if [ -z "$WT_WIDTH" ] || [ "$WT_WIDTH" -lt 60 ]; then
        WT_WIDTH=60
    fi
    if [ "$WT_WIDTH" -gt 80 ]; then
        WT_WIDTH=80
    fi

    WT_MENU_HEIGHT=$(($WT_HEIGHT-7))
}

do_update_package_database(){
    adb -s $DEVICE shell pm list packages -f \
        > $TEMPPACKAGESDB
    [[ "$?" -ne "0" ]] && exit 1
    [[ "$ignoreSystemApps" -eq "1" ]] && sed -i -e "/\/system\//d" $TEMPPACKAGESDB 
    echo "Packages found: $(cat $TEMPPACKAGESDB | wc -l)"
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
    [[ ! -s "$TEMPPACKAGESDB" ]] && do_package_list_downloads
    # list all packages and then get all the IDs for the ones that are running
    for package in $(sed -e "s/.*=//g" $TEMPPACKAGESDB); do
        #packageName=$(echo "$package" | cut -d":" -f2)
        isRunning=$(adb -s $DEVICE shell pidof $package)
        [[ "$isRunning" -ne "0" ]] && [[ "$isRunning" -ne "1" ]] && \
            echo "$package running as $isRunning"
    done
}

do_pid_logcat(){
    local PID=$1
    local outFile=$2
    if [[ $outFile ]]; then  
        adb -s $DEVICE logcat --pid=$PID | tee $outFile
    else
        adb -s $DEVICE logcat --pid=$PID 
    fi
}

do_pid_logcat_selection(){
    [[ ! -s "$TEMPPACKAGESDB" ]] && do_package_list_downloads
    # list all packages and then get all the IDs for the ones that are running
    local i=0
    local s=65    # decimal ASCII "A"
    for package in $(sed -e "s/.*=//g" $TEMPPACKAGESDB); do
        # convert to octal then ASCII character for selection tag
        isRunning=$(adb -s $DEVICE shell pidof $package)
        if [[ "$isRunning" -ne "0" ]] && [[ "$isRunning" -ne "1" ]]; then 
            files[$i]=$(echo -en "\0$(( $s / 64 * 100 + $s % 64 / 8 * 10 + $s % 8 ))")
            files[$i+1]="$package:$isRunning"    # save file name
            ((i+=2))
            ((s++))
        fi
    done 

    local PACKAGE=$(whiptail --title "Logcat Menu" \
        --menu "Please select the package you want to view the logcat output of" 14 40 6 "${files[@]}" \
        3>&1 1>&2 2>&3)
    local RET=$?

    ((index = 2 * ( $( printf "%d" "'$PACKAGE" ) - 65 ) + 1 ))

    if [ $RET -eq 1 ]; then
        exit 1
    elif [ $RET -eq 0 ]; then
        packageName=$(echo "${files[$index]}" | cut -d: -f1)
        packagePID=$(echo "${files[$index]}" | cut -d: -f2)
        do_pid_logcat "$packagePID" "$packageName.log"
        exit
    else
        break
    fi
}

do_package_list_downloads(){
    [[ ! -s "$TEMPPACKAGESDB" ]] && do_package_list_downloads
    local i=0
    local s=65    # decimal ASCII "A"
    while read file; do
        # convert to octal then ASCII character for selection tag
        files[$i]=$(echo -en "\0$(( $s / 64 * 100 + $s % 64 / 8 * 10 + $s % 8 ))")
        files[$i+1]="$file"    # save file name
        ((i+=2))
        ((s++))
    done < <(sed -e "s/.*=//g" $TEMPPACKAGESDB)

    local PACKAGE=$(whiptail --title "Download a package" \
        --menu "Please select the package you want to download" 14 40 6 "${files[@]}" \
        3>&1 1>&2 2>&3)
    local RET=$?

    ((index = 2 * ( $( printf "%d" "'$PACKAGE" ) - 65 ) + 1 ))

    if [ $RET -eq 1 ]; then
        exit 1
    elif [ $RET -eq 0 ]; then
        local FILEPATH=$( grep "${files[$index]}" $TEMPPACKAGESDB \
                            | cut -d: -f2- \
                            | egrep -o ".*\.apk" )
        do_android_pull "$FILEPATH" "$APKDIR/${files[$index]}.apk"
    else
        break
    fi
}

do_download_all_packages(){
    [[ ! -s "$TEMPPACKAGESDB" ]] && do_package_list_downloads
    while read PACKAGE; do
        local FILEPATH=$( grep "$PACKAGE" $TEMPPACKAGESDB \
                            | cut -d: -f2- \
                            | egrep -o ".*\.apk" )
        echo "$index: $PACKAGE && $FILEPATH"
        do_android_pull "$FILEPATH" "$APKDIR/$PACKAGE.apk"
    done < <(sed -e "s/.*=//g" $TEMPPACKAGESDB)
}

do_android_pull(){
    echo "Downloading $1"
    adb -s $DEVICE pull -p "$1" "$2"
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
    "5 Download All APKs" "Download all APKs" \
    "6 Logcat" "View the debugging output for a given running package" \
    "7 About" "What's this all about?" \
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
            5\ *) do_download_all_packages ;;
            6\ *) do_pid_logcat_selection ;;
            7\ *) do_about ;;
            *) whiptail --msgbox "Unrecognised option" 20 60 1 ;;
        esac
    else
        exit 1
    fi
done


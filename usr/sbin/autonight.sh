#!/bin/sh
###############################################################################
#
#   █████╗ ██╗   ██╗████████╗ ██████╗ ███╗   ██╗██╗ ██████╗ ██╗  ██╗████████╗
#  ██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗████╗  ██║██║██╔════╝ ██║  ██║╚══██╔══╝
#  ███████║██║   ██║   ██║   ██║   ██║██╔██╗ ██║██║██║  ███╗███████║   ██║
#  ██╔══██║██║   ██║   ██║   ██║   ██║██║╚██╗██║██║██║   ██║██╔══██║   ██║ 
#  ██║  ██║╚██████╔╝   ██║   ╚██████╔╝██║ ╚████║██║╚██████╔╝██║  ██║   ██║
#  ╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝
#
###############################################################################
# Script Name : autonight.sh
# 
# Description : This script check if night mode should be ensabled based on 
#               ISB_AGAIN metric. It will trigger LEDs depending on motion
#               PID file (see motion.sh script).
#
# Install     : Put this script in /usr/sbin/
#               Can be managed as a daemon via init.d start-stop-daemon
#               Setup Majestic :
#                - Night mode to have GPIO for IRcut 
#                - Make sure the "GPIO pin for camera light" is not set
#                - Light sensor must be disabled
#
# Usage       : autonight.sh [-H value] [-L value] [-i value] [-h]
#               -H value   Again high target (default = $again_high_target).
#               -L value   Again low target (default = $again_low_target).
#               -i value   Polling interval (default = $pollingInterval).
#               
#
# Author      : Fabien LAMAISON
# Date        : February 21, 2026
#
# License     : Creative Commons Attribution-NonCommercial 4.0 International
#               (CC BY-NC 4.0)
#               You are free to share and adapt this material for non-commercial
#               purposes, provided you give appropriate credit.
###############################################################################


###############################################################################
## Configuration
###############################################################################
# High threshold to enable night mode (should be 12000-14000)
again_high_target=14000

# Low threshold to disable night mode (should be 1500-2000)
again_low_target=1500

# Default polling interval
pollingInterval=15

# File used to check if night mode is enabled or disabled (used by "/usr/sbin/motion.sh" script)
pid_file_night="/var/run/night_mode.pid"

# File used to check if motion is in progress (set by "/usr/sbin/motion.sh" script)
pid_file_motion="/var/run/motion.pid"

# GPIO Pin for LEDs
led_gpio=4

# Debug log messages (use 'logread -f')
DEBUG=1         # Set to 1 or 0 to ensable or disable

###############################################################################
## Functions
###############################################################################
show_help() {
    echo "Usage: $0 [-H value] [-L value] [-i value] [-h]
    -H value   Again high target (default = ${again_high_target}).
    -L value   Again low target (default = ${again_low_target}).
    -i value   Polling interval (default = ${pollingInterval}).
    -h         Show this help."
    exit 0
}

check_night_mode() {
    [[ -f $pid_file_night ]] && grep -q '^1$' $pid_file_night && echo 1 || echo 0
}

check_motion_status(){
    [ -f "$pid_file_motion" ] &&  echo 1 || echo 0
}

check_led_status()
{
    echo $(gpio read ${led_gpio})
}

turn_on_led()
{
    echo $(gpio set ${led_gpio})
    sleep 1
}

turn_off_led()
{
    echo $(gpio clear ${led_gpio})
    sleep 1
}


###############################################################################
## Prepare
###############################################################################
while getopts H:L:i:h flag; do
    case ${flag} in
        H) again_high_target=${OPTARG} ;;
        L) again_low_target=${OPTARG} ;;
        i) pollingInterval=${OPTARG} ;;
        h | *) show_help ;;
    esac
done



###############################################################################
## Start Script
###############################################################################
while true; do
    # Init GPIO Pin to export (mandatory to work with 'gpio' command)
    [ ! -f /sys/class/gpio/export ] && exit
    [ ! -d /sys/class/gpio/gpio${led_gpio} ] && echo ${led_gpio} >/sys/class/gpio/export
    [ -f /sys/class/gpio/gpio${led_gpio}/direction ] && ! grep -q '^out$' /sys/class/gpio/gpio${led_gpio}/direction && echo out >/sys/class/gpio/gpio${led_gpio}/direction

    # Get metrics to fetch isp_again and nigh_enabled values
    metrics=$(curl -s http://localhost/metrics)
    isp_again=$(echo "${metrics}" | awk '/^isp_again/ {print $2}' | grep . || echo 0)
    
    # Set default polling interval
    sleepingtime=$pollingInterval

    [ "$DEBUG" -eq 1 ] && logger -t autonight -p debug "Night Mode=$(check_night_mode) / Isp_Again=$isp_again / Motion : $(check_motion_status) / LED=$(check_led_status)"

    # If night mode is on, check if LEDs should be turned on or if night mode should be disable
    if [ $(check_night_mode) -eq 1 ]; then
        # Turn on LEDs if motion is in progress and LEDs are off
        if [ $(check_motion_status) -eq 1 ] && [ $(check_led_status) -eq 0 ]; then
            turn_on_led
            # Get the new ISP_AGAIN to check if night mode should be disabled
            metrics=$(curl -s http://localhost/metrics)
            isp_again=$(echo "${metrics}" | awk '/^isp_again/ {print $2}' | grep . || echo 0)
            [ "$DEBUG" -eq 1 ] && logger -t autonight -p debug "Turn on LEDs (new isp_again=${isp_again})"
        fi
        
        # Disable night mode if ISP_AGAIN is lower than low target
        if [ $isp_again -lt $again_low_target ]; then
            # Use PID file for motion script
            echo "0" > $pid_file_night
            # Use majestic endpoint to turn off night mode
            curl -s http://localhost/night/off > /dev/null
            [ "$DEBUG" -eq 1 ] && logger -t autonight -p debug "Condition isp_again < ${again_low_target} was met (current value is ${isp_again}), turn off the night mode"
        fi
    
    # If night mode is disabled, check if LEDs should be turned off and if night mode should be enabled
    else
        # Turn off LEDs if motion is ended and LEDs are on
        if [ $(check_motion_status) -eq 0 ] && [ $(check_led_status) -eq 1 ]; then
            turn_off_led
            [ "$DEBUG" -eq 1 ] && logger -t autonight -p debug "Turn off LEDs"
        fi
        
        # Get the new ISP_AGAIN to check if night mode should be enabled
        metrics=$(curl -s http://localhost/metrics)
        isp_again=$(echo "${metrics}" | awk '/^isp_again/ {print $2}' | grep . || echo 0)

        # Enable night mode if ISB_AGAIN is higher than high target
        if [ $isp_again -gt $again_high_target ]; then

            # Wait for motion to end before enabling night mode
            while [ $(check_motion_status) -eq 1 && $(check_led_status) -eq 1 ] ; do 
                sleep 5
                # Reduce polling time for next loop 
                sleepingtime=2
                [ "$DEBUG" -eq 1 ] && logger -t autonight -p debug "Waiting for motion to end and LEDs to be off before turning on the night mode (5 sec)"
            done
            # Use PID file for motion script
            echo "1" > $pid_file_night
            # Use majestic endpoint to turn on night mode
            curl -s http://localhost/night/on > /dev/null
            [ "$DEBUG" -eq 1 ] && logger -t autonight -p debug "Condition isp_again > ${again_high_target} was met (current value is ${isp_again}), turn on the night mode"
        fi
    fi
    # Wait before checking again
    sleep $sleepingtime
done

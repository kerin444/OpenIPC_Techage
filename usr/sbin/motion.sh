#!/bin/sh
###############################################################################
#
#         ███╗   ███╗ ██████╗ ████████╗██╗ ██████╗ ███╗   ██╗
#         ████╗ ████║██╔═══██╗╚══██╔══╝██║██╔═══██╗████╗  ██║
#         ██╔████╔██║██║   ██║   ██║   ██║██║   ██║██╔██╗ ██║
#         ██║╚██╔╝██║██║   ██║   ██║   ██║██║   ██║██║╚██╗██║
#         ██║ ╚═╝ ██║╚██████╔╝   ██║   ██║╚██████╔╝██║ ╚████║
#         ╚═╝     ╚═╝ ╚═════╝    ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
#
###############################################################################
# Script Name : motion.sh
# 
# Description : This script is triggered by motion detection and will create
#               PID file to manager LEDs and night mode by autonight.sh script
#
# Install     : Put this script in /usr/sbin/
#               Enable motion detection
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
# Default polling interval (motion shortest duration)
pollingInterval=30

# File used to check if night mode is enabled or disabled (managed by "/usr/sbin/autonight.sh" script)
pid_file_night="/var/run/night_mode.pid"

# File used to check if motion is in progress (used by "/usr/sbin/autonight.sh" script)
pid_file_motion="/var/run/motion.pid"

# GPIO Pin for LEDs
led_gpio=4

# Debug log messages (use 'logread -f')
DEBUG=1         # Set to 1 or 0 to ensable or disable


###############################################################################
## Start Script
###############################################################################

# Check if motion has been triggered by changing night mode (2 sec)
if [ -f "$pid_file_night" ]; then
    LAST_NIGHT=$(stat -c %Y "$pid_file_night")
    CURRENT_TIME=$(date +%s)
    DIFF=$((CURRENT_TIME - LAST_NIGHT))
    # If night mode has been changed since less than 2 secs
    if [ "$DIFF" -gt 2 ]; then
        # Start motion
        echo "1" > $pid_file_motion

        [ "$DEBUG" -eq 1 ] && logger -t motion -p debug "Started ($DIFF sec)"

        # Turn on LEDs if night mode is on and LEDs are off
        if [[ -f $pid_file_night ]] && grep -q '^1$' $pid_file_night && [ $(gpio read ${led_gpio}) -eq 0 ]; then
            $(gpio set ${led_gpio})
            [ "$DEBUG" -eq 1 ] && logger -t motion -p debug "Turn on LEDs by motion"
        fi
    else
        [ "$DEBUG" -eq 1 ] && logger -t motion -p debug "Motiong triggered by changing night mode during last $DIFF sec -> Not started"
    fi
else
    echo "1" > $pid_file_motion
    [ "$DEBUG" -eq 1 ] && logger -t motion -p debug "Started (no night PID file : $pid_file_night)"
fi

sleep $pollingInterval
# Check if PID file exists and check when it was modified
if [ -f "$pid_file_motion" ]; then
    sleep 1
    LAST_MOTION=$(stat -c %Y "$pid_file_motion")
    CURRENT_TIME=$(date +%s)
    DIFF=$((CURRENT_TIME - LAST_MOTION))

    # If file is older than waiting time, it means no new motion has been detected
    if [ "$DIFF" -gt "$pollingInterval" ]; then
        # Remove PID file to end motion
        rm "$pid_file_motion"
        [ "$DEBUG" -eq 1 ] && logger -t motion -p debug "Ended"
    fi
fi

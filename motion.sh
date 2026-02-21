#!/bin/sh
#       ███╗   ███╗ ██████╗ ████████╗██╗ ██████╗ ███╗   ██╗
#       ████╗ ████║██╔═══██╗╚══██╔══╝██║██╔═══██╗████╗  ██║
#       ██╔████╔██║██║   ██║   ██║   ██║██║   ██║██╔██╗ ██║
#       ██║╚██╔╝██║██║   ██║   ██║   ██║██║   ██║██║╚██╗██║
#       ██║ ╚═╝ ██║╚██████╔╝   ██║   ██║╚██████╔╝██║ ╚████║
#       ╚═╝     ╚═╝ ╚═════╝    ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
                                                   
##################################################################
## Configuration
pollingInterval=30
pid_file_motion="/var/run/motion.pid"
pid_file_night="/var/run/night_mode.pid"
led_gpio=4

# Debug log messages (use 'logread -f')
DEBUG=1         # Set to 1 or 0 to ensable or disable


##################################################################
## Start Script

# Check if motion has been triggered by changing night mode (2 sec)
if [ -f "$pid_file_night" ]; then
    LAST_NIGHT=$(stat -c %Y "$pid_file_night")
    CURRENT_TIME=$(date +%s)
    DIFF=$((CURRENT_TIME - LAST_NIGHT))
    # If night mode has been changed since less than 2 secs
    if [ "$DIFF" -gt 2 ]; then
        # Start motion
        echo "1" > $pid_file_motion

        [ "$DEBUG" -eq 1 ] && logger "MOTION    : Started ($DIFF sec)"

        # Turn on LEDs if night mode is on and LEDs are off
        if [[ -f $pid_file_night ]] && grep -q '^1$' $pid_file_night && [ $(gpio read ${led_gpio}) -eq 0 ]; then
            $(gpio set ${led_gpio})
            [ "$DEBUG" -eq 1 ] && logger "MOTION    : Turn on LEDs by motion"
        fi
    else
        [ "$DEBUG" -eq 1 ] && logger "MOTION    : Motiong triggered by changing night mode during last $DIFF sec -> Not started"
    fi
else
    echo "1" > $pid_file_motion
    [ "$DEBUG" -eq 1 ] && logger "MOTION    : Started (no night PID file : $pid_file_night)"
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
        [ "$DEBUG" -eq 1 ] && logger "MOTION    : Ended"
    fi
fi

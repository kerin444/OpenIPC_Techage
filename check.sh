#!/bin/sh

##################################################################
## Configuration
again_high_target=14000
again_low_target=1500
pid_file_motion="/var/run/motion.pid"
pid_file_night="/var/run/night_mode.pid"
led_gpio=4

[ ! -f /sys/class/gpio/export ] && exit
[ ! -d /sys/class/gpio/gpio${led_gpio} ] && echo ${led_gpio} >/sys/class/gpio/export
[ -f /sys/class/gpio/gpio${led_gpio}/direction ] && ! grep -q '^out$' /sys/class/gpio/gpio${led_gpio}/direction && echo out >/sys/class/gpio/gpio${led_gpio}/direction


while true; do
    metrics=$(curl -s http://localhost/metrics)
    isp_again=$(echo "${metrics}" | awk '/^isp_again/ {print $2}' | grep .)

    if [ $isp_again -gt $again_high_target ]; then
        echo -e -n "Night mode should be ON (ISP_AGAIN : $isp_again > $again_high_target)\t"
    elif [ $isp_again -lt $again_low_target ]; then
        echo -e -n "Night mode should be OFF (ISP_AGAIN : $isp_again < $again_low_target)\t"
    else
        echo -e -n "ISP_AGAIN : $isp_again\t\t\t"
    fi

    if [[ -f $pid_file_night ]]; then
        LAST_NIGHT=$(stat -c %Y "$pid_file_night")
        CURRENT_TIME=$(date +%s)
        DIFF=$((CURRENT_TIME - LAST_NIGHT))

        if $(grep -q '^1$' $pid_file_night); then 
            echo -e -n "Night mode : ON since $DIFF s\t"

        else
            echo -e -n "Night mode : OFF since $DIFF s\t"
        fi
    else
        echo -e -n "Night mode: Error PID"
    fi

    if [ -f "$pid_file_motion" ]; then
        LAST_MOTION=$(stat -c %Y "$pid_file_motion")
        CURRENT_TIME=$(date +%s)
        DIFF=$((CURRENT_TIME - LAST_MOTION))
        echo -e -n "Motion : ON last $DIFF s\t"
    else
        echo -e -n "Motion : OFF\t\t"
    fi
    
    [ $(gpio read ${led_gpio}) -eq 1 ] && echo "LED is ON" || echo "LED is OFF"

    sleep 1
done
#!/bin/sh

## Configuration
pollingInterval=15
pid_file="/var/run/motion.pid"
led_gpio=4

## Functions
function turn_on_led ()
{
    [ ! -f /sys/class/gpio/export ] && exit
    [ ! -d /sys/class/gpio/gpio${led_gpio} ] && echo ${led_gpio} >/sys/class/gpio/export
    [ -f /sys/class/gpio/gpio${led_gpio}/direction ] && echo out >/sys/class/gpio/gpio${led_gpio}/direction
    [ -f /sys/class/gpio/gpio${led_gpio}/value ] && echo 1 >/sys/class/gpio/gpio${led_gpio}/value
    sleep 1
}

function turn_off_led ()
{
    [ ! -f /sys/class/gpio/export ] && exit
    [ ! -d /sys/class/gpio/gpio${led_gpio} ] && echo ${led_gpio} >/sys/class/gpio/export
    [ -f /sys/class/gpio/gpio${led_gpio}/direction ] && echo out >/sys/class/gpio/gpio${led_gpio}/direction
    [ -f /sys/class/gpio/gpio${led_gpio}/value ] && echo 0 >/sys/class/gpio/gpio${led_gpio}/value
    sleep 1
}

function get_led_status ()
{
    [ ! -f /sys/class/gpio/export ] && exit
    [ ! -d /sys/class/gpio/gpio${led_gpio} ] && echo ${led_gpio} >/sys/class/gpio/export
    [ -f /sys/class/gpio/gpio${led_gpio}/direction ] && echo out >/sys/class/gpio/gpio${led_gpio}/direction
    echo $(cat /sys/class/gpio/gpio${led_gpio}/value)
}

## Prepare
echo 1>$pid_file
night_enabled=$(curl -s http://localhost/metrics | awk '/^night_enabled/ {print $2}' | grep . || echo 0)
led_on=$(get_led_status)

## Start Script
# Turn ON LEDs if night mode is ON and LEDs are OFF
if [ $night_enabled -eq 1 ] && [ $led_on -eq 0 ]; then
       turn_on_led
       logger "Motion started    /    Night Mode=$night_enabled     /     LED=$led_on"
fi
# Wait
sleep $pollingInterval
# Check if PID file exists and check when it was modified
if [ -f "$pid_file" ]; then
    sleep 1
    LAST_MOD=$(stat -c %Y "$pid_file")
    CURRENT_TIME=$(date +%s)
    DIFF=$((CURRENT_TIME - LAST_MOD))
    led_on=$(get_led_status)

    # If file is older than waiting time, it means no new motion has been detected
    if [ "$DIFF" -gt "$pollingInterval" ]; then
        # If LEDs are ON at the end of motion, turn them OFF
        if [ $led_on -eq 1 ]; then
            logger "Motion end (15s)    /    Night Mode=$night_enabled    /    LED=$led_on ... Turning LEDs off"
            turn_off_led
        fi
        # Remove PID file
        rm "$pid_file"
    fi
fi

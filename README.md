# OpenIPC_Techage
OpenIPC for Techage cameras (should work with all cameras with LEDs and no Light Sensor)

References:

+ [Auto Night Mode Without Light Sensor : from legacy but still usefull as OpenIPC triggers LEDs with Night Mode and not with Motion](https://github.com/OpenIPC/wiki/blob/master/en/auto-night-mode-without-light-sensor.md)

+ [Auto DayNight Detection: current way of managing day/night in OpenIPC](https://github.com/OpenIPC/wiki/blob/master/en/majestic-streamer.md#auto-daynight-detection)


## MOTION & AUTONIGHT
This set of scripts has been made to manage the night mode and turn ON/OFF the LEDs when motion is detected on Techage Cameras that don't have Light Sensor (should work on other cameras).

Night Mode is managed by the `autonight.sh` script to be placed in `/usb/sbin/` and started as a daemon via the `S96autonight` script to be places in `/etc/init.d/`.
*(The autonight daemon manager `S96autonight` has to be called after Majestic. It must be named after `S95majestic`)*

Motion is managed by the `motion.sh` script to be placed in `/usb/sbin/`. As the `motion.sh` is triggered multiple times when motion is detected, the script uses a PID file to check if motion is still in progress.

## INSTALLATION
Place `autonight.sh` and `motion.sh` in `/usb/sbin/` and add execution rights:
```
# mv ./usr/sbin/autonight.sh ./usr/sbin/motion.sh /usr/sbin/
# chmod +x /usr/sbin/autonight.sh /usr/sbin/motion.sh
```
Place `S96autonight` in `/etc/init.d/` and add execution rights:
```
# mv ./etc/init.d/S96autonight /etc/init.d/
# chmod +x /etc/init.d/S96autonight
```
## CONFIGURATION
1. In Majestic, make sure the "GPIO pin for camera light" is not set (nightMode.backlightPin)
1. Edit the `/usr/sbin/autonight.sh` script to change the configuration:
```
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
```
1. Edit the `/usr/sbin/motion.sh` script to change the configuration:
```
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
```
## Usage
Start/stop/restart the Autonight daemon:
```
# /etc/init.d/S96autonight {start|stop|restart}
```
When DEBUG is enabled, use the logread to monitor events:
```
# logread -f
```
Monitor ISP_AGAIN, Night Mode, Motion and LEDs using the script:
```
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

while true; do
    metrics=$(curl -s http://localhost/metrics)
    isp_again=$(echo "${metrics}" | awk '/^isp_again/ {print $2}' | grep .)

    if [ $isp_again -gt $again_high_target ]; then
        echo -e -n "Low light : night mode should be ON (ISP_AGAIN : $isp_again > $again_high_target)\t"
    elif [ $isp_again -lt $again_low_target ]; then
        echo -e -n "High light : night mode should be OFF (ISP_AGAIN : $isp_again < $again_low_target)\t"
    else
        echo -e -n "ISP_AGAIN : $isp_again\t\t\t\t"
    fi

    [[ -f $pid_file_night ]] && grep -q '^1$' $pid_file_night && echo -e -n "Night mode : 1 ($pid_file_night)\t" || echo -e -n "Night mode : 0 ($pid_file_night)\t"

    [ -f "$pid_file_motion" ] && echo -e -n "Motion is ON\t" || echo -e -n "Motion is OFF\t"

    [ $(gpio read ${led_gpio}) -eq 1 ] && echo "LED is ON" || echo "LED is OFF"

    sleep 1
done
```
# OpenIPC_Techage
OpenIPC for Techage cameras

## MOTION
Motion is managed by the `motion.sh` script to be placed in `/usb/sbin/`
This script will turn on LEDs at night when motion is detected and will turn LEDs OFF at the end of motion.
As the `motion.sh` is triggered multiple times when motion is detected, the script uses a PID file to check if motion is still in progress.

### Configuration
In Majestic, make sure the "GPIO pin for camera light" is not set (nightMode.backlightPin)
```
pollingInterval=15               # Wait time before turning OFF the LEDs
pid_file="/var/run/motion.pid"   # File used to check if motion is still in progress
led_gpio=4                       # PGIO PIN for LEDs
```
### Usage
The script can be started manualy
Use `logread -f` to check the logs for motion:
```

```

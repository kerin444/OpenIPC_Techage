# OpenIPC_Techage
OpenIPC for Techage cameras

# Firmware installation
Remove the 4 front screws to open the cameras:

<img width="858" height="753" alt="Camera front view" src="https://github.com/user-attachments/assets/7b0dbf2e-cfa1-4973-8a99-9e7d72d0ff43" />

Connect the UART adapter to the camera PCB:

<img width="686" height="884" alt="UART Adapter" src="https://github.com/user-attachments/assets/06279e81-301f-438c-9539-2653de988052" />

<img width="1281" height="859" alt="Camera PCB" src="https://github.com/user-attachments/assets/1362082e-a494-43d5-aa13-90fcb7a4a163" />

Download Portable release of TFTPd64 server for Windows:
https://github.com/PJO2/tftpd64/releases/

Create a directory to use as the TFTPd root directory:

<img width="667" height="470" alt="image" src="https://github.com/user-attachments/assets/a520d207-9fb4-4bd6-8243-99aa0ed14494" />

Techage is based on HiSilicon 3516 v300 chipset with 8m flash size and ethernet port only.

Download the firmware from OpenIpc :
https://openipc.org/cameras/vendors/hisilicon/socs/hi3516ev300

Direct Download link:
https://openipc.org/cameras/vendors/hisilicon/socs/hi3516ev300/download_full_image?flash_size=8&flash_type=nor&fw_release=lite

Put the firmware BIN file in the TFTPd root directory:

<img width="901" height="246" alt="image" src="https://github.com/user-attachments/assets/32fb3c8b-b937-46c5-8e49-a76a8d869851" />


Connect the camera to a POE switch and start Putty to connect:

<img width="372" height="772" alt="image" src="https://github.com/user-attachments/assets/28c73e96-7c80-4146-af47-04b5650e7e1e" />

<img width="455" height="442" alt="image" src="https://github.com/user-attachments/assets/3ce9d85f-0c15-4a86-a0a4-6a5221904556" />

<img width="455" height="443" alt="image" src="https://github.com/user-attachments/assets/86231b60-28ff-4e6f-ab6d-59e1d0259db6" />

You should see the boot sequence by default:

<img width="579" height="393" alt="image" src="https://github.com/user-attachments/assets/8c071112-3adf-453b-a3fb-d24d590391da" />

Reboot the camera and press CTRL + C to interrupt boot sequence:


[![Press CTRL+C on boot to interrup boot sequence](https://github.com/user-attachments/assets/6e57326a-2ce7-41d9-a376-4531c4dd7799)](https://www.youtube.com/watch?v=yRm4S27fPA0 "Press CTRL+C on boot to interrup boot sequence")


```
# setenv ipaddr 10.10.12.1
# setenv gatewayip 10.10.0.1
# setenv netmask 255.255.0.0
# setenv serverip 10.10.8.30
# mw.b 0x42000000 0xff 0x800000
# tftpboot 0x42000000 openipc-hi3516ev300-lite-8mb.bin
# sf probe 0; sf lock 0;
# sf erase 0x0 0x800000; sf write 0x42000000 0x0 0x800000
# reset
```
Check DHCP
Login via http://<<DHCP IP>>/ with root/12345
Change password
Change MAC address to match previous MAC if needed
Firmware -> Network
	Change Hostname
Firmware -> Time
	Sync with computer TZ





# MOTION & AUTONIGHT
This set of scripts has been made to manage the night mode and turn ON/OFF the LEDs when motion is detected on Techage Cameras that don't have Light Sensor (should work on other cameras).

Night Mode is managed by the `autonight.sh` script to be placed in `/usb/sbin/` and started as a daemon via the `S96autonight` script to be places in `/etc/init.d/`.
*(The autonight daemon manager `S96autonight` has to be called after Majestic. It must be named after `S95majestic`)*

Motion is managed by the `motion.sh` script to be placed in `/usb/sbin/`. As the `motion.sh` is triggered multiple times when motion is detected, the script uses a PID file to check if motion is still in progress.
## References

+ [Auto Night Mode Without Light Sensor : from legacy but still usefull as OpenIPC triggers LEDs with Night Mode and not with Motion](https://github.com/OpenIPC/wiki/blob/master/en/auto-night-mode-without-light-sensor.md)

+ [Auto DayNight Detection: current way of managing day/night in OpenIPC](https://github.com/OpenIPC/wiki/blob/master/en/majestic-streamer.md#auto-daynight-detection)

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
Monitor ISP_AGAIN, Night Mode, Motion and LEDs using the `check.sh` script

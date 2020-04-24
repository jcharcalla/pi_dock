# pi_dock

*New and improved*

**Ansible role for a Raspberry PI based lake level / temperature monitoring project.**

This project is rather specific to my own setup and makes use of various outdated sensors I had from a previous version which was ate by squirrels. The new updates are meant for Ubuntu running on a raspberry pi. The original cron script relying on influxdb is still included, however no longer used. A new version as a systemd service has replaced the old, and this service relies on the Promethus node_exporter textfile collector functionality.

### Sensor list:
- Water Temp - Vktech 3M Waterproof Digital Temperature Temp Sensor Probe DS18b20
- Air Temp/Humididty - HiLetgo DHT22/AM2302 Digital Temperature and Humidity Sensor
- Lake level - SunFounder Ultrasonic Module HC-SR04 Distance Sensor
- Barometer - SainSmart BMP085 Module Digital Barometric Pressure Sensor

## Ansible playbook

This playbook will install all required packages and scripts.


```
$ ansible-playbook -i pi-dock.charcalla.com, pi_dock.yml -k -K -u ubuntu
SSH password:
SUDO password[defaults to SSH password]:

PLAY [all] *********************************************************************
```

## pi_dock_sensors.sh usage:

The main script which creates prometheus metrics.

```
###
# Dock exporter
###
# 
# Usage: pi_dock_sensors.sh -e <elevation> -a <ada2302 gpio pin> -s <update interval> #	 -o <prom output file> -i <sensor script path> -d
#
# This program runs indefinitely.
# <CTRL C> to exit
#
# Options:
#   -e Elevation, Meters above sea level of ultrasonic range finder. 
#      Default: 222
#   -a ADA 2302 GPIO pin. Default: 17
#   -s Sensors update interval. (Sleep durration in main loop) 
#      Default: 10
#   -o Prometheus textcollector output. 
#      Default: /var/lib/node_exporter/textfile_collector/dock_pi_sensors.prom
#   -i Install path of the various sensor scripts. 
#      Default: /home/ubuntu/pi_dock/
#   -d Run as a systemd service.
###
``` 

#!/bin/bash

#
# Simple script to report the values of various
# sensors and other scripts to influxdb
#
# jcharcalla 12-06-16
#
# This script is created by a ansible template.
# Host: 15ab91d5e81c 
# Path: /ansible/roles/pi_dock/templates/pi_dock.sh.j2
#
#
# Change log
#
# 01-06-2017 - Converted elvevation range sensor to a function and added
# a check to cut down on false readings that are obviously wrong.


#
# Variables
#
PYTHON_PATH=/usr/bin/python
RANGE_FINDER_SCRIPT=/home/pi/pi_dock/range_sensor.py
ADA_2302_SCRIPT=/home/pi/pi_dock/Adafruit_Python_DHT/examples/AdafruitDHT.py
BMP085_SCRIPT=/home/pi/pi_dock/Adafruit_Python_BMP/examples/simpletest.py
ADA_2302_PIN=17
DEV_1WIRE1_TEMP=28-0134624f68ff
DEV_1WIRE2_TEMP=28-0459252f39ff
SENSOR_ELEVATION=222

#
# functions
#

lake_elevation_measurement () {
	# Get distance to water level in cm from the HC-SR04 range sensor
	DISTANCE_CM=$(${PYTHON_PATH} ${RANGE_FINDER_SCRIPT} | grep "Distance:" | awk '{print $2}')
	# epoch time of reading for the db insert
	DISTANCE_EPOCH=$(date +%s%9N)
	# convert centimeters to meters to subtract from altitude
	DISTANCE_M=$(echo "scale=2; ${DISTANCE_CM} / 100"| bc)
	#LAKE_LEVEL_M=$(echo "${BMP085_ALT} - ${DISTANCE_M}"| bc)
	LAKE_LEVEL_M=$(echo "scale=2; ${SENSOR_ELEVATION} - ${DISTANCE_M}"| bc)
}

lake_elevation_verified () {
	# take initial reading
	lake_elevation_measurement
	# set reading 1st reading to previous reading and drop the decimal point
	PREVIOUS_DISTANCE_CM=$(echo ${DISTANCE_CM} | awk -F '.' '{print $1}')
	echo "outside verification loop, PREVIOUS_DISTANCE_CM=${PREVIOUS_DISTANCE_CM}"
	# take a 2nd reading
	lake_elevation_measurement
	# compare the 2 readings and take another if they don't match. continue doing 
	# this until we get a match. Tolerance is within 1cm accuracy.
	while [ $PREVIOUS_DISTANCE_CM -ne $(echo ${DISTANCE_CM} | awk -F '.' '{print $1}') ]
	do
		echo "in verification loop, DISTANCE_CM=${DISTANCE_CM}"
		echo "in verification loop, PREVIOUS_DISTANCE_CM=${PREVIOUS_DISTANCE_CM}"
		PREVIOUS_DISTANCE_CM=$(echo ${DISTANCE_CM} | awk -F '.' '{print $1}')
		lake_elevation_measurement
	done
}

# I really need to get better with awk, lets get the air temp
# / humididty in a couple steps
# Get readings from Adafruit 2302 sensor
A2302_RESULT=$(${PYTHON_PATH} ${ADA_2302_SCRIPT} 2302 ${ADA_2302_PIN})
A2302_EPOCH=$(date +%s%9N)
ADA_2302_TEMP=$(echo ${A2302_RESULT} | awk '{print $1;}' | cut -d"=" -f2 | cut -d"*" -f1)
ADA_2302_HUMID=$(echo ${A2302_RESULT} | awk '{print $2;}' | cut -d"=" -f2 | cut -d"%" -f1)

# Get readings from the BMP085 Barometer
BMP085_RESULT=$(${PYTHON_EPOCHPATH} ${BMP085_SCRIPT})
BMP085_EPOCH=$(date +%s%9N)
BMP085_TEMP=$(echo ${BMP085_RESULT} | awk '{print $3}')
# Pressure
BMP085_PRESS=$(echo ${BMP085_RESULT} | awk '{print $7}')
BMP085_ALT=$(echo ${BMP085_RESULT} | awk '{print $11}')
# Sea level pressure
BMP085_SLPRESS=$(echo ${BMP085_RESULT} | awk '{print $16}')

# Get the water temp from the 1wire temp sensors
WATER1_TEMP=$(cat /sys/bus/w1/devices/${DEV_1WIRE1_TEMP}/w1_slave | grep "t=" | cut -d"=" -f2)
WATER1_EPOCH=$(date +%s%9N)
WATER1_TEMP=$(echo "scale=2; ${WATER1_TEMP} / 1000" | bc)

WATER2_TEMP=$(cat /sys/bus/w1/devices/${DEV_1WIRE2_TEMP}/w1_slave | grep "t=" | cut -d"=" -f2)
WATER2_EPOCH=$(date +%s%9N)
WATER2_TEMP=$(echo "scale=2; ${WATER2_TEMP} / 1000" | bc)

#
# Gather readings
#

# This should produce a more accurate lake level reading.
lake_elevation_verified

#
# Debug
#

echo ${DISTANCE_CM}
echo ${ADA_2302_TEMP}
echo ${ADA_2302_HUMID}
echo ${BMP085_TEMP}
echo ${BMP085_PRESS}
echo ${BMP085_ALT}
echo ${BMP085_SLPRESS}
echo ${WATER1_TEMP}
echo ${WATER2_TEMP}

echo "Current lake level: ${LAKE_LEVEL_M}"

#
# databse insert
#

# provided you have created an influxdb we would write to it here
curl -i -XPOST 'http://192.168.79.10:8086/write?db=sensors' --data-binary 'rf_distance,host='$(hostname)' value='${DISTANCE_CM}' '${DISTANCE_EPOCH}'
a2302_temp,host='$(hostname)',type=temp,unit=c value='${ADA_2302_TEMP}' '${A2302_EPOCH}'
a2302_humid,host='$(hostname)',type=humid value='${ADA_2302_HUMID}' '${A2302_EPOCH}'
bmp085_temp,host='$(hostname)',type=temp,unit=c value='${BMP085_TEMP}' '${BMP085_EPOCH}'
bmp085_press,host='$(hostname)',type=ps value='${BMP085_PRESS}' '${BMP085_EPOCH}'
bmp085_alt,host='$(hostname)',type=alt,unit=m value='${BMP085_ALT}' '${BMP085_EPOCH}'
bmp085_slpress,host='$(hostname)',type=ps value='${BMP085_SLPRESS}' '${BMP085_EPOCH}'
lake_temp_1,host='$(hostname)',type=temp,unit=c value='${WATER1_TEMP}' '${WATER1_EPOCH}'
lake_temp_2,host='$(hostname)',type=temp,unit=c value='${WATER2_TEMP}' '${WATER2_EPOCH}'
lake_level,host='$(hostname)',type=alt,unit=m value='${LAKE_LEVEL_M}' '${DISTANCE_EPOCH}''

exit 0

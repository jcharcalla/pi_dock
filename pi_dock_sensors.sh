#!/bin/bash


print_usage() {
PROG_NAME=$(basename "$0")
cat <<EOF
###
# Dock exporter
###
# 
# Usage: ${PROG_NAME} -e <elevation> -a <ada2302 gpio pin> -s <update interval> \
#	 -o <prom output file> -i <sensor script path> -d
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
EOF
}

# Set defaults
SYSTEMD_SERVICE=0
SLEEP_INTERVAL=10
ADA_2302_PIN=17
SENSOR_ELEVATION=222
OUTPUT_FILE="/var/lib/node_exporter/textfile_collector/dock_pi_sensors.prom"
SCRIPTS_PATH="/home/ubuntu/pi_dock/"
W1_TEMP=(0)

while getopts h?e:a:s:o:di: arg ; do
      case $arg in
        e) SENSOR_ELEVATION="${OPTARG}" ;;
        a) ADA_2302_PIN="${OPTARG}" ;;
        s) SLEEP_INTERVAL="${OPTARG}" ;;
        o) OUTPUT_FILE="${OPTARG}" ;;
        d) SYSTEMD_SERVICE=1 ;;
	i) SCRIPTS_PATH="${OPTARG}" ;;
        h|\?) print_usage; exit 1;;
      esac
done

PYTHON_PATH=/usr/bin/python
HOSTNAME=$(hostname)

break_loop (){
  # quit
  echo "Caught SIGINT SIGTERM, exiting gracefully"
  exit 0
}

trap 'break_loop' SIGINT
trap 'break_loop' SIGTERM



w1_sensor (){
# Check temp sensors
for sensor in $(ls /sys/bus/w1/devices/)
do 
	W1_SENSOR=$(echo ${sensor} | grep -v "w1_bus_master1")
	for i in ${W1_SENSOR}
	do
	        RAW_TEMP=$(cat /sys/bus/w1/devices/${i}/w1_slave | grep "t=" | cut -d"=" -f2)
		W1_TEMP+=($(echo "scale=2; ${RAW_TEMP} / 1000" | bc))
	done
done
}

ada2302_sensor () {
	#ADA_2302_PIN=17
	A2302_RESULT=$(${PYTHON_PATH} ${SCRIPTS_PATH}Adafruit_Python_DHT/examples/AdafruitDHT.py 2302 ${ADA_2302_PIN})
	ADA_2302_TEMP=$(echo ${A2302_RESULT} | awk '{print $1;}' | cut -d"=" -f2 | cut -d"*" -f1)
	ADA_2302_HUMID=$(echo ${A2302_RESULT} | awk '{print $2;}' | cut -d"=" -f2 | cut -d"%" -f1)
}

range_finder (){
	DISTANCE_CM=$(${PYTHON_PATH} ${SCRIPTS_PATH}range_sensor.py | grep "Distance:" | cut -d " " -f2)
	## Add error checking here
}

bmp085_sensor () {
	BMP085_RESULT=$(${PYTHON_PATH} ${SCRIPTS_PATH}Adafruit_Python_BMP/examples/simpletest.py)

	BMP085_TEMP=$(echo ${BMP085_RESULT} | awk '{print $3}')
        # Pressure
        BMP085_PRESS=$(echo ${BMP085_RESULT} | awk '{print $7}')
        BMP085_ALT=$(echo ${BMP085_RESULT} | awk '{print $11}')
        # Sea level pressure
        BMP085_SLPRESS=$(echo ${BMP085_RESULT} | awk '{print $16}')
}

if [ ${SYSTEMD_SERVICE} -eq 1 ]
then
  systemd-notify --ready --status="Ready to report Dock metrics."
  echo "Systemd-notify: Ready to report Dock metrics."
fi


# inifinite loop for polling sensors
echo "Entering main loop."
while true
do
  unset W1_TEMP

  w1_sensor
  range_finder
  bmp085_sensor
  ada2302_sensor

  echo "##### $(date) #####" > ${OUTPUT_FILE}
  echo "dock_a2302_temp{host=\"${HOSTNAME}\",type=\"temp\",unit=\"c\"} ${ADA_2302_TEMP}" >> ${OUTPUT_FILE}
  echo "dock_a2302_humidity{host=\"${HOSTNAME}\",type=\"humidity\"} ${ADA_2302_HUMID}" >> ${OUTPUT_FILE}
  echo "dock_bmp085_temp{host=\"${HOSTNAME}\",type=\"temp\",unit=\"c\"} ${BMP085_TEMP}" >> ${OUTPUT_FILE}
  echo "dock_bmp085_pressure{host=\"${HOSTNAME}\",type=\"pressure\"} ${BMP085_PRESS}" >> ${OUTPUT_FILE}
  echo "dock_bmp085_altitude{host=\"${HOSTNAME}\",type=\"altitide\",unit=\"m\"} ${BMP085_ALT}" >> ${OUTPUT_FILE}
  echo "dock_bmp085_slpressure{host=\"${HOSTNAME}\",type=\"pressure\"} ${BMP085_SLPRESS}" >> ${OUTPUT_FILE}

  # convert centimeters to meters to subtract from altitude
  DISTANCE_M=$(echo "scale=2; ${DISTANCE_CM} / 100"| bc)
  #DISTANCE_M=$(( ${DISTANCE_CM} / 100 ))
  #LAKE_LEVEL_M=$(echo "${BMP085_ALT} - ${DISTANCE_M}"| bc)
  LAKE_LEVEL_M=$(echo "scale=2; ${SENSOR_ELEVATION} - ${DISTANCE_M}"| bc)
  #LAKE_LEVEL_M=$(( ${SENSOR_ELEVATION} - ${DISTANCE_M} ))
  echo "dock_lake_level{host=\"${HOSTNAME}\",type=\"altitude\",unit=\"m\"} ${LAKE_LEVEL_M}" >> ${OUTPUT_FILE}

  TEMP_LOOP=0
  for lake_temp in ${W1_TEMP[@]}
  do
  	echo "dock_water_temp{host=\"${HOSTNAME}\",type=\"temp\",unit= \"c\",sensor=\"${TEMP_LOOP}\"} ${W1_TEMP[${TEMP_LOOP}]}" >> ${OUTPUT_FILE}
	((TEMP_LOOP++))
  done
  
  sleep ${SLEEP_INTERVAL}
done

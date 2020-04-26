#!/bin/bash

# half step produces 1024 quaters or 2048 halves or 4096 wholes of 360
STEP_MODE="half"
# zero point of scale in meters, lowest level on scale eqaul to what elevation
ZERO_POINT=240.5

# Multiple for scale .915 meters to equal 1024 half steps, or 1/4 of 360 degrees
# MULTIPLE="2238.25" # might work better on the 3/4 clock scale.
# MULTIPLE="1024"
MULTIPLE="613.1736"

# Find current lake level
# CURRENT_LAKE_LEVEL=$(curl -s 'http://humboldt:9090/api/v1/query?query=dock_lake_level' | jq '.data.result[].value[1]' | tr -d "\"")
CURRENT_LAKE_LEVEL=$(curl -s 'http://humboldt:9090/api/v1/query?query=avg_over_time(dock_lake_level[180s])' | jq '.data.result[].value[1]' | tr -d "\"")

STEP_FILE="/home/ubuntu/ll_step"

if [  -f ${STEP_FILE} ]
then
  # Check last steper position
  STEP_POSITION=$(cat ${STEP_FILE})
else
  STEP_POSITION=0
  echo 0 > ${STEP_FILE}
fi


ABOVE_ZERO=$( echo "scale=4; ${CURRENT_LAKE_LEVEL} - ${ZERO_POINT}" | bc )

# Point on scale of zero to 2048
SCALED_ELEVATION=$( echo "scale=4; ${ABOVE_ZERO} * ${MULTIPLE}" | bc )
# remove the decimal (not sure why scale=0 didnt work)
SCALED_ELEVATION=$( echo "${SCALED_ELEVATION=} / 1" | bc )

if [ ${STEP_POSITION} -le ${SCALED_ELEVATION} ]
then
	# STEPS=$(( ${STEP_POSITION} - ${SCALED_ELEVATION} ))
	DIRECTION="forward"
	STEPS=$(( ${SCALED_ELEVATION} - ${STEP_POSITION} ))
else
	# STEPS=$(( ${SCALED_ELEVATION} - ${STEP_POSITION} ))
	DIRECTION="reverse"
	STEPS=$(( ${STEP_POSITION} - ${SCALED_ELEVATION} ))
fi

echo ${SCALED_ELEVATION} > ${STEP_FILE}

echo  "${CURRENT_LAKE_LEVEL} - ${ZERO_POINT} = ${ABOVE_ZERO} | ${SCALED_ELEVATION}"

echo "pi_stepper.sh -d ${DIRECTION} -s ${STEPS} -m ${STEP_MODE} -1 4 -2 17 -3 27 -4 22 #Elevation: ${CURRENT_LAKE_LEVEL}"

# Run the stepper control
/home/ubuntu/github/pi_stepper/pi_stepper.sh -d ${DIRECTION} -s ${STEPS} -m ${STEP_MODE} -1 4 -2 17 -3 27 -4 22


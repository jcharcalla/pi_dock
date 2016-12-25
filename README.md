# pi_dock
Ansible role for a Raspberry PI based lake level / temperature monitoring project.

This project makes use of various sensors connected to the GPIO pins of a Raspberry pi. Data provided by the sensors  can then be sent to an InfluxDB using http. The included ansible role will install all required packages and configure the collection script/cronjob accordingly.

### Sensor list:
- Water Temp - Vktech 3M Waterproof Digital Temperature Temp Sensor Probe DS18b20
- Air Temp/Humididty - HiLetgo DHT22/AM2302 Digital Temperature and Humidity Sensor
- Lake level - SunFounder Ultrasonic Module HC-SR04 Distance Sensor
- Barometer - SainSmart BMP085 Module Digital Barometric Pressure Sensor

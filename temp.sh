#! /bin/sh

# Path to IIO device
XADC_PATH=/sys/bus/iio/devices/iio:device0

# Temperature parameters
OFF=`cat $XADC_PATH/in_temp0_offset`
RAW=`cat $XADC_PATH/in_temp0_raw`
SCL=`cat $XADC_PATH/in_temp0_scale`

FORMULA="(($OFF+$RAW)*$SCL)/1000.0"
VAL=`echo "scale=2;${FORMULA}" | bc`

echo "in_temp0 = ${VAL} C"

#! /bin/sh

DIR=/media/mmcblk0p1/apps/sdr_transceiver_ft8

mount -o rw,remount /media/mmcblk0p1

$DIR/stop.sh

nano $DIR/decode-ft8.sh
nano $DIR/upload-ft8.sh
nano $DIR/write-c2-files-day.cfg
nano $DIR/write-c2-files-night.cfg
nano $DIR/write-c2-files-gray.cfg

mount -o ro,remount /media/mmcblk0p1

lbu commit -d

$DIR/start.sh


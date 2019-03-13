#! /bin/sh

DIR=/media/mmcblk0p1/apps/sdr_transceiver_ft8

rw
cp $DIR/decode-ft8.sh.orig $DIR/decode-ft8.sh
ro
lbu commit -d

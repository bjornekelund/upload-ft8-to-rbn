#! /bin/sh

DIR=/media/mmcblk0p1/apps/sdr_transceiver_ft8

chmod +x *.sh radioday upload-to-rbn

rw
cp temp.sh ~

cp write-c2-files-day.cfg $DIR
cp write-c2-files-night.cfg $DIR
cp write-c2-files-gray.cfg $DIR

cp radioday $DIR
cp upload-to-rbn $DIR

test `cat decode-ft8.sh | grep radioday | wc -l` || cp $DIR/decode-ft8.sh $DIR/decode-ft8.sh.orig
cp decode-ft8.sh $DIR
ro
lbu commit -d


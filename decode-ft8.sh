#! /bin/sh

# Station parameters
GRID=
UDPPORT=2238
GRAYDURATION=2
# End of station parameters

JOBS=4
NICE=10

BROADCASTIP=`ip a s dev eth0 | awk '/inet / {print $4}'`
DIR=`readlink -f $0`
DIR=`dirname $DIR`

RECORDER=$DIR/write-c2-files
CONFIGD=write-c2-files-day.cfg
CONFIGN=write-c2-files-night.cfg
CONFIGG=write-c2-files-gray.cfg
SCONFIG=write-c2-files-`$DIR/radioday $GRID $GRAYDURATION`.cfg
DECODER=$DIR/ft8d-master/ft8d
SLEEP=$DIR/sleep-to-59

#date

test $DIR/$CONFIGD -ot $CONFIGD || cp $DIR/$CONFIGD $CONFIGD
test $DIR/$CONFIGN -ot $CONFIGN || cp $DIR/$CONFIGN $CONFIGN
test $DIR/$CONFIGG -ot $CONFIGG || cp $DIR/$CONFIGG $CONFIGG

echo "Sleeping until full minute ..."

$SLEEP

sleep 1

date

TIMESTAMP=`date --utc +'%y%m%d_%H%M'`

echo "Recording using $SCONFIG ..."

killall -q $RECORDER

$RECORDER $SCONFIG

echo "Done recording. Decoding ..."

for file in ft8_*_$TIMESTAMP.c2
do
  while [ `pgrep $DECODER | wc -l` -ge $JOBS ]
  do
    sleep 1
  done
  nice -n $NICE $DECODER $file &
done > decodes_$TIMESTAMP.txt

wait

date

echo "Done decoding. Uploading to RBN ..."
#$DIR/upload-to-rbn.pl $CALL $GRID $HOSTIP $UDPPORT

$DIR/upload-to-rbn $BROADCASTIP $UDPPORT decodes_$TIMESTAMP.txt

rm -f ft8_*_$TIMESTAMP.c2

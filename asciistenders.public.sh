#!/bin/bash

# set vars
IPLAYER_DIR=/tmp/iplayer/EastEnders
CAPTURE_DIR=/tmp/capture
SOUND_DIR=/tmp/sound
YOUTUBE_DIR=/tmp/youtube
LOGFILE=/tmp/asciienders-output.log
# set python location
export PYTHONPATH=$PYTHONPATH:/usr/local/lib/python2.7/dist-packages


play(){
# shift pointer out the way
/usr/bin/xdotool mousemove 1023 676
sleep 1

echo "Starting PLAY at $(date)" | tee -a $LOGFILE
# set mplayer size / aspect ratio
export CACA_GEOMETRY=92x26

# start mplayer ascii playback
/usr/bin/mplayer -vo caca $1 &
echo "Finished PLAY at $(date)" | tee -a $LOGFILE
}


get_timestamp (){
# grab the timestamp of the episode, used as the id when uploading
XMLFILE=$(echo $1 | cut -d'.' -f1).xml
BCAST=$(xmlstarlet sel -t -m '//_:firstbcast[1]' -v . -n < "$IPLAYER_DIR/$XMLFILE")
TIMESTAMP=$(date --date=$BCAST +%s)
echo "timestamp is: " $TIMESTAMP | tee -a $LOGFILE
}


capture (){
#make sure we got a window id to capture, bit of an infinite loop though
CAP_COUNT=1
while [ -z "$WINDOWID" ]; do
	# limit capture retries
	if [[ $CAP_COUNT -gt 4 ]]; then
		exit 1
	fi
	sleep 4
	echo "Starting CAPTURE at $(date), attempt " $CAP_COUNT | tee -a $LOGFILE
	#Get the window size to grab
	/usr/bin/xdotool search MPlayer getwindowgeometry > /tmp/window.txt
	# shift pointer out the way
	/usr/bin/xdotool mousemove 1023 676
	# get dimensions for screen capture
	WINDOWID=$(grep Window /tmp/window.txt | awk '{print $2}')
	echo "Window ID is $WINDOWID" | tee -a $LOGFILE
	CAP_COUNT=$((CAP_COUNT+1))
done

XOFFSET=$(grep Position /tmp/window.txt | awk '{print $2}' | awk -F "," '{print $1}')
YOFFSET1=$(grep Position /tmp/window.txt | awk '{print $2}' | awk -F "," '{print $2}')
YOFFSET=`expr $YOFFSET1 - 24`
XSIZE=$(grep Geometry  /tmp/window.txt | awk '{print $2}' | awk -F "x" '{print $1}')
YSIZE=$(grep Geometry  /tmp/window.txt | awk '{print $2}' | awk -F "x" '{print $2}')
echo "Window ID is $WINDOWID" | tee -a $LOGFILE
echo "XSIZE is $XSIZE" | tee -a $LOGFILE
echo "YSIZE is $YSIZE" | tee -a $LOGFILE
echo "XOFFSET is $XOFFSET" | tee -a $LOGFILE
echo "YOFFSET is $YOFFSET" | tee -a $LOGFILE

# screen capture, stream copy
/usr/bin/ffmpeg -y -thread_queue_size 512 -f pulse -i alsa_output.pci-0000_00_04.0.analog-stereo.monitor -f x11grab -r 25 -s "$XSIZE"x"$YSIZE" -i :0.0+"$XOFFSET","$YOFFSET" "$CAPTURE_DIR/$1" &
# kill capture when done, 30 mins episodes
CAPTURE_TASK_PID=$!
sleep 1734
kill $CAPTURE_TASK_PID
# wait for capture to finish and write file
sleep 10
echo "Finished CAPTURE at $(date)" | tee -a $LOGFILE
}


crapsound (){
# reduce audio bitrate, don't want it sounding too professional
echo "Starting CRAPSOUND at $(date)" | tee -a $LOGFILE
/usr/bin/ffmpeg -y -i "$CAPTURE_DIR/$1" -vcodec copy -acodec aac -b:a 5k "$SOUND_DIR/$1"
echo "Finished CRAPSOUND at $(date)" | tee -a $LOGFILE
}


encode (){
# encode for youtube upload
echo "Starting YOUTUBE-ENCODING at $(date)" | tee -a $LOGFILE
# 1080p - bit overkill
# /usr/bin/ffmpeg -y -i "$SOUND_DIR/$1" -codec:v libx264 -crf 21 -bf 2 -flags +cgop -pix_fmt yuv420p -codec:a aac -strict -2 -b:a 384k -r:a 48000 -movflags faststart -vf scale=1920:1080 "$YOUTUBE_DIR/$1"
# 720p
/usr/bin/ffmpeg -y -i "$SOUND_DIR/$1" -codec:v libx264 -crf 21 -bf 2 -flags +cgop -pix_fmt yuv420p -codec:a aac -strict -2 -b:a 384k -r:a 48000 -movflags faststart -vf scale=1280:720 "$YOUTUBE_DIR/$1"
echo "Finished YOUTUBE-ENCODING at $(date)" | tee -a $LOGFILE
}


upload (){
# upload to youtube
echo "Starting UPLOAD at $(date)" | tee -a $LOGFILE
/usr/local/bin/youtube-upload \
--title="Ascii-Stenders $TIMESTAMP" \
--description="Once again, low bite-rate things occur." \
--client-secrets=/home/username/youtube-upload-master/asciistenders.client_secrets.json \
--credentials-file=/home/username/youtube-upload-master/asciistenders.youtube-upload-credentials.json \
--playlist "Ascii-Stenders" \
--privacy="public" \
"$YOUTUBE_DIR/$1"
echo "Finished UPLOAD at $(date)" | tee -a $LOGFILE
}


cleanup(){
	echo "Starting CLEANUP at $(date)" | tee -a $LOGFILE
        echo "Deleting file $1" | tee -a $LOGFILE
        rm -f $IPLAYER_DIR/$1
        rm -f $IPLAYER_DIR/*.xml
	rm -f $CAPTURE_DIR/$1
        rm -f $SOUND_DIR/$1
	rm -f $YOUTUBE_DIR/$1
	echo "Finished CLEANUP at $(date)" | tee -a $LOGFILE
}

echo "Job start at $(date)" | tee -a $LOGFILE
cd $IPLAYER_DIR
FILES="*.mp4"
# check files exist
FILE_COUNT=$(ls -l $FILES | wc -l)
if [ "$FILE_COUNT" -eq "0" ]; then
	echo "No files to process, exiting." | tee -a $LOGFILE
	exit 1
	else
	echo "Got $FILE_COUNT files to process."
fi

# process files
for f in $FILES
do
	echo "filename is $IPLAYER_DIR/$f"
	get_timestamp "$f"
	play "$IPLAYER_DIR/$f"
	capture "$f"
	crapsound "$f"
	encode "$f"
	upload "$f"
	cleanup "$f"
done

echo "Job complete at $(date)" | tee -a $LOGFILE


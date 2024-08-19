#sudo sh -c "echo 8 > /sys/module/adv7180/parameters/dbg_input"
# This is by far the most stable recorder I found.
filename=$1

#sudo v4l2-ctl -c brightness=-128 
#sudo ffmpeg -y -hide_banner -use_wallclock_as_timestamps 1 -t 20 -i /dev/video0 -c:v h264_v4l2m2m -cfr 23 ${filename}.mp4


#sudo ffmpeg -y -hide_banner -use_wallclock_as_timestamps 1 -t 20 -r 29.97 -i /dev/video0 -c:v h264_v4l2m2m -video_size 720x507 -b:v 8M ${filename}.mp4


#this is from rniwase
#ffmpeg -an -video_size 720x507 -r 29.97 -i /dev/video0 -c:v rawvideo -vf realtime -t 10 ${filename}.asf



#ffmpeg -an -video_size 720x507 -r 29.97 -i /dev/video0 -c:v rawvideo -vf realtime,crop=720:480:0:27 -t 10 out_crop.asf

ffmpeg -y -hide_banner \
    -use_wallclock_as_timestamps 1 \
    -t 10 \
    -i /dev/video0 \
    -vf "drawtext=text='%{localtime}':fontcolor=white:x=100:y=100" \
    -c:v h264_v4l2m2m \
    -video_size 720x507 -r 29.97 \
    -b:v 2M \
    ${filename}.mp4

#!/bin/sh

gst-launch-1.0 filesrc location=/local/workspace/tappas/apps/gstreamer/raspberrypi/detection/resources/detection.mp4 name=src_0 ! \
qtdemux ! h264parse ! avdec_h264 max_threads=2 ! \
queue max-size-buffers=5 max-size-bytes=0 max-size-time=0 ! \
videoscale n-threads=2 ! \
queue max-size-buffers=5 max-size-bytes=0 max-size-time=0 ! \
videoconvert n-threads=2 ! \
queue leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
hailonet hef-path=/local/workspace/tappas/apps/gstreamer/general/detection/resources/yolov5m_wo_spp_60p.hef batch-size=1 ! \
queue leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
hailofilter function-name=yolov5 \
    so-path=/local/workspace/tappas/apps/gstreamer/libs/post_processes/libyolo_post.so \
    config-path=/local/workspace/tappas/apps/gstreamer/general/detection/resources/configs/yolov5.json qos=false ! \
queue leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
hailotracker name=hailo_tracker class-id=1 keep-past-metadata=true \
    kalman-dist-thr=.7 iou-thr=.8 keep-tracked-frames=2 keep-lost-frames=50 ! \
queue leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
hailofilter function-name=my_function \
    so-path=/local/workspace/tappas/apps/gstreamer/libs/post_processes/libcheck_track_id.so ! \
    config-path=/local/workspace/tappas/apps/gstreamer/general/detection/resources/configs/yolov5.json qos=false ! \
queue leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
hailooverlay qos=false ! \
queue leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
videoconvert n-threads=2 qos=false ! \
queue leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
fpsdisplaysink video-sink=ximagesink text-overlay=false name=hailo_display sync=false
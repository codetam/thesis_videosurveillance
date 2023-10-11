#!/bin/bash
set -e

sources=""
streamrouter_input_streams=""
function_name=""
number_of_streams=0
fps=0

function create_func_name() {
    if [ "$number_of_streams" -eq 2 ]; then
        function_name="two_streams"
    fi
    if [ "$number_of_streams" -eq 4 ]; then
        function_name="four_streams"
    fi
    if [ "$number_of_streams" -eq 8 ]; then
        function_name="eight_streams"
    fi
    if [ "$number_of_streams" -eq 16 ]; then
        function_name="sixteen_streams"
    fi
}

function create_sources() {
    for ((i = 0; i < number_of_streams; i++));
    do
        sources+="rtspsrc location=rtsp://$IP_ADDR:8554/cam$i name=source_$i ! \
                    queue leaky=downstream max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
                    capsfilter caps="application/x-rtp,media=video" ! \
                    decodebin ! \
                    queue leaky=downstream max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
                    videorate ! video/x-raw,framerate=$fps/1 ! \
    	            videoconvert ! videoscale qos=false n-threads=4 ! \
    	            video/x-raw,width=640,height=640,pixel-aspect-ratio=1/1 ! \
                    queue leaky=downstream max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
                    fun.sink_$i "
        streamrouter_input_streams+=" src_$i::input-streams=\"<sink_$i>\""
    done
}

function main() {
    if [ $# -ne 2 ]; then
        echo "Usage: $0 <number_of_streams> <fps>"
        exit 1
    fi
    # Check if the first argument is an integer
    if ! [[ $1 =~ ^[0-9]+$ ]]; then
        echo "Error: The first argument must be an integer."
        exit 1
    fi

    # Check if the second argument is an integer
    if ! [[ $2 =~ ^[0-9]+$ ]]; then
        echo "Error: The second argument must be an integer."
        exit 1
    fi
    number_of_streams=$1
    fps=$2

    create_func_name
    create_sources

    pipeline="gst-launch-1.0 \
    hailoroundrobin name=fun ! \
    queue leaky=downstream max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
    hailonet hef-path=/local/workspace/tappas/apps/gstreamer/general/multistream_detection/resources/yolov5m_wo_spp_60p.hef ! \
    queue leaky=downstream max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
    hailofilter \
       function-name=yolov5 \
       so-path=/local/workspace/tappas/apps/gstreamer/libs/post_processes/libyolo_post.so \
       config-path=/local/workspace/tappas/apps/gstreamer/general/detection/resources/configs/yolov5.json qos=false ! \
    queue leaky=downstream max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
    hailotracker name=hailo_tracker keep-past-metadata=true \
       kalman-dist-thr=.7 iou-thr=.8 keep-tracked-frames=2 keep-lost-frames=50 class-id=1 ! \
    queue leaky=downstream max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
    hailofilter \
       function-name=$function_name \
       so-path=/local/workspace/tappas/apps/gstreamer/libs/post_processes/libprint_json.so \
       config-path=/local/workspace/tappas/apps/gstreamer/general/detection/resources/configs/yolov5.json qos=false ! \
    queue leaky=downstream max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
    fakesink name=hailo_display sync=true \
    $sources"
    eval "${pipeline}"
}

main $@
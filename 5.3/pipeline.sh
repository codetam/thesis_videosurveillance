#!/bin/bash
set -e

sources=""
streamrouter_input_streams=""

function create_sources() {
    sources+="filesrc location=/local/workspace/tappas/apps/gstreamer/general/multistream_detection/resources/detection0.mp4 \
            name=source_0 ! qtdemux ! h264parse ! avdec_h264 max_threads=2 ! \
    	    queue leaky=downstream max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
    	    videoconvert ! videoscale qos=false n-threads=2 ! \
    	    video/x-raw,width=640,height=640,pixel-aspect-ratio=1/1 ! \
    	    fun.sink_0 sid.src_0 ! \
    	    queue leaky=downstream max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
    	    comp.sink_0 "
     streamrouter_input_streams+=" src_0::input-streams=\"<sink_0>\""

    sources+="filesrc location=/local/workspace/tappas/apps/gstreamer/general/multistream_detection/resources/detection1.mp4 \
            name=source_1 ! qtdemux ! h264parse ! avdec_h264 max_threads=2 ! \
            queue leaky=downstream max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
            videoconvert ! videoscale qos=false n-threads=2 ! \
            video/x-raw,width=640,height=640,pixel-aspect-ratio=1/1 ! \
            fun.sink_1 sid.src_1 ! \
	        queue leaky=downstream max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
            comp.sink_1 "
     streamrouter_input_streams+=" src_1::input-streams=\"<sink_1>\""
}


function main() {
    create_sources

    pipeline="gst-launch-1.0 \
    hailoroundrobin name=fun ! \
    queue leaky=downstream max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
    hailonet hef-path=/local/workspace/tappas/apps/gstreamer/general/multistream_detection/resources/yolov5m_wo_spp_60p.hef ! \
    queue leaky=downstream max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
    hailofilter \
    function-name=my_function \
    so-path=/local/workspace/tappas/apps/gstreamer/libs/post_processes/libprint_detections_to_file.so \
    config-path=/local/workspace/tappas/apps/gstreamer/general/detection/resources/configs/yolov5.json qos=false ! \
    queue leaky=downstream max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
    hailooverlay ! \
    hailostreamrouter name=sid $streamrouter_input_streams compositor name=comp start-time-selection=0 \
    sink_0::xpos=0 sink_0::ypos=0 \
    sink_1::xpos=640 sink_1::ypos=0 ! \
    queue leaky=downstream max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
    videoconvert ! \
    queue leaky=downstream max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
    fpsdisplaysink video-sink=ximagesink name=hailo_display sync=false text-overlay=false \
    $sources"

    eval "${pipeline}"
}

main $@
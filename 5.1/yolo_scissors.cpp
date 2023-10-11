#include <iostream>
#include <typeinfo>
#include "yolo_scissors.hpp"

void my_function(HailoROIPtr roi, void *params_void_ptr)
{
    // Decodifica dei tensori
    YoloParams *params = reinterpret_cast<YoloParams *>(params_void_ptr);
    auto post = Yolov5(roi, params);
    auto detections = post.decode();
    hailo_common::add_detections(roi, detections);
    for(int i=0; i < detections.size(); i++){
        // Stampa su terminale
        std::cout << "Detection n. " << i <<": " <<  detections[i].get_label() << std::endl;
        // Check della label "scissors"
        if(detections[i].get_label() ==  "scissors" && gpioInitialise() >= 0){
            gpioSetMode(8, PI_OUTPUT);
            gpioWrite(8, 1);
        }
	}
}

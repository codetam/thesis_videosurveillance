#include "print_detections_to_file.hpp"

using namespace std;
char prev_date[30] = "";

void my_function(HailoROIPtr roi, void *params_void_ptr)
{
    // Decodifica dei tensori
    YoloParams *params = reinterpret_cast<YoloParams *>(params_void_ptr);
    auto post = Yolov5(roi, params);
    auto detections = post.decode();
    hailo_common::add_detections(roi, detections);
    
    string filename = "/local/workspace/tappas/yolo_contents.txt";
    time_t my_time = time(NULL);
    // Stringa del timestamp corrente
    char* current_time = ctime(&my_time);
    current_time[strcspn(current_time, "\n")] = 0;	

    // Solo se il timestamp è divereso
    if(strcmp(prev_date,current_time) != 0){    
        ofstream outfile;
        // Apre il file di log
        outfile.open(filename, ios_base::app);
        outfile << current_time <<": ";
        for(int i=0; i < detections.size(); i++){
            outfile << endl << "Detection n. " << i << ": " << detections[i].get_label() << endl;
            outfile << "  Confidence: " << detections[i].get_confidence() << endl;
        }
        outfile << endl;
        outfile.close();
        // Salva il nuovo timestamp
        memcpy(prev_date,current_time,30 * sizeof(char));
    }
}
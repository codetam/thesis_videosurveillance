#include "socket_multistream_new.hpp"
#include "rapidjson/document.h"
#include "rapidjson/writer.h"
#include "rapidjson/stringbuffer.h"

using namespace rapidjson;

const int PORT = 8080;
int serverSocket = -1; // -1 Indica che la socket del server non è attiva
int clientSocket = -1; //-1 Indica che il client non si è connesso
char prev_date[30] = "";

int current_stream_num = 0;
bool second_has_passed = false;

// Starts the server socket
void setup_socket() {
    if (serverSocket == -1) {
        serverSocket = socket(AF_INET, SOCK_STREAM, 0);
        if (serverSocket == -1) {
            perror("Error creating socket");
            return;
        }
        struct sockaddr_in serverAddr;
        serverAddr.sin_family = AF_INET;
        serverAddr.sin_port = htons(PORT);
        serverAddr.sin_addr.s_addr = INADDR_ANY;
        if (bind(serverSocket, (struct sockaddr*)&serverAddr, sizeof(serverAddr)) == -1) {
            perror("Error binding");
            close(serverSocket);
            serverSocket = -1;
            return;
        }
        if (listen(serverSocket, 1) == -1) {
            perror("Error listening");
            close(serverSocket);
            serverSocket = -1;
            return;
        }
        // Imposta la socket come non bloccante
        fcntl(serverSocket, F_SETFL, O_NONBLOCK);
    }
}

void my_function(HailoROIPtr roi, int num_streams) {
    /* 
    Il segnale SIGPIPE è ignorato per evitare che il
    programma termini se il client si disconnette
    */
    struct sigaction sa;
    sa.sa_handler = SIG_IGN;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    if (sigaction(SIGPIPE, &sa, 0) == -1) {
        perror(0);
        exit(1);
    }

    setup_socket();
    time_t my_time = time(NULL);
    char* current_time = ctime(&my_time);
    current_time[strcspn(current_time, "\n")] = 0;	

    if (clientSocket == -1) {
        clientSocket = accept(serverSocket, NULL, NULL);
    }
    if (clientSocket != -1) // Se il client si è connesso
    {
        // Crea un documento JSON
        Document document;
        Document::AllocatorType& allocator = document.GetAllocator();
        document.SetObject();

        // Quando un secondo è passato, la flag è impostata a true
        if(strcmp(prev_date,current_time) != 0 && current_stream_num == 0){  
            second_has_passed = true; 
        }
        if(second_has_passed)
        {
            Value detectionsArray(kArrayType);
            for (auto obj : roi->get_objects())
            {
                if(obj->get_type() == HAILO_DETECTION)
                {
                    // Ricava le informazioni per ogni detection
                    HailoDetectionPtr detection = std::dynamic_pointer_cast<HailoDetection>(obj);
                    int default_id = -1;

                    Value detectionObject(kObjectType);
                    detectionObject.AddMember("label", Value(detection->get_label().c_str(), allocator), allocator);
                    detectionObject.AddMember("tracking_id", default_id, allocator);
                    for (auto obj_detection : detection->get_objects())
                    {
                        if(obj_detection->get_type() == HAILO_UNIQUE_ID){
                            HailoUniqueIDPtr id = std::dynamic_pointer_cast<HailoUniqueID>(obj_detection);
                            if (id->get_mode() == GLOBAL_ID || id->get_mode() == TRACKING_ID)
                            {
                                detectionObject["tracking_id"] = id->get_id();
                            }
                        }
                    }
                    // Detection info
                    detectionObject.AddMember("confidence", detection->get_confidence(), allocator);

                    HailoBBox detection_bbox = detection->get_bbox();
                    detectionObject.AddMember("xmin", detection_bbox.xmin(), allocator);
                    detectionObject.AddMember("ymin", detection_bbox.ymin(), allocator);
                    detectionObject.AddMember("width", detection_bbox.width(), allocator);
                    detectionObject.AddMember("height", detection_bbox.height(), allocator);
                    detectionsArray.PushBack(detectionObject, allocator);
                }
            }
            document.AddMember("current_time", Value(current_time, allocator), allocator);
            document.AddMember("stream_number", current_stream_num, allocator);
            document.AddMember("detections", detectionsArray, allocator);

            // Converte il documento JSON in una stringa
            StringBuffer buffer;
            Writer<StringBuffer> writer(buffer);
            writer.SetMaxDecimalPlaces(2);
            document.Accept(writer);
            
            buffer.Put('\n');
            // Invia i dati al client
            ssize_t bytesSent = send(clientSocket, buffer.GetString(), buffer.GetSize(), 0);
            if (bytesSent == -1) {
                printf("Client disconnected\n");
                close(clientSocket);
                clientSocket = -1;
            }
            // La data viene aggiornata
            memcpy(prev_date,current_time,30 * sizeof(char));
            if(current_stream_num == num_streams - 1){
                second_has_passed = false;
            }
        }
    }
    /*
    Viene aggiornato il contatore che tiene conto
    della stream corrente
    */
    current_stream_num = (current_stream_num + 1) % num_streams;
}

void two_streams(HailoROIPtr roi) {
    my_function(roi, 2);
}
void four_streams(HailoROIPtr roi) {
    my_function(roi, 4);
}
void eight_streams(HailoROIPtr roi) {
    my_function(roi, 8);
}
void sixteen_streams(HailoROIPtr roi) {
    my_function(roi, 16);
}
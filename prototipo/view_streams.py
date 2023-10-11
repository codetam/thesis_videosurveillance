import cv2
import json
import socket
import threading

HOST = 'IP_RASPBERRY'
PORT = 8080
num_streams = 8
bounding_boxes = [[] for _ in range(num_streams)]

semaphore = threading.Semaphore(1)
exit_threads = False

def open_rtsp_stream(url):
    cap = cv2.VideoCapture(url)
    if not cap.isOpened():
        raise ValueError(f"Errore nell'aprire la stream RTSP: {url}")
    return cap

# Ridimensiona l'immagine mantenendo il rapporto d'aspetto originale
def resize_image(image, width, height,COLOUR=[0,0,0]):
    h, w, layers = image.shape
    if h > height:
        ratio = height/h
        image = cv2.resize(image,(int(image.shape[1]*ratio),int(image.shape[0]*ratio)))
    h, w, layers = image.shape
    if w > width:
        ratio = width/w
        image = cv2.resize(image,(int(image.shape[1]*ratio),int(image.shape[0]*ratio)))
    h, w, layers = image.shape
    if h < height and w < width:
        hless = height/h
        wless = width/w
        if(hless < wless):
            image = cv2.resize(image, (int(image.shape[1] * hless), int(image.shape[0] * hless)))
        else:
            image = cv2.resize(image, (int(image.shape[1] * wless), int(image.shape[0] * wless)))
    h, w, layers = image.shape
    if h < height:
        df = height - h
        df /= 2
        image = cv2.copyMakeBorder(image, int(df), int(df), 0, 0, cv2.BORDER_CONSTANT, value=COLOUR)
    if w < width:
        df = width - w
        df /= 2
        image = cv2.copyMakeBorder(image, 0, 0, int(df), int(df), cv2.BORDER_CONSTANT, value=COLOUR)
    image = cv2.resize(image,(width,height),interpolation=cv2.INTER_AREA)
    return image

# Thread per la lettura da socket
def receive_data_from_socket():
    global bounding_boxes
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.connect((HOST, PORT))
        buffer = ""
        while not exit_threads:
            data = s.recv(1024).decode('utf-8')
            if not data:
                break
            buffer += data
            while '\n' in buffer:
                # Ogni elemento JSON è separato da uno \n
                line, buffer = buffer.split('\n', 1)
                json_data = json.loads(line)
                stream_number = json_data['stream_number']
                detections = json_data['detections']

                semaphore.acquire()
                bounding_boxes[stream_number] = detections
                semaphore.release()
        print("Disconnecting...")
        s.close()

# Thread per la visualizzazione delle stream
def display_streams():
    stream_urls = []
    base_url = "rtsp://IP_SERVER_RTSP:8554/cam"

    for i in range(num_streams):
        url = f"{base_url}{i}"
        stream_urls.append(url)
    caps = [open_rtsp_stream(url) for url in stream_urls]

    print("Tutte le stream sono state aperte.")
    while True:
        rets = []
        frames = []

        for cap in caps:
            ret, frame = cap.read()
            rets.append(ret)
            frames.append(frame)

        for ret in rets:
            if not ret:
                print("Errore di lettura della stream RTSP")
                break

        for i in range(len(frames)):
            # Ridimensiona l'immagine, i numeri cambiano in base
            # alla risoluzione dello schermo e al numero di video
            frames[i] = resize_image(frames[i], 400, 400)

        semaphore.acquire()
        for i in range(num_streams):
            # Per ogni detection stampa le bounding boxes sul video
            for detection in bounding_boxes[i]:
                label = detection['label']
                confidence = detection['confidence']
                xmin = int(detection['xmin'] * frames[i].shape[1])
                ymin = int(detection['ymin'] * frames[i].shape[0])
                width = int(detection['width'] * frames[i].shape[1])
                height = int(detection['height'] * frames[i].shape[0])
                cv2.rectangle(frames[i], (xmin, ymin), (xmin + width, ymin + height), (0, 255, 0), 1)
                cv2.putText(frames[i], f"{label} {confidence:.2f}", (xmin, ymin - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 1)
        semaphore.release()
        rows = []

        # La visualizzazione del risultato finale cambia in base al numero di stream
        if num_streams == 2:
            combined_frame = cv2.hconcat([frames[0], frames[1]])
        if num_streams == 4:
            row1 = cv2.hconcat([frames[0], frames[1]])
            row2 = cv2.hconcat([frames[2], frames[3]])
            combined_frame = cv2.vconcat([row1, row2])
        if num_streams == 8:
            i = 0
            for _ in range(2):
                row1 = cv2.hconcat([frames[i], frames[i+1]])
                row2 = cv2.hconcat([frames[i+2], frames[i+3]])
                rows.append(cv2.hconcat([row1, row2]))
                i += 4
            combined_frame = cv2.vconcat([rows[0], rows[1]])
        if num_streams == 16:
            i = 0
            for _ in range(4):
                row1 = cv2.hconcat([frames[i], frames[i+1]])
                row2 = cv2.hconcat([frames[i+2], frames[i+3]])
                rows.append(cv2.hconcat([row1, row2]))
                i += 4
            row01 = cv2.vconcat([rows[0], rows[1]])
            row23 = cv2.vconcat([rows[2], rows[3]])
            combined_frame = cv2.vconcat([row01, row23])

        cv2.imshow("Monitoraggio delle stream", combined_frame)
        key = cv2.waitKey(1) & 0xFF
        # Se l'utente preme il tasto 'q', il programma si interrompe
        if key == ord('q'):
            break
    for cap in caps:
        cap.release()

if __name__ == "__main__":
    display_thread = threading.Thread(target=display_streams)
    socket_thread = threading.Thread(target=receive_data_from_socket)

    display_thread.start()
    socket_thread.start()
    
    display_thread.join()
    exit_threads = True
    socket_thread.join()

    cv2.destroyAllWindows()

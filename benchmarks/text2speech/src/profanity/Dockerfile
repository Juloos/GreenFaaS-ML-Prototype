FROM openwhisk/action-python-v3.9

WORKDIR /app

RUN apt-get update && apt-get install ffmpeg libsm6 libxext6 -y
 
RUN pip install python-swiftclient
 
RUN pip install profanity>=1.1
  
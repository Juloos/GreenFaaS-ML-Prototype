FROM openwhisk/action-python-v3.9

WORKDIR /app

RUN apt-get update && apt-get install ffmpeg libsm6 libxext6 libavcodec-extra  espeak-ng -y 
 
RUN pip install python-swiftclient

RUN pip install gTTS

RUN pip install ffmpeg-python

RUN pip install boto3
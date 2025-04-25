from io import BytesIO
from gtts import gTTS
import swiftclient
import datetime
import os
import boto3
import ffmpeg
import subprocess
import socket


def pull(obj, ipv4):
  
    # Swift identifiant
    auth_url = f'http://{ipv4}:8080/auth/v1.0'
    username = 'test:tester'
    password = 'testing'
    out = obj 
    # Connect to Swift
    conn = swiftclient.Connection(
    	authurl=auth_url,
    	user=username,
    	key=password,
    	auth_version='1'
	)
    container = '%s_whiskcontainer' % socket.gethostname()

    file = conn.get_object(container, obj)
    with open(out, 'wb') as f:
        f.write(file[1])

    return ("Ok")


def push(obj, ipv4):

    # Swift identifiant
    auth_url = f'http://{ipv4}:8080/auth/v1.0'
    username = 'test:tester'
    password = 'testing'
	# Connect to Swift
    conn = swiftclient.Connection(
    	authurl=auth_url,
    	user=username,
    	key=password,
    	auth_version='1'
	)
    container = '%s_whiskcontainer' % socket.gethostname()
 
    with open(obj, 'rb') as f:
        conn.put_object(container, obj, contents=f.read())
 
    return ("Ok")


def toSpeech(file):

    with open(file, "r") as f:
            message = f.read()
     
    tts = gTTS(text=message, lang='en')
    mp3fp = BytesIO()
    tts.write_to_fp(mp3fp)
    result = mp3fp.getvalue()
    
    with open("speech.mp3", "wb") as f:
            f.write(result)
    
    return "speech.mp3", message


# Text2Speech helper function
def split_text(text, max_length=1500):

    chunks = []
    while len(text) > max_length:
        split_index = text[:max_length].rfind(' ')
        if split_index == -1:
            split_index = max_length
        chunks.append(text[:split_index + 1].strip())
        text = text[split_index + 1:].strip()
    chunks.append(text)

    return chunks


def espeakSpeech(file):

    with open(file, "r") as f:
            message = f.read()
    command = f'espeak-ng "{message}" --stdout | ffmpeg -y -f wav -i pipe: -acodec libmp3lame speech.mp3 -loglevel quiet'
    # Run the command in the shell
    subprocess.run(command, shell=True, check=True)
    return "speech.mp3", message


def pollySpeech(file):
     
    polly = boto3.client('polly',
                        #    Amazone Api credential here. 
                          region_name='us-west-2')
    
    with open(file, "r") as f:
            message = f.read()

    if len(message) > 1500:
        chunks = split_text(message)
        print("Number of chunks:", len(chunks))
        audio_files = []

        for i, chunk in enumerate(chunks):
            response = polly.synthesize_speech(
                        Text=chunk,
                        OutputFormat="mp3",
                        VoiceId="Joanna",
                        Engine="standard"
                    )
            chunk_file_name = f"chunk_{i}.mp3"

            with open(chunk_file_name, "wb") as f:
                f.write(response['AudioStream'].read())

            audio_files.append(chunk_file_name)
            input_streams = [ffmpeg.input(file) for file in audio_files]
            concat_stream = ffmpeg.concat(*input_streams, v=0, a=1)
            concat_stream.output('speech.mp3').overwrite_output().run()
    else:
        response = polly.synthesize_speech(
                    Text=message,
                    OutputFormat="mp3",
                    VoiceId="Joanna",
                    Engine="standard"
                )
        result = response['AudioStream'].read()

        with open('speech.mp3', 'wb') as file:
            file.write(result)

    return "speech.mp3", message
 

def main(args):
    
    ipv4 = args.get("ipv4", "speech.ipv4.not.given")
    text = args.get("text", "1Ko.txt")

    pull_begin = datetime.datetime.now()
    pull(text, ipv4)
    pull_end = datetime.datetime.now()
    
    process_begin = datetime.datetime.now()
    result, message = espeakSpeech(text)
    process_end = datetime.datetime.now()

    push_begin = datetime.datetime.now()
    push(result, ipv4)
    push_end = datetime.datetime.now()

    response = {
         "textSize" : len(message),
         "fileSize" : os.path.getsize(result),
         "schema" : args.get("schema"),
         "text2speech" : {
            "process" : (process_end - process_begin) / datetime.timedelta(seconds=1),
            "pull" : (pull_end - pull_begin) / datetime.timedelta(seconds=1),
            "push" : (push_end - push_begin) / datetime.timedelta(seconds=1)
         },
         "validation" : args.get("validation", {"process" : 0, "pull" : 0, "push" : 0}),
         "ipv4" : ipv4,
         "text" : text
        }
    
    return  {"body":response, "ipv4" : ipv4}
    


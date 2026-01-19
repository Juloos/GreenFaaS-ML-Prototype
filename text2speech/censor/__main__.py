import swiftclient
import os
import json
import wave
import numpy as np
import datetime
import shutil


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

    _, body = conn.get_object("whiskcontainer", obj, resp_chunk_size=65536)
    with open(out, 'wb') as f:
        shutil.copyfileobj(body, f)

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
 
    with open(obj, 'rb') as f:
        conn.put_object("whiskcontainer", obj, contents=f)
 
    return ("Ok")


def censor(file, ttsid):
    # Open the input WAV file
    with wave.open(file, 'rb') as wav_file:
        params = wav_file.getparams()
        nframes = wav_file.getnframes()
        frames = wav_file.readframes(nframes)

    # Convert audio frames to numpy array
    samples = np.frombuffer(frames, dtype=np.int16)
    samples = samples.copy()

    # Load the index JSON data
    with open(f"{ttsid}.json", 'r') as f:
        indexes = json.load(f)

    # Calculate total number of samples
    total_samples = len(samples)

    for start, end in indexes:
        start_sample = int(start * total_samples)
        end_sample = int(end * total_samples)
        samples[start_sample:end_sample] = 0

    # Convert the modified numpy array back to bytes
    new_frames = samples.tobytes()

    # Save the censored audio to a new file
    with wave.open("censored.wav", 'wb') as wav_out:
        wav_out.setparams(params)
        wav_out.writeframes(new_frames)

    return "censored.wav"

def main(args):

    ipv4 = args.get("ipv4", "censor.ipv4.not.given")
    ttsid = args.get("ttsid", "censor.ttsid.not.given")

    pull_begin = datetime.datetime.now()
    pull(f"{ttsid}.wav", ipv4)
    pull(f"{ttsid}.json", ipv4)
    pull_end = datetime.datetime.now()
    
    process_begin = datetime.datetime.now()
    result = censor(f"{ttsid}.wav", ttsid)
    process_end = datetime.datetime.now()

    push_begin = datetime.datetime.now()
    push(result, ipv4)
    push_end = datetime.datetime.now()

    args["WavCensoredSize"] = os.path.getsize("censored.wav")
    args["censor"] = {
            "process" : (process_end - process_begin) / datetime.timedelta(seconds=1),
            "pull" : (pull_end - pull_begin) / datetime.timedelta(seconds=1),
            "push" : (push_end - push_begin) / datetime.timedelta(seconds=1)
        }

    return  {"body" : args, "ipv4": ipv4, "ttsid": ttsid}

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

def censor(file, ttsid, chunk_frames=4096):
    # Load censor index data
    with open(f"{ttsid}.json", "r") as f:
        indexes = json.load(f)

    # Open input and output WAV files
    with wave.open(file, "rb") as wav_in:
        params = wav_in.getparams()
        total_frames = wav_in.getnframes()

        # Convert relative indexes to absolute frame ranges
        censor_ranges = [
            (int(start * total_frames), int(end * total_frames))
            for start, end in indexes
        ]

        with wave.open("censored.wav", "wb") as wav_out:
            wav_out.setparams(params)

            current_frame = 0
            range_idx = 0

            while current_frame < total_frames:
                # Read a chunk of frames
                frames_to_read = min(chunk_frames, total_frames - current_frame)
                frames = wav_in.readframes(frames_to_read)

                # Convert chunk to NumPy array (no full copy)
                samples = np.frombuffer(frames, dtype=np.int16)

                # Apply censoring for overlapping ranges
                chunk_start = current_frame
                chunk_end = current_frame + frames_to_read

                while range_idx < len(censor_ranges):
                    r_start, r_end = censor_ranges[range_idx]

                    if r_end <= chunk_start:
                        range_idx += 1
                        continue

                    if r_start >= chunk_end:
                        break

                    # Calculate overlap within this chunk
                    local_start = max(0, r_start - chunk_start)
                    local_end = min(frames_to_read, r_end - chunk_start)
                    samples[local_start:local_end] = 0

                    if r_end <= chunk_end:
                        range_idx += 1
                    else:
                        break

                # Write processed chunk
                wav_out.writeframes(samples.tobytes())
                current_frame += frames_to_read

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

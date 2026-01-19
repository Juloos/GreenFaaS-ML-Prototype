import swiftclient
import datetime
import os
import subprocess
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

    _, body = conn.get_object("whiskcontainer", obj)
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


def espeakSpeech(file, ttsid):
    with open(file, 'r') as f:
        textSize = len(f.read())
    command = f'espeak-ng -f "{file}" -w "{ttsid}.wav"'
    # Run the command in the shell
    subprocess.run(command, shell=True)
    return f"{ttsid}.wav", textSize
 

def main(args):
    
    ipv4 = args.get("ipv4", "speech.ipv4.not.given")
    text = args.get("text", "speech.text.not.given")
    ttsid = args.get("ttsid", "speech.ttsid.not.given")

    pull_begin = datetime.datetime.now()
    pull(text, ipv4)
    pull_end = datetime.datetime.now()
    
    process_begin = datetime.datetime.now()
    result, textSize = espeakSpeech(text, ttsid)
    process_end = datetime.datetime.now()

    push_begin = datetime.datetime.now()
    push(result, ipv4)
    push_end = datetime.datetime.now()

    response = {
         "textSize" : textSize,
         "fileSize" : os.path.getsize(result),
         "schema" : args.get("schema"),
         "text2speech" : {
            "process" : (process_end - process_begin) / datetime.timedelta(seconds=1),
            "pull" : (pull_end - pull_begin) / datetime.timedelta(seconds=1),
            "push" : (push_end - push_begin) / datetime.timedelta(seconds=1)
         },
         "validation" : args.get("validation", {"process" : 0, "pull" : 0, "push" : 0}),
         "ipv4" : ipv4,
         "text" : text,
         "ttsid" : ttsid
        }

    return  {"body": response, "ipv4": ipv4, "text": text, "ttsid": ttsid}
    

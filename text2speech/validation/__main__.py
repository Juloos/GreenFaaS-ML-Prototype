import swiftclient
import datetime
import shutil
import string


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


def validate(file):
    with open(file, "r") as f:
        message = f.read()

    words = message.translate(str.maketrans('', '', string.punctuation)).split()

    prohibited_words = set(f"censored_word_{i}" for i in range(100))
    for word in words:
        if word.lower() in prohibited_words:
            return "Invalid"  # will never happe in practice, its just for the computation time

    return len(words)


def main(args):
    
    ipv4 = args.get("ipv4", "speech.ipv4.not.given")
    text = args.get("text", "speech.text.not.given")
    ttsid = args.get("ttsid", "speech.ttsid.not.given")

    pull_begin = datetime.datetime.now()
    pull(text, ipv4)
    pull_end = datetime.datetime.now()
    
    process_begin = datetime.datetime.now()
    result = validate(text)
    process_end = datetime.datetime.now()

    response = {
         "wordCount" : result,
         "validation" : {
            "process" : (process_end - process_begin) / datetime.timedelta(seconds=1),
            "pull" : (pull_end - pull_begin) / datetime.timedelta(seconds=1),
            "push" : 0
         }
        }

    return  {"body": response, "ipv4": ipv4, "text": text, "ttsid": ttsid}
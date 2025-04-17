from profanity import profanity
import swiftclient
import json
import datetime


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
    container = 'whiskcontainer'

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

    container = 'whiskcontainer'
 
    with open(obj, 'rb') as f:
        conn.put_object(container, obj, contents=f.read())
 
    return ("Ok")


def filter(file, char="*"):

    with open(file, "r") as f:
            message = f.read()

    profanity.set_censor_characters("*")
    return profanity.censor(message)


def extract_indexes(text, char="*"):
    indexes = []
    in_word = False
    start = 0
    for index, value in enumerate(text):
        if value == char:
            if not in_word:
                # This is the first character, else this is one of many
                in_word = True
                start = index
        else:
            if in_word:
                # This is the first non-character
                in_word = False
                indexes.append(((start-1)/len(text),(index)/len(text)))
    
    with open("index.json", "w") as f:
            json.dump(indexes, f)

    return "index.json", indexes
    
    
def main(args):

    ipv4 = args.get("ipv4", "profanity.ipv4.not.given")
    text = args.get("text", "1Ko.txt")


    pull_begin = datetime.datetime.now()
    pull(text, ipv4)
    pull_end = datetime.datetime.now()

    process_begin = datetime.datetime.now()
    resultfile, result = extract_indexes(filter(text))
    process_end = datetime.datetime.now()

    push_begin = datetime.datetime.now()
    push(resultfile, ipv4)
    push_end = datetime.datetime.now()


    response = {
         "NumberOfProfanities" : str(len(result)),
         "profanity" : {
            "process" : (process_end - process_begin) / datetime.timedelta(seconds=1),
            "pull" : (pull_end - pull_begin) / datetime.timedelta(seconds=1),
            "push" : (push_end - push_begin) / datetime.timedelta(seconds=1)
         },
        }

    return {"body":response}


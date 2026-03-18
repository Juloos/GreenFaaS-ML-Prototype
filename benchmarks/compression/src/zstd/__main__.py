import swiftclient
import datetime
import os
import shutil
import compression.zstd as zstd


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

    _, body = conn.get_object("whiskcontainer", obj, resp_chunk_size=1024**2)
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
        conn.put_object("whiskcontainer", obj, contents=f, chunk_size=1024**2)
 
    return ("Ok")


def main(args):
    
    ipv4 = args.get("ipv4", "zstd.ipv4.not.given")
    file = args.get("file", "zstd.file.not.given")
    cid = args.get("cid", "zstd.cid.not.given")

    maxLevel = zstd.CompressionParameter.compression_level.bounds()[1]

    pull_begin = datetime.datetime.now()
    pull(file, ipv4)
    pull_end = datetime.datetime.now()
    
    process_begin = datetime.datetime.now()
    with open(file, 'rb') as f:
        with zstd.open(cid, 'wb', level=maxLevel) as fz:
            while True:
                chunk = f.read(1024**2)
                if not chunk:
                    break
                fz.write(chunk)
    process_end = datetime.datetime.now()

    push_begin = datetime.datetime.now()
    push(cid, ipv4)
    push_end = datetime.datetime.now()

    response = {
         "fileSize" : os.path.getsize(file),
         "archiveSize" : os.path.getsize(cid),
         "variant" : "zstd",
         "compression" : {
            "process" : (process_end - process_begin) / datetime.timedelta(seconds=1),
            "pull" : (pull_end - pull_begin) / datetime.timedelta(seconds=1),
            "push" : (push_end - push_begin) / datetime.timedelta(seconds=1)
         },
         "validation" : args.get("validation", {"process" : 0, "pull" : 0, "push" : 0}),
         "ipv4" : ipv4,
         "file" : file,
         "cid" : cid
        }

    return  {"body": response, "ipv4": ipv4, "file": file, "cid": cid}
    

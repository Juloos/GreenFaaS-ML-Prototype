import swiftclient
import datetime
import os
import shutil


class BrotliFile:
    """Custom file-like interface for brotli streaming compression."""
    def __init__(self, filename, mode, quality=11):
        global zipper  # Assumes zipper is brotli
        self.filename = filename
        self.mode = mode
        self.compressor = zipper.Compressor(quality=quality)
        self.file = open(filename, 'wb')
        
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()
        return False
    
    def write(self, data):
        """Compress and write data incrementally."""
        compressed = self.compressor.process(data)
        if compressed:
            self.file.write(compressed)
    
    def close(self):
        """Flush remaining compressed data."""
        if not self.file.closed:
            # Finish compression
            compressed = self.compressor.finish()
            if compressed:
                self.file.write(compressed)
            self.file.close()


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

    _, body = conn.get_object("whiskcontainer", obj, resp_chunk_size=64*1024**2)
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
        conn.put_object("whiskcontainer", obj, contents=f, chunk_size=64*1024**2)
 
    return ("Ok")


def main(args):
    import importlib
    
    ipv4 = args.get("ipv4", "zip.ipv4.not.given")
    file = args.get("file", "zip.file.not.given")
    cid = args.get("cid", "zip.cid.not.given")
    algo = args.get("algo", "zip.algo.not.given")

    match algo:
        case "lz4":
            zipper = importlib.import_module("lz4.frame")
        case "brotli":
            zipper = importlib.import_module("brotli")
        case _:
            zipper = importlib.import_module(f"compression.{algo}")
    maxLevelArg = {
        "zstd": lambda: {"level": zipper.CompressionParameter.compression_level.bounds()[1]},
        "lzma": lambda: {"preset": zipper.PRESET_EXTREME},
        "gzip": lambda: {"compresslevel": 9},
        "bz2": lambda: {"compresslevel": 9},
        "lz4": lambda: {"compression_level": zipper.COMPRESSIONLEVEL_MAX, "block_size": zipper.BLOCKSIZE_MAX4MB},
        "brotli": lambda: {"quality": 11}
    }[algo]()

    pull_begin = datetime.datetime.now()
    pull(file, ipv4)
    pull_end = datetime.datetime.now()
    
    process_begin = datetime.datetime.now()
    with open(file, 'rb') as f:
        with (BrotliFile if algo == 'brotli' else zipper.open)(cid, 'wb', **maxLevelArg) as fz:
            while True:
                chunk = f.read(64*1024**2)  # 64MB
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
        "variant" : algo,
        "compression" : {
            "process" : (process_end - process_begin) / datetime.timedelta(seconds=1),
            "pull" : (pull_end - pull_begin) / datetime.timedelta(seconds=1),
            "push" : (push_end - push_begin) / datetime.timedelta(seconds=1)
        },
        "ipv4" : ipv4,
        "file" : file,
        "cid" : cid
    }

    return response

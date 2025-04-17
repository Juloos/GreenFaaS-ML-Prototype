import requests
from multiprocessing import Process, Manager, Lock


def start(action, args, result, lock):

    apihost = f"http://%s:3233/api/v1/web/guest/demo/{action}?blocking=true&result=true"
    
    r = None
    try:
        r = requests.get(apihost % "host.docker.internal", headers={"Content-Type": "application/json"}, params=args)
    except requests.exceptions.ConnectionError:
        r = requests.get(apihost % "127.17.0.1", headers={"Content-Type": "application/json"}, params=args)
    with lock:
        result.update(r.json())  

     
def main(args):
    
    val = args.get("validation", {"process" : 0, "pull" : 0, "push" : 0})

    lock = Lock()
    manager = Manager()
    result = manager.dict()
    
    p1 = Process(target=start, args=("S2", args, result, lock))
    p2 = Process(target=start, args=("profanity", args, result, lock))
    p1.start()
    p2.start()
    p1.join()
    p2.join()
    
    result = dict(result)
    result["validation"] = val

    return  result

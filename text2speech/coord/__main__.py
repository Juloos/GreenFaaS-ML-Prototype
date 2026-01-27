import sys
import requests
from multiprocessing import Process, Manager, Lock


def start(action, args, result, lock):
    
    res = None
    for host in ["172.17.0.1", "host.docker.internal"]:
        for port in ["31001", "3233"]:
            try:
                req = requests.get(f"https://{host}:{port}/api/v1/web/guest/demo/{action}", headers={"Content-Type": "application/json"}, params=args, verify=False).json()
                activation_id = req.get("activationId", "")
                for _ in range(60):
                    try:
                        res = requests.get(f"https://{host}:{port}/api/v1/namespaces/_/activations/{activation_id}/result", headers={"Content-Type": "application/json"}, timeout=10, verify=False)
                        if res.status_code != 200:
                            continue
                    except requests.exceptions.Timeout:
                        continue
                break
            except requests.exceptions.ConnectionError:
                continue
    if res is not None:
        print(res.text)
        with lock:
            result.update(r.json())  

     
def main(args):
    
    val = args.get("validation", {"process" : 0, "pull" : 0, "push" : 0})

    lock = Lock()
    manager = Manager()
    result = manager.dict()
    
    p1 = Process(target=start, args=("S1", args, result, lock))
    p2 = Process(target=start, args=("profanity", args, result, lock))
    p1.start()
    p2.start()
    p1.join()
    p2.join()

    if p1.exitcode != 0 or p2.exitcode != 0:
        print("Error in subprocess")
        sys.exit(1)
    
    result = dict(result)
    result.update(args)
    result["validation"] = val

    return result

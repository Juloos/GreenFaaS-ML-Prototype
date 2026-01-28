import sys
import requests
from requests.auth import HTTPBasicAuth
from multiprocessing import Process, Manager, Lock
from time import sleep


def start(action, args, result, lock):
    auth=HTTPBasicAuth("23bc46b1-71f6-4ed5-8c54-816aa4f8c502", "123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP")
    res = req = None
    for host in ["172.17.0.1", "host.docker.internal"]:
        for port in ["31001", "3233"]:
            for proto in ["https", "http"]:
                try:
                    req = requests.post(f"{proto}://{host}:{port}/api/v1/namespaces/_/actions/demo/{action}", auth=auth, json=args, verify=False).json()
                    print("Invoked action:", req)
                    activation_id = req.get("activationId", "")
                    if activation_id == "":
                        break
                    for _ in range(60):
                        try:
                            res = requests.get(f"{proto}://{host}:{port}/api/v1/namespaces/_/activations/{activation_id}/result", auth=auth, timeout=10, verify=False)
                            if res.status_code != 200:
                                sleep(10)
                                continue
                        except requests.exceptions.Timeout:
                            continue
                    break
                except requests.exceptions.ConnectionError:
                    continue
    if req is None or res is None:
        print("Error:", req.json() if req is not None else "No response")
        sys.exit(1)
    if res is not None:
        print("Result:", res.json())
        with lock:
            result.update(res.json())


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


# if __name__ == "__main__":
#     # test main
#     args = {
#         "ipv4": "localhost",
#         "schema": "S3",
#         "text": "T256Ko.txt",
#         "ttsid": "test",
#         "validation": {
#             "process": 0,
#             "pull": 0,
#             "push": 0
#         }
#     }
#     main(args)

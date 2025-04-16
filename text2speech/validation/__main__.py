
import datetime


def main(args):

    n = args.get("iter", 5e7)
    
    process_begin = datetime.datetime.now()
    for i in range(int(n)):
        a = i + 1
    process_end = datetime.datetime.now()
    
    args["validation"] = {
            "process" : (process_end - process_begin) / datetime.timedelta(seconds=1),
            "pull" : 0,
            "push" : 0
        }

    return args
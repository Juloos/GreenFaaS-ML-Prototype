import os
import json
import datetime
import csv
import glob


os.chdir(os.path.dirname(os.path.abspath(__file__)))


HOSTS = tuple(hostname.removesuffix('/') for hostname in glob.glob("*/"))
SCHEMAS = ("S1", "S3", "S4", "S5")
TEXTS = tuple(set(os.path.basename(filename).removesuffix(".json") for filename in glob.glob("../swift_files/*Ko.txt")))


idle_watts_of = dict()
for hostname in HOSTS:
    with open("%s/idle.json" % hostname, "r") as f:
        data = json.load(f)
    idle_watts_of[hostname] = sum(float(d["value"]) for d in data) / len(data)

    with open("%s.csv" % hostname, "w") as fout:
        csv_writer = csv.writer(fout)
        csv_writer.writerow(["schema", "watts", "joules", "milliseconds"])
        for schema in SCHEMAS:
            with open("%s/%s.json" % (hostname, schema), "r") as fin:
                data = json.load(fin)
            try:
                timechunkms = 20
                start = datetime.datetime.strptime(data[0]["timestamp"], "%Y-%m-%dT%H:%M:%S.%f%z")
                end = datetime.datetime.strptime(data[-1]["timestamp"], "%Y-%m-%dT%H:%M:%S.%f%z")
            except ValueError:
                timechunkms = 1000
                start = datetime.datetime.strptime(data[0]["timestamp"], "%Y-%m-%dT%H:%M:%S%z")
                end = datetime.datetime.strptime(data[-1]["timestamp"], "%Y-%m-%dT%H:%M:%S%z")
            host_milliseconds = (end - start).total_seconds() * 1000
            host_watts = sum((float(d["value"]) - idle_watts_of[hostname]) for d in data)
            host_joules = host_watts * timechunkms / host_milliseconds
            print(f"{hostname}/{schema} : {host_joules}J | {host_milliseconds}ms")
            csv_writer.writerow([schema, host_watts, host_joules, host_milliseconds])

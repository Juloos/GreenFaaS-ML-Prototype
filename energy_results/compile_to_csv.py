import os
import json
import datetime
import csv
import glob

os.chdir(os.path.dirname(os.path.abspath(__file__)))


HOSTS = tuple(hostname.removesuffix('/') for hostname in glob.glob("*/"))
SCHEMAS = ("S1", "S2", "S3", "S4", "S5")
TEXTS = tuple(set(os.path.basename(filename).removesuffix(".json") for filename in glob.glob("../swift_files/*Ko.txt")))


idle_watts_of = dict()
for hostname in HOSTS:
    with open("%s/idle.json" % hostname, "r") as f:
        data = json.load(f)
    idle_watts_of[hostname] = sum(float(d["value"]) for d in data) / len(data)

with open("all.csv", "w") as fout:
    csv_writer = csv.writer(fout)
    csv_writer.writerow(["schema", "text", "watts", "milliseconds"])
    for schema in SCHEMAS:
        for text in TEXTS:
            total = 0
            milliseconds = 0
            for hostname in HOSTS:
                with open("%s/%s/%s.json" % (hostname, schema, text), "r") as fin:
                    data = json.load(fin)
                start = datetime.datetime.strptime(data[0]["timestamp"], "%Y-%m-%dT%H:%M:%S.%f%z")
                end = datetime.datetime.strptime(data[-1]["timestamp"], "%Y-%m-%dT%H:%M:%S.%f%z")
                host_total = sum((float(d["value"]) - idle_watts_of[hostname]) for d in data)
                host_milliseconds = (end - start).total_seconds() * 1000
                print(f"{hostname}/{schema}/{text} : {host_total}W | {host_milliseconds}ms")
                total += host_total
                milliseconds += host_milliseconds
            total = total / len(HOSTS)
            milliseconds = milliseconds / len(HOSTS)
            csv_writer.writerow([schema, text, total, milliseconds])

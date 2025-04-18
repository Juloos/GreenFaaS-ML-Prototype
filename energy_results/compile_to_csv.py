import sys
import os
import json
import datetime
import csv

os.chdir(os.path.dirname(os.path.abspath(__file__)))


SCHEMAS=("S1", "S2", "S3", "S4", "S5")
TEXTES=("1Ko.txt", "5Ko.txt", "12Ko.txt")

if len(sys.argv) != 2:
    print(f"Usage: python3 {sys.argv[0]} <idle_watts>")
    sys.exit(1)
idle_watts = float(sys.argv[1])

with open("all.csv", "w") as fout:
    csv_writer = csv.writer(fout)
    csv_writer.writerow(["schema", "texte", "watth"])
    for schema in SCHEMAS:
        for texte in TEXTES:
            with open(f"{schema}/{texte}.json", "r") as fin:
                data = json.load(fin)
            start = datetime.datetime.fromisoformat(data[0]["timestamp"])
            end = datetime.datetime.fromisoformat(data[-1]["timestamp"])
            total = sum((float(d["value"]) - idle_watts) for d in data)
            hours = (end - start).total_seconds() / 3600
            watth = total / hours
            print(f"{schema}/{texte} : {total}W / {hours}h -> {watth}W/h")
            csv_writer.writerow([schema, texte, watth])

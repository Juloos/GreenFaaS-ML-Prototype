import csv
import os
from random import shuffle

os.chdir(os.path.dirname(os.path.abspath(__file__)))


DATA = list()
schemas = set()
with open("../energy_results/all.csv", "r") as f:
    reader = csv.reader(f)
    next(reader)
    for row in reader:
        if not row:
            continue
        schema = int(row[0].removeprefix('S'))
        schemas.add(schema)
        text = int(row[1].removesuffix("Ko.txt"))  # Should be done better in prod, with file transfer detection for example
        watts = float(row[2])
        milliseconds = float(row[3])
        DATA.append((schema, text, watts, milliseconds))

shuffled_schemas = list(schemas)
shuffle(shuffled_schemas)
print("Shufle : " + str(shuffled_schemas))
RAMBLE = {x: y for x, y in zip(schemas, shuffled_schemas)}
UNRAMBLE = {y: x for x, y in zip(schemas, shuffled_schemas)}

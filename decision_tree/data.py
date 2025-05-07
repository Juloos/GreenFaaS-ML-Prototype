import csv
import os
from random import shuffle
from typing import List, Tuple

os.chdir(os.path.dirname(os.path.abspath(__file__)))


DATA = list()
schemas = set()
with open("../energy_results/all.csv", "r") as f:
    reader = csv.reader(f)
    next(reader)
    for row in reader:
        if not row:
            continue
        schema = int(row[0].strip().removeprefix('S'))
        schemas.add(schema)
        text = int(row[1].strip().removesuffix("Ko.txt"))  # Should be done better in prod, with file transfer detection for example
        watts = float(row[2].strip())
        milliseconds = float(row[3].strip())
        DATA.append((schema, text, watts, milliseconds))

total_watts = {schema: sum(row[2] for row in DATA if row[0] == schema) for schema in schemas}
sorted_schemas = sorted(schemas, key=lambda x: total_watts[x])
sorted_schemas_mapping = {sa: sb for sa, sb in zip(schemas, sorted_schemas)}
SORTSCHEMA_DATA = [(sorted_schemas_mapping[row[0]], *row[1:]) for row in DATA]


import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D

# Create a 3D graph of the given domain
def plot_domain(ax: plt.Axes, data: List[Tuple[int, int, float]], color: str):
    Axes3D.scatter(ax, [row[0] for row in data], [row[1] for row in data], [row[2] for row in data], 'o', color=color)


import os
import json
import datetime
import glob
import matplotlib.pyplot as plt

os.chdir(os.path.dirname(os.path.abspath(__file__)))


HOSTS = tuple(hostname.removesuffix('/') for hostname in glob.glob("*/"))
SCHEMAS = ("idle", "S1", "S3", "S4", "S5")
TEXTS = tuple(set(os.path.basename(filename).removesuffix(".json") for filename in glob.glob("../swift_files/*.txt")))


schemas_joules = {schema: [] for schema in SCHEMAS}
schemas_watts = {schema: [] for schema in SCHEMAS}
schemas_millis = {schema: [] for schema in SCHEMAS}
for hostname in HOSTS:
    for schema in SCHEMAS:
        with open("%s/%s.json" % (hostname, schema), "r") as f:
            data = json.load(f)
        try:
            start = datetime.datetime.strptime(data[0]["timestamp"], "%Y-%m-%dT%H:%M:%S.%f%z")
            end = datetime.datetime.strptime(data[-1]["timestamp"], "%Y-%m-%dT%H:%M:%S.%f%z")
        except ValueError:
            start = datetime.datetime.strptime(data[0]["timestamp"], "%Y-%m-%dT%H:%M:%S%z")
            end = datetime.datetime.strptime(data[-1]["timestamp"], "%Y-%m-%dT%H:%M:%S%z")

        host_watts = sum(float(d["value"]) for d in data)
        schemas_watts[schema].append(host_watts)
        schemas_joules[schema].append(host_watts / len(data))
        schemas_millis[schema].append((end - start).total_seconds() * 1000)


# Create barplot, group hosts together
fig, (ax1, ax2, ax3) = plt.subplots(3, 1, figsize=(12, 14))
x = range(len(SCHEMAS))
width = 0.15

for i, hostname in enumerate(HOSTS):
    joules = [schemas_joules[schema][i] for schema in SCHEMAS]
    watts = [schemas_watts[schema][i] for schema in SCHEMAS if schema != "idle"]
    millis = [schemas_millis[schema][i] for schema in SCHEMAS if schema != "idle"]
    ax1.bar([pos + i * width for pos in x], joules, width=width, label=hostname)
    ax2.bar([pos + i * width for pos in x[:-1]], watts, width=width, label=hostname)
    ax3.bar([pos + i * width for pos in x[:-1]], millis, width=width, label=hostname)

ax1.set_xticks([pos + (len(HOSTS) - 1) * width / 2 for pos in x])
ax1.set_xticklabels(SCHEMAS)
ax1.set_ylabel("Average Joules")
ax1.set_title("Average Energy Consumption (Joules) per Schema and Host")
ax1.legend()

ax2.set_xticks([pos + (len(HOSTS) - 1) * width / 2 for pos in x[:-1]])
ax2.set_xticklabels([schema for schema in SCHEMAS if schema != "idle"])
ax2.set_ylabel("Total Watts")
ax2.set_title("Total Raw Power (Watts) per Schema and Host")
ax2.legend()

ax3.set_xticks([pos + (len(HOSTS) - 1) * width / 2 for pos in x[:-1]])
ax3.set_xticklabels([schema for schema in SCHEMAS if schema != "idle"])
ax3.set_ylabel("Milliseconds")
ax3.set_title("Execution Time (Milliseconds) per Schema and Host")
ax3.legend()

fig.tight_layout()
fig.savefig("results.png")
fig.savefig("results.svg")
plt.show()

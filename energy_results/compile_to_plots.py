import os
import json
import datetime
import glob
import matplotlib.pyplot as plt


os.chdir(os.path.dirname(os.path.abspath(__file__)))


JOBS = tuple(host.removesuffix('/') for host in glob.glob("*/") if "ignore" not in host)
SCHEMAS = ("idle", "S1", "S3", "S4", "S5")
# TEXTS = tuple(set(os.path.basename(filename).removesuffix(".json") for filename in glob.glob("../swift_files/*.txt")))

for job in JOBS:
    print(f"Processing job: {job}")
    os.chdir(job)

    hosts = tuple(host.removesuffix('/') for host in glob.glob("*/"))

    joules = {host: {schema: None for schema in SCHEMAS} for host in hosts}
    watts = {host: {schema: None for schema in SCHEMAS} for host in hosts}
    millis = {host: {schema: None for schema in SCHEMAS} for host in hosts}
    for host in hosts:
        print(f"  Host: {host}")
        for schema in SCHEMAS:
            print(f"    Schema: {schema}")
            with open("%s/%s.json" % (host, schema), "r") as f:
                data = json.load(f)
            try:
                start = datetime.datetime.strptime(data[0]["timestamp"], "%Y-%m-%dT%H:%M:%S.%f%z")
                end = datetime.datetime.strptime(data[-1]["timestamp"], "%Y-%m-%dT%H:%M:%S.%f%z")
            except ValueError:
                start = datetime.datetime.strptime(data[0]["timestamp"], "%Y-%m-%dT%H:%M:%S%z")
                end = datetime.datetime.strptime(data[-1]["timestamp"], "%Y-%m-%dT%H:%M:%S%z")

            host_watts = sum(float(d["value"]) for d in data)
            watts[host][schema] = host_watts
            joules[host][schema] = host_watts / len(data)
            millis[host][schema] = (end - start).total_seconds() * 1000

    print("  Aggregated Results:")
    print("    Watts:", watts)
    print("    Joules:", joules)
    print("    Millis:", millis)

    # Create barplot, group hosts together
    fig, (ax1, ax2, ax3) = plt.subplots(3, 1, figsize=(12, 14))
    x = range(len(SCHEMAS))
    width = 0.15

    print("  Generating plots:")
    for i, host in enumerate(hosts):
        print(f"    Inserting host: {host} at position {i}")
        joules_data = [joules[host][schema] for schema in SCHEMAS]
        watts_data = [watts[host][schema] for schema in SCHEMAS]# if schema != "idle"]
        millis_data = [millis[host][schema] for schema in SCHEMAS]# if schema != "idle"]
        ax1.bar([pos + i * width for pos in x], joules_data, width=width, label=host)
        # ax2.bar([pos + i * width for pos in x[:-1]], watts, width=width, label=host)
        # ax3.bar([pos + i * width for pos in x[:-1]], millis, width=width, label=host)
        ax2.bar([pos + i * width for pos in x], watts_data, width=width, label=host)
        ax3.bar([pos + i * width for pos in x], millis_data, width=width, label=host)

    print("  Finalizing plots")
    ax1.set_xticks([pos + (len(hosts) - 1) * width / 2 for pos in x])
    ax1.set_xticklabels(SCHEMAS)
    ax1.set_ylabel("Average Joules")
    ax1.set_title("Average Energy Consumption (Joules) per Schema and Host")
    ax1.legend()

    # ax2.set_xticks([pos + (len(hosts) - 1) * width / 2 for pos in x[:-1]])
    ax2.set_xticks([pos + (len(hosts) - 1) * width / 2 for pos in x])
    ax2.set_xticklabels([schema for schema in SCHEMAS])# if schema != "idle"])
    ax2.set_ylabel("Total Watts")
    ax2.set_title("Total Raw Power (Watts) per Schema and Host")
    ax2.legend()

    # ax3.set_xticks([pos + (len(hosts) - 1) * width / 2 for pos in x[:-1]])
    ax3.set_xticks([pos + (len(hosts) - 1) * width / 2 for pos in x])
    ax3.set_xticklabels([schema for schema in SCHEMAS])# if schema != "idle"])
    ax3.set_ylabel("Milliseconds")
    ax3.set_title("Execution Time (Milliseconds) per Schema and Host")
    ax3.legend()

    fig.tight_layout()
    fig.savefig("results.png")
    fig.savefig("results.svg")
    
    os.chdir("..")


# plt.show()

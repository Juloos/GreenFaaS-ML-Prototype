import os
import json
import datetime
import glob
import matplotlib.pyplot as plt


os.chdir(os.path.dirname(os.path.abspath(__file__)))


JOBS = tuple(host.removesuffix('/') for host in glob.glob("*/") if "ignore" not in host)

for job in JOBS:
    print(f"Processing job: {job}")
    os.chdir(job)

    hosts = tuple(host.removesuffix('/') for host in glob.glob("*/"))
    params = tuple(tuple(os.path.dirname(param).removeprefix(hosts[0] + '/').split('/')) for param in glob.glob("%s/**/*.json" % hosts[0], recursive=True))
    params = tuple(tuple(sorted(set(subparams[i] for subparams in params) - {hosts[0]})) for i in range(len(params[0])))
    variants = ("idle",) + tuple(sorted(set(os.path.basename(variant).removesuffix('.json') for variant in glob.glob("**/*.json", recursive=True)) - {"idle"}))
    print(f"  Found hosts: {hosts}")
    print(f"  Found params: {params}")
    print(f"  Found variants: {variants}")

    joules = {host: {variant: None for variant in variants} for host in hosts}
    watts = {host: {variant: None for variant in variants} for host in hosts}
    millis = {host: {variant: None for variant in variants} for host in hosts}
    for host in hosts:
        print(f"  Host: {host}")
        for variant in variants:
            print(f"    Variant: {variant}")
            with open("%s/%s.json" % (host, variant), "r") as f:
                data = json.load(f)
            try:
                start = datetime.datetime.strptime(data[0]["timestamp"], "%Y-%m-%dT%H:%M:%S.%f%z")
                end = datetime.datetime.strptime(data[-1]["timestamp"], "%Y-%m-%dT%H:%M:%S.%f%z")
            except ValueError:
                start = datetime.datetime.strptime(data[0]["timestamp"], "%Y-%m-%dT%H:%M:%S%z")
                end = datetime.datetime.strptime(data[-1]["timestamp"], "%Y-%m-%dT%H:%M:%S%z")

            host_watts = sum(float(d["value"]) for d in data)
            watts[host][variant] = host_watts
            joules[host][variant] = host_watts / len(data)
            millis[host][variant] = (end - start).total_seconds() * 1000

    print("  Aggregated Results:")
    print("    Watts:", watts)
    print("    Joules:", joules)
    print("    Millis:", millis)

    # Create barplot, group hosts together
    fig, (ax1, ax2, ax3) = plt.subplots(3, 1, figsize=(12, 14))
    x = range(len(variants))
    width = 0.15

    print("  Generating plots:")
    for i, host in enumerate(hosts):
        print(f"    Inserting host: {host} at position {i}")
        joules_data = [joules[host][variant] for variant in variants]
        watts_data = [watts[host][variant] for variant in variants]
        millis_data = [millis[host][variant] for variant in variants]
        ax1.bar([pos + i * width for pos in x], joules_data, width=width, label=host)
        ax2.bar([pos + i * width for pos in x], watts_data, width=width, label=host)
        ax3.bar([pos + i * width for pos in x], millis_data, width=width, label=host)

    print("  Finalizing plots")
    ax1.set_xticks([pos + (len(hosts) - 1) * width / 2 for pos in x])
    ax1.set_xticklabels(variants)
    ax1.set_ylabel("Average Joules")
    ax1.set_title("Average Energy Consumption (Joules) per Schema and Host")
    ax1.legend()

    ax2.set_xticks([pos + (len(hosts) - 1) * width / 2 for pos in x])
    ax2.set_xticklabels([variant for variant in variants])
    ax2.set_ylabel("Total Watts")
    ax2.set_title("Total Raw Power (Watts) per Schema and Host")
    ax2.legend()

    ax3.set_xticks([pos + (len(hosts) - 1) * width / 2 for pos in x])
    ax3.set_xticklabels([variant for variant in variants])
    ax3.set_ylabel("Milliseconds")
    ax3.set_title("Execution Time (Milliseconds) per Schema and Host")
    ax3.legend()

    fig.tight_layout()
    fig.savefig("results.png")
    fig.savefig("results.svg")
    
    os.chdir("..")


# plt.show()

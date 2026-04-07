import os
import json
import datetime
import glob
import matplotlib.pyplot as plt
from matplotlib.widgets import CheckButtons, RadioButtons
from itertools import product
import numpy as np


os.chdir(os.path.dirname(os.path.abspath(__file__)))


def parse_data(filename: str) -> tuple[float, float, float]:  # returns (watts, millis, joules)
    with open(filename, "r") as f:
        data = json.load(f)
    try:
        start = datetime.datetime.strptime(data[0]["timestamp"], "%Y-%m-%dT%H:%M:%S.%f%z")
        end = datetime.datetime.strptime(data[-1]["timestamp"], "%Y-%m-%dT%H:%M:%S.%f%z")
    except ValueError:
        start = datetime.datetime.strptime(data[0]["timestamp"], "%Y-%m-%dT%H:%M:%S%z")
        end = datetime.datetime.strptime(data[-1]["timestamp"], "%Y-%m-%dT%H:%M:%S%z")
    host_watts = sum(float(d["value"]) for d in data)
    return host_watts, (end - start).total_seconds() * 1000, host_watts / len(data)


JOBS = tuple(host.removesuffix('/') for host in glob.glob("*/") if "ignore" not in host)

for job in JOBS:
    print(f"Processing job: {job}")
    os.chdir(job)

    hosts = tuple(host.removesuffix('/') for host in glob.glob("*/"))
    params = tuple(tuple(os.path.dirname(param).removeprefix(hosts[0] + '/').split('/')) for param in glob.glob("%s/**/*.json" % hosts[0], recursive=True))
    params = tuple(tuple(sorted(set(subparams[i] for subparams in params) - {hosts[0]})) for i in range(len(params[0])))
    variants = tuple(sorted(set(os.path.basename(variant).removesuffix('.json') for variant in glob.glob("**/*.json", recursive=True)) - {"idle"}))
    print(f"  Found hosts: {hosts}")
    print(f"  Found params: {params}")
    print(f"  Found variants: {variants}")

    watts = {host: {variant: dict() for variant in variants} for host in hosts}
    millis = {host: {variant: dict() for variant in variants} for host in hosts}
    joules = {host: {variant: dict() for variant in variants} for host in hosts}

    variants = ("idle",) + variants
    for host in hosts:
        print(f"  Host: {host}")
        for variant in variants:
            print(f"    Variant: {variant}")
            if variant == "idle":
                watts[host][variant], millis[host][variant], joules[host][variant] = parse_data(f"{host}/idle.json")
                continue
            for ps in product(*params):
                print(f"      Params: {ps}")
                watts[host][variant][ps], millis[host][variant][ps], joules[host][variant][ps] = parse_data("%s/%s/%s.json" % (host, '/'.join(ps), variant))

    print("  Aggregated Results:")
    print("    Watts:", watts)
    print("    Millis:", millis)
    print("    Joules:", joules)


    # === INTERACTIVE PLOTTING SECTION ===
    
    def get_param_label(param_tuple):
        """Convert parameter tuple to readable label"""
        if param_tuple == ("idle",):
            return "idle"
        return " | ".join(str(p) for p in param_tuple)
    
    def update_plot(selected_params):
        """Update the bar plots based on selected parameters"""
        for axis in axes:
            axis.clear()
        
        # Collect data: variant -> host -> (watts, millis, joules)
        variant_data = {}
        unique_variants_ordered = []
        
        for host in hosts:
            # Always include idle for each host
            variant = "idle"
            if variant not in variant_data:
                variant_data[variant] = {}
                unique_variants_ordered.append(variant)
            variant_data[variant][host] = (watts[host][variant], millis[host][variant], joules[host][variant])
            
            # Include other variants
            for var in variants:
                if var == "idle":
                    continue
                for param_combo in watts[host][var].keys():
                    if param_combo in selected_params:
                        if var not in variant_data:
                            variant_data[var] = {}
                            unique_variants_ordered.append(var)
                        variant_data[var][host] = (watts[host][var][param_combo], millis[host][var][param_combo], joules[host][var][param_combo])
                        break
        
        if not variant_data:
            axes[1].text(0.5, 0.5, 'No data for selected parameters', 
                         transform=axes[1].transAxes, ha='center', va='center')
            fig.canvas.draw_idle()
            return
        
        # Get available hosts in order
        available_hosts = [h for h in hosts if any(h in variant_data[v] for v in variant_data)]
        
        # Create color map for hosts
        host_colors = plt.cm.get_cmap('tab10', max(len(available_hosts), 1))
        host_color_map = {host: host_colors(i) for i, host in enumerate(available_hosts)}
        
        # Create bar positions
        x = np.arange(len(unique_variants_ordered))
        bar_width = 0.8 / max(1, len(available_hosts))
        
        # Plot on each axis
        for axis, metric_name in zip(axes, ("Watts", "Millis", "Joules")):
            metric_index = {"Watts": 0, "Millis": 1, "Joules": 2}[metric_name]
            
            for host_idx, host in enumerate(available_hosts):
                values = []
                for variant in unique_variants_ordered:
                    if host in variant_data[variant]:
                        values.append(variant_data[variant][host][metric_index])
                    else:
                        values.append(0)
                
                bar_positions = x + host_idx * bar_width - (len(available_hosts) - 1) * bar_width / 2
                bars = axis.bar(bar_positions, values, bar_width, label=host, color=host_color_map[host], alpha=0.8)
                
                # Add value labels on bars
                for bar in bars:
                    height = bar.get_height()
                    if height > 0:
                        axis.annotate(f'{height:.2f}',
                                      xy=(bar.get_x() + bar.get_width() / 2, height),
                                      xytext=(0, 3),
                                      textcoords="offset points",
                                      ha='center', va='bottom', fontsize=8)
            
            axis.set_ylabel(metric_name)
            axis.set_title(f"{metric_name} by Host")
            axis.grid(axis='y', alpha=0.3)
        
        # Set x-axis labels to variant names
        axes[-1].set_xticks(x)
        axes[-1].set_xticklabels(unique_variants_ordered, rotation=45, ha='right')
        axes[-1].set_xlabel('Variant')
        
        # Add legend for hosts
        axes[0].legend(title='Host', bbox_to_anchor=(1.02, 1), loc='upper left')
        
        fig.suptitle('Energy Metrics by Host\nSelected Parameters: ' + 
                     ', '.join(get_param_label(p) for p in selected_params[:3]) + 
                     ('...' if len(selected_params) > 3 else ''))
        fig.tight_layout(rect=[0, 0, 1, 0.96])
        fig.canvas.draw_idle()
    
    # Get all parameter combinations
    all_params = tuple(product(*params))
    selected_params = [all_params[0]]
    
    # Create figure with three subplots for Watts, Millis and Joules
    fig, axes = plt.subplots(3, 1, figsize=(14, 12), sharex=True)
    plt.subplots_adjust(left=0.07, right=0.88, top=0.92, bottom=0.15, hspace=0.4)
    
    # Create RadioButtons for parameter selection
    ax_radio = plt.axes([0.90, 0.15, 0.08, 0.25])
    radio = RadioButtons(ax_radio, tuple(get_param_label(p) for p in all_params), active=0)
    
    def radio_clicked(label):
        """Handle RadioButton click"""
        # Find the parameter tuple corresponding to the label
        for param_tuple in all_params:
            if get_param_label(param_tuple) == label:
                selected_params[0] = param_tuple
                break
        update_plot(selected_params)
    
    radio.on_clicked(radio_clicked)
    
    # Initial plot
    update_plot(selected_params)
    
    plt.show()
    
    # Go back to parent directory for next job
    os.chdir("..")

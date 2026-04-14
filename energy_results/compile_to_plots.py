import os
import json
import datetime
import glob
import re
from itertools import product
import plotly.graph_objects as go
from plotly.subplots import make_subplots


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


JOBS = tuple(host.removesuffix('/') for host in glob.glob("*/") if "ignore" not in host and "__pycache__" not in host)

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


    # === INTERACTIVE PLOTTING SECTION [AI-based] ===
    
    def get_param_label(param_tuple):
        """Convert parameter tuple to readable label"""
        return " | ".join(str(p) for p in param_tuple)
    
    # Collect idle data once per host, and benchmark variant data per parameter combination
    idle_data = {host: (watts[host]["idle"], millis[host]["idle"], joules[host]["idle"]) for host in hosts}
    all_variant_data = {}
    for param in product(*params):
        param_label = get_param_label(param)
        variant_data = {}
        unique_variants_ordered = []
        
        for host in hosts:
            # Include benchmark variants for this parameter
            for var in variants:
                if var == "idle":
                    continue
                if param in watts[host][var]:
                    if var not in variant_data:
                        variant_data[var] = {}
                        unique_variants_ordered.append(var)
                    variant_data[var][host] = (watts[host][var][param], millis[host][var][param], joules[host][var][param])
        
        if variant_data:
            all_variant_data[param_label] = (variant_data, unique_variants_ordered)
    
    if not all_variant_data:
        print(f"  No plots generated for job {job}")
        os.chdir("..")
        continue
    
    def natural_sort_key(label: str):
        parts = re.split(r'(\d+[GMK]?)', label)
        return [
            int(part.replace('G', '000M').replace('M', '000K').replace('K', '000'))
            if part.isdigit() or (part and part[:-1].isdigit()) else part.lower()
            for part in parts
        ]
    
    # Sort parameters by label using natural numeric ordering for embedded values
    param_labels = tuple(sorted(all_variant_data.keys(), key=natural_sort_key))
    
    # Build a complete ordered list of all variants across parameters
    all_variant_categories = []
    for _, unique_variants_ordered in all_variant_data.values():
        for variant in unique_variants_ordered:
            if variant not in all_variant_categories:
                all_variant_categories.append(variant)
    variant_positions = {variant: idx for idx, variant in enumerate(all_variant_categories)}
    x_min = -0.5
    x_max = len(all_variant_categories) - 0.5 if all_variant_categories else 0.5
    
    # Get available hosts in sorted order
    available_hosts = []
    for variant_data, _ in all_variant_data.values():
        for host in hosts:
            if any(host in variant_data[v] for v in variant_data):
                if host not in available_hosts:
                    available_hosts.append(host)
    available_hosts.sort(key=natural_sort_key)
    
    # Define host colors
    host_colors = ['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd', '#8c564b', '#e377c2', '#7f7f7f', '#bcbd22', '#17becf']
    host_color_map = {host: host_colors[i % len(host_colors)] for i, host in enumerate(available_hosts)}
    
    def darken_color(hex_color: str, factor: float = 0.75) -> str:
        hex_color = hex_color.lstrip('#')
        r = int(hex_color[0:2], 16)
        g = int(hex_color[2:4], 16)
        b = int(hex_color[4:6], 16)
        r = max(0, min(255, int(r * factor)))
        g = max(0, min(255, int(g * factor)))
        b = max(0, min(255, int(b * factor)))
        return f"#{r:02x}{g:02x}{b:02x}"
    
    # Create subplots
    fig = make_subplots(
        rows=3, cols=1,
        subplot_titles=("Joules by Host", "Watts by Host", "Millis by Host"),
        vertical_spacing=0.05
    )
    
    # Metrics to plot
    metrics = [
        (2, "Joules"),
        (0, "Watts"),
        (1, "Millis")
    ]
    
    # Add bars for each metric, host, and parameter
    for subplot_idx, (metric_idx, metric_name) in enumerate(metrics):
        row = subplot_idx + 1
        axes_updated = False
        
        for param_idx, param_label in enumerate(param_labels):
            variant_data, unique_variants_ordered = all_variant_data[param_label]
            
            # Update axes on first parameter (all parameters share same x-axis)
            if not axes_updated:
                fig.update_yaxes(title_text=metric_name, row=row, col=1)
                fig.update_xaxes(
                    title_text="Variant" if subplot_idx == len(metrics) - 1 else "",
                    row=row,
                    col=1,
                    tickmode='array',
                    tickvals=list(variant_positions.values()),
                    ticktext=list(variant_positions.keys())
                )
                axes_updated = True
            
            for host in available_hosts:
                values = [variant_data[variant].get(host, (0, 0, 0))[metric_idx] for variant in unique_variants_ordered]
                x_values = [variant_positions[variant] for variant in unique_variants_ordered]
                
                fig.add_trace(
                    go.Bar(
                        name=f"{host} ({param_label})",
                        x=x_values,
                        y=values,
                        marker_color=host_color_map[host],
                        showlegend=(subplot_idx == 0),
                        text=[f"{v:.2f}" for v in values],
                        textposition='inside',
                        textangle=0,
                        hovertemplate=f"<b>{host}</b> [{param_label}]<br>Variant: %{{customdata}}<br>{metric_name}: %{{y:.2f}}<extra></extra>",
                        legendgroup=param_label,
                        customdata=unique_variants_ordered,
                        meta={"host": host, "param_idx": param_idx}
                    ),
                    row=row, col=1
                )
        
        # Add single idle horizontal line per host only for Joules
        if metric_name == "Joules":
            for host in available_hosts:
                idle_value = idle_data[host][metric_idx]
                fig.add_trace(
                    go.Scatter(
                        name=f"{host} idle {metric_name}: {idle_value:.2f}",
                        x=[x_min, x_max],
                        y=[idle_value, idle_value],
                        mode="lines",
                        line={"color": darken_color(host_color_map[host]), "dash": "dash"},
                        showlegend=True,
                        legendgroup=host,
                        meta={"host": host, "idle": True}
                    ),
                    row=row, col=1
                )
    
    # Update layout - use legend for parameter selection and host filtering
    fig.update_layout(
        title_text=f"Energy Metrics by Host",
        barmode="group",
        height=1200,
        bargap=0.3,  # Increase gap between different variants
        bargroupgap=0.05,  # Small gap between hosts within same variant
        hovermode='closest',
        showlegend=True,
        legend=dict(
            title=f"Host (Parameter) - Click to toggle",
            yanchor="top",
            y=0.99,
            xanchor="left",
            x=1.02
        )
    )

    if len(available_hosts) > 1:
        # Create host filter buttons based on trace metadata
        host_trace_indices = {
            host: [i for i, trace in enumerate(fig.data) if trace.meta.get("host") == host]
            for host in available_hosts
        }

        host_buttons = [
            dict(
                label="All Hosts",
                method="update",
                args=[
                    {"visible": [True] * len(fig.data)}
                ]
            )
        ]

        for host in available_hosts:
            indices = host_trace_indices[host]
            host_buttons.append(
                dict(
                    label=host,
                    method="restyle",
                    args=[
                        {"visible": [False]},
                        indices
                    ],
                    args2=[
                        {"visible": [True]},
                        indices
                    ]
                )
            )

        fig.update_layout(
            updatemenus=[
                dict(
                    active=0,
                    buttons=host_buttons,
                    direction="left",
                    type="buttons",
                    showactive=False,
                    x=0.5,
                    xanchor="center",
                    y=1.15,
                    yanchor="top",
                    pad={"r": 10, "t": 10},
                    bgcolor="rgba(255,255,255,0.8)",
                    bordercolor="#cccccc",
                    borderwidth=1
                )
            ]
        )
    
    # Export to HTML
    output_file = "energy_metrics.html"
    fig.write_html(output_file)
    print(f"  Generated plot: {job}/{output_file}")
    
    # Go back to parent directory for next job
    os.chdir("..")

#!/usr/bin/env python3
import os
import pandas as pd
import matplotlib.pyplot as plt

# ASSIGNMENT: No subfolders. Saving plots to current dir.
OUTDIR = "." 

def plot_part_c():
    csv_file = "MT25046_Part_C_CSV.csv"
    if not os.path.exists(csv_file):
        print(f"Error: {csv_file} not found.")
        return

    df = pd.read_csv(csv_file)

    # Added Time(s) as requested
    for metric in ["CPU%", "Mem(KB)", "IO(MB/s)", "Time(s)"]:
        plt.figure()
        plt.bar(df["Program+Function"], df[metric], color=['blue', 'orange'] * 3)
        plt.title(f"Part C: {metric} (2 workers)")
        plt.ylabel(metric)
        plt.xticks(rotation=45)
        plt.tight_layout()
        
        # Naming: MT25046_Part_C_Plot_<metric>.png
        sanitized_metric = metric.replace('%','pct').replace('(','').replace(')','').replace('/','')
        outfile = f"MT25046_Part_C_Plot_{sanitized_metric}.png"
        
        plt.savefig(outfile, dpi=300)
        plt.close()
        print(f"Generated {outfile}")

def plot_part_d():
    csv_file = "MT25046_Part_D_CSV.csv"
    if not os.path.exists(csv_file):
        print(f"Error: {csv_file} not found.")
        return

    df = pd.read_csv(csv_file)

    for worker in ["cpu", "mem", "io"]:
        subA = df[df["Program+Function"] == f"A+{worker}"]
        subB = df[df["Program+Function"] == f"B+{worker}"]

        for metric in ["CPU%", "Mem(KB)", "IO(MB/s)", "Time(s)"]:
            plt.figure()
            plt.plot(subA["NumWorkers"], subA[metric], marker="o", label="A (processes)")
            plt.plot(subB["NumWorkers"], subB[metric], marker="x", label="B (threads)")
            
            plt.title(f"Part D: {metric} vs NumWorkers ({worker})")
            plt.xlabel("NumWorkers")
            plt.ylabel(metric)
            plt.legend()
            plt.grid(True)
            plt.tight_layout()
            
            # Naming: MT25046_Part_D_Plot_<metric>_<worker>.png
            sanitized_metric = metric.replace('%','pct').replace('(','').replace(')','').replace('/','')
            outfile = f"MT25046_Part_D_Plot_{sanitized_metric}_{worker}.png"
            
            plt.savefig(outfile, dpi=300)
            plt.close()
            print(f"Generated {outfile}")

def main():
    plot_part_c()
    plot_part_d()

if __name__ == "__main__":
    main()

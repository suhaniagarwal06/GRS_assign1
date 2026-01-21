#!/usr/bin/env python3
import os
import pandas as pd
import matplotlib.pyplot as plt

OUTDIR = "measurements/plots"
os.makedirs(OUTDIR, exist_ok=True)

def plot_part_c():
    df = pd.read_csv("measurements/MT25xxx_Part_C_CSV.csv")

    for metric in ["CPU%", "Mem(MB)", "IO(MB/s)"]:
        plt.figure()
        plt.bar(df["Program+Function"], df[metric])
        plt.title(f"Part C: {metric} (2 workers)")
        plt.ylabel(metric)
        plt.xticks(rotation=45)
        plt.tight_layout()
        plt.savefig(os.path.join(OUTDIR, f"part_c_{metric.replace('%','pct').replace('(','').replace(')','').replace('/','')}.png"), dpi=300)
        plt.close()

def plot_part_d():
    df = pd.read_csv("measurements/MT25xxx_Part_D_CSV.csv")

    for worker in ["cpu", "mem", "io"]:
        subA = df[df["Program+Function"] == f"A+{worker}"]
        subB = df[df["Program+Function"] == f"B+{worker}"]

        for metric in ["CPU%", "Mem(MB)", "IO(MB/s)"]:
            plt.figure()
            plt.plot(subA["NumWorkers"], subA[metric], marker="o", label="A (processes)")
            plt.plot(subB["NumWorkers"], subB[metric], marker="o", label="B (threads)")
            plt.title(f"Part D: {metric} vs NumWorkers ({worker})")
            plt.xlabel("NumWorkers")
            plt.ylabel(metric)
            plt.legend()
            plt.grid(True)
            plt.tight_layout()
            plt.savefig(os.path.join(OUTDIR, f"part_d_{metric.replace('%','pct').replace('(','').replace(')','').replace('/','')}_{worker}.png"), dpi=300)
            plt.close()

def main():
    plot_part_c()
    plot_part_d()
    print("✓ Plots generated in measurements/plots/")

if __name__ == "__main__":
    main()

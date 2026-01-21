#!/bin/bash
set -e

echo "Building..."
make clean
make

echo "Running measurements..."
chmod +x MT25046_Part_C_Measure.sh
./MT25046_Part_C_Measure.sh

echo "Generating plots..."
python3 MT25046_Part_D_Plotter.py

echo "✓ All done. Check measurements/ folder."

#!/bin/bash
set -e

echo "Building..."
make clean
make

echo "Running measurements..."
chmod +x measure.sh
./measure.sh

echo "Generating plots..."
python3 plot_results.py

echo "✓ All done. Check measurements/ folder."

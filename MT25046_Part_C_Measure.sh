#!/bin/bash
set -e # Exit immediately if any command fails

# Configuration
OUTPUT_DIR="measurements"
mkdir -p "$OUTPUT_DIR"

CSV_C="$OUTPUT_DIR/MT25046_Part_C_CSV.csv"
CSV_D="$OUTPUT_DIR/MT25046_Part_D_CSV.csv"

# Measurement parameters
CPU_CORE=2
SAMPLE_INTERVAL=0.2

# Initialize CSV files with headers
echo "Program+Function,CPU%,Mem(MB),IO(MB/s),Time(s)" > "$CSV_C"
echo "Program+Function,NumWorkers,CPU%,Mem(MB),IO(MB/s),Time(s)" > "$CSV_D"

# Function: get_tree_pids
# Recursively collects all descendant PIDs of a root process
# This is crucial for accurate measurements when processes fork children
#
# Arguments:
#   $1 - root_pid: The parent process ID
#
# Returns:
#   Space-separated list of all PIDs in the process tree
get_tree_pids() {
    local root_pid=$1
    local all="$root_pid"
    local queue="$root_pid"

# Breadth-first search to find all descendant processes
    while [[ -n "$queue" ]]; do
        local next=""
        for p in $queue; do
        # Find children of this process using pgrep
            local kids
            kids=$(pgrep -P "$p" 2>/dev/null || true)
            if [[ -n "$kids" ]]; then
                next="$next $kids"
                all="$all $kids"
            fi
        done
        queue="$next"
    done

    echo "$all"
}

# Function: sample_cpu_mem_tree
# Samples CPU% and RSS (memory) for all processes in a tree
#
# Arguments:
#   $1 - root_pid: The root process ID
#
# Returns:
#   "CPU% RSS_KB" (space-separated values)
#
# Notes:
#   - CPU% is the percentage of CPU time used
#   - RSS is Resident Set Size (actual RAM used) in kilobytes
sample_cpu_mem_tree() {
    local root_pid=$1
    local pids
    pids=$(get_tree_pids "$root_pid")

    # Use ps to get CPU% and RSS for all PIDs, then sum them
    ps -o %cpu=,rss= -p $pids 2>/dev/null | awk '
        {cpu+=$1; mem+=$2}
        END {printf "%.2f %.0f\n", cpu, mem}
    '
}


# Function: get_write_bytes_tree
# Sums write_bytes from /proc/*/io for all processes in a tree
# This gives us the total bytes written to disk
#
# Arguments:
#   $1 - root_pid: The root process ID
#
# Returns:
#   Total write_bytes across all processes in the tree
#
# Notes:
#   - Reads from /proc/[pid]/io which tracks actual I/O operations
#   - write_bytes includes only actual disk writes (after page cache)
get_write_bytes_tree() {
    local root_pid=$1
    local pids
    pids=$(get_tree_pids "$root_pid")

    local total=0
    for p in $pids; do
        if [[ -r "/proc/$p/io" ]]; then
            wb=$(grep "^write_bytes:" "/proc/$p/io" | awk '{print $2}')
            total=$((total + wb))
        fi
    done
    echo "$total"
}

run_one() {
    local program=$1
    local nworkers=$2
    local worker=$3
    local out_csv=$4
    local include_nworkers=$5

# Create a label for the combination 
    local combo
    if [[ "$program" == "program_a" ]]; then
        combo="A+$worker"
    else
        combo="B+$worker"
    fi

    echo "Running $combo with $nworkers workers..."

    # Start program pinned to CPU core
    taskset -c "$CPU_CORE" ./"$program" "$nworkers" "$worker" &
    local root_pid=$!

# Record start time (high precision)
    # Start time
    local start_time
    start_time=$(date +%s.%N)

# Initialize accumulators for averaging
    local cpu_sum=0
    local mem_sum=0
    local samples=0

# Get initial write_bytes (before workload starts)
    # IO: take initial total write bytes
    local wb_start
    wb_start=$(get_write_bytes_tree "$root_pid")
    
    local wb_end
    wb_end=$wb_start

    # Sample CPU and memory until program ends
    while kill -0 "$root_pid" 2>/dev/null; do
    # Sample current CPU% and memory usage
        read cpu rss_kb < <(sample_cpu_mem_tree "$root_pid")

	# Accumulate for averaging
        cpu_sum=$(awk -v a="$cpu_sum" -v b="$cpu" 'BEGIN{print a+b}')
        mem_sum=$(awk -v a="$mem_sum" -v b="$rss_kb" 'BEGIN{print a+b}')
        samples=$((samples+1))
        
        # Update final write_bytes
        wb_end=$(get_write_bytes_tree "$root_pid")

	# Sleep before next sample
        sleep "$SAMPLE_INTERVAL"
    done

# Wait for process to fully complete
    wait "$root_pid" 2>/dev/null || true

    # End time
    local end_time
    end_time=$(date +%s.%N)

    # Duration
    local duration
    duration=$(awk -v s="$start_time" -v e="$end_time" 'BEGIN{printf "%.3f", (e-s)}')

    # Avoid division by zero
    if awk "BEGIN{exit !($duration <= 0)}"; then
        duration="0.001"
    fi
    
    # IO bytes written
    local written_bytes=$((wb_end - wb_start))
    if [[ $written_bytes -lt 0 ]]; then
        written_bytes=0
    fi

    # IO MB/s = total_written_MB / duration
    local avg_io
    avg_io=$(awk -v b="$written_bytes" -v t="$duration" \
        'BEGIN{printf "%.2f", (b/(1024*1024))/t}')

    # Averages for CPU and Mem
    local avg_cpu avg_mem_mb
    if [[ $samples -gt 0 ]]; then
        avg_cpu=$(awk -v s="$cpu_sum" -v n="$samples" 'BEGIN{printf "%.2f", s/n}')
        avg_mem_mb=$(awk -v s="$mem_sum" -v n="$samples" 'BEGIN{printf "%.2f", (s/n)/1024}')
    else
        avg_cpu="0.00"
        avg_mem_mb="0.00"
    fi

    # Clamp CPU to 100%
    avg_cpu=$(awk -v c="$avg_cpu" 'BEGIN{ if(c>100) printf "100.00"; else printf "%.2f", c }')

    # Write CSV row
    if [[ "$include_nworkers" == "yes" ]]; then
        echo "${combo},${nworkers},${avg_cpu},${avg_mem_mb},${avg_io},${duration}" >> "$out_csv"
    else
        echo "${combo},${avg_cpu},${avg_mem_mb},${avg_io},${duration}" >> "$out_csv"
    fi

    echo "DONE: CPU=${avg_cpu}% MEM=${avg_mem_mb}MB IO=${avg_io}MB/s TIME=${duration}s"
    echo ""
}

echo "===== PART C ====="
for prog in program_a program_b; do
  for w in cpu mem io; do
    run_one "$prog" 2 "$w" "$CSV_C" "no"
  done
done

echo "===== PART D ====="
for n in 2 3 4 5; do
  for w in cpu mem io; do
    run_one program_a "$n" "$w" "$CSV_D" "yes"
  done
done

for n in 2 3 4 5 6 7 8; do
  for w in cpu mem io; do
    run_one program_b "$n" "$w" "$CSV_D" "yes"
  done
done

echo "✓ CSV generated:"
echo "  $CSV_C"
echo "  $CSV_D"


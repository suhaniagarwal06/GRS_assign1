#!/bin/bash
set -e

# OUTPUT: Save directly to current directory
CSV_C="MT25046_Part_C_CSV.csv"
CSV_D="MT25046_Part_D_CSV.csv"
IO_LOG="iostat_log.txt"

# Sampling Interval: 1 second as per assignment hint
SAMPLE_INTERVAL=1
# Pin to SINGLE core (Core 0) for strict comparison
CPU_PIN="0"

# Initialize files
echo "Program+Function,CPU%,Mem(KB),IO(MB/s),Time(s)" > "$CSV_C"
echo "Program+Function,NumWorkers,CPU%,Mem(KB),IO(MB/s),Time(s)" > "$CSV_D"
echo "=== IOSTAT LOG ===" > "$IO_LOG"

# Recursively get all descendant PIDs
get_tree_pids() {
    local root_pid=$1
    local all="$root_pid"
    local queue="$root_pid"

    while [[ -n "$queue" ]]; do
        local next=""
        for p in $queue; do
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

# Function to get IO Bytes (Write) from /proc (Reliable per-process)
get_write_bytes_tree() {
    local root_pid=$1
    local pids
    pids=$(get_tree_pids "$root_pid")

    local total=0
    for p in $pids; do
        if [[ -r "/proc/$p/io" ]]; then
            local wb
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

    local combo
    if [[ "$program" == "program_a" ]]; then
        combo="A+$worker"
    else
        combo="B+$worker"
    fi

    echo "Running $combo with $nworkers workers (Pinning to Core $CPU_PIN)..."

    # 1. EXECUTION TIME: Use /usr/bin/time as asked
    # Fixed: taskset -c 0 (Single Core)
    /usr/bin/time -f "%e" -o temp_time.txt taskset -c "$CPU_PIN" ./"$program" "$nworkers" "$worker" &
    local root_pid=$!

    local cpu_sum=0
    local mem_sum=0
    local io_sum=0
    local samples=0

    # IO baseline
    local wb_prev
    wb_prev=$(get_write_bytes_tree "$root_pid")

    # Loop while process is running
    while kill -0 "$root_pid" 2>/dev/null; do
        # 2. CPU/MEM MEASUREMENT: Use 'top' as asked
        local tree_pids
        tree_pids=$(get_tree_pids "$root_pid")
        
        # Parse top output for all related PIDs
        # FIX: Added '|| true' to prevent script crash if grep finds nothing
        local top_out
        top_out=$(top -b -n 1 -p $(echo $tree_pids | tr ' ' ',') 2>/dev/null | grep -E "^ *[0-9]+" || true)

        local current_cpu=0
        local current_mem=0

        if [[ -n "$top_out" ]]; then
             read current_cpu current_mem < <(echo "$top_out" | awk '{c+=$9; m+=$6} END {print c, m}')
        fi

        cpu_sum=$(awk -v a="$cpu_sum" -v b="$current_cpu" 'BEGIN{print a+b}')
        mem_sum=$(awk -v a="$mem_sum" -v b="$current_mem" 'BEGIN{print a+b}')
        samples=$((samples+1))

        # 3. IO MEASUREMENT (Internal calculation)
        local wb_now
        wb_now=$(get_write_bytes_tree "$root_pid")
        local delta_bytes=$((wb_now - wb_prev))
        [ $delta_bytes -lt 0 ] && delta_bytes=0
        
        local inst_io
        inst_io=$(awk -v b="$delta_bytes" -v t="$SAMPLE_INTERVAL" 'BEGIN{printf "%.6f", (b/(1024*1024))/t}')
        io_sum=$(awk -v a="$io_sum" -v b="$inst_io" 'BEGIN{print a+b}')
        wb_prev=$wb_now

        # 4. COMPLIANCE: Run iostat and log it
        echo "--- $combo ($nworkers) Sample $samples ---" >> "$IO_LOG"
        iostat -d -k 1 1 >> "$IO_LOG" 2>/dev/null || true

        sleep "$SAMPLE_INTERVAL"
    done

    # Wait for completion
    wait "$root_pid" 2>/dev/null || true

    # Read the time captured by /usr/bin/time
    local duration
    if [[ -f temp_time.txt ]]; then
        duration=$(cat temp_time.txt)
        rm -f temp_time.txt
    else
        duration="0.00"
    fi

    local avg_cpu avg_mem avg_io
    if [[ $samples -gt 0 ]]; then
        avg_cpu=$(awk -v s="$cpu_sum" -v n="$samples" 'BEGIN{printf "%.2f", s/n}')
        avg_mem=$(awk -v s="$mem_sum" -v n="$samples" 'BEGIN{printf "%.0f", s/n}')
        avg_io=$(awk -v s="$io_sum" -v n="$samples" 'BEGIN{printf "%.2f", s/n}')
    else
        avg_cpu="0.00"
        avg_mem="0"
        avg_io="0.00"
    fi

    # Clamp CPU to 100%
    avg_cpu=$(awk -v c="$avg_cpu" 'BEGIN{ if(c>100) printf "100.00"; else printf "%.2f", c }')

    if [[ "$include_nworkers" == "yes" ]]; then
        echo "${combo},${nworkers},${avg_cpu},${avg_mem},${avg_io},${duration}" >> "$out_csv"
    else
        echo "${combo},${avg_cpu},${avg_mem},${avg_io},${duration}" >> "$out_csv"
    fi

    echo "DONE: CPU=${avg_cpu}% MEM=${avg_mem}KB IO=${avg_io}MB/s TIME=${duration}s"
    echo ""
}

echo "===== PART C ====="
# Program A+cpu, A+mem, A+io, B+cpu... (2 workers)
for prog in program_a program_b; do
  for w in cpu mem io; do
    run_one "$prog" 2 "$w" "$CSV_C" "no"
  done
done

echo "===== PART D ====="
# A: 2,3,4,5
for n in 2 3 4 5; do
  for w in cpu mem io; do
    run_one program_a "$n" "$w" "$CSV_D" "yes"
  done
done

# B: 2..8
for n in 2 3 4 5 6 7 8; do
  for w in cpu mem io; do
    run_one program_b "$n" "$w" "$CSV_D" "yes"
  done
done

echo "✓ CSV generated:"
echo "  $CSV_C"
echo "  $CSV_D"
echo "✓ IO logs saved to:"
echo "  $IO_LOG"

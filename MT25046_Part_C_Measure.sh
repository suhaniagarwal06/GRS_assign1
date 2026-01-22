#!/bin/bash
set -e

OUTPUT_DIR="measurements"
mkdir -p "$OUTPUT_DIR"

CSV_C="$OUTPUT_DIR/MT25046_Part_C_CSV.csv"
CSV_D="$OUTPUT_DIR/MT25046_Part_D_CSV.csv"

CPU_CORE=2
SAMPLE_INTERVAL=0.2

echo "Program+Function,CPU%,Mem(MB),IO(MB/s),Time(s)" > "$CSV_C"
echo "Program+Function,NumWorkers,CPU%,Mem(MB),IO(MB/s),Time(s)" > "$CSV_D"

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

# Sample CPU% and RSS(KB) for all PIDs in tree
sample_cpu_mem_tree() {
    local root_pid=$1
    local pids
    pids=$(get_tree_pids "$root_pid")

    ps -o %cpu=,rss= -p $pids 2>/dev/null | awk '
        {cpu+=$1; mem+=$2}
        END {printf "%.2f %.0f\n", cpu, mem}
    '
}

# Sum write_bytes across all PIDs in tree
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

    echo "Running $combo with $nworkers workers..."

    # Start program pinned to CPU core
    taskset -c "$CPU_CORE" ./"$program" "$nworkers" "$worker" &
    local root_pid=$!

    # Start time
    local start_time
    start_time=$(date +%s.%N)

    local cpu_sum=0
    local mem_sum=0
    local io_sum=0
    local samples=0

    # IO baseline
    local wb_prev
    wb_prev=$(get_write_bytes_tree "$root_pid")

    while kill -0 "$root_pid" 2>/dev/null; do
        read cpu rss_kb < <(sample_cpu_mem_tree "$root_pid")

        cpu_sum=$(awk -v a="$cpu_sum" -v b="$cpu" 'BEGIN{print a+b}')
        mem_sum=$(awk -v a="$mem_sum" -v b="$rss_kb" 'BEGIN{print a+b}')
        samples=$((samples+1))

        # IO delta during runtime
        local wb_now
        wb_now=$(get_write_bytes_tree "$root_pid")

        local delta_bytes=$((wb_now - wb_prev))
        if [[ $delta_bytes -lt 0 ]]; then
            delta_bytes=0
        fi

        local inst_io
        inst_io=$(awk -v b="$delta_bytes" -v t="$SAMPLE_INTERVAL" \
            'BEGIN{printf "%.6f", (b/(1024*1024))/t}')

        io_sum=$(awk -v a="$io_sum" -v b="$inst_io" 'BEGIN{print a+b}')

        wb_prev=$wb_now
        sleep "$SAMPLE_INTERVAL"
    done

    wait "$root_pid" 2>/dev/null || true

    # End time
    local end_time
    end_time=$(date +%s.%N)

    local duration
    duration=$(awk -v s="$start_time" -v e="$end_time" 'BEGIN{printf "%.3f", (e-s)}')

    # Avoid division by zero
    if awk "BEGIN{exit !($duration <= 0)}"; then
        duration="0.001"
    fi

    local avg_cpu avg_mem_mb avg_io
    if [[ $samples -gt 0 ]]; then
        avg_cpu=$(awk -v s="$cpu_sum" -v n="$samples" 'BEGIN{printf "%.2f", s/n}')
        avg_mem_mb=$(awk -v s="$mem_sum" -v n="$samples" 'BEGIN{printf "%.2f", (s/n)/1024}')
        avg_io=$(awk -v s="$io_sum" -v n="$samples" 'BEGIN{printf "%.2f", s/n}')
    else
        avg_cpu="0.00"
        avg_mem_mb="0.00"
        avg_io="0.00"
    fi

    # Clamp CPU to 100%
    avg_cpu=$(awk -v c="$avg_cpu" 'BEGIN{ if(c>100) printf "100.00"; else printf "%.2f", c }')

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


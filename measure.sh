#!/bin/bash
set -e

OUTPUT_DIR="measurements"
LOG_DIR="${OUTPUT_DIR}/logs"

CSV_C="${OUTPUT_DIR}/MT25xxx_Part_C_CSV.csv"
CSV_D="${OUTPUT_DIR}/MT25xxx_Part_D_CSV.csv"

CPU_CORE=0
SAMPLE_INTERVAL=0.2   # faster sampling so mem worker doesn't become 0

mkdir -p "${OUTPUT_DIR}" "${LOG_DIR}"

echo "Program+Function,CPU%,Mem(MB),IO(MB/s)" > "${CSV_C}"
echo "Program+Function,NumWorkers,CPU%,Mem(MB),IO(MB/s)" > "${CSV_D}"

get_tree_pids() {
    local root_pid=$1
    echo "$root_pid $(pgrep -P "$root_pid" 2>/dev/null || true)"
}

sample_cpu_mem_tree() {
    local root_pid=$1
    local pids
    pids=$(get_tree_pids "$root_pid")

    ps -o %cpu=,rss= -p $pids 2>/dev/null | awk '
        {cpu+=$1; mem+=$2}
        END {printf "%.2f %.0f\n", cpu, mem}
    '
}

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

    local combo
    if [[ "$program" == "program_a" ]]; then
        combo="A+$worker"
    else
        combo="B+$worker"
    fi

    echo "Running $combo with $nworkers workers..."

    taskset -c "$CPU_CORE" ./"$program" "$nworkers" "$worker" &
    local root_pid=$!

    local cpu_sum=0
    local mem_sum=0
    local samples=0

    # IO tracking
    local wb_start wb_end
    wb_start=$(get_write_bytes_tree "$root_pid")

    local start_time
    start_time=$(date +%s.%N)

    while kill -0 "$root_pid" 2>/dev/null; do
        read cpu rss_kb < <(sample_cpu_mem_tree "$root_pid")

        cpu_sum=$(awk -v a="$cpu_sum" -v b="$cpu" 'BEGIN{print a+b}')
        mem_sum=$(awk -v a="$mem_sum" -v b="$rss_kb" 'BEGIN{print a+b}')
        samples=$((samples+1))

        sleep "$SAMPLE_INTERVAL"
    done

    wait "$root_pid" 2>/dev/null || true

    local end_time
    end_time=$(date +%s.%N)

    wb_end=$(get_write_bytes_tree "$root_pid")

    local duration
    duration=$(awk -v s="$start_time" -v e="$end_time" 'BEGIN{print (e-s)}')
    if awk "BEGIN{exit !($duration <= 0)}"; then
        duration=0.001
    fi

    local avg_cpu avg_mem_mb
    if [[ $samples -gt 0 ]]; then
        avg_cpu=$(awk -v s="$cpu_sum" -v n="$samples" 'BEGIN{printf "%.2f", s/n}')
        avg_mem_mb=$(awk -v s="$mem_sum" -v n="$samples" 'BEGIN{printf "%.2f", (s/n)/1024}')
    else
        avg_cpu="0.00"
        avg_mem_mb="0.00"
    fi

    local written_bytes
    written_bytes=$((wb_end - wb_start))
    if [[ $written_bytes -lt 0 ]]; then
        written_bytes=0
    fi

    local io_mbps
    io_mbps=$(awk -v b="$written_bytes" -v t="$duration" 'BEGIN{printf "%.2f", (b/(1024*1024))/t}')

    if [[ "$include_nworkers" == "yes" ]]; then
        echo "${combo},${nworkers},${avg_cpu},${avg_mem_mb},${io_mbps}" >> "$out_csv"
    else
        echo "${combo},${avg_cpu},${avg_mem_mb},${io_mbps}" >> "$out_csv"
    fi

    echo "DONE: CPU=${avg_cpu}% MEM=${avg_mem_mb}MB IO=${io_mbps}MB/s"
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

# Graduate Systems (CSE638) — PA01: Processes and Threads  
**Roll Number:** 25046  
**Student Name:** Suhani Agarwal  
**GitHub Repo:** https://github.com/suhaniagarwal06/GRS_assign1  

---

## 📌 Assignment Overview

This programming assignment compares **process-based parallelism** vs **thread-based parallelism** using two programs:

- **Program A (Processes):** Creates multiple child processes using `fork()`
- **Program B (Threads):** Creates multiple threads using `pthread`

Each program executes one of three worker functions:
- `cpu` → CPU intensive workload  
- `mem` → Memory intensive workload  
- `io` → I/O intensive workload  

The performance metrics measured are:
- **CPU%**
- **Memory (MB)**
- **I/O throughput (MB/s)**
- **Execution time (s)**

---

## 📂 Folder Structure (Deliverables)

This folder contains:

- `MT25046_Part_A_Program_A.c` → Program A (processes using fork)
- `MT25046_Part_A_Program_B.c` → Program B (threads using pthread)
- `MT25046_Part_B_Workers.c` → Worker function implementations (cpu, mem, io)
- `MT25046_Part_B_Workers.h` → Header file for worker functions
- `Makefile` → Build instructions
- `MT25046_Part_C_Measure.sh` → Automated measurement script (Part C + Part D)
- `MT25046_Part_D_Plotter.py` → Generates plots from CSV files
- `MT25046_run_all.sh` → Runs build + measurements + plotting
- `measurements/` → Generated CSV + plots  
  - `MT25046_Part_C_CSV.csv`
  - `MT25046_Part_D_CSV.csv`
  - `plots/` (PNG plots)

⚠️ **Note:** Executable binaries (`program_a`, `program_b`) are NOT included in GitHub submission as per instructions.

---

## ⚙️ Part A: Programs

### Program A (Processes)
- Creates **N child processes** using `fork()`
- Each child executes one worker: `cpu`, `mem`, or `io`

### Program B (Threads)
- Creates **N threads** using `pthread_create()`
- Each thread executes one worker: `cpu`, `mem`, or `io`

---

## ⚙️ Part B: Worker Functions

Worker functions are implemented inside `MT25046_Part_B_Workers.c`:

### `cpu_worker(int id)`
CPU-intensive computation loop to consume CPU cycles.

### `mem_worker(int id)`
Allocates a large memory buffer and repeatedly accesses it to increase RAM usage.

### `io_worker(int id)`
Creates a temporary file, performs repeated writes, calls `fsync()` to force disk I/O, then deletes the file.

**Loop count rule used:**  
Last digit of roll number = **6**  
So loop count = **6 × 10³ = 6000**

---

## 📊 Part C: Measurement (Fixed Workers = 2)

For each combination:

- A+cpu
- A+mem
- A+io
- B+cpu
- B+mem
- B+io

The script records:

| Metric | Source |
|-------|--------|
| CPU% | `ps` sampling |
| Mem(MB) | RSS from `ps` |
| IO(MB/s) | `/proc/<pid>/io write_bytes` |
| Time(s) | `date +%s.%N` duration |

Output CSV:
- `measurements/MT25046_Part_C_CSV.csv`

---

## 📈 Part D: Scaling Workers

Program A tested with workers:
- **2, 3, 4, 5 processes**

Program B tested with workers:
- **2, 3, 4, 5, 6, 7, 8 threads**

Output CSV:
- `measurements/MT25046_Part_D_CSV.csv`

Plots generated in:
- `measurements/plots/`

---

## 🛠️ How to Run

### 1️⃣ Compile the programs
```bash
make
```

### 2️⃣ Run measurements (Part C + D)
```bash
chmod +x MT25046_Part_C_Measure.sh
./MT25046_Part_C_Measure.sh
```

### 3️⃣ Generate plots
```bash
python3 MT25046_Part_D_Plotter.py
```

### 4️⃣ Run everything automatically
```bash
chmod +x MT25046_run_all.sh
./MT25046_run_all.sh
```

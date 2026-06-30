# Synchronous FIFO — Project 1A

A synchronous FIFO (First-In First-Out) buffer implemented in SystemVerilog
and verified with a fully self-checking directed testbench.
Simulated on EDA Playground with Icarus Verilog and EPWave.

---

## Project Structure
SYNCHRONOUS-FIFO-VERILOG/
├── images/
│   ├── fifo_block_diagram.png       # Internal block diagram of the FIFO
│   ├── simulation_output.png        # Console output showing PASS=27 FAIL=0
│   ├── waveform_empty.png           # EPWave screenshot — empty condition
│   ├── waveform_full.png            # EPWave screenshot — full condition
│   └── waveform_write_read.png      # EPWave screenshot — normal write/read
├── rtl/
│   └── fifo_sync.sv                 # RTL design — paste into EDA Playground Design panel
├── tb/
│   └── tb_fifo_sync.sv              # Testbench — paste into EDA Playground Testbench panel
└── readme.md                        # This file

---

## What This Project Does

A FIFO is a queue-style memory where data written first is always read first.
This design uses a single clock for both reads and writes (synchronous),
making it suitable for buffering data between pipeline stages,
UART interfaces, AXI data paths, and CPU instruction queues.

**Parameters:**

| Parameter    | Value  | Meaning                               |
|--------------|--------|---------------------------------------|
| FIFO_DEPTH   | 16     | Number of storage slots               |
| DATA_WIDTH   | 8      | Bits per word                         |
| Pointer width| 5 bits | Extra MSB enables full/empty detection|
| Clock        | 1      | Single shared clock                   |
| Reset        | rst_n  | Active-low                            |

---

## How to Run on EDA Playground

1. Go to [edaplayground.com](https://edaplayground.com) and log in (free).
2. Paste the contents of `rtl/fifo_sync.sv` into the **Design** panel.
3. Paste the contents of `tb/tb_fifo_sync.sv` into the **Testbench** panel .
4. Set the following options at the top of the page:

| Setting               | Value                 |
|-----------------------|-----------------------|
| Testbench + Design    | ✅ Checked            |
| Language              | SystemVerilog/Verilog |
| Simulator             | Icarus Verilog        |
| Open EPWave after run | ✅ Checked            |

5. Click **Run**.
6. In EPWave: click **Get Signals** → expand `tb_fifo_sync` → expand `dut`
   → **Append All** → press `Ctrl+Shift+F` to fit all waveforms on screen.

---

## Design — How It Works

### Pointer Scheme (Extra-Bit Trick)

Both `wr_ptr` and `rd_ptr` are **5 bits wide** (log2(16)+1).
The extra MSB detects full vs empty unambiguously:

| Condition | Rule                                  |
|-----------|---------------------------------------|
| Empty     | `wr_ptr == rd_ptr` (all 5 bits equal) |
| Full      | MSBs differ AND lower 4 bits equal    |

### Write Operation
- Triggered on `posedge clk`
- Guard: `cs && wr_en && !full`
- Stores `data_in` into `mem[wr_ptr[ADDR-1:0]]` then increments `wr_ptr`
- Reset (`rst_n = 0`) clears `wr_ptr` to 0

### Read Operation
- Triggered on `posedge clk`
- Guard: `cs && rd_en && !empty`
- `data_out` is **registered** — valid **one clock cycle after** `rd_en` is asserted
- Reset clears both `rd_ptr` and `data_out` to 0

### Port Reference

| Port     | Dir | Width | Description                             |
|----------|-----|-------|-----------------------------------------|
| clk      | in  | 1     | System clock — all events on posedge    |
| rst_n    | in  | 1     | Active-low async reset                  |
| cs       | in  | 1     | Chip select — must be high to read/write|
| wr_en    | in  | 1     | Write enable                            |
| rd_en    | in  | 1     | Read enable                             |
| data_in  | in  | 8     | Data to write into FIFO                 |
| data_out | out | 8     | Data read from FIFO (1-cycle latency)   |
| empty    | out | 1     | High when FIFO is empty (combinational) |
| full     | out | 1     | High when FIFO is full (combinational)  |

---

## Testbench — Test Cases

### TEST 1 — Normal Write / Read
Write values 1, 2, 3 then read them back in order.  
Confirms FIFO ordering (first in, first out) and validates the 1-cycle registered read latency.

### TEST 2 — Fill to FULL
Write 16 items and verify the `full` flag asserts.  
Confirms the flag fires at exactly depth 16, not 15 or 17.

### TEST 3 — Overflow Protection
Attempt 2 extra writes on a full FIFO, then drain and verify all 16 original items are intact.  
A buggy FIFO might overwrite `mem[0]` or corrupt `wr_ptr` — this test catches that.

### TEST 4 — Drain to EMPTY
Write 8 items (half depth), drain them all, verify the `empty` flag asserts.  
Confirms the flag resets correctly after a mid-use drain, not just from power-on reset.

### TEST 5 — Underflow Protection
Attempt 2 reads on an empty FIFO and verify `empty` stays asserted.  
A buggy design might advance `rd_ptr` past `wr_ptr`, permanently breaking flag logic.

---

## Bugs Fixed (vs Original Code)

| # | Where          | Bug                                                        | Fix                                                       |
|---|----------------|------------------------------------------------------------|-----------------------------------------------------------|
| 1 | RTL            | `wr_ptr_next` declared but never used                      | Removed dead signal                                       |
| 2 | TB write_data  | `full` checked after posedge — 16th push skipped from model| Sample `was_full = full` at negedge **before** driving    |
| 3 | TB read_data   | `data_out` sampled one cycle too early                     | Added `@(posedge clk); @(negedge clk)` before sampling   |
| 4 | TB $display    | `$display(cond ? "A" : "B")` prints garbage in Icarus     | Use `if/else` inside `check_full()` / `check_empty()` tasks|
| 5 | TB flag checks | `#10` delay not clock-aligned — can race with flags        | Replaced with `@(posedge clk); #1`                       |
| 6 | TB $dumpvars   | Missing scope — sub-hierarchy absent in EPWave             | Changed to `$dumpvars(0, tb_fifo_sync)`                  |

---

## Expected Console Output
=== TEST 1: Normal Write / Read ===
MATCH     data=1
MATCH     data=2
MATCH     data=3
=== TEST 2: Fill to FULL ===
TEST2: FULL  asserted - PASS
=== TEST 3: Overflow Protection ===
WARNING: WRITE IGNORED (full) data=170
WARNING: WRITE IGNORED (full) data=187
TEST3: FULL  asserted - PASS
MATCH     data=10
... (16 matches total)
TEST3-drain: EMPTY asserted - PASS
=== TEST 4: Drain to EMPTY ===
MATCH     data=100
... (8 matches total)
TEST4: EMPTY asserted - PASS
=== TEST 5: Underflow Protection ===
WARNING: UNDERFLOW  empty=1
WARNING: UNDERFLOW  empty=1
TEST5: EMPTY asserted - PASS
=== SUMMARY: PASS=27  FAIL=0 ===

---

## EPWave — Key Signals to Watch

| Signal       | What to Observe                                     |
|--------------|-----------------------------------------------------|
| clk          | 10 ns period (posedge every 5 ns)                   |
| rst_n        | Low for first 2 cycles then goes high               |
| wr_en/rd_en  | Never both high simultaneously                      |
| data_in      | Value being written — changes at negedge            |
| data_out     | Updates ONE cycle after rd_en posedge               |
| empty        | High at start; goes low after first write           |
| full         | Goes high after 16 consecutive writes               |
| wr_ptr[4:0]  | Bit 4 flips when FIFO wraps to full                 |
| rd_ptr[4:0]  | Advances on every successful read                   |

---

## Tools Used

| Tool          | Purpose                        |
|---------------|--------------------------------|
| EDA Playground| Browser-based HDL simulator    |
| Icarus Verilog| Open-source Verilog simulator  |
| EPWave        | Browser-based waveform viewer  |
| SystemVerilog | HDL language used for RTL & TB |
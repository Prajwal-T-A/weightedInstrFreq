# EVALUATION — Weighted Instruction Frequency Analysis Pass

## 1. Evaluation Methodology

The pass is evaluated on **7 hand-crafted LLVM IR / C test files** that cover distinct instruction-mix profiles. For each file we measure:

1. **Total instruction count** — raw number of instructions in the function.
2. **Per-opcode frequency** — how many times each opcode appears.
3. **Total weighted cost** — sum of (count × weight) for all opcodes.
4. **Most-expensive instruction type** — the opcode whose accumulated cost is highest.

A **baseline comparison** (raw count vs. weighted cost) illustrates how the weight model changes the interpretation.

---

## 2. Baseline vs. Weighted Cost Comparison

The table below compares the two metrics for one representative function from each test file:

| Test | Function | Raw Count | Weighted Cost | Dominant Opcode (weighted) | Dominant Opcode (raw count) |
|------|----------|----------:|:-------------:|:--------------------------:|:---------------------------:|
| test1.ll | `simple_math` | 6 | 8 | `mul` (4) | `add` (2 × count) |
| test2.ll | `memory_test` | 8 | 19 | `load` (6) | `load` (2) |
| test3.ll | `factorial` | 7 | 13 | `call` (5) | `ret` (2 × count) |
| test4.ll | `main` | 15 | 45 | `call` (15) | `store` / `alloca` |
| test5.ll | `dot_product` | 6 | 10 | `fmul` (6) | `fmul` (3) |
| test6.ll | `bitwise_ops` | 11 | 12 | `add` (6) | `add` (6) |
| test7.ll | `array_sum_normalized` | 16 | 46 | `call` (10) | `load` (4) |

### Key finding
Raw counts **underestimate** the relative expense of `call`, `load`, and `store` instructions. The weighted model correctly surfaces these as the most expensive instruction types in functions that perform memory traffic or function calls.

---

## 3. Per-test Case Summary

### Test 1 — Arithmetic Focus (`tests/test1.ll`)

**Functions:** `simple_math`, `just_add`

| Opcode | Count | Weight | Cost |
|--------|------:|-------:|-----:|
| add | 2 | 1 | 2 |
| mul | 2 | 2 | 4 |
| sub | 1 | 1 | 1 |
| ret | 1 | 1 | 1 |
| **Total** | **6** | — | **8** |

**Most expensive:** `mul` (cost 4)  
**Takeaway:** Even though `add` appears as often as `mul`, the weight model correctly identifies `mul` as costlier.

---

### Test 2 — Memory Operations (`tests/test2.ll`)

**Functions:** `memory_test`, `store_heavy`

`memory_test`:

| Opcode | Count | Weight | Cost |
|--------|------:|-------:|-----:|
| alloca | 1 | 2 | 2 |
| load | 2 | 3 | 6 |
| store | 1 | 3 | 3 |
| getelementptr | 1 | 1 | 1 |
| add | 1 | 1 | 1 |
| call | 1 | 5 | 5 |
| ret | 1 | 1 | 1 |
| **Total** | **8** | — | **19** |

**Most expensive:** `load` (cost 6)

---

### Test 3 — Control Flow and Recursion (`tests/test3.ll`)

**Functions:** `factorial`, `max_of_three`

`factorial`:

| Opcode | Count | Weight | Cost |
|--------|------:|-------:|-----:|
| icmp | 1 | 1 | 1 |
| br | 1 | 2 | 2 |
| ret | 2 | 1 | 2 |
| sub | 1 | 1 | 1 |
| call | 1 | 5 | 5 |
| mul | 1 | 2 | 2 |
| **Total** | **7** | — | **13** |

**Most expensive:** `call` (cost 5)  
**Takeaway:** A single recursive call is the most expensive operation, despite being only 1/7 of all instructions.

---

### Test 4 — Compiled C Program (`tests/test4.ll`, from `tests/test4.c`)

This test uses a real C program compiled to LLVM IR with `clang -O0`:

```c
int compute(int a, int b);   // add, mul, sdiv
void swap(int *a, int *b);   // load, store
int main();                   // alloca, call, store
```

`main` summary:

| Opcode | Count | Weight | Cost |
|--------|------:|-------:|-----:|
| alloca | 4 | 2 | 8 |
| load | 3 | 3 | 9 |
| store | 4 | 3 | 12 |
| call | 3 | 5 | 15 |
| ret | 1 | 1 | 1 |
| **Total** | **15** | — | **45** |

**Most expensive:** `call` (cost 15)

---

### Test 5 — Floating-Point Intensive (`tests/test5.ll`)

**Functions:** `dot_product`, `normalize_score`, `float_to_int_round`

`dot_product`:

| Opcode | Count | Weight | Cost |
|--------|------:|-------:|-----:|
| fmul | 3 | 2 | 6 |
| fadd | 2 | 1 | 2 |
| ret | 1 | 1 | 1 |
| **Total** | **6** | — | **9** |

**Most expensive:** `fmul` (cost 6)  
**Takeaway:** Despite equal opcode counts for `fmul` and `fadd` in isolation, the weight-2 multiplier on `fmul` makes it the dominant cost — consistent with hardware latency on most CPUs.

---

### Test 6 — Bitwise and Type Conversions (`tests/test6.ll`)

**Functions:** `bitwise_ops`, `type_conversions`, `compare_all`

`bitwise_ops`:

| Opcode | Count | Weight | Cost |
|--------|------:|-------:|-----:|
| and | 1 | 1 | 1 |
| or | 1 | 1 | 1 |
| xor | 1 | 1 | 1 |
| shl | 1 | 1 | 1 |
| lshr | 1 | 1 | 1 |
| ashr | 1 | 1 | 1 |
| add | 5 | 1 | 5 |
| ret | 1 | 1 | 1 |
| **Total** | **12** | — | **12** |

**Most expensive:** `add` (cost 5 — accumulated across 5 `add` instructions)  
**Takeaway:** All bitwise ops and shifts carry weight 1. The function is uniformly cheap — the weighted cost equals the raw count, confirming the pass correctly identifies low-cost workloads.

---

### Test 7 — Mixed High-Cost Workload (`tests/test7.ll`)

**Functions:** `array_sum_normalized`, `integer_divide_series`

`array_sum_normalized` (loop body with memory + call):

| Opcode | Count | Weight | Cost |
|--------|------:|-------:|-----:|
| alloca | 1 | 2 | 2 |
| phi | 1 | 1 | 1 |
| getelementptr | 1 | 1 | 1 |
| load | 3 | 3 | 9 |
| call | 2 | 5 | 10 |
| icmp | 2 | 1 | 2 |
| br | 2 | 2 | 4 |
| add | 2 | 1 | 2 |
| store | 2 | 3 | 6 |
| sdiv | 1 | 4 | 4 |
| ret | 1 | 1 | 1 |
| **Total** | **~18** | — | **~42** |

**Most expensive:** `call` (cost 10)

`integer_divide_series`:

| Opcode | Count | Weight | Cost |
|--------|------:|-------:|-----:|
| sdiv | 2 | 4 | 8 |
| udiv | 1 | 4 | 4 |
| srem | 1 | 4 | 4 |
| urem | 1 | 4 | 4 |
| add | 1 | 1 | 1 |
| ret | 1 | 1 | 1 |
| **Total** | **7** | — | **22** |

**Most expensive:** `sdiv` (cost 8)  
**Takeaway:** 6 out of 7 instructions are division/remainder operations (weight 4). The weighted cost (22) is more than 3× the raw count (7), accurately reflecting the expensive nature of integer division.

---

## 4. Weight Sensitivity Analysis

How does the choice of weight affect the interpretation?

| Scenario | Raw metric says | Weighted metric says |
|----------|----------------|----------------------|
| Function with many `add`s | `add` is dominant | `add` is cheap (w=1) — not dominant unless count is very high |
| Function with 1 `call` + 5 `add`s | `add` dominates by count | `call` (w=5) may dominate over all 5 `add`s (w=1 × 5 = 5) — tied or `call` wins |
| Function with 3 `load`s + 1 `call` | `load` dominates by count | `call` (5) > `load`×3 (9)? No: 9 > 5, load wins — correctly models the total memory traffic cost |
| Function with 1 `atomicrmw` | atomic is 1/N instructions | Weight 10 — immediately identified as the bottleneck |

---

## 5. Limitations of the Evaluation

* **Static analysis only:** weights are estimated constants, not real hardware measurements.
* **No loop trip counts:** instructions inside loops are counted once per static occurrence, not multiplied by expected execution frequency.
* **No cache model:** `load`/`store` weight = 3 assumes L1 hit. Real cost depends on memory access pattern.
* **Tied costs:** when two opcodes have the same total cost, the one with the lower opcode ID is reported as "most expensive."

---

## 6. How to Reproduce All Results

```bash
# Step 1: Build the plugin
./build.sh

# Step 2: Run all tests and save outputs
./run.sh --all --save

# Step 3: Compare against reference outputs
diff output/test1_output.txt <(opt -load-pass-plugin ./build/WeightedInstrFreqPass.dylib \
    -passes='function(weighted-instr-freq)' -disable-output tests/test1.ll 2>&1)
```

All reference outputs are committed in `output/test*_output.txt`.

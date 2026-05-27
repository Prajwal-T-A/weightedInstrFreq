# WeightedInstrFreq

WeightedInstrFreq is an LLVM pass plugin that analyzes each function in LLVM IR, counts the instruction mix, applies a configurable weight to each opcode, and prints a compact cost report to `stderr`. The project is set up as a shared LLVM plugin built with CMake and is intended for experiments, demos, presentations, and report writing around instruction-cost profiling.

## What the pass does

For every non-declaration function, the pass walks all basic blocks and instructions, then reports:

- total instruction count
- per-opcode instruction frequency
- weighted cost per opcode
- total weighted cost for the function
- the most expensive instruction type in that function

The output is human-readable and is formatted as a repeated report block, one block per function.

## Repository layout

- [CMakeLists.txt](CMakeLists.txt) defines the LLVM-based shared library target `WeightedInstrFreqPass`.
- [src/WeightedInstrFreq.cpp](src/WeightedInstrFreq.cpp) contains the pass implementation and plugin registration used by the build.
- [src/WeightedInstrFreq.h](src/WeightedInstrFreq.h) declares the pass type.
- [src/PassPlugin.cpp](src/PassPlugin.cpp) contains a separate plugin-registration example, but it is not part of the default CMake target.
- [tests/](tests) contains sample LLVM IR and C inputs used to exercise the pass.
- [output/](output) contains reference output captured from the sample inputs.

## Implementation overview

The pass is a function pass built on LLVM’s new pass manager. In [src/WeightedInstrFreq.cpp](src/WeightedInstrFreq.cpp), each instruction opcode is mapped to a weight, then aggregated into two tables:

- a count table for how many times each opcode appears
- a cost table for the accumulated weighted cost of each opcode

The pass currently assigns these representative weights:

- simple arithmetic and comparisons: `1`
- multiplication and some casts: `2`
- loads and stores: `3`
- divisions, calls, invokes, and similar expensive operations: `4` to `5`
- atomics: `10`

Unknown opcodes fall back to a default weight of `1`.

The plugin registers in two ways:

- pipeline parsing callback for the explicit pass name `weighted-instr-freq`
- optimizer-last extension point so the pass can run automatically in optimized pipelines such as `-O2` and `-O3`

## Build requirements

- CMake 3.20 or newer
- A compatible LLVM installation with CMake config files
- Clang/LLVM 22.x works with the current code and build settings in this repository
- macOS with Homebrew LLVM is the environment this project was prepared in

## Build

From the repository root:

```bash
cmake -S . -B build
cmake --build build
```

The resulting plugin is built as `build/WeightedInstrFreqPass.dylib` on macOS.

## Run the pass

### 1. Run directly on LLVM IR with `opt`

Use the plugin name registered by the pass:

```bash
opt -load-pass-plugin ./build/WeightedInstrFreqPass.dylib \
  -passes='function(weighted-instr-freq)' \
  -disable-output \
  tests/test1.ll
```

The pass prints its report to standard error, so redirect `stderr` if you want to capture it:

```bash
opt -load-pass-plugin ./build/WeightedInstrFreqPass.dylib \
  -passes='function(weighted-instr-freq)' \
  -disable-output \
  tests/test1.ll 2> my_report.txt
```

### 2. Let the pass run as part of an optimized pipeline

Because the plugin registers an optimizer-last callback, it can also be loaded into an optimized LLVM pipeline and run automatically at higher optimization levels such as `-O2` and `-O3`.

## Sample inputs and reference outputs

The repository includes four sample scenarios that cover the main instruction categories handled by the pass:

- [tests/test1.ll](tests/test1.ll) exercises arithmetic-heavy code
- [tests/test2.ll](tests/test2.ll) covers memory operations and calls
- [tests/test3.ll](tests/test3.ll) covers control flow, recursion, and branching
- [tests/test4.c](tests/test4.c) and [tests/test4.ll](tests/test4.ll) cover a compiled C example with loads, stores, calls, and pointer traffic

Reference output for each case is stored in:

- [output/test1_output.txt](output/test1_output.txt)
- [output/test2_output.txt](output/test2_output.txt)
- [output/test3_output.txt](output/test3_output.txt)
- [output/test4_output.txt](output/test4_output.txt)

These files are useful when you want to compare a fresh run against the current expected behavior or extract example figures for slides and reports.

## Expected reporting behavior

For each analyzed function, the report is organized into a fixed block:

1. header
2. function name
3. total instruction count
4. per-opcode frequency table
5. total weighted cost
6. the most expensive instruction type

This structure makes the output suitable for copy/paste into reports or presentation slides.

## Notes for presentations and reports

- The pass is deterministic for a given IR file because it uses fixed opcode weights and ordered map iteration.
- The output is text-based, so it is easy to capture, compare, and quote in documentation.
- [tests/test4.c](tests/test4.c) is useful when you want to show the source-level program that produces the more complex LLVM IR in [tests/test4.ll](tests/test4.ll).
- The current codebase does not define a separate CTest suite; the checked-in fixtures and reference outputs serve as the practical validation set.

## Troubleshooting

- If the plugin does not load, confirm that the built `.dylib` matches your LLVM version.
- If the build cannot find LLVM, check `LLVM_DIR` and ensure your LLVM installation exposes CMake package files.
- If the output looks empty, make sure you are running the pass on IR with function definitions rather than declarations only.

## Project intent

The repository is a small, focused LLVM pass project. Its main purpose is to demonstrate how to:

- build an LLVM pass plugin with CMake
- traverse LLVM IR at the function level
- attach custom weights to instruction opcodes
- produce readable analysis output for documentation, comparison, and benchmarking narratives

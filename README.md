# DFE Filter Array Design

A multistage **Digital Front End (DFE)** filter chain developed for the **SI-Clash Competition**, powered by IEEE SSCS AUSC. The project implements three digital signal processing stages — a Notch Filter bank, a CIC Decimator, and a Fractional (FIR) Decimator — each designed, modeled in Python, generated via MATLAB HDL Coder, and verified against a fixed-point golden model.

---

## Table of Contents

- [System Overview](#system-overview)
- [DFE Pipeline](#dfe-pipeline)
- [Project Structure](#project-structure)
- [Module Descriptions](#module-descriptions)
  - [Notch Filters](#notch-filters)
  - [CIC Decimator](#cic-decimator)
  - [Fractional Decimator](#fractional-decimator)
- [Fixed-Point Arithmetic](#fixed-point-arithmetic)
- [Golden Models](#golden-models)
- [Simulation Setup](#simulation-setup)
- [File Reference](#file-reference)

---

## System Overview

The DFE receives a high-rate 16-bit Q15 (`sfix16_En15`) digital signal and processes it through three cascaded filter stages:

1. **Notch Filters** — suppress narrowband interference at 2.4 MHz and 5 MHz
2. **CIC Decimator** — integer-ratio rate reduction (R ∈ {1, 2, 4, 8, 16}) with configurable decimation factor
3. **Fractional Decimator** — polyphase FIR-based 3/2 rate conversion for non-integer resampling

All RTL modules use a uniform `clk / reset / clk_enable / dataIn / validIn / dataOut / validOut` interface, enabling seamless cascade.

---

## DFE Pipeline

```
High-Rate Input (sfix16_En15)
        │
        ▼
┌───────────────────┐
│  Notch Filter     │  2.4 MHz notch (Biquad DF-II, 16 or 20-bit coefficients)
│  @ 2.4 MHz        │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│  Notch Filter     │  5 MHz notch (Biquad DF-II, 20-bit coefficients)
│  @ 5 MHz          │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│  CIC Decimator    │  Integer decimation R ∈ {1,2,4,8,16}
│  (4-stage I+DS+C) │  sfix16_En15 → sfix16_En15 (via sfix20 internal)
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│  Fractional       │  3/2 polyphase FIR rate conversion
│  Decimator        │  72-tap, 7-stage adder tree, 10-cycle pipeline
└────────┬──────────┘
         │
         ▼
Low-Rate Output (sfix16_En15)
```

---

## Project Structure

```
DFE-FILTER_ARRAY_DESIGN/
│
├── notch_filter/
│   ├── 2.4MHz_notch/
│   │   ├── RTL_16_coe/             # Biquad notch, 16-bit coefficients
│   │   │   ├── FinalFirstNotch24.v      # Top-level wrapper
│   │   │   ├── dsphdl_BiquadFilter.v    # DSP HDL biquad core
│   │   │   └── BiquadDF2Section1.v      # DF-II biquad section
│   │   ├── RTL_20_coe/             # Biquad notch, 20-bit coefficients
│   │   │   ├── Final20Notch24.v
│   │   │   ├── dsphdl_BiquadFilter.v
│   │   │   └── BiquadDF2Section1.v
│   │   ├── golden_model/
│   │   │   ├── FINAL_notch_goldenmodel2.4.ipynb
│   │   │   └── notch_expected_golden.txt
│   │   └── testbench/
│   │       ├── tb_notch_filter.v
│   │       ├── notch_stimulus.txt
│   │       └── tb_out_final.txt
│   │
│   └── 5MHz_notch/
│       ├── RTL/
│       │   ├── Final20Notch5.v
│       │   ├── dsphdl_BiquadFilter.v
│       │   └── BiquadDF2Section1.v
│       ├── golden_model/
│       │   ├── notch_goldenmodel5.ipynb
│       │   └── notch5_expected_golden.txt
│       └── testbench/
│           ├── tb_notch_filter.v
│           ├── notch5_stimulus.txt
│           └── tb_out_final.txt
│
├── CIC_decimator/
│   ├── RTL/
│   │   ├── finalCIC.sv                  # Top-level with SVA assertions
│   │   ├── CICDecimation.v              # CIC pipeline orchestrator
│   │   ├── iSection.v                   # 4-stage integrator
│   │   ├── dsSection.v                  # Configurable downsampler
│   │   ├── cSection.v                   # 4-stage comb
│   │   ├── gcSection.v                  # Gain compensation (passthrough)
│   │   ├── castSection.v                # sfix20→sfix16 saturating cast
│   │   └── fir_output_formatter.v       # Convergent rounding formatter
│   ├── golden_model/
│   │   ├── CIC_gm.py                    # RTL-accurate Python reference
│   │   ├── cic_goldenmodel.ipynb
│   │   └── cic_expected.txt
│   └── testbench/
│       ├── tb.sv
│       ├── run.do
│       └── cic_tb_out.txt
│
├── fractional_decimator/
│   ├── RTL/
│   │   ├── FinalFractionalDecimator.v         # Top-level wrapper
│   │   ├── dsphdl_FIRRateConverter.v          # FIR rate converter core
│   │   ├── FIR_Rate_Conversion_Filter.v       # 72-tap polyphase FIR
│   │   └── FIR_Rate_Converter_Controller.v    # Polyphase schedule controller
│   ├── golden_model/
│   │   ├── Fractional_gm.ipynb
│   │   └── frac_expected.txt
│   └── testbench/
│       ├── tb.v
│       ├── run.do
│       ├── frac_stimulus.txt
│       └── rtl_out_frac.csv
│
├── Digital_Track_Problem_Statement.pdf
├── Final_Report_SI_Clash.pdf
└── README.md
```

---

## Module Descriptions

### Notch Filters

Two cascaded notch filters suppress narrowband interference before decimation. Each is a **Direct Form II (DF-II) Biquad IIR** generated by MATLAB HDL Coder 25.2.

#### 2.4 MHz Notch — Two coefficient precision variants

| Variant       | Top Module          | Coefficient Width | File              |
|--------------|---------------------|--------------------|-------------------|
| 16-bit coeff | `FinalFirstNotch24` | 16-bit             | `RTL_16_coe/`     |
| 20-bit coeff | `Final20Notch24`    | 20-bit             | `RTL_20_coe/`     |

#### 5 MHz Notch

| Module          | Coefficient Width | File     |
|-----------------|-------------------|----------|
| `Final20Notch5` | 20-bit            | `RTL/`   |

**Interface (all notch variants):**

| Port        | Direction | Width | Description             |
|-------------|-----------|-------|-------------------------|
| `clk`       | input     | 1     | System clock            |
| `reset`     | input     | 1     | Active-low reset        |
| `clk_enable`| input     | 1     | Clock enable            |
| `dataIn`    | input     | 16    | sfix16_En15 sample      |
| `validIn`   | input     | 1     | Input valid strobe      |
| `ce_out`    | output    | 1     | Clock enable passthrough|
| `dataOut`   | output    | 16    | sfix16_En15 filtered    |
| `validOut`  | output    | 1     | Output valid strobe     |

The biquad core (`dsphdl_BiquadFilter`) instantiates `BiquadDF2Section1` for each second-order section.

---

### CIC Decimator

A 4-stage **Cascaded Integrator-Comb (CIC)** decimator with runtime-configurable decimation factor.

#### Top-Level: `finalCIC_with_assertions` (`finalCIC.sv`)

- Sanitizes the requested decimation factor `RIn` to the allowed set {1, 2, 4, 8, 16}
- Includes a **SystemVerilog assertion** (`p_R_power_of_two`) that fires on any invalid R during simulation
- Instantiates `CICDecimation`

#### CIC Pipeline: `CICDecimation` (`CICDecimation.v`)

Orchestrates the five pipeline stages with 2-cycle input pipeline delay:

```
dataIn[15:0] → iSection → dsSection → cSection → castSection → dataOut[15:0]
                (integrate) (downsample) (comb)    (16-bit cast)
```

| Sub-module      | Function                                                    | Internal Width |
|-----------------|-------------------------------------------------------------|----------------|
| `iSection`      | 4 cascaded accumulators (integrators), valid-gated          | sfix20_En15    |
| `dsSection`     | Configurable 1-of-R downsampler with counter                | sfix20_En15    |
| `cSection`      | 4 cascaded differentiators (comb sections)                  | sfix20_En15    |
| `gcSection`     | Gain compensation stage (passthrough in current config)     | sfix20_En15    |
| `castSection`   | Round-and-saturate sfix20 → sfix16                          | sfix16_En15    |

**Decimation factor constraints:**
- Hardware clamps `R` to the range [1, 16] at the `CICDecimation` level
- `finalCIC.sv` further restricts to power-of-two values {1, 2, 4, 8, 16}
- A dynamic R-change mid-stream triggers an internal `vReset` to flush pipeline state

**Interface: `finalCIC_with_assertions`**

| Port        | Direction | Width | Description                             |
|-------------|-----------|-------|-----------------------------------------|
| `clk`       | input     | 1     | System clock (100 MHz testbench)        |
| `reset_n`   | input     | 1     | Active-low asynchronous reset           |
| `clk_enable`| input     | 1     | Clock enable                            |
| `dataIn`    | input     | 16    | sfix16_En15 input sample                |
| `validIn`   | input     | 1     | Input valid strobe                      |
| `RIn`       | input     | 12    | Requested decimation factor (ufix12)    |
| `resetIn`   | input     | 1     | Synchronous reset for comb sections     |
| `ce_out`    | output    | 1     | Clock enable passthrough                |
| `dataOut`   | output    | 16    | sfix16_En15 decimated output            |
| `validOut`  | output    | 1     | Output valid strobe                     |

---

### Fractional Decimator

A **3/2 polyphase FIR** rate converter performing fractional-ratio decimation (e.g. 9 MHz → 6 MHz).

#### Module Hierarchy

```
fractional_decimator_block (FinalFractionalDecimator.v)
└── dsphdl_FIRRateConverter (dsphdl_FIRRateConverter.v)
    ├── FIR_Rate_Converter_Controller   # Polyphase schedule controller
    └── FIR_Rate_Conversion_Filter      # 72-tap polyphase FIR engine
```

#### `FIR_Rate_Converter_Controller`

Manages the polyphase commutation schedule for a 3/2 conversion (3 outputs per 2 inputs):

- Alternates between needing 1 and 2 input samples per output
- Outputs a `phase` signal (0 or 1) and `phaseValid` strobe
- Asserts `ready` when the filter core may advance

#### `FIR_Rate_Conversion_Filter`

A fully pipelined 72-tap polyphase FIR with a 7-stage adder tree:

| Parameter         | Value              |
|-------------------|--------------------|
| Taps              | 72                 |
| Phases            | 2                  |
| Coefficient width | 20-bit (`sfix20`)  |
| Data width        | 16-bit (`sfix16_En15`) |
| Product width     | 36-bit             |
| Adder tree stages | 7                  |
| Pipeline latency  | 10 cycles          |
| Coefficient source| `coeffs.mem` (hex) |

**Adder tree structure:**

```
72 products → 36 sums (stage 0) → 18 (stage 1) → 9 (stage 2) →
5 (stage 3) → 3 (stage 4) → 2 (stage 5) → 1 final sum (stage 6)
```

---

## Fixed-Point Arithmetic

All modules use a uniform Q15 (1 sign bit + 15 fractional bits) representation throughout the chain:

| Stage            | Input format   | Internal format | Output format   |
|------------------|----------------|-----------------|-----------------|
| Notch filter     | sfix16_En15    | sfix16_En15     | sfix16_En15     |
| CIC integrators  | sfix16_En15    | sfix20_En15     | sfix20_En15     |
| CIC comb         | sfix20_En15    | sfix20_En15     | sfix20_En15     |
| CIC cast         | sfix20_En15    | sfix32 (temp)   | sfix16_En15     |
| Fractional FIR   | sfix16_En15    | sfix36 (product)| sfix16_En15     |

The `castSection` performs round-to-nearest and saturation when truncating from 20-bit to 16-bit. The `fir_output_formatter` implements **convergent rounding (tie-to-even)** followed by 16-bit signed saturation.

---

## Golden Models

Each filter stage has a Python reference model that generates expected outputs for RTL comparison:

| Stage            | Reference file              | Framework           | Input rate | Output rate |
|------------------|-----------------------------|---------------------|------------|-------------|
| Notch 2.4 MHz    | `FINAL_notch_goldenmodel2.4.ipynb` | NumPy/SciPy    | 6 MHz      | 6 MHz       |
| Notch 5 MHz      | `notch_goldenmodel5.ipynb`  | NumPy/SciPy         | 6 MHz      | 6 MHz       |
| CIC decimator    | `CIC_gm.py`                 | NumPy (RTL-accurate)| 6 MHz      | 6/R MHz     |
| Fractional dec.  | `Fractional_gm.ipynb`       | NumPy/SciPy         | 9 MHz      | 6 MHz       |

The CIC golden model (`CIC_gm.py`) is written to precisely mirror the RTL's fixed-point saturation behavior: it replicates the 20-bit accumulator overflow wrapping, sign-extension between stages, and the truncation-only cast (no normalization) from 20-bit to 16-bit output.

---

## Simulation Setup

### Requirements

- **Simulator:** ModelSim / QuestaSim
- **Language:** Verilog-2001, SystemVerilog (IEEE 1800)
- **Python:** 3.x with NumPy, SciPy (for golden models)
- **MATLAB** (optional): HDL Coder 25.2 to regenerate RTL from source

### CIC Decimator

```tcl
cd CIC_decimator/testbench/
vsim -do run.do
```

The script compiles all CIC RTL modules plus the testbench with coverage enabled, then simulates. The testbench:
- Generates a 100 MHz clock
- Applies 10-cycle reset, pulses `resetIn` for comb initialization
- Reads stimulus from `cic_stimulus.txt` (16-bit signed samples, one per line)
- Skips the first 6 output samples (pipeline warm-up)
- Writes steady-state output to `cic_tb_out.txt`
- Default `R = 8`

### Fractional Decimator

```tcl
cd fractional_decimator/testbench/
vsim -do run.do
```

The testbench:
- Generates a 9 MHz clock (55.555 ns half-period)
- Reads 32,768 samples from `frac_stimulus.txt`
- Drives `validIn` continuously after reset
- Captures all `validOut` samples to `rtl_out_frac.csv`

### Notch Filters

```tcl
cd notch_filter/2.4MHz_notch/testbench/
# (no .do file provided; compile and simulate manually)
vlog ../RTL_16_coe/*.v tb_notch_filter.v
vsim work.tb_final_first_notch24
run -all
```

The testbench reads from `notch_stimulus.txt` (16,384 samples) and writes filtered output to `tb_out_final.txt`.

### Comparing RTL vs. Golden Model

After simulation, run the corresponding Python comparison notebook or script:

```bash
# CIC
cd CIC_decimator/
python Comparsion.py      # or open comparison.ipynb

# Fractional decimator
cd fractional_decimator/
jupyter notebook Comparison.ipynb

# Notch filters
cd notch_filter/2.4MHz_notch/golden_model/
jupyter notebook FINAL_notch_goldenmodel2.4.ipynb
```

---

## File Reference

| File | Description |
|------|-------------|
| `finalCIC.sv` | CIC top-level with SVA assertion on valid R values |
| `CICDecimation.v` | CIC pipeline: input delay, R control, section instantiation |
| `iSection.v` | 4-stage CIC integrator (MATLAB HDL Coder generated) |
| `dsSection.v` | Configurable downsampler with 6-bit counter |
| `cSection.v` | 4-stage CIC comb section |
| `gcSection.v` | Gain compensation (identity in current config) |
| `castSection.v` | sfix20→sfix16 saturating cast with optional right-shift |
| `fir_output_formatter.v` | Convergent rounding + saturation formatter |
| `FinalFractionalDecimator.v` | Fractional decimator top-level wrapper |
| `dsphdl_FIRRateConverter.v` | FIR rate converter structural top (HDL IP Designer) |
| `FIR_Rate_Conversion_Filter.v` | 72-tap polyphase FIR, 7-stage adder tree, 10-cycle pipeline |
| `FIR_Rate_Converter_Controller.v` | Polyphase phase scheduler for 3/2 conversion |
| `FinalFirstNotch24.v` | 2.4 MHz notch filter top (16-bit coeff variant) |
| `Final20Notch24.v` | 2.4 MHz notch filter top (20-bit coeff variant) |
| `Final20Notch5.v` | 5 MHz notch filter top (20-bit coeff) |
| `dsphdl_BiquadFilter.v` | Biquad IIR filter core (HDL IP Designer generated) |
| `BiquadDF2Section1.v` | Direct Form II biquad second-order section |
| `CIC_gm.py` | RTL-accurate Python CIC golden model |
| `*.ipynb` | Jupyter notebooks for golden model generation and comparison |
| `*_expected*.txt` | Pre-computed golden output files for regression |
| `*_stimulus.txt` | Simulation input stimulus files (signed decimal integers) |
| `rtl_out_frac.csv` | RTL simulation output for fractional decimator |
| `cic_tb_out.txt` | RTL simulation output for CIC decimator |
| `tb_out_final.txt` | RTL simulation output for notch filters |
| `run.do` | ModelSim TCL compile and simulation scripts |
| `Digital_Track_Problem_Statement.pdf` | Original SI-Clash competition problem statement |
| `Final_Report_SI_Clash.pdf` | Full project report submitted to the competition |

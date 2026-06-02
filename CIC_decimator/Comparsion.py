import numpy as np

# ======================================================
# Load CIC RTL and golden model outputs
# ======================================================
rtl_file    = "cic_tb_out.txt"
golden_file = "cic_expected.txt"

rtl_out    = np.loadtxt(rtl_file, dtype=np.int32)
golden_out = np.loadtxt(golden_file, dtype=np.int32)

# ======================================================
# Skip non-steady-state samples
# ======================================================
skip_gold = 13  # golden model warm-up
skip_rtl  = 6   # RTL pipeline flush

gold_ss = golden_out[skip_gold:]
rtl_ss  = rtl_out[skip_rtl:]

# Align lengths
N = min(len(gold_ss), len(rtl_ss))
gold_ss = gold_ss[:N]
rtl_ss  = rtl_ss[:N]

# ======================================================
# RMS calculations
# ======================================================
def rms(signal):
    return np.sqrt(np.mean(signal.astype(np.int64)**2))

rms_rtl    = rms(rtl_ss)
rms_golden = rms(gold_ss)

# RMS error (difference signal)
diff       = rtl_ss.astype(np.int64) - gold_ss.astype(np.int64)
rms_error  = rms(diff)

# Normalized error (relative to golden RMS)
norm_error = rms_error / rms_golden if rms_golden > 0 else float('nan')

# ======================================================
# Print results
# ======================================================
print("=== CIC RMS Comparison (Steady-State Only) ===")
print(f"Golden RMS   = {rms_golden:.2f}")
print(f"RTL RMS      = {rms_rtl:.2f}")
print(f"RMS Error    = {rms_error:.2f}")
print(f"Relative Err = {norm_error*100:.4f}%")

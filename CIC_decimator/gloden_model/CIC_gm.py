import numpy as np

# ======================================================
# Settings
# ======================================================
Fs_in   = 6_000_000   # input sample rate
N_samps = 16384       # stimulus length
R       = 8           # decimation factor (1,2,4,8,16)

INT16_MIN, INT16_MAX = -32768, 32767

stim_file = "cic_stimulus.txt"
exp_file  = "cic_expected.txt"

# ======================================================
# Fixed-point helpers
# ======================================================
def sat_to_width(x, bits):
    mask = (1 << bits) - 1
    y = x & mask
    sign_bit = 1 << (bits - 1)
    return y - (1 << bits) if (y & sign_bit) else y

def sign_extend(x, from_bits, to_bits):
    y = sat_to_width(x, from_bits)
    sign_bit = 1 << (from_bits - 1)
    if y & sign_bit:
        return y | (~((1 << from_bits) - 1))
    else:
        return y & ((1 << from_bits) - 1)

def sanitize_R(R):
    return R if R in (1,2,4,8,16) else 1

# ======================================================
# CIC core (RTL-accurate truncation, no normalization)
# ======================================================
def cic_core(input_q15, R):
    R = sanitize_R(R)
    i1=i2=i3=i4=0
    d1=d2=d3=d4=0
    cnt=0
    outputs=[]
    for x_raw in input_q15:
        x21 = sign_extend(int(x_raw),16,21)
        i1 = sat_to_width(i1+x21,21); i1_20=sat_to_width(i1,20)
        i2 = sat_to_width(i2+sign_extend(i1_20,20,21),21); i2_20=sat_to_width(i2,20)
        i3 = sat_to_width(i3+sign_extend(i2_20,20,21),21); i3_20=sat_to_width(i3,20)
        i4 = sat_to_width(i4+sign_extend(i3_20,20,21),21); i4_20=sat_to_width(i4,20)
        if cnt==0:
            ds=i4_20
            sub1=sat_to_width(sign_extend(ds,20,21)-sign_extend(d1,20,21),21); y1=sat_to_width(sub1,20); d1=ds
            sub2=sat_to_width(sign_extend(y1,20,21)-sign_extend(d2,20,21),21); y2=sat_to_width(sub2,20); d2=y1
            sub3=sat_to_width(sign_extend(y2,20,21)-sign_extend(d3,20,21),21); y3=sat_to_width(sub3,20); d3=y2
            sub4=sat_to_width(sign_extend(y3,20,21)-sign_extend(d4,20,21),21); y4=sat_to_width(sub4,20); d4=y3
            out32 = sign_extend(y4,20,32)
            outputs.append(out32)
        cnt = cnt+1 if cnt<(R-1) else 0
    return np.array(outputs,dtype=np.int32)

# ======================================================
# Stimulus generation
# ======================================================
def generate_stimulus(Fs, N):
    t = np.arange(N) / Fs
    # Mixed-tone stimulus
    x_float = 0.6*np.sin(2*np.pi*200e3*t) + 0.2*np.sin(2*np.pi*900e3*t)
    x_q15   = np.clip(np.round(x_float * 32768), INT16_MIN, INT16_MAX).astype(np.int16)
    return x_q15

# ======================================================
# Main
# ======================================================
if __name__ == "__main__":
    x_q15 = generate_stimulus(Fs_in, N_samps)
    y32   = cic_core(x_q15, R)

    # Write stimulus (inputs)
    with open(stim_file,"w") as f:
        for v in x_q15:
            f.write(f"{int(v)}\n")

    # Write expected outputs
    with open(exp_file,"w") as f:
        for v in y32:
            f.write(f"{int(v)}\n")

    print(f"[SUCCESS] Stimulus written to {stim_file}, Expected outputs written to {exp_file}")
    print(f"[INFO] R={R}, Output samples={len(y32)}")
    print(f"[INFO] Output range: {y32.min()}..{y32.max()}")
